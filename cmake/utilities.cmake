# =============================================================================
# cmake/utilities.cmake
# =============================================================================
# Small helpers shared by the project configuration. Include it from the root
# CMakeLists.txt before the project() call:
#
#   include (${CMAKE_CURRENT_SOURCE_DIR}/cmake/utilities.cmake)
#
# Everything here is implemented as a macro so the variables it computes end up
# in the scope of the caller.
# =============================================================================

# -----------------------------------------------------------------------------
# project_read_version (<version_file>)
#
# Reads the project version from <version_file> for centralized version control
# and defines in the calling scope:
#
#   CURRENT_VERSION - the whole version string (e.g. "1.2.3")
#   VERSION_MAJOR   - the major component
#   VERSION_MINOR   - the minor component
#   VERSION_PATCH   - the patch component
# -----------------------------------------------------------------------------
macro (project_read_version version_file)
  if (NOT EXISTS "${version_file}")
    message (FATAL_ERROR "Version file not found: ${version_file}")
  endif()

  file (READ "${version_file}" CURRENT_VERSION)
  string (STRIP "${CURRENT_VERSION}" CURRENT_VERSION)
  string (REGEX MATCH "^([0-9]+)\\.([0-9]+)\\.([0-9]+)" _ "${CURRENT_VERSION}")

  if (NOT CMAKE_MATCH_1)
    message (FATAL_ERROR "'${CURRENT_VERSION}' in ${version_file} is not a MAJOR.MINOR.PATCH version")
  endif()

  set (VERSION_MAJOR "${CMAKE_MATCH_1}")
  set (VERSION_MINOR "${CMAKE_MATCH_2}")
  set (VERSION_PATCH "${CMAKE_MATCH_3}")
endmacro()

# -----------------------------------------------------------------------------
# project_setup_deployment_target ()
#
# Picks the minimum Apple deployment target supported by the installed Xcode and
# stores it in CMAKE_OSX_DEPLOYMENT_TARGET, unless a higher one was requested on
# the command line. Newer Xcode releases drop support for older deployment
# targets, so the floor is detected from the toolchain itself (mirroring YUP's
# own _yup_apple_setup_deployment_target logic - keep this in sync with YUP).
#
# Does nothing when not building from an Apple host.
# -----------------------------------------------------------------------------
macro (project_setup_deployment_target)
  if (CMAKE_HOST_APPLE)
    set (CMAKE_XCODE_GENERATE_SCHEME OFF)

    if (IOS OR CMAKE_SYSTEM_NAME MATCHES "iOS" OR CMAKE_TOOLCHAIN_FILE MATCHES ".*ios\\.cmake$")
      set (_project_is_mac OFF)
    else()
      set (_project_is_mac ON)
    endif()

    execute_process (COMMAND xcodebuild -version OUTPUT_VARIABLE _project_xcode_version ERROR_QUIET)
    string (REGEX MATCH "Xcode ([0-9]+)" _ "${_project_xcode_version}")
    set (_project_xcode_major "${CMAKE_MATCH_1}")

    if (_project_xcode_major GREATER_EQUAL 27)
      if (_project_is_mac)
        set (_project_min_deployment_target 12.0)
      else()
        set (_project_min_deployment_target 15.0)
      endif()
    else()
      if (_project_is_mac)
        set (_project_min_deployment_target 11.0)
      else()
        set (_project_min_deployment_target 13.0)
      endif()
    endif()

    if (NOT DEFINED CMAKE_OSX_DEPLOYMENT_TARGET OR CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS _project_min_deployment_target)
      set (CMAKE_OSX_DEPLOYMENT_TARGET ${_project_min_deployment_target})
    endif()

    if (NOT _project_is_mac)
      if (NOT DEFINED DEPLOYMENT_TARGET OR DEPLOYMENT_TARGET VERSION_LESS CMAKE_OSX_DEPLOYMENT_TARGET)
        set (DEPLOYMENT_TARGET ${CMAKE_OSX_DEPLOYMENT_TARGET})
      else()
        set (CMAKE_OSX_DEPLOYMENT_TARGET ${DEPLOYMENT_TARGET})
      endif()
    endif()

    message (STATUS "CMAKE_OSX_DEPLOYMENT_TARGET is set to ${CMAKE_OSX_DEPLOYMENT_TARGET}")
  endif()
endmacro()

# -----------------------------------------------------------------------------
# project_check_product_names ()
#
# Stops the configuration when two of the names in the project configuration
# block would end up as the same build output. yup_audio_plugin creates a custom
# target named PROJECT_NAME while the executables are named after their product,
# so a product called like the project makes single-config Ninja stop with
# "multiple rules generate <name>" (and Makefiles drop a circular dependency).
# -----------------------------------------------------------------------------
macro (project_check_product_names)
  if (BUILD_PLUGIN AND "${PLUGIN_PRODUCT_NAME}" STREQUAL "${PROJECT_NAME}")
    message (FATAL_ERROR "PLUGIN_PRODUCT_NAME must differ from PROJECT_NAME (\"${PROJECT_NAME}\"): "
      "the plugin target and the plugin's standalone executable would share one name.")
  endif()

  if (BUILD_PLUGIN AND BUILD_APP AND "${APP_PRODUCT_NAME}" STREQUAL "${PROJECT_NAME}")
    message (FATAL_ERROR "APP_PRODUCT_NAME must differ from PROJECT_NAME (\"${PROJECT_NAME}\"): "
      "the plugin target and the application executable would share one name.")
  endif()

  if (BUILD_PLUGIN AND BUILD_APP AND "${APP_PRODUCT_NAME}" STREQUAL "${PLUGIN_PRODUCT_NAME}")
    message (FATAL_ERROR "APP_PRODUCT_NAME must differ from PLUGIN_PRODUCT_NAME (\"${APP_PRODUCT_NAME}\"): "
      "the application and the plugin's standalone would be the same executable.")
  endif()
endmacro()

# -----------------------------------------------------------------------------
# project_enable_lto (<target>...)
#
# Switches on interprocedural optimisation for the Release configuration of the
# given targets, when the toolchain supports it. Targets that do not exist (a
# format that is switched off) and targets CMake does not compile are skipped.
# Must be called after project().
# -----------------------------------------------------------------------------
function (project_enable_lto)
  include (CheckIPOSupported)
  check_ipo_supported (RESULT ipo_supported OUTPUT ipo_output LANGUAGES C CXX)

  if (NOT ipo_supported)
    message (WARNING "ENABLE_LTO is ON but the toolchain does not support it: ${ipo_output}")
    return()
  endif()

  foreach (lto_target ${ARGN})
    if (NOT TARGET ${lto_target})
      continue()
    endif()

    get_target_property (lto_target_type ${lto_target} TYPE)
    if (lto_target_type STREQUAL "UTILITY" OR lto_target_type STREQUAL "INTERFACE_LIBRARY")
      continue()
    endif()

    set_target_properties (${lto_target} PROPERTIES INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)
  endforeach()

  message (STATUS "Release LTO enabled")
endfunction()
