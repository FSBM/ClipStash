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
SRC_DIR="$(pwd)/Sources"

echo ""
echo "  ┌─────────────────────────────────┐"
echo "  │   Building ClipStash v1.0       │"
echo "  └─────────────────────────────────┘"
echo ""

# Collect all Swift source files (handle spaces in paths)
SOURCES=()
while IFS= read -r -d '' file; do
    SOURCES+=("$file")
done < <(find "${SRC_DIR}" -name "*.swift" -print0 | sort -z)
echo "  ⟐  Found ${#SOURCES[@]} source files"

# Clean previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${MACOS}" "${RESOURCES}"

# Compile
echo "  ⟐  Compiling Swift..."
swiftc \
    -o "${MACOS}/${APP_NAME}" \
    -framework Cocoa \
    -framework Carbon \
    -framework AVFoundation \
    -target arm64-apple-macosx13.0 \
    -O \
    "${SOURCES[@]}"

echo "  ⟐  Packaging app bundle..."

# Copy Info.plist
cp Info.plist "${CONTENTS}/Info.plist"

# Copy app icon if exists
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "${RESOURCES}/AppIcon.icns"
    echo "  ⟐  App icon added"
fi

# Copy intro image
if [ -f "intro-bird.png" ]; then
    cp intro-bird.png "${RESOURCES}/intro-bird.png"
    echo "  ⟐  Intro image added"
fi

# Copy sound
if [ -f "open-sound.mp3" ]; then
    cp open-sound.mp3 "${RESOURCES}/open-sound.mp3"
    echo "  ⟐  Sound added"
fi

# Make executable
chmod +x "${MACOS}/${APP_NAME}"

# Sign the app properly so macOS can track permissions consistently
echo "  ⟐  Signing app bundle..."
codesign -f -s - --deep "${APP_BUNDLE}" 2>/dev/null && echo "  ⟐  App signed (ad-hoc)" || echo "  ⟐  Signing skipped"

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
        "${SOURCES[@]}"

    echo "  ⟐  Creating universal binary..."
    lipo -create \
        "${MACOS}/${APP_NAME}" \
        "${MACOS}/${APP_NAME}_x86" \
        -output "${MACOS}/${APP_NAME}_universal"

    mv "${MACOS}/${APP_NAME}_universal" "${MACOS}/${APP_NAME}"
    rm "${MACOS}/${APP_NAME}_x86"

    echo "  ✓  Universal binary created (ARM + Intel)"
fi
