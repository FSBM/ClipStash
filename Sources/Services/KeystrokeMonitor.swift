import Cocoa

/// Monitors keystrokes via NSEvent global monitor to enable typed-text recovery.
/// Groups keystrokes into segments separated by 30s gaps.
/// Segments older than 1 hour are pruned automatically.
final class KeystrokeMonitor {
    static let shared = KeystrokeMonitor()

    private(set) var segments: [TypedSegment] = []
    private var currentSegment: TypedSegment?
    private var lastKeystrokeTime: Date?
    private var globalMonitor: Any?
    private var pruneTimer: Timer?
    private var retryTimer: Timer?
    private(set) var isActive = false
    private var receivedFirstEvent = false
    private var usingMethod = "none"

    private let storageURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("ClipStash")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        self.storageURL = appSupport.appendingPathComponent("typed_segments.json")
        load()
    }

    // MARK: - Start

    func startMonitoring() {
        attemptInstall()

        // Retry every 5s — reinstall if we haven't received any events yet
        retryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if self.receivedFirstEvent {
                timer.invalidate()
                self.retryTimer = nil
            } else {
                // Previous install didn't work — tear down and retry
                self.tearDown()
                self.attemptInstall()
            }
        }

        pruneTimer = Timer.scheduledTimer(
            withTimeInterval: Keystroke.pruneInterval, repeats: true
        ) { [weak self] _ in
            self?.pruneExpired()
        }
    }

    private func tearDown() {
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }
        isActive = false
        usingMethod = "none"
    }

    private func attemptInstall() {
        // Try NSEvent global monitor
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.processKeyEvent(event)
        }
        if monitor != nil {
            globalMonitor = monitor
            isActive = true
            usingMethod = "NSEvent.global"
        }
    }

    // MARK: - Process Events

    private func processKeyEvent(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command) || modifiers.contains(.control) { return }
        guard let chars = event.characters, !chars.isEmpty else { return }

        if !receivedFirstEvent {
            receivedFirstEvent = true
        }

        processChars(chars)
    }

    private func processChars(_ character: String) {
        let now = Date()

        if let lastTime = lastKeystrokeTime,
           now.timeIntervalSince(lastTime) > Keystroke.segmentGap {
            finalizeCurrentSegment()
        }

        lastKeystrokeTime = now

        if currentSegment == nil {
            currentSegment = TypedSegment()
        }

        let firstChar = character.unicodeScalars.first?.value ?? 0

        if firstChar == 0x08 || firstChar == 0x7F {
            if currentSegment != nil && !currentSegment!.text.isEmpty {
                currentSegment!.text.removeLast()
            }
        } else if firstChar == 0x0D || firstChar == 0x0A {
            currentSegment?.text.append("\n")
        } else if firstChar == 0x09 {
            currentSegment?.text.append("  ")
        } else if firstChar >= 32 {
            currentSegment?.text.append(character)
        }

        currentSegment?.endTime = now
        NotificationCenter.default.post(name: .typedTextUpdated, object: nil)
    }

    // MARK: - Segment Management

    func allSegments() -> [TypedSegment] {
        var result = segments
        if let current = currentSegment,
           !current.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.insert(current, at: 0)
        }
        return result.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    func search(query: String) -> [TypedSegment] {
        let all = allSegments()
        guard !query.isEmpty else { return all }
        let lowered = query.lowercased()
        return all.filter { $0.text.lowercased().contains(lowered) }
    }

    private func finalizeCurrentSegment() {
        guard let segment = currentSegment,
              !segment.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            currentSegment = nil
            return
        }
        segments.insert(segment, at: 0)
        currentSegment = nil
        save()
    }

    private func pruneExpired() {
        segments.removeAll { $0.isExpired }
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(segments) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let saved = try? JSONDecoder().decode([TypedSegment].self, from: data) else { return }
        segments = saved.filter { !$0.isExpired }
    }
}
