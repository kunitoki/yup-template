cmake_minimum_required(VERSION 3.31)

# =============================================================================
# DSP micro-benchmarks (google/benchmark).
#
# When the plugin is built the benchmarks link its core, so they can measure
# the real processor, with every YUP module and embedded resource it uses, next
# to the header-only sound engine (source/shared/dsp). Without the plugin they
# only see the header-only, standard-library code.
#
# Built by default (-DBUILD_BENCHMARKS=OFF to skip). Build the
# `${PROJECT_NAME}_benchmarks_run` target to build and run them from any build
# folder, or use `just bench`.
# =============================================================================

set (BENCHMARK_ENABLE_TESTING OFF CACHE BOOL "" FORCE)
set (BENCHMARK_ENABLE_INSTALL OFF CACHE BOOL "" FORCE)
set (BENCHMARK_ENABLE_GTEST_TESTS OFF CACHE BOOL "" FORCE)
set (BENCHMARK_ENABLE_WERROR OFF CACHE BOOL "" FORCE)

_yup_fetchcontent_declare (benchmark
    GIT_REPOSITORY https://github.com/google/benchmark.git
    GIT_TAG v1.10.0)

FetchContent_MakeAvailable (benchmark)

set_target_properties (benchmark PROPERTIES FOLDER "Benchmarks")
set_target_properties (benchmark_main PROPERTIES FOLDER "Benchmarks")

set (target_name ${PROJECT_NAME}_benchmarks)

file (GLOB benchmark_sources "${CMAKE_CURRENT_LIST_DIR}/bench_*.cpp")
list (APPEND benchmark_sources "${CMAKE_CURRENT_LIST_DIR}/main.cpp")

# The processor benchmarks need the plugin core.
if (NOT BUILD_PLUGIN OR NOT TARGET ${PLUGIN_TARGET}_shared)
    list (REMOVE_ITEM benchmark_sources "${CMAKE_CURRENT_LIST_DIR}/bench_PluginProcessor.cpp")
endif()

add_executable (${target_name} ${benchmark_sources})

target_include_directories (${target_name} PRIVATE "${CMAKE_CURRENT_LIST_DIR}/../source/shared")
target_link_libraries (${target_name} PRIVATE benchmark::benchmark)

if (BUILD_PLUGIN AND TARGET ${PLUGIN_TARGET}_shared)
    # The core is compiled against SDL without linking it: each binary brings its own.
    target_include_directories (${target_name} PRIVATE "${CMAKE_CURRENT_LIST_DIR}/../source/plugin")
    target_link_libraries (${target_name} PRIVATE ${PLUGIN_TARGET}_shared sdl::sdl)
    target_compile_definitions (${target_name} PRIVATE BENCHMARKS_USE_PLUGIN_CORE=1)
endif()

source_group (TREE ${CMAKE_CURRENT_LIST_DIR}/ FILES ${benchmark_sources})

set_target_properties (${target_name} PROPERTIES
    FOLDER "Benchmarks"
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED ON
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
    XCODE_GENERATE_SCHEME ON
    XCODE_SCHEME_ARGUMENTS "--benchmark_counters_tabular=true"
    VS_DEBUGGER_COMMAND_ARGUMENTS "--benchmark_counters_tabular=true")

# Builds and runs the benchmarks of the selected configuration.
add_custom_target (${target_name}_run
    COMMAND ${target_name} --benchmark_counters_tabular=true
    USES_TERMINAL
    VERBATIM)

set_target_properties (${target_name}_run PROPERTIES FOLDER "Benchmarks")
