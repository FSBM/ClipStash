import Foundation

/// Represents a keyboard shortcut: modifier flags + virtual key code.
struct HotkeyBinding {
    let label: String
    let modifiers: UInt32
    let keyCode: UInt32
}
