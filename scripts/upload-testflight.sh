#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="Courtify"
TEAM_ID="B2P86X9N67"
ARCHIVE_PATH="$ROOT/build/TestFlight/Courtify.xcarchive"
EXPORT_PATH="$ROOT/build/TestFlight/export"
EXPORT_PLIST="$ROOT/scripts/ExportOptions.plist"

# Prefer Xcode 26 if installed alongside Xcode 16.2
for candidate in \
  "/Users/andreduong/Applications/Xcode-26.0.1.app/Contents/Developer" \
  "/Users/andreduong/Applications/Xcode.app/Contents/Developer" \
  "/Applications/Xcode.app/Contents/Developer"; do
  if [[ -d "$candidate" ]]; then
    export DEVELOPER_DIR="$candidate"
    break
  fi
done

log() { printf '==> %s\n' "$*"; }

ensure_ios_platform() {
  if xcodebuild -project "$ROOT/Courtify.xcodeproj" -scheme "$SCHEME" \
      -configuration Release -destination 'generic/platform=iOS' -showdestinations 2>&1 \
      | grep -q 'platform:iOS.*name:Any iOS Device' && \
     ! xcodebuild -project "$ROOT/Courtify.xcodeproj" -scheme "$SCHEME" \
      -configuration Release -destination 'generic/platform=iOS' -showdestinations 2>&1 \
      | grep -q 'iOS 26.0 is not installed'; then
    return
  fi

  log "iOS 26 platform not installed — downloading (~10GB, one-time)..."
  xcodebuild -runFirstLaunch -checkForNewerComponents >/dev/null 2>&1 || true
  xcodebuild -downloadPlatform iOS -buildVersion 26.0 -architectureVariant universal
}

log "Using $(xcodebuild -version | head -1) at ${DEVELOPER_DIR:-default}"
ensure_ios_platform

log "Archiving $SCHEME (Release, generic iOS)..."
rm -rf "$ROOT/build/TestFlight"
xcodebuild \
  -project "$ROOT/Courtify.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID"

log "Exporting + uploading to App Store Connect..."
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -allowProvisioningUpdates

log "Done. Check App Store Connect → TestFlight for processing status."
