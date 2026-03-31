#!/bin/bash
# Create GrostatBar.app bundle from the built binary
set -euo pipefail

BINARY="${1:-.build/release/GrostatBar}"
APP_DIR="GrostatBar.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"

rm -rf "$APP_DIR"
mkdir -p "$MACOS"

cp "$BINARY" "$MACOS/GrostatBar"

cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>GrostatBar</string>
    <key>CFBundleDisplayName</key>
    <string>GrostatBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.zalun.grostatbar</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>GrostatBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc code sign
codesign --force --sign - "$APP_DIR"

echo "Created $APP_DIR"
