#!/usr/bin/env bash
# One-shot TestFlight setup for Courtify.
# Run in Terminal (not Cursor) — needs sudo password + Apple ID for Xcode download.
#
# Usage:
#   cd /Users/andreduong/courtify
#   ./scripts/setup-testflight.sh
#
# If macOS upgrades, reboot when prompted, then run the same command again.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$HOME/.courtify-testflight-setup-state"
XCODES="$ROOT/.tools/xcodes"
XCODE_26_APP="/Users/andreduong/Applications/Xcode-26.0.1.app"
TEAM_ID="B2P86X9N67"

log() { printf '\n==> %s\n' "$*"; }
need_macos_major() { sw_vers -productVersion | awk -F. '{print $1}'; }

ensure_xcodes_cli() {
  if [[ -x "$XCODES" ]]; then
    return
  fi
  log "Installing xcodes CLI to $ROOT/.tools ..."
  mkdir -p "$ROOT/.tools"
  curl -L -o "$ROOT/.tools/xcodes.zip" \
    "https://github.com/XcodesOrg/xcodes/releases/download/2.0.3/xcodes.zip"
  unzip -o -q "$ROOT/.tools/xcodes.zip" -d "$ROOT/.tools"
  chmod +x "$XCODES"
}

maybe_upgrade_macos() {
  local major
  major="$(need_macos_major)"
  if [[ "$major" -ge 26 ]]; then
    log "macOS $major detected — OK for Xcode 26."
    return
  fi

  if [[ "$major" -ge 15 ]]; then
    log "macOS Sequoia $major detected — should run Xcode 26 after install."
    return
  fi

  log "macOS Sonoma detected. Xcode 26 requires macOS Sequoia 15.6+ (Tahoe 26 recommended)."
  log "Available upgrade: macOS Tahoe 26.5.2"
  read -r -p "Install macOS Tahoe 26.5.2 now? This downloads ~7GB and requires a restart. [y/N] " reply
  reply="$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]')"
  if [[ "$reply" != "y" && "$reply" != "yes" ]]; then
    echo "Upgrade macOS first, then re-run this script."
    exit 1
  fi

  echo "upgrade-started" > "$STATE_FILE"
  sudo softwareupdate --install "macOS Tahoe 26.5.2-25F84" --agree-to-license
  log "macOS Tahoe downloaded. You must restart to finish installing."
  log "After restart, open Terminal and run:  cd ~/courtify && ./scripts/setup-testflight.sh"
  read -r -p "Restart now? [y/N] " restart_reply
  restart_reply="$(printf '%s' "$restart_reply" | tr '[:upper:]' '[:lower:]')"
  if [[ "$restart_reply" == "y" || "$restart_reply" == "yes" ]]; then
    sudo shutdown -r now
  else
    echo "Restart manually when ready (Apple menu → Restart)."
  fi
  exit 0
}

install_xcode_26() {
  if [[ -d "$XCODE_26_APP" ]]; then
    log "Xcode 26 already at $XCODE_26_APP"
    return
  fi

  ensure_xcodes_cli
  mkdir -p /Users/andreduong/Applications

  log "Downloading Xcode 26.0.1 Universal (~8GB). You may be prompted for your Apple ID."
  log "Use the same Apple ID as your Apple Developer / App Store Connect account."
  "$XCODES" install "26.0.1 (17A400) [Universal]" \
    --directory /Users/andreduong/Applications \
    --experimental-unxip \
    --select

  # xcodes names the app Xcode.app inside the directory; rename for side-by-side with 16.2
  if [[ -d "/Users/andreduong/Applications/Xcode.app" && ! -d "$XCODE_26_APP" ]]; then
    mv "/Users/andreduong/Applications/Xcode.app" "$XCODE_26_APP"
  fi
}

select_xcode_26() {
  local app="$XCODE_26_APP"
  if [[ ! -d "$app" ]]; then
    app="/Users/andreduong/Applications/Xcode.app"
  fi
  if [[ ! -d "$app" ]]; then
    app="/Applications/Xcode.app"
  fi

  log "Selecting $app"
  sudo xcode-select -s "$app/Contents/Developer"
  sudo xcodebuild -license accept || true
  export DEVELOPER_DIR="$app/Contents/Developer"
  xcodebuild -version

  log "Installing iOS 26 platform support (~10GB, one-time)..."
  xcodebuild -runFirstLaunch -checkForNewerComponents || true
  if ! xcodebuild -downloadPlatform iOS -buildVersion 26.0 -architectureVariant universal; then
    log "Platform download may have been interrupted. Re-run this script to retry."
    exit 1
  fi
}

upload_build() {
  log "Archiving and uploading Courtify to TestFlight ..."
  # shellcheck source=/dev/null
  source "$ROOT/scripts/xcode-env.sh"
  "$ROOT/scripts/upload-testflight.sh"
}

main() {
  cd "$ROOT"
  maybe_upgrade_macos
  install_xcode_26
  select_xcode_26
  upload_build
  rm -f "$STATE_FILE"
  log "Done. Open App Store Connect → Courtify → TestFlight and wait for processing."
  log "Then install TestFlight on your iPhone and accept the invite."
}

main "$@"
