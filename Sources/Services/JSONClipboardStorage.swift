import Foundation

/// Concrete storage backend that persists clipboard history as JSON.
///
/// Implements `ClipboardStorable` — can be replaced with Core Data, SQLite,
/// or an in-memory store without changing `ClipboardManager`.
final class JSONClipboardStorage: ClipboardStorable {
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("ClipStash")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.fileURL = appSupport.appendingPathComponent("history.json")
    }

    func save(_ items: [ClipItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func load() -> [ClipItem] {
        guard let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([ClipItem].self, from: data) else {
            return []
        }
        return items
    }
}
