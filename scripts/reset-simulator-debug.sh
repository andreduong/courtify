#!/usr/bin/env bash
set -euo pipefail

echo "==> Stopping Courtify and Simulator services..."
xcrun simctl shutdown all 2>/dev/null || true
killall "Simulator" 2>/dev/null || true
killall lldb-rpc-server 2>/dev/null || true
killall Courtify 2>/dev/null || true
pkill -f com.courtify.xyz 2>/dev/null || true

echo "==> Erasing booted simulators (optional fresh state)..."
for udid in $(xcrun simctl list devices booted | awk -F '[()]' '/Booted/ {print $2}'); do
  xcrun simctl erase "$udid" 2>/dev/null || true
done

echo "==> Clearing Courtify DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Courtify-*

echo "==> Done. Reopen Xcode and press Run."
