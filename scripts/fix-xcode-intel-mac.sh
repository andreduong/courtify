#!/usr/bin/env bash
# One-time fix for Intel Mac + macOS Tahoe:
# - Retires Xcode 16.2 (incompatible with Tahoe)
# - Points /Applications/Xcode.app at your working Xcode 26.0.1 Universal install
set -euo pipefail

XCODE_26="/Users/andreduong/Applications/Xcode-26.0.1.app"

if [[ ! -d "$XCODE_26" ]]; then
  echo "Xcode 26.0.1 not found at $XCODE_26"
  echo "Run ./scripts/setup-testflight.sh first, or install via xcodes."
  exit 1
fi

if [[ -d /Applications/Xcode.app && ! -L /Applications/Xcode.app ]]; then
  echo "Moving /Applications/Xcode.app → /Applications/Xcode-16.2.app.backup"
  sudo mv /Applications/Xcode.app /Applications/Xcode-16.2.app.backup
fi

if [[ -L /Applications/Xcode.app ]]; then
  sudo rm /Applications/Xcode.app
fi

echo "Linking /Applications/Xcode.app → $XCODE_26"
sudo ln -sf "$XCODE_26" /Applications/Xcode.app

echo "Selecting Xcode 26.0.1"
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept 2>/dev/null || true

xcodebuild -version
echo "Done. Open Xcode from Applications or run: ./scripts/open-xcode.sh"
