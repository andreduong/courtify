#!/usr/bin/env bash
# Optional: open SwiftUI Canvas for isolated view tweaks.
# Courtify default is scripts/dev-sim-hot-reload.sh — Canvas loads the full
# asset catalog and is often slow / stuck on "empty catalog import…".
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/scripts/xcode-env.sh"

XCODE_APP="/Users/andreduong/Applications/Xcode-26.0.1.app"
PREVIEW_FILE="${1:-$ROOT/Courtify/Views/UITweakPreviews.swift}"

printf '==> UI tweak mode: opening %s\n' "$(basename "$PREVIEW_FILE")"
printf '    Enable Canvas: Editor → Canvas (or ⌥⌘↩)\n'
printf '    Pick a screen from the preview selector at the bottom of the editor.\n'
printf '    Saves refresh the canvas instantly — no simulator build.\n\n'

open -a "$XCODE_APP" "$ROOT/Courtify.xcodeproj"
open -a "$XCODE_APP" "$PREVIEW_FILE"
