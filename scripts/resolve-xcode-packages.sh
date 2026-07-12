#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_ROOT/Courtify.xcodeproj"

echo "==> Clearing Courtify DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Courtify-*

echo "==> Resolving Swift packages..."
xcodebuild -resolvePackageDependencies -project "$PROJECT"

echo "==> Done. Quit Xcode (⌘Q), reopen Courtify.xcodeproj, then build."
