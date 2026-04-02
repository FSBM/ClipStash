import Cocoa

/// Generates the "CP" template image for the menu bar.
///
/// Rendered programmatically — no external PNG dependency.
/// `isTemplate = true` lets macOS auto-adapt for light/dark menu bar.
enum MenuBarIcon {
    static func create() -> NSImage {
        let size = NSSize(width: 24, height: 22)
        let image = NSImage(size: size, flipped: false) { rect in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: NSColor.black,
            ]
            let text = NSAttributedString(string: "CP", attributes: attrs)
            let textSize = text.size()
            let origin = NSPoint(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2
            )
            text.draw(at: origin)
            return true
        }
        image.isTemplate = true
        return image
    }
}
