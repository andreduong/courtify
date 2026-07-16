#!/usr/bin/env bash
# Live-reload Courtify on the iOS Simulator while editing Swift sources.
# Watches Courtify/ + CourtifyWidget/, rebuilds incrementally, reinstalls, relaunches.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/scripts/xcode-env.sh"

UDID="${SIM_UDID:-744F6ACA-F0CC-4105-8794-D798EF7726CC}"
BUNDLE_ID="com.courtify.xyz"
DERIVED="$ROOT/.derivedData"
APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/Courtify.app"
WATCH_DIRS=("$ROOT/Courtify" "$ROOT/CourtifyWidget")
if (($# == 0)); then
  LAUNCH_ARGS=(-UITestHome -UITestTab rankings)
else
  LAUNCH_ARGS=("$@")
fi

log() { printf '[dev-sim] %s\n' "$*"; }

build() {
  xcodebuild \
    -scheme Courtify \
    -project "$ROOT/Courtify.xcodeproj" \
    -destination "platform=iOS Simulator,id=$UDID" \
    -derivedDataPath "$DERIVED" \
    -configuration Debug \
    build \
    CODE_SIGNING_ALLOWED=NO \
    >/tmp/courtify-dev-build.log 2>&1
}

install_and_launch() {
  xcrun simctl install "$UDID" "$APP_PATH"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" "${LAUNCH_ARGS[@]}"
}

newest_source_mtime() {
  local newest=0 mtime path
  for dir in "${WATCH_DIRS[@]}"; do
    while IFS= read -r path; do
      mtime=$(stat -f '%m' "$path")
      if (( mtime > newest )); then
        newest=$mtime
      fi
    done < <(find "$dir" -name '*.swift' -type f 2>/dev/null)
  done
  printf '%s' "$newest"
}

open_simulator() {
  open -a Simulator
  xcrun simctl boot "$UDID" 2>/dev/null || true
}

log "Booting iPhone 17 Pro ($UDID)…"
open_simulator

if [[ "${SKIP_INITIAL_BUILD:-}" != "1" ]]; then
  log "Initial build…"
  build
  install_and_launch
else
  log "Skipping initial build (SKIP_INITIAL_BUILD=1)."
fi

last_mtime="$(newest_source_mtime)"
log "Watching Swift sources (save a file to reload). Launch args: ${LAUNCH_ARGS[*]}"

while true; do
  sleep 2
  current_mtime="$(newest_source_mtime)"
  if [[ "$current_mtime" != "$last_mtime" ]]; then
    last_mtime="$current_mtime"
    log "Change detected — rebuilding…"
    if build; then
      install_and_launch
      log "Reloaded."
    else
      log "Build failed — see /tmp/courtify-dev-build.log"
    fi
  fi
done
