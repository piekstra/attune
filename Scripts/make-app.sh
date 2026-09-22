#!/bin/bash
# Builds Attune.app from the SwiftPM release binary.
#
# A proper .app bundle (vs `swift run`) gets you:
#   - Launch at login (SMAppService needs a bundle identifier)
#   - A stable identity for macOS privacy prompts
#   - Something you can drop into /Applications
#
# Usage:
#   Scripts/make-app.sh            # builds ./dist/Attune.app
#   Scripts/make-app.sh --install  # also copies it to /Applications
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Building release binary..."
swift build -c release

APP_DIR="dist/Attune.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp .build/release/attune "$APP_DIR/Contents/MacOS/Attune"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Attune</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.piekstra.attune</string>
    <key>CFBundleName</key>
    <string>Attune</string>
    <key>CFBundleDisplayName</key>
    <string>Attune</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSRemindersFullAccessUsageDescription</key>
    <string>With your permission, a Reminder is created when a break timer starts so your iPhone and Apple Watch can ring when it ends. Only reminders created by this app are ever touched; your existing reminders are never read.</string>
    <key>NSRemindersUsageDescription</key>
    <string>With your permission, a Reminder is created when a break timer starts so your iPhone and Apple Watch can ring when it ends. Only reminders created by this app are ever touched; your existing reminders are never read.</string>
    <key>NSHumanReadableCopyright</key>
    <string>MIT License</string>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough to run locally. Distribution would need a
# Developer ID and notarization.
codesign --force --sign - "$APP_DIR"

echo "Built $APP_DIR"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf "/Applications/Attune.app"
    cp -R "$APP_DIR" /Applications/
    echo "Installed to /Applications/Attune.app"
fi
