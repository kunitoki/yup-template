# =============================================================================
# YUP TEMPLATE - cmake/utilities.cmake
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
# yup_template_read_version (<version_file>)
#
# Reads the project version from <version_file> for centralized version control
# and defines in the calling scope:
#
#   CURRENT_VERSION - the whole version string (e.g. "1.2.3")
#   VERSION_MAJOR   - the major component
#   VERSION_MINOR   - the minor component
#   VERSION_PATCH   - the patch component
# -----------------------------------------------------------------------------
macro (yup_template_read_version version_file)
  if (NOT EXISTS "${version_file}")
    message (FATAL_ERROR "YUP template: version file not found: ${version_file}")
  endif()

  file (READ "${version_file}" CURRENT_VERSION)
  string (STRIP "${CURRENT_VERSION}" CURRENT_VERSION)
  string (REGEX MATCH "^([0-9]+)\\.([0-9]+)\\.([0-9]+)" _ "${CURRENT_VERSION}")

  if (NOT CMAKE_MATCH_1)
    message (FATAL_ERROR "YUP template: '${CURRENT_VERSION}' in ${version_file} is not a MAJOR.MINOR.PATCH version")
  endif()

  set (VERSION_MAJOR "${CMAKE_MATCH_1}")
  set (VERSION_MINOR "${CMAKE_MATCH_2}")
  set (VERSION_PATCH "${CMAKE_MATCH_3}")
endmacro()

# -----------------------------------------------------------------------------
# yup_template_setup_deployment_target ()
#
# Picks the minimum Apple deployment target supported by the installed Xcode and
# stores it in CMAKE_OSX_DEPLOYMENT_TARGET, unless a higher one was requested on
# the command line. Newer Xcode releases drop support for older deployment
# targets, so the floor is detected from the toolchain itself (mirroring YUP's
# own _yup_apple_setup_deployment_target logic - keep this in sync with YUP).
#
# Does nothing when not building from an Apple host.
# -----------------------------------------------------------------------------
macro (yup_template_setup_deployment_target)
  if (CMAKE_HOST_APPLE)
    set (CMAKE_XCODE_GENERATE_SCHEME OFF)

    if (IOS OR CMAKE_SYSTEM_NAME MATCHES "iOS")
      set (_yup_template_is_mac OFF)
    else()
      set (_yup_template_is_mac ON)
    endif()

    execute_process (COMMAND xcodebuild -version OUTPUT_VARIABLE _yup_template_xcode_version ERROR_QUIET)
    string (REGEX MATCH "Xcode ([0-9]+)" _ "${_yup_template_xcode_version}")
    set (_yup_template_xcode_major "${CMAKE_MATCH_1}")

    if (_yup_template_xcode_major GREATER_EQUAL 27)
      if (_yup_template_is_mac)
        set (_yup_template_min_deployment_target 12.0)
      else()
        set (_yup_template_min_deployment_target 15.0)
      endif()
    else()
      if (_yup_template_is_mac)
        set (_yup_template_min_deployment_target 11.0)
      else()
        set (_yup_template_min_deployment_target 13.0)
      endif()
    endif()

    if (NOT DEFINED CMAKE_OSX_DEPLOYMENT_TARGET OR CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS _yup_template_min_deployment_target)
      set (CMAKE_OSX_DEPLOYMENT_TARGET ${_yup_template_min_deployment_target})
    endif()

    message (STATUS "YUP template: CMAKE_OSX_DEPLOYMENT_TARGET is set to ${CMAKE_OSX_DEPLOYMENT_TARGET}")
  endif()
endmacro()
