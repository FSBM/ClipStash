import Foundation

/// A single clipboard history entry.
///
/// Immutable except for `pinned` — content and timestamp are fixed at creation.
/// Conforms to `Codable` for JSON persistence and `Identifiable` for list diffing.
struct ClipItem: Codable, Identifiable {
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

    /// Single-line preview with newlines replaced and length capped.
    var preview: String {
        let flat = content
            .replacingOccurrences(of: "\n", with: " ↵ ")
            .trimmingCharacters(in: .whitespaces)
        if flat.count > Clipboard.maxPreviewLength {
            return String(flat.prefix(Clipboard.maxPreviewLength)) + "…"
        }
        return flat
    }
}
