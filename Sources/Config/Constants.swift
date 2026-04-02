import Foundation

/// Clipboard behavior settings.
enum Clipboard {
    static let maxItems = 50
    static let pollInterval: TimeInterval = 0.5
    static let maxPreviewLength = 120
}

/// Animation timing.
enum Animation {
    static let showDuration: TimeInterval = 0.15
    static let hideDuration: TimeInterval = 0.12
    static let pasteDelay: TimeInterval = 0.15
}

/// App-wide notification names.
extension Notification.Name {
    static let clipboardUpdated = Notification.Name("ClipStash.clipboardUpdated")
}
