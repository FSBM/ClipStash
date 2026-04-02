import Carbon.HIToolbox
import Cocoa

/// Manages global hotkey registration and shortcut persistence.
///
/// Open for extension (new presets) without modifying registration logic
/// (Open/Closed Principle).
final class HotkeyService {
    private var hotKeyRef: EventHotKeyRef?
    private let onTrigger: () -> Void

    static let presets: [HotkeyBinding] = [
        HotkeyBinding(label: "⌥ Space (Option+Space)",   modifiers: UInt32(optionKey),              keyCode: 49),
        HotkeyBinding(label: "⌘⇧ V (Cmd+Shift+V)",      modifiers: UInt32(cmdKey | shiftKey),      keyCode: 9),
        HotkeyBinding(label: "⌃⇧ V (Ctrl+Shift+V)",     modifiers: UInt32(controlKey | shiftKey),  keyCode: 9),
        HotkeyBinding(label: "⌘⇧ C (Cmd+Shift+C)",      modifiers: UInt32(cmdKey | shiftKey),      keyCode: 8),
        HotkeyBinding(label: "⌥⇧ V (Option+Shift+V)",   modifiers: UInt32(optionKey | shiftKey),   keyCode: 9),
    ]

    private static let defaultBinding = HotkeyBinding(
        label: "⌥Space", modifiers: UInt32(optionKey), keyCode: 49
    )

    /// - Parameter onTrigger: Called on the main thread when the hotkey fires.
    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    // MARK: - Current Binding (persisted in UserDefaults)

    var currentBinding: HotkeyBinding {
        get {
            let code = UserDefaults.standard.integer(forKey: "hotkey_keycode")
            let mods = UserDefaults.standard.integer(forKey: "hotkey_modifiers")
            guard code != 0 else { return Self.defaultBinding }
            return HotkeyBinding(
                label: Self.displayString(modifiers: UInt32(mods), keyCode: UInt32(code)),
                modifiers: UInt32(mods),
                keyCode: UInt32(code)
            )
        }
        set {
            UserDefaults.standard.set(Int(newValue.keyCode), forKey: "hotkey_keycode")
            UserDefaults.standard.set(Int(newValue.modifiers), forKey: "hotkey_modifiers")
        }
    }

    // MARK: - Registration

    func register() {
        unregister()

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434C5053) // "CLPS"
        hotKeyID.id = 1

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            DispatchQueue.main.async {
                (NSApp.delegate as? AppDelegate)?.hotkeyTriggered()
            }
            return noErr
        }, 1, &eventSpec, nil, nil)

        let binding = currentBinding
        RegisterEventHotKey(
            binding.keyCode, binding.modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
    }

    func updateBinding(_ binding: HotkeyBinding) {
        currentBinding = binding
        register()
    }

    private func unregister() {
        guard let ref = hotKeyRef else { return }
        UnregisterEventHotKey(ref)
        hotKeyRef = nil
    }

    // MARK: - Display

    static func displayString(modifiers: UInt32, keyCode: UInt32) -> String {
        var symbols: [String] = []
        if modifiers & UInt32(cmdKey) != 0     { symbols.append("⌘") }
        if modifiers & UInt32(shiftKey) != 0   { symbols.append("⇧") }
        if modifiers & UInt32(optionKey) != 0  { symbols.append("⌥") }
        if modifiers & UInt32(controlKey) != 0 { symbols.append("⌃") }

        let keyNames: [UInt32: String] = [
            49: "Space", 9: "V", 8: "C", 0: "A", 1: "S", 2: "D",
            3: "F", 5: "G", 4: "H", 38: "J", 40: "K", 37: "L",
            6: "Z", 7: "X", 11: "B", 45: "N", 46: "M",
        ]
        symbols.append(keyNames[keyCode] ?? "Key(\(keyCode))")
        return symbols.joined()
    }
}
