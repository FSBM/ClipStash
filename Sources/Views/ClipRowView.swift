import Cocoa

/// A single row in the clipboard history list.
///
/// Handles its own hover tracking, drawing, and context menu.
/// Communicates user intent via closures (onSelect, onPin, onDelete)
/// — it does not know about ClipboardManager or any other service.
final class ClipRowView: NSView {
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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    init(item: ClipItem) {
        self.item = item
        super.init(frame: .zero)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Layout

    private func buildLayout() {
        wantsLayer = true
        layer?.cornerRadius = Layout.rowCornerRadius
        configureLabels()
        addSubview(contentLabel)
        addSubview(timeLabel)
        addSubview(pinLabel)
        activateConstraints()
    }

    private func configureLabels() {
        contentLabel.stringValue = item.preview
        contentLabel.font = Theme.contentFont
        contentLabel.textColor = Theme.textPrimary
        contentLabel.maximumNumberOfLines = 2
        contentLabel.lineBreakMode = .byTruncatingTail
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        timeLabel.stringValue = Self.timeFormatter.localizedString(for: item.timestamp, relativeTo: Date())
        timeLabel.font = Theme.timestampFont
        timeLabel.textColor = Theme.textSecondary
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        pinLabel.stringValue = item.pinned ? "📌" : ""
        pinLabel.font = Theme.timestampFont
        pinLabel.translatesAutoresizingMaskIntoConstraints = false
    }

    private func activateConstraints() {
        let pad = Layout.horizontalPadding
        NSLayoutConstraint.activate([
            contentLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            contentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            contentLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            pinLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            pinLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),

            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad),
            timeLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])
    }

    // MARK: - Mouse Tracking

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) { isHighlighted = true }
    override func mouseExited(with event: NSEvent)  { isHighlighted = false }
    override func mouseUp(with event: NSEvent) { if event.clickCount == 1 { onSelect?() } }

    override func rightMouseUp(with event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(makeMenuItem(title: item.pinned ? "Unpin" : "Pin", action: #selector(handlePin)))
        menu.addItem(makeMenuItem(title: "Delete", action: #selector(handleDelete)))
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func makeMenuItem(title: String, action: Selector) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        return menuItem
    }

    @objc private func handlePin() { onPin?() }
    @objc private func handleDelete() { onDelete?() }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let fill = isHighlighted ? Theme.rowHover : NSColor.clear
        fill.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: Layout.rowCornerRadius, yRadius: Layout.rowCornerRadius).fill()

        Theme.rowDivider.setStroke()
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: Layout.horizontalPadding, y: 0))
        divider.line(to: NSPoint(x: bounds.width - Layout.horizontalPadding, y: 0))
        divider.lineWidth = 0.5
        divider.stroke()
    }
}
