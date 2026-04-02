import Cocoa

/// Monitors the system pasteboard and manages clipboard history.
///
/// Depends on `ClipboardStorable` (Dependency Inversion) — the storage
/// backend is injected, not hardcoded.
final class ClipboardManager: ClipboardMonitoring {
    static let shared = ClipboardManager(storage: JSONClipboardStorage())

    private(set) var items: [ClipItem] = []
    private var lastChangeCount = 0
    private var timer: Timer?
    private let storage: ClipboardStorable

    init(storage: ClipboardStorable) {
        self.storage = storage
        self.items = storage.load()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(
            withTimeInterval: Clipboard.pollInterval, repeats: true
        ) { [weak self] _ in
            self?.pollPasteboard()
        }
    }

    private func pollPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              items.first?.content != text else { return }

        // Deduplicate: remove old entry with same content, insert at top
        items.removeAll { $0.content == text }
        items.insert(ClipItem(content: text), at: 0)
        trimIfNeeded()
        persist()
        NotificationCenter.default.post(name: .clipboardUpdated, object: nil)
    }

    // MARK: - Actions (Single Responsibility: each method does one thing)

    func select(_ item: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        lastChangeCount = pasteboard.changeCount

        items.removeAll { $0.id == item.id }
        items.insert(ClipItem(content: item.content, pinned: item.pinned), at: 0)
        persist()
    }

    func togglePin(_ item: ClipItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].pinned.toggle()
        persist()
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clearUnpinned() {
        items.removeAll { !$0.pinned }
        persist()
    }

    func search(query: String) -> [ClipItem] {
        guard !query.isEmpty else { return items }
        let lowered = query.lowercased()
        return items.filter { $0.content.lowercased().contains(lowered) }
    }

    // MARK: - Private

    private func persist() {
        storage.save(items)
    }

    /// Enforces the max-items cap while preserving pinned items.
    private func trimIfNeeded() {
        guard items.count > Clipboard.maxItems else { return }
        let pinned = items.filter(\.pinned)
        let unpinnedLimit = Clipboard.maxItems - pinned.count
        let unpinned = Array(items.filter { !$0.pinned }.prefix(unpinnedLimit))
        items = (pinned + unpinned).sorted { $0.timestamp > $1.timestamp }
    }
}
