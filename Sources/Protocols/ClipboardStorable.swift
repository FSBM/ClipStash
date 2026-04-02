import Foundation

/// Abstraction for clipboard history storage.
/// Allows swapping persistence backends (JSON file, Core Data, SQLite)
/// without touching business logic.
protocol ClipboardStorable {
    func save(_ items: [ClipItem])
    func load() -> [ClipItem]
}
