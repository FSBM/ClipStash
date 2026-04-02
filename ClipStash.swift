import Cocoa
import Carbon.HIToolbox

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Data Model
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct ClipItem: Codable {
    let id: String
    let content: String
    let timestamp: Date
    var pinned: Bool

    init(content: String, pinned: Bool = false) {
        self.id = UUID().uuidString
        self.content = content
        self.timestamp = Date()
        self.pinned = pinned
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Clipboard Manager
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ClipboardManager {
    static let shared = ClipboardManager()
    var items: [ClipItem] = []
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let maxItems = 50
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ClipStash")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("history.json")
        load()
    }

    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    private func check() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        guard let text = pb.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if items.first?.content == text { return }
        items.removeAll { $0.content == text }
        items.insert(ClipItem(content: text), at: 0)
        if items.count > maxItems {
            // Keep pinned items, trim unpinned
            let pinned = items.filter { $0.pinned }
            var unpinned = items.filter { !$0.pinned }
            if unpinned.count > maxItems - pinned.count {
                unpinned = Array(unpinned.prefix(maxItems - pinned.count))
            }
            items = pinned + unpinned
            items.sort { $0.timestamp > $1.timestamp }
        }
        save()
        NotificationCenter.default.post(name: .clipboardUpdated, object: nil)
    }

    func copyItem(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.content, forType: .string)
        lastChangeCount = pb.changeCount
        // Move to top
        items.removeAll { $0.id == item.id }
        var moved = item
        moved = ClipItem(content: item.content, pinned: item.pinned)
        items.insert(moved, at: 0)
        save()
    }

    func togglePin(_ item: ClipItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].pinned.toggle()
            save()
        }
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearAll() {
        items.removeAll { !$0.pinned }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let saved = try? JSONDecoder().decode([ClipItem].self, from: data) else { return }
        items = saved
    }
}

extension Notification.Name {
    static let clipboardUpdated = Notification.Name("clipboardUpdated")
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Overlay Panel (Spotlight-style)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class OverlayPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 480),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .floating
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        // FIX #2a: Close panel when user clicks outside it
        self.hidesOnDeactivate = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // FIX #2b: Dismiss when losing focus (clicking outside)
    override func resignKey() {
        super.resignKey()
        (NSApp.delegate as? AppDelegate)?.hideOverlay()
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Custom Views
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class ClipRowView: NSView {
    let item: ClipItem
    var onSelect: (() -> Void)?
    var onPin: (() -> Void)?
    var onDelete: (() -> Void)?
    var isSelected = false { didSet { needsDisplay = true } }

    private let contentLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "")
    private let pinIcon = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?

    init(item: ClipItem) {
        self.item = item
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 8

        // Content
        let preview = item.content
            .replacingOccurrences(of: "\n", with: " ↵ ")
            .trimmingCharacters(in: .whitespaces)
        let maxLen = 120
        contentLabel.stringValue = preview.count > maxLen ? String(preview.prefix(maxLen)) + "…" : preview
        contentLabel.font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        contentLabel.textColor = NSColor.white.withAlphaComponent(0.88)
        contentLabel.maximumNumberOfLines = 2
        contentLabel.lineBreakMode = .byTruncatingTail
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        // Time
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        timeLabel.stringValue = formatter.localizedString(for: item.timestamp, relativeTo: Date())
        timeLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        timeLabel.textColor = NSColor.white.withAlphaComponent(0.35)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        // Pin indicator
        pinIcon.stringValue = item.pinned ? "📌" : ""
        pinIcon.font = NSFont.systemFont(ofSize: 10)
        pinIcon.translatesAutoresizingMaskIntoConstraints = false

        addSubview(contentLabel)
        addSubview(timeLabel)
        addSubview(pinIcon)

        NSLayoutConstraint.activate([
            contentLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            contentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            contentLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            pinIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            pinIcon.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            timeLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) { isSelected = true }
    override func mouseExited(with event: NSEvent) { isSelected = false }

    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 1 { onSelect?() }
    }

    override func rightMouseUp(with event: NSEvent) {
        let menu = NSMenu()
        let pinTitle = item.pinned ? "Unpin" : "Pin"
        let pinItem = NSMenuItem(title: pinTitle, action: #selector(pinAction), keyEquivalent: "")
        pinItem.target = self
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteAction), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(pinItem)
        menu.addItem(deleteItem)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc func pinAction() { onPin?() }
    @objc func deleteAction() { onDelete?() }

    override func draw(_ dirtyRect: NSRect) {
        if isSelected {
            NSColor(white: 1, alpha: 0.08).setFill()
        } else {
            NSColor.clear.setFill()
        }
        let path = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
        path.fill()

        // Subtle bottom border
        NSColor(white: 1, alpha: 0.04).setStroke()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 14, y: 0))
        line.line(to: NSPoint(x: bounds.width - 14, y: 0))
        line.lineWidth = 0.5
        line.stroke()
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Main Overlay ViewController
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// FIX #1 & #3: Use NSTextFieldDelegate for real-time search + keyboard intercept
class OverlayViewController: NSViewController, NSTextFieldDelegate {
    private let searchField = NSTextField()
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let countLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(labelWithString: "")
    private var selectedIndex = -1
    private let manager = ClipboardManager.shared

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 480))
        container.wantsLayer = true
        container.layer?.cornerRadius = 16
        container.layer?.backgroundColor = NSColor(white: 0.08, alpha: 0.97).cgColor
        container.layer?.borderColor = NSColor(white: 1, alpha: 0.06).cgColor
        container.layer?.borderWidth = 1
        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSearch()
        setupScrollView()
        setupFooter()
        reloadList()

        NotificationCenter.default.addObserver(self, selector: #selector(reloadList), name: .clipboardUpdated, object: nil)
    }

    private func setupSearch() {
        // Search container
        let searchContainer = NSView()
        searchContainer.wantsLayer = true
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchContainer)

        // Search icon
        let icon = NSTextField(labelWithString: "⌘")
        icon.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        icon.textColor = NSColor.white.withAlphaComponent(0.3)
        icon.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(icon)

        // Search field
        searchField.placeholderString = "Search clipboard history..."
        searchField.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        searchField.textColor = .white
        searchField.backgroundColor = .clear
        searchField.isBordered = false
        searchField.focusRingType = .none
        // FIX #1: Set delegate for real-time search instead of action
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(searchField)

        // Divider
        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor(white: 1, alpha: 0.06).cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(divider)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchContainer.heightAnchor.constraint(equalToConstant: 48),

            icon.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),

            searchField.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -16),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),

            divider.topAnchor.constraint(equalTo: searchContainer.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            divider.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    private func setupScrollView() {
        stackView.orientation = .vertical
        stackView.spacing = 2
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let clipView = NSClipView()
        clipView.documentView = stackView
        clipView.drawsBackground = false

        scrollView.contentView = clipView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller?.alphaValue = 0.3
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        // Empty state
        emptyLabel.stringValue = "No clips yet — copy something!"
        emptyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        emptyLabel.textColor = NSColor.white.withAlphaComponent(0.25)
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 58),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -36),

            stackView.topAnchor.constraint(equalTo: clipView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
    }

    private func setupFooter() {
        countLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        countLabel.textColor = NSColor.white.withAlphaComponent(0.25)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(countLabel)

        let hint = NSTextField(labelWithString: "↩ paste  ·  ⌘⌫ delete  ·  right-click pin  ·  ⌥Space toggle  ·  esc close")
        hint.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        hint.textColor = NSColor.white.withAlphaComponent(0.2)
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)

        NSLayoutConstraint.activate([
            countLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            countLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            hint.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
        ])
    }

    // FIX #1: Real-time search — fires on every keystroke
    func controlTextDidChange(_ obj: Notification) {
        reloadList()
    }

    // FIX #3: Intercept arrow keys, Enter, Escape while search field has focus
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let rows = stackView.arrangedSubviews.compactMap { $0 as? ClipRowView }

        if commandSelector == #selector(moveDown(_:)) {
            if selectedIndex < rows.count - 1 {
                if selectedIndex >= 0 { rows[selectedIndex].isSelected = false }
                selectedIndex += 1
                rows[selectedIndex].isSelected = true
                rows[selectedIndex].scrollToVisible(rows[selectedIndex].bounds)
            }
            return true
        }
        if commandSelector == #selector(moveUp(_:)) {
            if selectedIndex > 0 {
                rows[selectedIndex].isSelected = false
                selectedIndex -= 1
                rows[selectedIndex].isSelected = true
                rows[selectedIndex].scrollToVisible(rows[selectedIndex].bounds)
            }
            return true
        }
        if commandSelector == #selector(insertNewline(_:)) {
            if selectedIndex >= 0 && selectedIndex < rows.count {
                rows[selectedIndex].onSelect?()
            }
            return true
        }
        if commandSelector == #selector(cancelOperation(_:)) {
            dismiss()
            return true
        }
        return false
    }

    @objc func reloadList() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        selectedIndex = -1

        let query = searchField.stringValue.lowercased()
        let filtered: [ClipItem]
        if query.isEmpty {
            filtered = manager.items
        } else {
            filtered = manager.items.filter { $0.content.lowercased().contains(query) }
        }

        emptyLabel.isHidden = !filtered.isEmpty
        countLabel.stringValue = "\(filtered.count) clip\(filtered.count == 1 ? "" : "s")"

        for item in filtered {
            let row = ClipRowView(item: item)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
            row.widthAnchor.constraint(equalToConstant: 604).isActive = true

            row.onSelect = { [weak self] in
                ClipboardManager.shared.copyItem(item)
                self?.dismiss()
                // Simulate Cmd+V paste
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self?.simulatePaste()
                }
            }
            row.onPin = { [weak self] in
                ClipboardManager.shared.togglePin(item)
                self?.reloadList()
            }
            row.onDelete = { [weak self] in
                ClipboardManager.shared.remove(item)
                self?.reloadList()
            }

            stackView.addArrangedSubview(row)
        }
    }

    private func dismiss() {
        (NSApp.delegate as? AppDelegate)?.hideOverlay()
    }

    private func simulatePaste() {
        let src = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true) // V key
        keyDown?.flags = CGEventFlags.maskCommand
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = CGEventFlags.maskCommand
        keyDown?.post(tap: CGEventTapLocation.cghidEventTap)
        keyUp?.post(tap: CGEventTapLocation.cghidEventTap)
    }

    // Keyboard navigation
    override func keyDown(with event: NSEvent) {
        let rows = stackView.arrangedSubviews.compactMap { $0 as? ClipRowView }
        switch event.keyCode {
        case 125: // Down arrow
            if selectedIndex < rows.count - 1 {
                if selectedIndex >= 0 { rows[selectedIndex].isSelected = false }
                selectedIndex += 1
                rows[selectedIndex].isSelected = true
                rows[selectedIndex].scrollToVisible(rows[selectedIndex].bounds)
            }
        case 126: // Up arrow
            if selectedIndex > 0 {
                rows[selectedIndex].isSelected = false
                selectedIndex -= 1
                rows[selectedIndex].isSelected = true
                rows[selectedIndex].scrollToVisible(rows[selectedIndex].bounds)
            }
        case 36: // Return - paste selected
            if selectedIndex >= 0 && selectedIndex < rows.count {
                rows[selectedIndex].onSelect?()
            }
        case 51: // Delete
            if event.modifierFlags.contains(.command) && selectedIndex >= 0 && selectedIndex < rows.count {
                rows[selectedIndex].onDelete?()
            }
        case 53: // Escape
            dismiss()
        default:
            super.keyDown(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    func focusSearch() {
        searchField.stringValue = ""
        reloadList()
        view.window?.makeFirstResponder(searchField)
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - App Delegate
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: OverlayPanel!
    var overlayVC: OverlayViewController!
    var hotKeyRef: EventHotKeyRef?
    private var panelIsShowing = false

    // Shortcut configuration (persisted in UserDefaults)
    private let defaultKeyCode: UInt32 = 49       // Space
    private let defaultModifiers: UInt32 = UInt32(optionKey)  // Option

    private var currentKeyCode: UInt32 {
        get {
            let val = UserDefaults.standard.integer(forKey: "hotkey_keycode")
            return val == 0 ? defaultKeyCode : UInt32(val)
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkey_keycode") }
    }

    private var currentModifiers: UInt32 {
        get {
            let val = UserDefaults.standard.integer(forKey: "hotkey_modifiers")
            return val == 0 ? defaultModifiers : UInt32(val)
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: "hotkey_modifiers") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // FIX #4: Menu bar — left-click toggles, right-click shows menu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            // Create menu bar icon: render "CP" text as an image
            let size = NSSize(width: 24, height: 22)
            let img = NSImage(size: size, flipped: false) { rect in
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 12, weight: .bold),
                    .foregroundColor: NSColor.black
                ]
                let str = NSAttributedString(string: "CP", attributes: attrs)
                let strSize = str.size()
                let x = (rect.width - strSize.width) / 2
                let y = (rect.height - strSize.height) / 2
                str.draw(at: NSPoint(x: x, y: y))
                return true
            }
            img.isTemplate = true
            btn.image = img
            btn.action = #selector(statusItemClicked)
            btn.target = self
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Setup overlay panel
        panel = OverlayPanel()
        overlayVC = OverlayViewController()
        panel.contentViewController = overlayVC

        // Start clipboard monitoring
        ClipboardManager.shared.startMonitoring()

        // Register global hotkey (default: Option + Space)
        registerHotKey()
    }

    // FIX #4: Left-click = toggle, right-click = menu
    @objc func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Show ClipStash", action: #selector(toggleOverlay), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())

            let shortcutItem = NSMenuItem(title: "Shortcut: \(shortcutDisplayString())", action: nil, keyEquivalent: "")
            shortcutItem.isEnabled = false
            menu.addItem(shortcutItem)

            let changeShortcutItem = NSMenuItem(title: "Change Shortcut…", action: #selector(changeShortcut), keyEquivalent: "")
            changeShortcutItem.target = self
            menu.addItem(changeShortcutItem)
            menu.addItem(NSMenuItem.separator())

            let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
            clearItem.target = self
            menu.addItem(clearItem)
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit ClipStash", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            // Remove menu after it closes so left-click works again
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.menu = nil
            }
        } else {
            toggleOverlay()
        }
    }

    func registerHotKey() {
        // Unregister previous hotkey if exists
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x434C5053) // "CLPS"
        hotKeyID.id = 1

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { (_, event, _) -> OSStatus in
            DispatchQueue.main.async {
                (NSApp.delegate as? AppDelegate)?.toggleOverlay()
            }
            return noErr
        }, 1, &eventType, nil, nil)

        RegisterEventHotKey(currentKeyCode, currentModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func shortcutDisplayString() -> String {
        var parts: [String] = []
        let mods = currentModifiers
        if mods & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if mods & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if mods & UInt32(optionKey) != 0 { parts.append("⌥") }
        if mods & UInt32(controlKey) != 0 { parts.append("⌃") }

        let keyNames: [UInt32: String] = [
            49: "Space", 9: "V", 8: "C", 0: "A", 1: "S", 2: "D",
            3: "F", 5: "G", 4: "H", 38: "J", 40: "K", 37: "L",
            6: "Z", 7: "X", 11: "B", 45: "N", 46: "M",
            36: "↩", 48: "⇥", 51: "⌫", 53: "⎋",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        parts.append(keyNames[currentKeyCode] ?? "Key(\(currentKeyCode))")
        return parts.joined(separator: "")
    }

    // FIX #2c: Use explicit state flag instead of panel.isVisible
    @objc func toggleOverlay() {
        if panelIsShowing {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    func showOverlay() {
        guard !panelIsShowing else { return }
        panelIsShowing = true

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelWidth: CGFloat = 620
            let panelHeight: CGFloat = 480
            let x = screenFrame.midX - (panelWidth / 2)
            let y = screenFrame.midY - (panelHeight / 2)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        overlayVC.reloadList()
        overlayVC.focusSearch()

        panel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hideOverlay() {
        guard panelIsShowing else { return }
        panelIsShowing = false

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }

    @objc func changeShortcut() {
        let alert = NSAlert()
        alert.messageText = "Change Shortcut"
        alert.informativeText = "Press your desired shortcut key combination.\n\nCurrent: \(shortcutDisplayString())\n\nChoose a modifier + key combination:"
        alert.alertStyle = .informational

        let shortcuts: [(String, UInt32, UInt32)] = [
            ("⌥ Space (Option+Space)", UInt32(optionKey), 49),
            ("⌘⇧ V (Cmd+Shift+V)", UInt32(cmdKey | shiftKey), 9),
            ("⌃⇧ V (Ctrl+Shift+V)", UInt32(controlKey | shiftKey), 9),
            ("⌘⇧ C (Cmd+Shift+C)", UInt32(cmdKey | shiftKey), 8),
            ("⌥⇧ V (Option+Shift+V)", UInt32(optionKey | shiftKey), 9),
        ]

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 250, height: 28), pullsDown: false)
        for (i, s) in shortcuts.enumerated() {
            popup.addItem(withTitle: s.0)
            popup.item(at: i)?.tag = i
        }
        // Select current shortcut if it matches
        for (i, s) in shortcuts.enumerated() {
            if s.1 == currentModifiers && s.2 == currentKeyCode {
                popup.selectItem(at: i)
                break
            }
        }
        alert.accessoryView = popup
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let idx = popup.indexOfSelectedItem
            let chosen = shortcuts[idx]
            currentModifiers = chosen.1
            currentKeyCode = chosen.2
            registerHotKey()
        }
    }

    @objc func clearHistory() {
        ClipboardManager.shared.clearAll()
        overlayVC.reloadList()
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - Entry Point
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
