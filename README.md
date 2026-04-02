# ClipStash

A lightweight, Spotlight-style clipboard history manager for macOS. Built as a single-file Swift application with no dependencies.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Quick Start

```bash
chmod +x build.sh
./build.sh
cp -r build/ClipStash.app /Applications/
open /Applications/ClipStash.app
```

## How It Works

### Architecture

ClipStash is a single-file macOS app (`ClipStash.swift`) built with AppKit — no SwiftUI, no Xcode project, no storyboards. It compiles directly with `swiftc`.

```
ClipStash.swift          # Entire application (single file)
├── ClipItem             # Data model (Codable struct)
├── ClipboardManager     # Singleton — polls pasteboard, persists history
├── OverlayPanel         # NSPanel subclass — floating Spotlight-style window
├── ClipRowView          # NSView subclass — individual clipboard entry row
├── OverlayViewController # Main UI — search, list, keyboard navigation
├── AppDelegate          # Menu bar icon, hotkey registration, panel toggle
└── Entry Point          # NSApplication.shared bootstrap
```

### Clipboard Monitoring

`ClipboardManager` polls `NSPasteboard.general` every 0.5 seconds via a scheduled `Timer`. When `changeCount` changes, the new text is captured, deduplicated, and stored. History is persisted as JSON to `~/Library/Application Support/ClipStash/history.json`.

### Overlay Panel

The overlay uses `NSPanel` with `.nonactivatingPanel` style, allowing it to float above all windows without stealing focus from the active app. It animates in/out with `NSAnimationContext` (0.15s ease-out / 0.12s ease-in). Clicking outside the panel dismisses it via `resignKey()`.

### Global Hotkey

Registered via the Carbon `RegisterEventHotKey` API. Default shortcut is **Option + Space** (`⌥Space`). The shortcut is persisted in `UserDefaults` and can be changed from the menu bar right-click menu.

### Menu Bar Icon

Rendered programmatically using `NSImage(size:flipped:)` — draws "CP" in bold system font as a template image. macOS automatically adapts the icon color for light/dark menu bar.

### Auto-Paste

When you select a clip, ClipStash copies it to the pasteboard, hides the overlay, then simulates `⌘V` via `CGEvent` to paste into the previously active application.

## Usage

| Action | How |
|---|---|
| Open / Close | `⌥ Space` (Option + Space) |
| Search | Start typing in the search field |
| Navigate | `↑` / `↓` arrow keys |
| Paste selected | `↩` Enter |
| Delete item | `⌘ ⌫` or right-click > Delete |
| Pin / Unpin | Right-click > Pin |
| Close | `Esc` or click outside |
| Change shortcut | Right-click menu bar icon > Change Shortcut |

## Features

- **Spotlight-style overlay** — centered floating panel with search
- **Auto-capture** — monitors clipboard every 0.5s
- **50-item history** — pinned items are protected from cleanup
- **Persistent storage** — survives app restarts (`~/Library/Application Support/ClipStash/`)
- **Real-time search** — filters as you type
- **Pin important clips** — pinned items never get pushed out
- **Auto-paste** — select a clip and it pastes into the active app
- **Keyboard-driven** — full arrow key + Enter navigation
- **Customizable shortcut** — change via right-click menu on the menu bar icon
- **Menu bar app** — no dock icon, lives in the menu bar as "CP"
- **Dark theme** — translucent dark glass aesthetic
- **No dependencies** — pure AppKit, compiles with `swiftc`

## First Launch Permissions

macOS will ask for:

1. **Accessibility access** — required for global hotkey and auto-paste
   - System Settings > Privacy & Security > Accessibility > enable ClipStash
2. If macOS blocks the unsigned app:
   - System Settings > Privacy & Security > "Open Anyway"

## Project Structure

```
ClipStash/
├── ClipStash.swift      # Complete application source
├── Info.plist           # macOS app bundle configuration
├── build.sh             # Build script (compiles + packages .app bundle)
├── AppIcon.icns         # Application icon
├── new-final-logo.png   # Source logo (CP)
└── README.md
```

## Build Options

```bash
# Standard build (Apple Silicon)
./build.sh

# Universal binary (Apple Silicon + Intel)
./build.sh --universal
```

### Requirements

- macOS 13.0+
- Swift 5.9+ (included with Xcode or Command Line Tools)

## Data Storage

All data is stored locally:

| What | Where |
|---|---|
| Clipboard history | `~/Library/Application Support/ClipStash/history.json` |
| Shortcut preference | `UserDefaults` (standard macOS preferences) |

No network requests. No telemetry. No cloud sync.

## Uninstall

```bash
rm -rf /Applications/ClipStash.app
rm -rf ~/Library/Application\ Support/ClipStash
defaults delete com.clipstash.app
```
