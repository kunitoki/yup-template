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

# The internal target name (see PROJECT_NAME in CMakeLists.txt).
PROJECT_NAME="${PROJECT_NAME:-$(cmake_var PROJECT_NAME)}"

# The user-facing product name (see PRODUCT_NAME in CMakeLists.txt). This is the
# name of the generated standalone .app bundle.
PRODUCT_NAME="${PRODUCT_NAME:-$(cmake_var PRODUCT_NAME)}"

# The vendor / author (see COMPANY_NAME in CMakeLists.txt).
COMPANY_NAME="${COMPANY_NAME:-$(cmake_var COMPANY_NAME)}"

# The reverse-domain bundle identifier prefix (see BUNDLE_ID in CMakeLists.txt).
BUNDLE_ID="${BUNDLE_ID:-$(cmake_var BUNDLE_ID)}"

# Short descriptive text (see PLUGIN_DESCRIPTION in CMakeLists.txt).
PLUGIN_DESCRIPTION="${PLUGIN_DESCRIPTION:-$(cmake_var PLUGIN_DESCRIPTION)}"

# Website / support URL (see PLUGIN_URL in CMakeLists.txt).
PLUGIN_URL="${PLUGIN_URL:-$(cmake_var PLUGIN_URL)}"

# Contact e-mail (see PLUGIN_EMAIL in CMakeLists.txt).
PLUGIN_EMAIL="${PLUGIN_EMAIL:-$(cmake_var PLUGIN_EMAIL)}"

# Build configuration and directory.
CONFIG="${CONFIG:-Release}"
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"

# Output directory for the finished installers / archives.
DIST_DIR="${DIST_DIR:-$PROJECT_ROOT/dist}"

# Version string read from the VERSION file.
VERSION="$(tr -d '[:space:]' < "$PROJECT_ROOT/VERSION")"

# A filesystem-friendly product slug (no spaces).
PRODUCT_SLUG="${PRODUCT_NAME// /-}"

# Find the first bundle/file with the given extension produced by the build.
# Searches the common config directory as well as the VST3-specific subtree,
# skipping third-party bundles under externals/ and the test/benchmark runners
# (e.g. "<project>_tests.app") which must never be shipped in a package.
# Usage: find_artifact <extension>
find_artifact() {
    local ext="$1"
    { find "$BUILD_DIR" \
        \( -path '*/externals/*' -o -path '*/_deps/*' \) -prune -o \
        -path "*/$CONFIG/*" -name "*.$ext" -print 2>/dev/null \
        | grep -Ev '(\.dSYM|_tests\.|_benchmarks\.)' \
        | head -n 1; } || true
}
