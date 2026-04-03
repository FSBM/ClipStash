import Foundation

/// Clipboard behavior settings.
enum Clipboard {
    static let maxItems = 50
    static let pollInterval: TimeInterval = 0.5
    static let maxPreviewLength = 120
}

/// Keystroke recovery settings.
enum Keystroke {
    static let segmentGap: TimeInterval = 30   // 30s gap = new segment
    static let maxAge: TimeInterval = 3600     // 1 hour retention
    static let pruneInterval: TimeInterval = 60 // prune check every 60s
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
    static let typedTextUpdated = Notification.Name("ClipStash.typedTextUpdated")
}
