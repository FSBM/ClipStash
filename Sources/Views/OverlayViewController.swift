import Cocoa

/// View modes for displaying clipboard items.
enum ViewMode {
    case list, grid
}

/// Content tabs.
enum ContentTab {
    case clipboard, typed
}

/// Main view controller for the clipboard overlay.
///
/// Features: search, tab bar (Clipboard / Typed), view toggle (List / Grid),
/// glassmorphic dark theme, keyboard navigation.
final class OverlayViewController: NSViewController, NSTextFieldDelegate {
    weak var delegate: OverlayViewControllerDelegate?

    private let clipboard: ClipboardMonitoring
    private let searchField = NSTextField()
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let countLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(labelWithString: "")
    private var selectedIndex = -1

    private var viewMode: ViewMode = .list
    private var activeTab: ContentTab = .clipboard

    // Tab buttons
    private let clipboardTabBtn = NSButton()
    private let typedTabBtn = NSButton()
    private let viewToggleBtn = NSButton()

    init(clipboard: ClipboardMonitoring) {
        self.clipboard = clipboard
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - View Lifecycle

    override func loadView() {
        // Glassmorphism: use NSVisualEffectView as the root
        let blurView = NSVisualEffectView(frame: NSRect(
            x: 0, y: 0, width: Layout.panelWidth, height: Layout.panelHeight
        ))
        blurView.material = .hudWindow
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = Layout.cornerRadius
        blurView.layer?.masksToBounds = true
        blurView.layer?.borderColor = Theme.border.cgColor
        blurView.layer?.borderWidth = 1
        self.view = blurView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildSearchBar()
        buildTabBar()
        buildClipList()
        buildFooter()
        reloadList()
        NotificationCenter.default.addObserver(
            self, selector: #selector(reloadList), name: .clipboardUpdated, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(onTypedTextUpdate), name: .typedTextUpdated, object: nil
        )
    }

    @objc private func onTypedTextUpdate() {
        if activeTab == .typed { reloadList() }
    }

    // MARK: - Search Bar

    private func buildSearchBar() {
        let container = NSView()
        container.wantsLayer = true
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        let iconView = NSImageView()
        if let sfImage = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search") {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            iconView.image = sfImage.withSymbolConfiguration(config)
            iconView.contentTintColor = Theme.textSecondary
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)
        let icon = iconView

        searchField.placeholderString = "Search..."
        searchField.font = Theme.searchFont
        searchField.textColor = .white
        searchField.backgroundColor = .clear
        searchField.isBordered = false
        searchField.focusRingType = .none
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(searchField)

        let divider = makeDivider()
        view.addSubview(divider)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.heightAnchor.constraint(equalToConstant: Layout.searchBarHeight),

            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            searchField.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            searchField.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            divider.topAnchor.constraint(equalTo: container.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Layout.horizontalPadding),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Layout.horizontalPadding),
            divider.heightAnchor.constraint(equalToConstant: 1),
        ])
    }

    // MARK: - Tab Bar

    private func buildTabBar() {
        let tabContainer = NSView()
        tabContainer.wantsLayer = true
        tabContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabContainer)

        configureTabButton(clipboardTabBtn, title: "Clipboard", tag: 0)
        configureTabButton(typedTabBtn, title: "Typed Text", tag: 1)
        configureViewToggle()

        tabContainer.addSubview(clipboardTabBtn)
        tabContainer.addSubview(typedTabBtn)
        tabContainer.addSubview(viewToggleBtn)

        clipboardTabBtn.translatesAutoresizingMaskIntoConstraints = false
        typedTabBtn.translatesAutoresizingMaskIntoConstraints = false
        viewToggleBtn.translatesAutoresizingMaskIntoConstraints = false

        let topOffset = 8 + Layout.searchBarHeight + 1
        NSLayoutConstraint.activate([
            tabContainer.topAnchor.constraint(equalTo: view.topAnchor, constant: topOffset),
            tabContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabContainer.heightAnchor.constraint(equalToConstant: Layout.tabBarHeight),

            clipboardTabBtn.leadingAnchor.constraint(equalTo: tabContainer.leadingAnchor, constant: 14),
            clipboardTabBtn.centerYAnchor.constraint(equalTo: tabContainer.centerYAnchor),
            clipboardTabBtn.widthAnchor.constraint(equalToConstant: 90),
            clipboardTabBtn.heightAnchor.constraint(equalToConstant: 26),

            typedTabBtn.leadingAnchor.constraint(equalTo: clipboardTabBtn.trailingAnchor, constant: 6),
            typedTabBtn.centerYAnchor.constraint(equalTo: tabContainer.centerYAnchor),
            typedTabBtn.widthAnchor.constraint(equalToConstant: 90),
            typedTabBtn.heightAnchor.constraint(equalToConstant: 26),

            viewToggleBtn.trailingAnchor.constraint(equalTo: tabContainer.trailingAnchor, constant: -14),
            viewToggleBtn.centerYAnchor.constraint(equalTo: tabContainer.centerYAnchor),
            viewToggleBtn.widthAnchor.constraint(equalToConstant: 28),
            viewToggleBtn.heightAnchor.constraint(equalToConstant: 26),
        ])

        updateTabAppearance()
    }

    private func configureTabButton(_ btn: NSButton, title: String, tag: Int) {
        btn.title = title
        btn.tag = tag
        btn.bezelStyle = .smallSquare
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 6
        btn.font = Theme.tabFont
        btn.target = self
        btn.action = #selector(tabClicked(_:))
        btn.contentTintColor = .white
    }

    private func configureViewToggle() {
        viewToggleBtn.bezelStyle = .smallSquare
        viewToggleBtn.isBordered = false
        viewToggleBtn.wantsLayer = true
        viewToggleBtn.layer?.cornerRadius = 6
        viewToggleBtn.target = self
        viewToggleBtn.action = #selector(toggleViewMode)
        viewToggleBtn.toolTip = "Toggle List/Grid view"
        updateViewToggleIcon()
    }

    private func updateViewToggleIcon() {
        let symbolName = viewMode == .list ? "square.grid.2x2" : "list.bullet"
        if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Toggle view") {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            viewToggleBtn.image = img.withSymbolConfiguration(config)
            viewToggleBtn.contentTintColor = Theme.textSecondary
            viewToggleBtn.title = ""
        }
    }

    @objc private func tabClicked(_ sender: NSButton) {
        activeTab = sender.tag == 0 ? .clipboard : .typed
        updateTabAppearance()
        reloadList()
    }

    @objc private func toggleViewMode() {
        viewMode = viewMode == .list ? .grid : .list
        updateViewToggleIcon()
        reloadList()
    }

    private func updateTabAppearance() {
        clipboardTabBtn.layer?.backgroundColor = (activeTab == .clipboard ? Theme.tabActive : Theme.tabInactive).cgColor
        typedTabBtn.layer?.backgroundColor = (activeTab == .typed ? Theme.tabActive : Theme.tabInactive).cgColor
    }

    // MARK: - Clip List

    private func buildClipList() {
        stackView.orientation = .vertical
        stackView.spacing = Layout.rowSpacing
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

        emptyLabel.stringValue = "Nothing here yet"
        emptyLabel.font = Theme.font(ofSize: 13, weight: .medium)
        emptyLabel.textColor = Theme.textTertiary
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)

        let topOffset: CGFloat = 8 + Layout.searchBarHeight + 1 + Layout.tabBarHeight + 2
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: topOffset),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Layout.scrollInset),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Layout.scrollInset),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Layout.footerHeight),

            stackView.topAnchor.constraint(equalTo: clipView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
    }

    // MARK: - Footer

    private func buildFooter() {
        countLabel.font = Theme.footerFont
        countLabel.textColor = Theme.textTertiary
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(countLabel)

        let hint = NSTextField(labelWithString: "↩ paste  ·  ⌘⌫ del  ·  right-click pin  ·  ⌥Space toggle  ·  esc close")
        hint.font = Theme.footerFont
        hint.textColor = Theme.textHint
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)

        NSLayoutConstraint.activate([
            countLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            countLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            hint.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
        ])
    }

    // MARK: - List Management

    @objc func reloadList() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        selectedIndex = -1

        switch activeTab {
        case .clipboard:
            reloadClipboardTab()
        case .typed:
            reloadTypedTab()
        }

        // Scroll to top after layout
        DispatchQueue.main.async { [weak self] in
            self?.scrollView.contentView.scroll(to: .zero)
        }
    }

    private func reloadClipboardTab() {
        let filtered = clipboard.search(query: searchField.stringValue)
        emptyLabel.isHidden = !filtered.isEmpty
        emptyLabel.stringValue = "No clips yet — copy something!"
        countLabel.stringValue = "\(filtered.count) clip\(filtered.count == 1 ? "" : "s")"

        switch viewMode {
        case .list:
            stackView.spacing = Layout.rowSpacing
            stackView.alignment = .leading
            for item in filtered {
                stackView.addArrangedSubview(makeListRow(for: item))
            }
        case .grid:
            stackView.spacing = Layout.gridSpacing
            stackView.alignment = .centerX
            let rows = stride(from: 0, to: filtered.count, by: Layout.gridColumns)
            for startIdx in rows {
                let endIdx = min(startIdx + Layout.gridColumns, filtered.count)
                let rowItems = Array(filtered[startIdx..<endIdx])
                stackView.addArrangedSubview(makeGridRow(for: rowItems))
            }
        }
    }

    private func reloadTypedTab() {
        let query = searchField.stringValue
        let segments = KeystrokeMonitor.shared.search(query: query)
        emptyLabel.isHidden = !segments.isEmpty
        if segments.isEmpty {
            emptyLabel.stringValue = "Type in another app, then check here"
        }
        countLabel.stringValue = "\(segments.count) segment\(segments.count == 1 ? "" : "s")"

        switch viewMode {
        case .list:
            stackView.spacing = Layout.rowSpacing
            stackView.alignment = .leading
            for segment in segments {
                stackView.addArrangedSubview(makeTypedRow(for: segment))
            }
        case .grid:
            stackView.spacing = Layout.gridSpacing
            stackView.alignment = .centerX
            let rows = stride(from: 0, to: segments.count, by: Layout.gridColumns)
            for startIdx in rows {
                let endIdx = min(startIdx + Layout.gridColumns, segments.count)
                let rowSegments = Array(segments[startIdx..<endIdx])
                stackView.addArrangedSubview(makeTypedGridRow(for: rowSegments))
            }
        }
    }

    private func makeTypedGridRow(for segments: [TypedSegment]) -> NSStackView {
        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.spacing = Layout.gridSpacing
        hStack.alignment = .top
        hStack.translatesAutoresizingMaskIntoConstraints = false

        for segment in segments {
            let card = NSView()
            card.wantsLayer = true
            card.layer?.cornerRadius = 10
            card.layer?.borderWidth = 1
            card.layer?.borderColor = Theme.cardBorder.cgColor
            card.layer?.backgroundColor = Theme.cardBackground.cgColor
            card.translatesAutoresizingMaskIntoConstraints = false
            card.widthAnchor.constraint(equalToConstant: Layout.gridCardWidth).isActive = true
            card.heightAnchor.constraint(equalToConstant: Layout.gridCardHeight).isActive = true

            let contentLabel = NSTextField(labelWithString: segment.preview)
            contentLabel.font = Theme.gridTitleFont
            contentLabel.textColor = Theme.textPrimary
            contentLabel.maximumNumberOfLines = 3
            contentLabel.lineBreakMode = .byTruncatingTail
            contentLabel.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(contentLabel)

            let timeFormatter = RelativeDateTimeFormatter()
            timeFormatter.unitsStyle = .abbreviated
            let timeLabel = NSTextField(labelWithString: timeFormatter.localizedString(for: segment.startTime, relativeTo: Date()))
            timeLabel.font = Theme.gridTimeFont
            timeLabel.textColor = Theme.textSecondary
            timeLabel.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(timeLabel)

            NSLayoutConstraint.activate([
                contentLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
                contentLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
                contentLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
                timeLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
                timeLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),
            ])

            let click = NSClickGestureRecognizer(target: self, action: #selector(typedRowClicked(_:)))
            card.addGestureRecognizer(click)
            card.identifier = NSUserInterfaceItemIdentifier(segment.text)

            hStack.addArrangedSubview(card)
        }
        return hStack
    }

    // MARK: - Row Builders

    private func makeListRow(for item: ClipItem) -> ClipRowView {
        let row = ClipRowView(item: item)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.rowHeight).isActive = true
        row.widthAnchor.constraint(equalToConstant: Layout.rowWidth).isActive = true

        row.onSelect = { [weak self] in
            ClipboardManager.shared.select(item)
            self?.showCopiedToast()
            self?.delegate?.overlayDidRequestDismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + Animation.pasteDelay) {
                self?.delegate?.overlayDidSelectItem()
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
        return row
    }

    private func makeGridRow(for items: [ClipItem]) -> NSStackView {
        let hStack = NSStackView()
        hStack.orientation = .horizontal
        hStack.spacing = Layout.gridSpacing
        hStack.alignment = .top
        hStack.translatesAutoresizingMaskIntoConstraints = false

        for item in items {
            let card = ClipGridItemView(item: item)
            card.translatesAutoresizingMaskIntoConstraints = false
            card.widthAnchor.constraint(equalToConstant: Layout.gridCardWidth).isActive = true
            card.heightAnchor.constraint(equalToConstant: Layout.gridCardHeight).isActive = true

            card.onSelect = { [weak self] in
                ClipboardManager.shared.select(item)
                self?.showCopiedToast()
                self?.delegate?.overlayDidRequestDismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + Animation.pasteDelay) {
                    self?.delegate?.overlayDidSelectItem()
                }
            }
            card.onPin = { [weak self] in
                ClipboardManager.shared.togglePin(item)
                self?.reloadList()
            }
            card.onDelete = { [weak self] in
                ClipboardManager.shared.remove(item)
                self?.reloadList()
            }
            hStack.addArrangedSubview(card)
        }

        return hStack
    }

    private func makeTypedRow(for segment: TypedSegment) -> NSView {
        let row = NSView()
        row.wantsLayer = true
        row.layer?.cornerRadius = Layout.rowCornerRadius
        row.layer?.backgroundColor = Theme.cardBackground.cgColor
        row.layer?.borderColor = Theme.cardBorder.cgColor
        row.layer?.borderWidth = 0.5
        row.translatesAutoresizingMaskIntoConstraints = false

        let contentLabel = NSTextField(labelWithString: segment.preview)
        contentLabel.font = Theme.contentFont
        contentLabel.textColor = Theme.textPrimary
        contentLabel.maximumNumberOfLines = 3
        contentLabel.lineBreakMode = .byTruncatingTail
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        let timeFormatter = RelativeDateTimeFormatter()
        timeFormatter.unitsStyle = .abbreviated
        let timeLabel = NSTextField(labelWithString: timeFormatter.localizedString(for: segment.startTime, relativeTo: Date()))
        timeLabel.font = Theme.timestampFont
        timeLabel.textColor = Theme.textSecondary
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        let charCount = NSTextField(labelWithString: "\(segment.text.count) chars")
        charCount.font = Theme.timestampFont
        charCount.textColor = Theme.textTertiary
        charCount.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(contentLabel)
        row.addSubview(timeLabel)
        row.addSubview(charCount)

        let pad = Layout.horizontalPadding
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            row.widthAnchor.constraint(equalToConstant: Layout.rowWidth),

            contentLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
            contentLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: pad),
            contentLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -pad),

            charCount.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: pad),
            charCount.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -8),

            timeLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -pad),
            timeLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -8),
        ])

        // Click to copy
        let click = NSClickGestureRecognizer(target: self, action: #selector(typedRowClicked(_:)))
        row.addGestureRecognizer(click)
        row.identifier = NSUserInterfaceItemIdentifier(segment.text)

        return row
    }

    @objc private func typedRowClicked(_ gesture: NSClickGestureRecognizer) {
        guard let text = gesture.view?.identifier?.rawValue else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        showCopiedToast()
    }

    // MARK: - Copied Toast

    private func showCopiedToast() {
        let pill = NSView()
        pill.wantsLayer = true
        pill.layer?.cornerRadius = 16
        pill.layer?.backgroundColor = NSColor.white.cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pill)

        let label = NSTextField(labelWithString: "Copied")
        label.font = Theme.font(ofSize: 12, weight: .bold)
        label.textColor = .black
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)

        let toast = pill
        NSLayoutConstraint.activate([
            pill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pill.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -50),
            pill.widthAnchor.constraint(equalToConstant: 80),
            pill.heightAnchor.constraint(equalToConstant: 32),
            label.centerXAnchor.constraint(equalTo: pill.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
        ])

        toast.alphaValue = 0
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            toast.animator().alphaValue = 1
        }, completionHandler: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.2
                    toast.animator().alphaValue = 0
                }, completionHandler: {
                    toast.removeFromSuperview()
                })
            }
        })
    }

    // MARK: - Public

    func focusSearch() {
        searchField.stringValue = ""
        reloadList()
        view.window?.makeFirstResponder(searchField)
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        reloadList()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        let rows = stackView.arrangedSubviews.compactMap { $0 as? ClipRowView }
        switch sel {
        case #selector(moveDown(_:)):
            moveSelection(by: 1, in: rows)
            return true
        case #selector(moveUp(_:)):
            moveSelection(by: -1, in: rows)
            return true
        case #selector(insertNewline(_:)):
            confirmSelection(in: rows)
            return true
        case #selector(cancelOperation(_:)):
            delegate?.overlayDidRequestDismiss()
            return true
        case #selector(NSText.selectAll(_:)),
             #selector(deleteBackward(_:)),
             #selector(deleteForward(_:)):
            return false
        default:
            return false
        }
    }

    // MARK: - Selection Navigation

    private func moveSelection(by delta: Int, in rows: [ClipRowView]) {
        let nextIndex = selectedIndex + delta
        guard nextIndex >= 0, nextIndex < rows.count else { return }
        if selectedIndex >= 0, selectedIndex < rows.count {
            rows[selectedIndex].isHighlighted = false
        }
        selectedIndex = nextIndex
        rows[selectedIndex].isHighlighted = true
        rows[selectedIndex].scrollToVisible(rows[selectedIndex].bounds)
    }

    private func confirmSelection(in rows: [ClipRowView]) {
        guard selectedIndex >= 0, selectedIndex < rows.count else { return }
        rows[selectedIndex].onSelect?()
    }

    // MARK: - Helpers

    private func makeDivider() -> NSView {
        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = Theme.border.cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        return divider
    }
}
