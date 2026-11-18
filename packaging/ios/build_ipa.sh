#!/usr/bin/env bash
# =============================================================================
# Package every iOS application (.app) that was built - the standalone
# application and the plugin's standalone application - into its own .ipa
# archive in the dist/ directory, under a versioned, product-named file.
#
# The iOS build (Ninja Multi-Config + the ios toolchain) produces a standalone
# ".app" bundle under "<build>/.../<CONFIG>/". An .ipa is simply a zip archive
# containing a top-level "Payload/" directory with the .app inside, so we stage
# the bundle into Payload/ and compress it.
#
# NOTE: the resulting .ipa is unsigned. It is suitable as a CI build artifact,
# but installing it on a device still requires code signing / a provisioning
# profile.
#
# Usage: packaging/ios/build_ipa.sh [CONFIG] [BUILD_DIR (default: build/ios)]
#   CONFIG     Release (default) or Debug.
#   BUILD_DIR  The CMake build directory containing the built .app bundles.
# =============================================================================
set -euo pipefail

CONFIG="${1:-${CONFIG:-Release}}"
BUILD_DIR="${2:-${BUILD_DIR:-}}"
BUILD_PLATFORM="${BUILD_PLATFORM:-ios}"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

mkdir -p "$DIST_DIR"

APPS=()
while IFS= read -r artifact; do
    [[ -n "$artifact" ]] && APPS+=("$artifact")
done < <(find_artifacts app)
[[ ${#APPS[@]} -gt 0 ]] || die "No .app bundle found under $BUILD_DIR for config $CONFIG. Build the project first."

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

for APP in "${APPS[@]}"; do
    NAME="$(basename "$APP" .app)"
    rm -rf "$STAGE/Payload"
    mkdir -p "$STAGE/Payload"

    log "Staging $(basename "$APP") into Payload/"
    cp -R "$APP" "$STAGE/Payload/"

    OUTPUT="$DIST_DIR/$(slugify "$NAME")-$VERSION-ios.ipa"
    rm -f "$OUTPUT"
    log "Creating archive"
    ( cd "$STAGE" && zip -qry "$OUTPUT" Payload )
    log "Created $OUTPUT"
done
