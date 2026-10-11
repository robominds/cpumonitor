#!/bin/bash
# Builds a release binary and wraps it in CPUMonitor.app (menu-bar only, ad-hoc signed).
# Usage: scripts/bundle.sh [--install]   (--install copies the app to /Applications)
# Author: Mark Castelluccio. Written with assistance from Claude (Anthropic).
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD_FLAGS=(-c release --arch arm64 --arch x86_64)
swift build "${BUILD_FLAGS[@]}"
BIN_DIR="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"

APP="build/CPUMonitor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/CPUMonitor" "$APP/Contents/MacOS/CPUMonitor"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>CPUMonitor</string>
    <key>CFBundleDisplayName</key>     <string>CPUMonitor</string>
    <key>CFBundleIdentifier</key>      <string>com.markcastelluccio.cpumonitor</string>
    <key>CFBundleExecutable</key>      <string>CPUMonitor</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHumanReadableCopyright</key><string>© 2026 Mark Castelluccio</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x CPUMonitor 2>/dev/null || true
    rm -rf /Applications/CPUMonitor.app
    cp -R "$APP" /Applications/
    open /Applications/CPUMonitor.app
    echo "Installed to /Applications/CPUMonitor.app"
fi
