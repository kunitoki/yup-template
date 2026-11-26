#!/usr/bin/env bash
# =============================================================================
# Shared helpers for the packaging scripts.
#
# The product naming is read straight from the project configuration block in
# CMakeLists.txt, so CMake stays the single source of truth: renaming a plugin
# there automatically updates every package.
# Override any value from the environment before invoking a packaging script.
# =============================================================================
set -euo pipefail

PACKAGING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$PACKAGING_DIR/.." && pwd)"
PROJECT_CMAKELISTS="$PROJECT_ROOT/CMakeLists.txt"

# Read a `set (<NAME> "<value>")` entry from the project CMakeLists.txt.
# Usage: cmake_var <NAME>
cmake_var() {
    local name="$1" value
    value="$(sed -n -E "s/^[[:space:]]*set[[:space:]]*\\([[:space:]]*${name}[[:space:]]+\"([^\"]*)\".*/\\1/p" \
        "$PROJECT_CMAKELISTS" | head -n 1)"
    [[ -n "$value" ]] || die "could not read '$name' from $PROJECT_CMAKELISTS"
    printf '%s' "$value"
}

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# The internal project name (see PROJECT_NAME in CMakeLists.txt).
PROJECT_NAME="${PROJECT_NAME:-$(cmake_var PROJECT_NAME)}"

# The user-facing product name (see PRODUCT_NAME in CMakeLists.txt). It names
# the installers and archives that bundle the application and the plugin.
PRODUCT_NAME="${PRODUCT_NAME:-$(cmake_var PRODUCT_NAME)}"

# Short descriptive text for the product (see PRODUCT_DESCRIPTION).
PRODUCT_DESCRIPTION="${PRODUCT_DESCRIPTION:-$(cmake_var PRODUCT_DESCRIPTION)}"

# Short descriptive text for the plugin (see PLUGIN_DESCRIPTION).
PLUGIN_DESCRIPTION="${PLUGIN_DESCRIPTION:-$(cmake_var PLUGIN_DESCRIPTION)}"

# The vendor / author (see COMPANY_NAME in CMakeLists.txt).
COMPANY_NAME="${COMPANY_NAME:-$(cmake_var COMPANY_NAME)}"

# The reverse-domain bundle identifier of the product (see BUNDLE_ID).
BUNDLE_ID="${BUNDLE_ID:-$(cmake_var BUNDLE_ID)}"

# Website / support URL (see PRODUCT_URL in CMakeLists.txt).
PRODUCT_URL="${PRODUCT_URL:-$(cmake_var PRODUCT_URL)}"

# Contact e-mail (see PRODUCT_EMAIL in CMakeLists.txt).
PRODUCT_EMAIL="${PRODUCT_EMAIL:-$(cmake_var PRODUCT_EMAIL)}"

# The name of the standalone application (see APP_PRODUCT_NAME). This is the
# name of the generated executable / .app bundle of the application target.
APP_PRODUCT_NAME="${APP_PRODUCT_NAME:-$(cmake_var APP_PRODUCT_NAME)}"

# The name of the plugin (see PLUGIN_PRODUCT_NAME). It is also the name of the
# standalone application shipped with the plugin formats.
PLUGIN_PRODUCT_NAME="${PLUGIN_PRODUCT_NAME:-$(cmake_var PLUGIN_PRODUCT_NAME)}"

# The CMake target names of the two products (see CMakeLists.txt).
APP_TARGET="${APP_TARGET:-${PROJECT_NAME}_app}"
PLUGIN_TARGET="${PLUGIN_TARGET:-$PROJECT_NAME}"

# Build configuration and directory. Every platform is generated into its own
# build/<platform> folder (see the justfile): each packaging script sets the
# BUILD_PLATFORM default that matches it before sourcing this file.
CONFIG="${CONFIG:-Release}"
BUILD_PLATFORM="${BUILD_PLATFORM:-}"
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build/$BUILD_PLATFORM}"
[[ "$BUILD_DIR" == /* ]] || BUILD_DIR="$PWD/$BUILD_DIR"
BUILD_DIR="${BUILD_DIR%/}"

# Output directory for the finished installers / archives.
DIST_DIR="${DIST_DIR:-$PROJECT_ROOT/dist}"

# Version string read from the VERSION file.
VERSION="$(tr -d '[:space:]' < "$PROJECT_ROOT/VERSION")"

# A filesystem-friendly product slug (no spaces).
PRODUCT_SLUG="${PRODUCT_NAME// /-}"

# Read a boolean option (BUILD_APP, BUILD_PLUGIN, ...) from the CMake cache of
# the build directory, so the scripts skip what the build switched off instead
# of looking for it. Succeeds when the option is ON, and also when the cache or
# the entry is missing: an unknown build is searched for everything.
# Usage: build_option_enabled <NAME>
build_option_enabled() {
    local name="$1" value
    [[ -f "$BUILD_DIR/CMakeCache.txt" ]] || return 0
    value="$(sed -n -E "s/^${name}:[A-Z]+=(.*)$/\\1/p" "$BUILD_DIR/CMakeCache.txt" | head -n 1)"
    case "$(printf '%s' "$value" | tr '[:lower:]' '[:upper:]')" in
        OFF|0|NO|FALSE|N) return 1 ;;
        *) return 0 ;;
    esac
}

# True when a build output holds something that was actually built. CMake
# writes the Info.plist of every bundle target at generate time, so bundles of
# targets that were never built (or of another configuration) exist as empty
# shells that must not be shipped. Plain files always count as built.
# Usage: artifact_has_binary <path>
artifact_has_binary() {
    local artifact="$1"
    [[ -d "$artifact" ]] || return 0
    if [[ -f "$artifact/Contents/Info.plist" ]]; then
        [[ -n "$(find "$artifact/Contents/MacOS" -type f -print -quit 2>/dev/null)" ]]
    else
        [[ -n "$(find "$artifact" -type f ! -name 'Info.plist' ! -name 'PkgInfo' -print -quit 2>/dev/null)" ]]
    fi
}

# Find every bundle/file with the given extension produced by the build, one per
# line. Only outputs sitting directly in a "<CONFIG>/" folder are returned (some
# formats nest every configuration under the folder of another one), skipping
# third-party bundles under externals/, the test/benchmark runners (e.g.
# "<project>_tests.app") and the AUv3 container application, which must never be
# shipped in a package, anything nested inside another bundle, and the empty
# bundles CMake generates for targets that were not built. Both the application
# and the standalone plugin produce a ".app" bundle, so the packaging scripts
# stage every match rather than just the first one.
# Usage: find_artifacts <extension>
find_artifacts() {
    local ext="$1" artifact
    { find "$BUILD_DIR" \
        \( -path '*/externals/*' -o -path '*/_deps/*' \) -prune -o \
        -path "*/$CONFIG/*" -name "*.$ext" -print 2>/dev/null \
        | grep -E "/$CONFIG/[^/]+\\.$ext\$" \
        | grep -Ev '(\.dSYM|_tests\.|_benchmarks\.|_auv3_container\.)' \
        | grep -Ev '\.(app|appex|vst3|clap|component|lv2|aaxplugin)/' \
        | sort; } \
    | while IFS= read -r artifact; do
        if artifact_has_binary "$artifact"; then
            printf '%s\n' "$artifact"
        fi
    done || true
}

# Find the first bundle/file with the given extension produced by the build.
# Usage: find_artifact <extension>
find_artifact() {
    find_artifacts "$1" | head -n 1
}

# Find an executable produced by the build for the given file name (no extension
# on Linux, ".exe" on Windows), sitting directly in a "<CONFIG>/" folder.
# Usage: find_executable <name>
find_executable() {
    local name="$1"
    { find "$BUILD_DIR" \
        \( -path '*/externals/*' -o -path '*/_deps/*' \) -prune -o \
        -path "*/$CONFIG/$name" -type f -print 2>/dev/null \
        | head -n 1; } || true
}

# A filesystem-friendly slug (no spaces) for an arbitrary name.
# Usage: slugify <name>
slugify() {
    printf '%s' "${1// /-}"
}

# Render a freedesktop.org .desktop entry from packaging/linux/app.desktop.in.
# Usage: write_desktop_entry <name> <description> <exec> <icon> <output-file>
write_desktop_entry() {
    local name="$1" description="$2" exec="$3" icon="$4" output="$5"
    mkdir -p "$(dirname "$output")"
    sed -e "s|@NAME@|$name|g" \
        -e "s|@DESCRIPTION@|$description|g" \
        -e "s|@EXEC@|$exec|g" \
        -e "s|@ICON@|$icon|g" \
        "$PACKAGING_DIR/linux/app.desktop.in" > "$output"
}
