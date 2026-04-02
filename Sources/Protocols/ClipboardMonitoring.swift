import Foundation

/// Abstraction for clipboard monitoring.
/// Decouples polling strategy from business logic — could be swapped
/// for an event-driven approach without changing consumers.
protocol ClipboardMonitoring {
    var items: [ClipItem] { get }
    func startMonitoring()
    func select(_ item: ClipItem)
    func togglePin(_ item: ClipItem)
    func remove(_ item: ClipItem)
    func clearUnpinned()
    func search(query: String) -> [ClipItem]
}
