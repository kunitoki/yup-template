cmake_minimum_required(VERSION 3.31)

enable_testing()

# ==== Setup googletests
if (YUP_PLATFORM_EMSCRIPTEN)
    set (gtest_disable_pthreads ON CACHE BOOL "" FORCE)
    set (gtest_disable_warnings ON CACHE BOOL "" FORCE)
    set (gtest_hide_internal_symbols ON CACHE BOOL "" FORCE)
    add_definitions (-DTEST_HAS_PTHREAD=0)
endif()

set (gtest_force_shared_crt ON CACHE BOOL "" FORCE)

_yup_fetchcontent_declare (googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG v1.17.0)

FetchContent_MakeAvailable (googletest)

if (YUP_PLATFORM_EMSCRIPTEN)
    target_compile_options (gmock PRIVATE -pthread)
    target_compile_options (gtest PRIVATE -pthread)
endif()

set_target_properties (gtest PROPERTIES FOLDER "Tests")
set_target_properties (gtest_main PROPERTIES FOLDER "Tests")
set_target_properties (gmock PROPERTIES FOLDER "Tests")
set_target_properties (gmock_main PROPERTIES FOLDER "Tests")

# ==== Create executable
set (target_name ${PROJECT_NAME}_tests)
set (target_version ${TARGET_VERSION})
set (target_company "${BUNDLE_ID}")
set (target_console OFF)
set (target_gtest_modules "")
set (target_app_modules "")
set (target_definitions "")
set (target_preloaded "")

# On desktop the tests link the plugin core, exactly as the plugin's own
# standalone does: the plugin sources, the YUP modules and the embedded
# resources compile once and the tests see the real YupPlugin_* definitions.
# Without the plugin (or on Emscripten, where only the header-only code is
# tested) the tests compile the YUP modules they need themselves.
set (target_uses_plugin_core OFF)
if (BUILD_PLUGIN AND NOT YUP_PLATFORM_EMSCRIPTEN AND TARGET ${PLUGIN_TARGET}_shared)
    set (target_uses_plugin_core ON)
endif()

if (target_uses_plugin_core)
    list (APPEND target_app_modules
        ${PLUGIN_TARGET}_shared)
else()
    list (APPEND target_app_modules
        yup::yup_core
        yup::yup_events
        yup::yup_graphics)
    list (APPEND target_definitions
        YUP_USE_CURL=0
        YUP_MODAL_LOOPS_PERMITTED=1)
endif()

if (NOT YUP_PLATFORM_EMSCRIPTEN)
    if (NOT target_uses_plugin_core)
        list (APPEND target_app_modules
            yup::yup_gui)
    endif()
    list (APPEND target_gtest_modules
        GTest::gtest
        GTest::gmock)
else()
    set (target_console ON)
    list (APPEND target_gtest_modules
        GTest::gtest
        GTest::gmock)

    file (GLOB_RECURSE data_files "${CMAKE_CURRENT_LIST_DIR}/data/*")
    foreach (data_file ${data_files})
        file (RELATIVE_PATH rel_path "${CMAKE_CURRENT_LIST_DIR}" "${data_file}")
        list (APPEND target_preloaded "${data_file}@${rel_path}")
    endforeach()
endif()

yup_standalone_app (
    TARGET_NAME ${target_name}
    TARGET_VERSION ${target_version}
    TARGET_IDE_GROUP "Tests"
    TARGET_APP_ID "${target_company}.${target_name}"
    TARGET_APP_NAMESPACE "${target_company}"
    TARGET_CONSOLE ${target_console}
    DEFINITIONS
        YupApp_Name="${APP_PRODUCT_NAME}"
        YupApp_Version="${TARGET_VERSION}"
        ${target_definitions}
    PRELOAD_FILES
        ${target_preloaded}
    MODULES
        ${target_app_modules}
        ${target_gtest_modules})

# ==== Setup test sources
# The plugin tests only exist when the plugin is built; the DSP tests cover the
# shared sound engine and build everywhere.
file (GLOB test_sources "${CMAKE_CURRENT_LIST_DIR}/test_*.cpp")
list (APPEND test_sources "${CMAKE_CURRENT_LIST_DIR}/main.cpp")

if (NOT target_uses_plugin_core)
    list (REMOVE_ITEM test_sources
        "${CMAKE_CURRENT_LIST_DIR}/test_PluginProcessor.cpp"
        "${CMAKE_CURRENT_LIST_DIR}/test_PluginEditor.cpp")
endif()

target_include_directories (${target_name} PRIVATE
    "${CMAKE_CURRENT_LIST_DIR}"
    "${CMAKE_CURRENT_LIST_DIR}/../source/app"
    "${CMAKE_CURRENT_LIST_DIR}/../source/plugin"
    "${CMAKE_CURRENT_LIST_DIR}/../source/shared")
target_sources (${target_name} PRIVATE ${test_sources})
source_group (TREE ${CMAKE_CURRENT_LIST_DIR}/ FILES ${test_sources})

if (target_uses_plugin_core)
    set (test_helper_headers "${CMAKE_CURRENT_LIST_DIR}/helpers/Helpers.h")
    target_sources (${target_name} PRIVATE ${test_helper_headers})
    source_group (TREE ${CMAKE_CURRENT_LIST_DIR}/ FILES ${test_helper_headers})
endif()

# ==== Reuse YUP's shared GoogleTest runner (adds the runner source + gtest link)
yup_add_test_runner (${target_name})

# ==== Setup target properties
set_target_properties (${target_name} PROPERTIES
    XCODE_SCHEME_ARGUMENTS "--gtest_filter=*"
    VS_DEBUGGER_COMMAND_ARGUMENTS "--gtest_filter=*")

# ==== Register with CTest (desktop only; Emscripten runs via `just emscripten_test`)
if (NOT YUP_PLATFORM_EMSCRIPTEN)
    add_test (NAME ${target_name} COMMAND ${target_name} --gtest_filter=*)
endif()

# ==== Setup coverage support
if (ENABLE_COVERAGE AND (CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang"))
    target_compile_options (${target_name} PRIVATE
        --coverage
        -fprofile-arcs
        -ftest-coverage
        -fprofile-update=atomic
        "$<$<COMPILE_LANGUAGE:CXX>:-fno-elide-constructors>")
    target_link_options (${target_name} PRIVATE --coverage)

    # The plugin sources are compiled by the plugin core, so that is where they
    # have to be instrumented. Everything linking the core needs the runtime.
    if (target_uses_plugin_core)
        target_compile_options (${PLUGIN_TARGET}_shared PRIVATE
            --coverage
            -fprofile-arcs
            -ftest-coverage
            -fprofile-update=atomic
            "$<$<COMPILE_LANGUAGE:CXX>:-fno-elide-constructors>")
        target_link_options (${PLUGIN_TARGET}_shared INTERFACE --coverage)
    endif()

    if (CMAKE_CXX_COMPILER_ID MATCHES "GNU")
        target_link_libraries (${target_name} PRIVATE gcov)
    endif()

    _yup_setup_coverage_targets (${target_name} "")
endif()
