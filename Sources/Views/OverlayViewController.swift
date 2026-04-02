import Cocoa

/// Main view controller for the clipboard overlay.
///
/// Responsibilities: search bar, scrollable clip list, keyboard navigation.
/// Delegates dismissal and paste actions upward via `OverlayViewControllerDelegate`.
/// Depends on `ClipboardMonitoring` abstraction (Dependency Inversion).
final class OverlayViewController: NSViewController, NSTextFieldDelegate {
    weak var delegate: OverlayViewControllerDelegate?

    private let clipboard: ClipboardMonitoring
    private let searchField = NSTextField()
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let countLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(labelWithString: "")
    private var selectedIndex = -1

    init(clipboard: ClipboardMonitoring) {
        self.clipboard = clipboard
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - View Lifecycle

    override func loadView() {
        let container = NSView(frame: NSRect(
            x: 0, y: 0, width: Layout.panelWidth, height: Layout.panelHeight
        ))
        container.wantsLayer = true
        container.layer?.cornerRadius = Layout.cornerRadius
        container.layer?.backgroundColor = Theme.background.cgColor
        container.layer?.borderColor = Theme.border.cgColor
        container.layer?.borderWidth = 1
        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildSearchBar()
        buildClipList()
        buildFooter()
        reloadList()
        NotificationCenter.default.addObserver(
            self, selector: #selector(reloadList), name: .clipboardUpdated, object: nil
        )
    }

    // MARK: - Search Bar

    private func buildSearchBar() {
        let container = NSView()
        container.wantsLayer = true
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        let icon = NSTextField(labelWithString: "⌘")
        icon.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        icon.textColor = Theme.textHint
        icon.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(icon)

        searchField.placeholderString = "Search clipboard history..."
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

            searchField.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            searchField.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            divider.topAnchor.constraint(equalTo: container.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Layout.horizontalPadding),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -Layout.horizontalPadding),
            divider.heightAnchor.constraint(equalToConstant: 1),
        ])
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

        emptyLabel.stringValue = "No clips yet — copy something!"
        emptyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        emptyLabel.textColor = Theme.textTertiary
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)

        let topOffset: CGFloat = 8 + Layout.searchBarHeight + 2
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

        let hint = NSTextField(labelWithString: "↩ paste  ·  ⌘⌫ delete  ·  right-click pin  ·  ⌥Space toggle  ·  esc close")
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

        let filtered = clipboard.search(query: searchField.stringValue)
        emptyLabel.isHidden = !filtered.isEmpty
        countLabel.stringValue = "\(filtered.count) clip\(filtered.count == 1 ? "" : "s")"

        for item in filtered {
            stackView.addArrangedSubview(makeRow(for: item))
        }
    }

    private func makeRow(for item: ClipItem) -> ClipRowView {
        let row = ClipRowView(item: item)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.rowHeight).isActive = true
        row.widthAnchor.constraint(equalToConstant: Layout.rowWidth).isActive = true

        row.onSelect = { [weak self] in
            ClipboardManager.shared.select(item)
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
