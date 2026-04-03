import Cocoa

/// Visual styling: colors and fonts.
/// Glassmorphism dark theme with Visuelt Pro (fallback: Avenir Next → system).
enum Theme {
    // MARK: - Font Resolution

    /// Tries Visuelt Pro, falls back to Avenir Next, then system font.
    static func font(ofSize size: CGFloat, weight: NSFont.Weight) -> NSFont {
        if let visuelt = NSFont(name: visueltName(for: weight), size: size) {
            return visuelt
        }
        if let avenir = NSFont(name: avenirName(for: weight), size: size) {
            return avenir
        }
        return NSFont.systemFont(ofSize: size, weight: weight)
    }

    private static func visueltName(for weight: NSFont.Weight) -> String {
        switch weight {
        case .bold: return "VisueltPro-Bold"
        case .medium: return "VisueltPro-Medium"
        case .light: return "VisueltPro-Light"
        default: return "VisueltPro-Regular"
        }
    }

    private static func avenirName(for weight: NSFont.Weight) -> String {
        switch weight {
        case .bold: return "AvenirNext-Bold"
        case .medium: return "AvenirNext-Medium"
        case .light: return "AvenirNext-UltraLight"
        default: return "AvenirNext-Regular"
        }
    }

    // MARK: - Glassmorphism Colors

    static let panelBackground = NSColor(white: 0.05, alpha: 0.65)
    static let cardBackground  = NSColor(white: 0.12, alpha: 0.5)
    static let cardBorder      = NSColor(white: 1.0, alpha: 0.08)
    static let border          = NSColor(white: 1.0, alpha: 0.06)

    static let textPrimary   = NSColor.white.withAlphaComponent(0.92)
    static let textSecondary = NSColor.white.withAlphaComponent(0.45)
    static let textTertiary  = NSColor.white.withAlphaComponent(0.28)
    static let textHint      = NSColor.white.withAlphaComponent(0.2)

    static let rowHover      = NSColor(white: 1.0, alpha: 0.1)
    static let rowDivider    = NSColor(white: 1.0, alpha: 0.04)
    static let accent        = NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
    static let tabActive     = NSColor.white.withAlphaComponent(0.12)
    static let tabInactive   = NSColor.clear

    // MARK: - Semantic Fonts

    static let contentFont   = font(ofSize: 12.5, weight: .regular)
    static let timestampFont = font(ofSize: 10, weight: .medium)
    static let searchFont    = font(ofSize: 16, weight: .regular)
    static let footerFont    = font(ofSize: 10, weight: .medium)
    static let tabFont       = font(ofSize: 11, weight: .medium)
    static let gridTitleFont = font(ofSize: 11, weight: .medium)
    static let gridTimeFont  = font(ofSize: 9, weight: .regular)
}
