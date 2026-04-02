import Cocoa

/// Visual styling: colors and fonts.
/// Single source of truth — update the dark theme here.
enum Theme {
    // Colors
    static let background  = NSColor(white: 0.08, alpha: 0.97)
    static let border      = NSColor(white: 1, alpha: 0.06)
    static let textPrimary   = NSColor.white.withAlphaComponent(0.88)
    static let textSecondary = NSColor.white.withAlphaComponent(0.35)
    static let textTertiary  = NSColor.white.withAlphaComponent(0.25)
    static let textHint      = NSColor.white.withAlphaComponent(0.2)
    static let rowHover    = NSColor(white: 1, alpha: 0.08)
    static let rowDivider  = NSColor(white: 1, alpha: 0.04)

    // Fonts
    static let contentFont   = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
    static let timestampFont = NSFont.systemFont(ofSize: 10, weight: .medium)
    static let searchFont    = NSFont.systemFont(ofSize: 16, weight: .regular)
    static let footerFont    = NSFont.systemFont(ofSize: 10, weight: .medium)
}
