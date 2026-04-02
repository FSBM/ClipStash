import Cocoa

/// Simulates keyboard events via CGEvent.
/// Isolated from business logic — only knows how to press keys.
enum KeyboardSimulator {
    /// Simulates Cmd+V (paste) at the HID event tap level.
    static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vKey: CGKeyCode = 0x09

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
