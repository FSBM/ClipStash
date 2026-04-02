#!/bin/bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ClipStash — Build Script
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -e

APP_NAME="ClipStash"
BUILD_DIR="$(pwd)/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo ""
echo "  ┌─────────────────────────────────┐"
echo "  │   Building ClipStash v1.0       │"
echo "  └─────────────────────────────────┘"
echo ""

# Clean previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${MACOS}" "${RESOURCES}"

# Compile
echo "  ⟐  Compiling Swift..."
swiftc \
    -o "${MACOS}/${APP_NAME}" \
    -framework Cocoa \
    -framework Carbon \
    -target arm64-apple-macosx13.0 \
    -O \
    ClipStash.swift

echo "  ⟐  Packaging app bundle..."

# Copy Info.plist
cp Info.plist "${CONTENTS}/Info.plist"

# Copy app icon if exists
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "${RESOURCES}/AppIcon.icns"
    echo "  ⟐  App icon added"
fi

# Make executable
chmod +x "${MACOS}/${APP_NAME}"

echo ""
echo "  ✓  Build complete!"
echo ""
echo "  App:  ${APP_BUNDLE}"
echo ""
echo "  To install:"
echo "    cp -r ${APP_BUNDLE} /Applications/"
echo ""
echo "  To run now:"
echo "    open ${APP_BUNDLE}"
echo ""
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Shortcut:  ⌥ + Space  to open/close"
echo "  (Right-click menu bar icon to change)"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Also build Intel version if requested
if [ "$1" = "--universal" ]; then
    echo "  ⟐  Building Intel binary..."
    swiftc \
        -o "${MACOS}/${APP_NAME}_x86" \
        -framework Cocoa \
        -framework Carbon \
        -target x86_64-apple-macosx13.0 \
        -O \
        ClipStash.swift

    echo "  ⟐  Creating universal binary..."
    lipo -create \
        "${MACOS}/${APP_NAME}" \
        "${MACOS}/${APP_NAME}_x86" \
        -output "${MACOS}/${APP_NAME}_universal"

    mv "${MACOS}/${APP_NAME}_universal" "${MACOS}/${APP_NAME}"
    rm "${MACOS}/${APP_NAME}_x86"

    echo "  ✓  Universal binary created (ARM + Intel)"
fi
