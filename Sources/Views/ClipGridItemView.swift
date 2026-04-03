import Cocoa

/// A card in the grid view — glassmorphic rounded rectangle with content preview.
final class ClipGridItemView: NSView {
    let item: ClipItem
    var onSelect: (() -> Void)?
    var onPin: (() -> Void)?
    var onDelete: (() -> Void)?

    var isHighlighted = false {
        didSet { needsDisplay = true }
    }

    private let contentLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "")
    private let pinLabel = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?

    private static let timeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    init(item: ClipItem) {
        self.item = item
        super.init(frame: .zero)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildLayout() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = Theme.cardBorder.cgColor

        contentLabel.stringValue = item.preview
        contentLabel.font = Theme.gridTitleFont
        contentLabel.textColor = Theme.textPrimary
        contentLabel.maximumNumberOfLines = 3
        contentLabel.lineBreakMode = .byTruncatingTail
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.stringValue = Self.timeFormatter.localizedString(for: item.timestamp, relativeTo: Date())
        timeLabel.font = Theme.gridTimeFont
        timeLabel.textColor = Theme.textSecondary
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        pinLabel.stringValue = item.pinned ? "pinned" : ""
        pinLabel.font = NSFont.systemFont(ofSize: 9)
        pinLabel.textColor = Theme.accent
        pinLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(contentLabel)
        addSubview(timeLabel)
        addSubview(pinLabel)

        NSLayoutConstraint.activate([
            contentLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            contentLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            contentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),

            pinLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            pinLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            timeLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    // MARK: - Mouse

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) { isHighlighted = true }
    override func mouseExited(with event: NSEvent)  { isHighlighted = false }
    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 1 {
            isHighlighted = false
            onSelect?()
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        let menu = NSMenu()
        let pinTitle = item.pinned ? "Unpin" : "Pin"
        let pinItem = NSMenuItem(title: pinTitle, action: #selector(handlePin), keyEquivalent: "")
        pinItem.target = self
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(handleDelete), keyEquivalent: "")
        deleteItem.target = self
        menu.addItem(pinItem)
        menu.addItem(deleteItem)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func handlePin() { onPin?() }
    @objc private func handleDelete() { onDelete?() }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let bg = isHighlighted ? Theme.rowHover : Theme.cardBackground
        bg.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill()
    }
}
