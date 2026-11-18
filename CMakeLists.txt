# =============================================================================
# YUP TEMPLATE - CMakeLists.txt
# =============================================================================
# This is a template for creating cross-platform standalone applications and
# audio plugins (CLAP, VST3, AU, AUv3, LV2, AAX and a Standalone app) with the
# YUP framework. Both targets live in the same source tree and are built by
# default - turn off the one you don't need with -DBUILD_APP=OFF or
# -DBUILD_PLUGIN=OFF. Customize the variables below to match your project.
# =============================================================================

cmake_minimum_required (VERSION 3.31)

# =============================================================================
# TEMPLATE UTILITIES
# =============================================================================
# Shared helper macros (version parsing, Apple deployment target detection).
include (${CMAKE_CURRENT_SOURCE_DIR}/cmake/utilities.cmake)

# Read the version from the VERSION file for centralized version control. This
# sets CURRENT_VERSION, VERSION_MAJOR, VERSION_MINOR and VERSION_PATCH.
yup_template_read_version ("${CMAKE_CURRENT_SOURCE_DIR}/VERSION")

# Detect the minimum Apple deployment target supported by the installed Xcode
# and set CMAKE_OSX_DEPLOYMENT_TARGET accordingly (no-op on other hosts).
yup_template_setup_deployment_target ()

# =============================================================================
# PROJECT CONFIGURATION - CHANGE THESE VALUES FOR YOUR PROJECT!
# =============================================================================
# Every value below must stay a plain literal string: the justfile, the CI
# workflows and the packaging scripts parse this block to stay in sync with
# CMake, and they cannot expand ${variable} references.

# The internal name of the project and the prefix of every target (no spaces).
set (PROJECT_NAME "YupTemplate")

# The display name of the whole product, used for the installers and archives.
set (PRODUCT_NAME "YUP Template")

# Short descriptive text for the product.
set (PRODUCT_DESCRIPTION "A cross-platform application and audio plugin built with YUP.")

# Company / author name, used for attribution, bundle ids and code signing.
set (COMPANY_NAME "YUP Audio")

# Bundle identifier of the product for macOS/iOS (reverse domain notation).
set (BUNDLE_ID "audio.yup.yuptemplate")

# Your website / support URL.
set (PRODUCT_URL "https://github.com/kunitoki/yup-template")

# Contact e-mail embedded in the application and plugin metadata.
set (PRODUCT_EMAIL "support@yourcompany.com")

# Application icon file (path to .png).
set (APPLICATION_ICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/app-icon.png")

# --- Standalone application --------------------------------------------------

# The display name of the application shown to users (spaces allowed). It is the
# name of the generated executable / .app bundle, so it must differ from
# PLUGIN_PRODUCT_NAME when both targets are built.
set (APP_PRODUCT_NAME "YUP Application")

# Bundle identifier of the application for macOS/iOS (reverse domain notation).
set (APP_BUNDLE_ID "audio.yup.yuptemplate.app")

# --- Audio plugin ------------------------------------------------------------

# The display name of the plugin shown to users (spaces allowed). It is also the
# name of the standalone application shipped with the plugin formats.
set (PLUGIN_PRODUCT_NAME "YUP Instrument")

# Bundle identifier prefix of the plugin for macOS/iOS (reverse domain notation).
set (PLUGIN_BUNDLE_ID "audio.yup.yuptemplate.plugin")

# Short descriptive text for the plugin.
set (PLUGIN_DESCRIPTION "A simple polyphonic instrument built with YUP.")

# Four character codes. These are case sensitive and must stay stable once shipped.
set (PLUGIN_CODE "YpIn")              # Unique plugin id (AU subtype / AAX product id)
set (PLUGIN_MANUFACTURER_CODE "Yup!") # Manufacturer id (exactly 4 characters, one uppercase)

# AAX plugin category.
set (PLUGIN_AAX_CATEGORY "AAX_ePlugInCategory_SWGenerators")

# --- Packaging ---------------------------------------------------------------

# Unique id of the Windows installer (Inno Setup AppId). Generate your own GUID
# for a real product (e.g. `powershell [guid]::NewGuid()`) and keep it stable
# across releases so upgrades replace the previous installation.
set (INSTALLER_GUID "28F190D9-1045-4E2D-B7BC-F7D875542C27")

# Version can be overridden via command line: cmake -DTARGET_VERSION="2.0.0" ..
set (TARGET_VERSION "${CURRENT_VERSION}" CACHE STRING "Product version")

# =============================================================================
# BUILD OPTIONS & FEATURES
# =============================================================================

option (BUILD_APP "Build the standalone application" ON)
option (BUILD_PLUGIN "Build the audio plugin" ON)
option (BUILD_TESTS "Build test suite" ON)
option (BUILD_BENCHMARKS "Build the DSP micro-benchmarks (google/benchmark)" ON)
option (ENABLE_COVERAGE "Enable code coverage analysis (requires lcov/gcov)" OFF)
option (ENABLE_CODE_SIGNING "Enable code signing (macOS/iOS)" OFF)

# Plugin formats to build. Toggle these to match your distribution targets.
option (PLUGIN_BUILD_CLAP "Build the CLAP format" ON)
option (PLUGIN_BUILD_VST3 "Build the VST3 format" ON)
option (PLUGIN_BUILD_AU "Build the Audio Unit format (macOS)" ON)
option (PLUGIN_BUILD_AUV3 "Build the Audio Unit v3 app extension" ON)
option (PLUGIN_BUILD_LV2 "Build the LV2 format" ON)
option (PLUGIN_BUILD_STANDALONE "Build the Standalone application of the plugin" ON)

# Code signing configuration (macOS/iOS).
set (MACOS_SIGNING_IDENTITY "" CACHE STRING "macOS code signing identity")
set (DEVELOPMENT_TEAM_ID "" CACHE STRING "Apple Developer Team ID")

if (NOT BUILD_APP AND NOT BUILD_PLUGIN)
    message (FATAL_ERROR "Nothing to build: enable at least one of BUILD_APP and BUILD_PLUGIN.")
endif()

# =============================================================================
# PROJECT DECLARATION
# =============================================================================

set (_template_project_languages C CXX)
if (CMAKE_HOST_APPLE)
  list (APPEND _template_project_languages OBJC OBJCXX)
endif()

project (${PROJECT_NAME} VERSION ${TARGET_VERSION} LANGUAGES ${_template_project_languages})

# The application and the plugin are two separate targets built from the same
# source tree. The plugin keeps the bare project name so that the generated
# plugin bundles are named "<PROJECT_NAME>_<format>_plugin".
set (APP_TARGET "${PROJECT_NAME}_app")
set (PLUGIN_TARGET "${PROJECT_NAME}")

# =============================================================================
# YUP FRAMEWORK SETUP
# =============================================================================

set (YUP_BUILD_EXAMPLES OFF)
set (YUP_BUILD_PLUGINS OFF)
set (YUP_BUILD_TESTS OFF)
set (YUP_ENABLE_VST3_VALIDATOR ON)
set (YUP_ENABLE_CLAP_VALIDATOR ON)
set (YUP_ENABLE_AUVAL_VALIDATOR ON)
set (YUP_ENABLE_PLUGINVAL ON)
add_subdirectory (yup)

# =============================================================================
# SOURCE FILES
# =============================================================================
# source/app     - the standalone application
# source/plugin  - the audio processor and its editor
# source/shared  - code used by both targets (and by the tests and benchmarks)

file (GLOB_RECURSE APP_SOURCES
  CONFIGURE_DEPENDS
  "${CMAKE_CURRENT_SOURCE_DIR}/source/app/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/source/app/*.h"
)

file (GLOB_RECURSE PLUGIN_SOURCES
  CONFIGURE_DEPENDS
  "${CMAKE_CURRENT_SOURCE_DIR}/source/plugin/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/source/plugin/*.h"
)

file (GLOB_RECURSE SHARED_SOURCES
  CONFIGURE_DEPENDS
  "${CMAKE_CURRENT_SOURCE_DIR}/source/shared/*.cpp"
  "${CMAKE_CURRENT_SOURCE_DIR}/source/shared/*.h"
)

source_group (TREE ${CMAKE_CURRENT_SOURCE_DIR}/source PREFIX "Source Files"
  FILES ${APP_SOURCES} ${PLUGIN_SOURCES} ${SHARED_SOURCES})

# =============================================================================
# AUDIO PLUGIN TARGET
# =============================================================================
# Declared before the application because Android generates a single APK entry
# point per build: the application target wins when both are enabled.

if (BUILD_PLUGIN)
    # ==== AAX (optional, auto-detected)
    # AAX requires the Avid SDK. If YUP_AAX_SDK_ROOT is set (env or cache) the
    # AAX target is enabled automatically.
    set (plugin_create_aax OFF)
    if (DEFINED YUP_AAX_SDK_ROOT OR DEFINED ENV{YUP_AAX_SDK_ROOT})
        if (DEFINED ENV{YUP_AAX_SDK_ROOT} AND NOT DEFINED YUP_AAX_SDK_ROOT)
            set (YUP_AAX_SDK_ROOT "$ENV{YUP_AAX_SDK_ROOT}" CACHE PATH "Path to the AAX SDK")
        endif()
        message (STATUS "AAX SDK using YUP_AAX_SDK_ROOT: ${YUP_AAX_SDK_ROOT}")
        set (plugin_create_aax ON)
    endif()

    yup_audio_plugin (
        TARGET_NAME ${PLUGIN_TARGET}
        TARGET_VERSION ${TARGET_VERSION}
        TARGET_APP_ID "${PLUGIN_BUNDLE_ID}"
        TARGET_APP_NAMESPACE "${PLUGIN_BUNDLE_ID}"
        TARGET_CXX_STANDARD 20
        TARGET_IDE_GROUP "Plugin"
        TARGET_ICON "${APPLICATION_ICON}"

        PLUGIN_ID "${PLUGIN_BUNDLE_ID}"
        PLUGIN_NAME "${PLUGIN_PRODUCT_NAME}"
        PLUGIN_VENDOR "${COMPANY_NAME}"
        PLUGIN_EMAIL "${PRODUCT_EMAIL}"
        PLUGIN_VERSION "${TARGET_VERSION}"
        PLUGIN_DESCRIPTION "${PLUGIN_DESCRIPTION}"
        PLUGIN_URL "${PRODUCT_URL}"

        PLUGIN_IS_SYNTH ON
        PLUGIN_IS_MONO OFF

        PLUGIN_CREATE_CLAP ${PLUGIN_BUILD_CLAP}
        PLUGIN_CREATE_VST3 ${PLUGIN_BUILD_VST3}
        PLUGIN_CREATE_AU ${PLUGIN_BUILD_AU}
        PLUGIN_CREATE_AUv3 ${PLUGIN_BUILD_AUV3}
        PLUGIN_CREATE_LV2 ${PLUGIN_BUILD_LV2}
        PLUGIN_CREATE_STANDALONE ${PLUGIN_BUILD_STANDALONE}
        PLUGIN_CREATE_AAX ${plugin_create_aax}

        PLUGIN_AU_MANUFACTURER "${PLUGIN_MANUFACTURER_CODE}"
        PLUGIN_AU_SUBTYPE "${PLUGIN_CODE}"
        PLUGIN_AAX_MANUFACTURER_ID "${PLUGIN_MANUFACTURER_CODE}"
        PLUGIN_AAX_PRODUCT_ID "${PLUGIN_CODE}"
        PLUGIN_AAX_CATEGORY "${PLUGIN_AAX_CATEGORY}"

        PLUGIN_COPY_AFTER_BUILD ON

        MODULES
          yup::yup_gui
          yup::yup_audio_processors
          yup::yup_audio_gui
    )

    # The plugin sources compile once into the shared plugin core.
    target_sources (${PLUGIN_TARGET}_shared PRIVATE ${PLUGIN_SOURCES} ${SHARED_SOURCES})
    target_include_directories (${PLUGIN_TARGET}_shared PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/source/plugin"
        "${CMAKE_CURRENT_SOURCE_DIR}/source/shared")
endif()

# =============================================================================
# APPLICATION TARGET
# =============================================================================

if (BUILD_APP)
    yup_standalone_app (
        TARGET_NAME ${APP_TARGET}
        TARGET_PRODUCT_NAME "${APP_PRODUCT_NAME}"
        TARGET_VERSION ${TARGET_VERSION}
        TARGET_IDE_GROUP "Application"
        TARGET_APP_ID "${APP_BUNDLE_ID}"
        TARGET_APP_NAMESPACE "${APP_BUNDLE_ID}"
        TARGET_CXX_STANDARD 20
        TARGET_ICON "${APPLICATION_ICON}"

        DEFINITIONS
          YupApp_Name="${APP_PRODUCT_NAME}"
          YupApp_Version="${TARGET_VERSION}"

        MODULES
          yup::yup_core
          yup::yup_events
          yup::yup_graphics
          yup::yup_gui

        SOURCES
          ${APP_SOURCES}
          ${SHARED_SOURCES}
    )

    # On Android yup_standalone_app only generates the Gradle project, so the
    # target itself does not exist at this point.
    if (TARGET ${APP_TARGET})
        target_include_directories (${APP_TARGET} PRIVATE
            "${CMAKE_CURRENT_SOURCE_DIR}/source/app"
            "${CMAKE_CURRENT_SOURCE_DIR}/source/shared")
    endif()
endif()

# =============================================================================
# AGGREGATE TARGET
# =============================================================================
# Builds every enabled target at once. Used by `just build` and by the CI
# workflows, so they do not have to know which targets are enabled.

set (_template_all_targets "")
if (TARGET ${PLUGIN_TARGET})
    list (APPEND _template_all_targets ${PLUGIN_TARGET})
endif()
if (TARGET ${APP_TARGET})
    list (APPEND _template_all_targets ${APP_TARGET})
endif()

if (_template_all_targets)
    add_custom_target (${PROJECT_NAME}_all DEPENDS ${_template_all_targets})
    set_target_properties (${PROJECT_NAME}_all PROPERTIES XCODE_GENERATE_SCHEME ON)
endif()

# =============================================================================
# CODE SIGNING (macOS)
# =============================================================================

if (APPLE AND ENABLE_CODE_SIGNING AND MACOS_SIGNING_IDENTITY)
    set (signable_targets ${APP_TARGET})
    foreach (plugin_format clap vst3 au auv3 lv2 standalone aax)
        list (APPEND signable_targets ${PLUGIN_TARGET}_${plugin_format}_plugin)
    endforeach()

    foreach (signable_target ${signable_targets})
        if (TARGET ${signable_target})
            set_target_properties (${signable_target} PROPERTIES
                XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "${MACOS_SIGNING_IDENTITY}"
                XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${DEVELOPMENT_TEAM_ID}"
                XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Manual")
        endif()
    endforeach()
    message (STATUS "macOS Code Signing: ${MACOS_SIGNING_IDENTITY}")
endif()

# =============================================================================
# TESTING
# =============================================================================

if (BUILD_TESTS AND NOT YUP_PLATFORM_MOBILE)
    enable_testing()
    add_subdirectory (tests)
    message (STATUS "Building test suite")
endif()

if (BUILD_BENCHMARKS AND NOT YUP_PLATFORM_MOBILE AND NOT YUP_PLATFORM_EMSCRIPTEN)
    add_subdirectory (benchmarks)
    message (STATUS "Building DSP benchmarks")
endif()
