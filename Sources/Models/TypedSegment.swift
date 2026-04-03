import Foundation

/// A segment of typed text recovered from keystrokes.
/// Segments are separated by gaps of 30+ seconds of inactivity.
struct TypedSegment: Codable, Identifiable {
    let id: String
    var text: String
    let startTime: Date
    var endTime: Date

    init(text: String = "") {
        self.id = UUID().uuidString
        self.text = text
        self.startTime = Date()
        self.endTime = Date()
    }

    var preview: String {
        let flat = text
            .replacingOccurrences(of: "\n", with: " ↵ ")
            .trimmingCharacters(in: .whitespaces)
        if flat.count > Clipboard.maxPreviewLength {
            return String(flat.prefix(Clipboard.maxPreviewLength)) + "…"
        }
        return flat
    }

    var isExpired: Bool {
        Date().timeIntervalSince(endTime) > Keystroke.maxAge
    }
}
