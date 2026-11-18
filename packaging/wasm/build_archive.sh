#!/usr/bin/env bash
# =============================================================================
# Build a WebAssembly tarball (.tar.gz) containing every Emscripten application
# that was built (the standalone application and the plugin's standalone
# application). Each one is staged into its own "<name>/" folder with its HTML
# shell, every file Emscripten emits alongside it (.js, .wasm, .data, worker
# scripts, source maps, ...) and the mini-coi.js cross-origin-isolation helper.
# The top-level index.html redirects to the application (or to the plugin's
# standalone when the application was not built).
#
# Usage: packaging/wasm/build_archive.sh [CONFIG] [BUILD_DIR (default: build/emscripten)]
# =============================================================================
set -euo pipefail

CONFIG="${1:-${CONFIG:-Release}}"
BUILD_DIR="${2:-${BUILD_DIR:-}}"
BUILD_PLATFORM="${BUILD_PLATFORM:-emscripten}"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/common.sh"

mkdir -p "$DIST_DIR"

# Every Emscripten application emits "<product>.html" into its per-config output
# directory.
HTMLS=()
while IFS= read -r artifact; do
    [[ -n "$artifact" ]] && HTMLS+=("$artifact")
done < <(find_artifacts html)
[[ ${#HTMLS[@]} -gt 0 ]] || die "No Emscripten .html output found under $BUILD_DIR for config $CONFIG. Build the WASM project first."

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
ROOT="$STAGE/$PRODUCT_SLUG-$VERSION"
mkdir -p "$ROOT"

ENTRY=""
for HTML in "${HTMLS[@]}"; do
    OUT_DIR="$(dirname "$HTML")"
    STEM="$(basename "$HTML" .html)"
    SLUG="$(slugify "$STEM")"

    log "Staging WebAssembly application \"$STEM\" -> $SLUG/"
    mkdir -p "$ROOT/$SLUG"

    # Copy every file that shares the HTML stem (.html/.js/.wasm/.data/.wasm.map
    # and the pthread / wasm-worker / audio-worklet helper scripts).
    shopt -s nullglob
    for f in "$OUT_DIR/$STEM".*; do
        [[ -f "$f" ]] || continue
        cp "$f" "$ROOT/$SLUG/"
    done
    shopt -u nullglob

    # The cross-origin-isolation shim required to serve the SharedArrayBuffer build.
    if [[ -f "$OUT_DIR/mini-coi.js" ]]; then
        cp "$OUT_DIR/mini-coi.js" "$ROOT/$SLUG/"
    fi

    # Expose each shell as index.html so every folder can be served as-is.
    cp "$ROOT/$SLUG/$STEM.html" "$ROOT/$SLUG/index.html"

    if [[ "$STEM" == "$APP_PRODUCT_NAME" || -z "$ENTRY" ]]; then
        ENTRY="$SLUG"
    fi
done

# The archive root redirects to the main entry point.
cat > "$ROOT/index.html" <<HTML
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=$ENTRY/index.html">
    <title>$PRODUCT_NAME</title>
</head>
<body>
    <a href="$ENTRY/index.html">$PRODUCT_NAME</a>
</body>
</html>
HTML

[[ -f "$PROJECT_ROOT/LICENSE" ]] && cp "$PROJECT_ROOT/LICENSE" "$ROOT/LICENSE"

OUTPUT="$DIST_DIR/$PRODUCT_SLUG-$VERSION-wasm.tar.gz"
log "Creating archive"
tar -czf "$OUTPUT" -C "$STAGE" "$PRODUCT_SLUG-$VERSION"
log "Created $OUTPUT"
