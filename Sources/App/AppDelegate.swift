import Cocoa

/// Application delegate — wires services together and manages the overlay lifecycle.
///
/// This is the composition root: it creates concrete implementations and
/// injects them. No business logic lives here.
final class AppDelegate: NSObject, NSApplicationDelegate, OverlayPanelDelegate, OverlayViewControllerDelegate {
    private var statusItem: NSStatusItem!
    private var panel: OverlayPanel!
    private var overlayVC: OverlayViewController!
    private var hotkeyService: HotkeyService!
    private var isShowing = false

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupOverlay()
        setupHotkey()
        ClipboardManager.shared.startMonitoring()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = MenuBarIcon.create()
        button.action = #selector(statusItemClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleOverlay()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Show ClipStash", action: #selector(toggleOverlay), keyEquivalent: ""))
        menu.addItem(.separator())

        let shortcutLabel = NSMenuItem(
            title: "Shortcut: \(hotkeyService.currentBinding.label)", action: nil, keyEquivalent: ""
        )
        shortcutLabel.isEnabled = false
        menu.addItem(shortcutLabel)
        menu.addItem(makeMenuItem(title: "Change Shortcut…", action: #selector(changeShortcut)))
        menu.addItem(.separator())
        menu.addItem(makeMenuItem(title: "Clear History", action: #selector(clearHistory)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit ClipStash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        ))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.menu = nil
        }
    }

    private func makeMenuItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    // MARK: - Overlay

    private func setupOverlay() {
        panel = OverlayPanel()
        panel.overlayDelegate = self

        overlayVC = OverlayViewController(clipboard: ClipboardManager.shared)
        overlayVC.delegate = self
        panel.contentViewController = overlayVC
    }

    @objc private func toggleOverlay() {
        isShowing ? hideOverlay() : showOverlay()
    }

    private func showOverlay() {
        guard !isShowing else { return }
        isShowing = true

        centerPanel()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        overlayVC.reloadList()
        overlayVC.focusSearch()

        panel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Animation.showDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hideOverlay() {
        guard isShowing else { return }
        isShowing = false

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Animation.hideDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }

    private func centerPanel() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - (Layout.panelWidth / 2),
            y: frame.midY - (Layout.panelHeight / 2)
        ))
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        hotkeyService = HotkeyService { [weak self] in
            self?.toggleOverlay()
        }
        hotkeyService.register()
    }

    /// Called by the Carbon event handler (must be accessible from C callback).
    @objc func hotkeyTriggered() {
        toggleOverlay()
    }

    // MARK: - OverlayPanelDelegate

    func overlayPanelDidResignKey() {
        hideOverlay()
    }

    // MARK: - OverlayViewControllerDelegate

    func overlayDidRequestDismiss() {
        hideOverlay()
    }

    func overlayDidSelectItem() {
        KeyboardSimulator.simulatePaste()
    }

    // MARK: - Menu Actions

    @objc private func changeShortcut() {
        let alert = NSAlert()
        alert.messageText = "Change Shortcut"
        alert.informativeText = "Current: \(hotkeyService.currentBinding.label)\n\nChoose a new shortcut:"
        alert.alertStyle = .informational

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 250, height: 28), pullsDown: false)
        for (index, preset) in HotkeyService.presets.enumerated() {
            popup.addItem(withTitle: preset.label)
            if preset.modifiers == hotkeyService.currentBinding.modifiers &&
               preset.keyCode == hotkeyService.currentBinding.keyCode {
                popup.selectItem(at: index)
            }
        }

        alert.accessoryView = popup
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        hotkeyService.updateBinding(HotkeyService.presets[popup.indexOfSelectedItem])
    }

    @objc private func clearHistory() {
        ClipboardManager.shared.clearUnpinned()
        overlayVC.reloadList()
    }
}
