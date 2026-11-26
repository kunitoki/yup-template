#!/usr/bin/env bash
# =============================================================================
# Build a Debian package (.deb) that installs every built plugin format, the
# standalone application and the plugin's standalone application system-wide.
#
#   VST3 -> /usr/lib/vst3        CLAP -> /usr/lib/clap
#   LV2  -> /usr/lib/lv2         apps -> /usr/bin + one .desktop entry each
#
# Usage: packaging/linux/build_deb.sh [CONFIG] [BUILD_DIR (default: build/linux)]
# Requires: dpkg-deb
# =============================================================================
set -euo pipefail

CONFIG="${1:-${CONFIG:-Release}}"
BUILD_DIR="${2:-${BUILD_DIR:-}}"
BUILD_PLATFORM="${BUILD_PLATFORM:-linux}"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

command -v dpkg-deb >/dev/null || die "dpkg-deb not found (install the dpkg package)."

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$DIST_DIR"

# Lowercase, hyphenated package name as required by Debian policy.
PKG_NAME="$(echo "$PRODUCT_SLUG" | tr '[:upper:]' '[:lower:]')"
ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"

declare -a FOUND=()
stage_bundle() {
    local ext="$1" dest="$2"
    local artifact
    artifact="$(find_artifact "$ext")"
    if [[ -z "$artifact" ]]; then
        warn "No .$ext artifact found for $CONFIG; skipping."
        return
    fi
    log "Staging $(basename "$artifact") -> $dest"
    mkdir -p "$STAGE/$dest"
    cp -R "$artifact" "$STAGE/$dest/"
    FOUND+=("$ext")
}

if build_option_enabled BUILD_PLUGIN; then
    build_option_enabled PLUGIN_BUILD_VST3 && stage_bundle vst3 "usr/lib/vst3"
    build_option_enabled PLUGIN_BUILD_CLAP && stage_bundle clap "usr/lib/clap"
    build_option_enabled PLUGIN_BUILD_LV2  && stage_bundle lv2  "usr/lib/lv2"
fi

if [[ -f "$PROJECT_ROOT/assets/app-icon.png" ]]; then
    mkdir -p "$STAGE/usr/share/icons/hicolor/512x512/apps"
    cp "$PROJECT_ROOT/assets/app-icon.png" "$STAGE/usr/share/icons/hicolor/512x512/apps/$PKG_NAME.png"
fi

# The standalone executables on Linux are plain files named after their product
# name; install them under a lowercase, hyphenated command name.
stage_executable() {
    local name="$1" description="$2" kind="$3"
    local executable command
    executable="$(find_executable "$name")"
    if [[ -z "$executable" ]]; then
        warn "No $kind executable '$name' found for $CONFIG; skipping."
        return
    fi
    command="$(slugify "$name" | tr '[:upper:]' '[:lower:]')"
    log "Staging $kind '$name' -> /usr/bin/$command"
    mkdir -p "$STAGE/usr/bin"
    cp "$executable" "$STAGE/usr/bin/$command"
    chmod 755 "$STAGE/usr/bin/$command"
    write_desktop_entry "$name" "$description" "$command" "$PKG_NAME" \
        "$STAGE/usr/share/applications/$command.desktop"
    FOUND+=("$kind")
}

# Only look for what the build was configured to produce.
if build_option_enabled BUILD_APP; then
    stage_executable "$APP_PRODUCT_NAME" "$PRODUCT_DESCRIPTION" "application"
fi
if build_option_enabled BUILD_PLUGIN && build_option_enabled PLUGIN_BUILD_STANDALONE; then
    stage_executable "$PLUGIN_PRODUCT_NAME" "$PLUGIN_DESCRIPTION" "plugin standalone"
fi

[[ ${#FOUND[@]} -gt 0 ]] || die "No artifacts found under $BUILD_DIR for config $CONFIG. Build the project first."

# Control metadata.
INSTALLED_KB="$(du -sk "$STAGE" | cut -f1)"
mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/control" <<CONTROL
Package: $PKG_NAME
Version: $VERSION
Section: sound
Priority: optional
Architecture: $ARCH
Maintainer: $COMPANY_NAME <$PRODUCT_EMAIL>
Installed-Size: $INSTALLED_KB
Description: $PRODUCT_NAME
 $PRODUCT_DESCRIPTION
CONTROL

OUTPUT="$DIST_DIR/${PKG_NAME}_${VERSION}_${ARCH}.deb"
log "Building Debian package"
dpkg-deb --build --root-owner-group "$STAGE" "$OUTPUT"
log "Created $OUTPUT"
