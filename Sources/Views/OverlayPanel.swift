import Cocoa

/// Spotlight-style floating panel.
///
/// Configured as a non-activating, transparent-titlebar panel that
/// floats above all windows and dismisses on focus loss.
final class OverlayPanel: NSPanel {
    weak var overlayDelegate: OverlayPanelDelegate?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Layout.panelWidth, height: Layout.panelHeight),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    private func configure() {
        isFloatingPanel = true
        level = .floating
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func resignKey() {
        super.resignKey()
        overlayDelegate?.overlayPanelDidResignKey()
    }
}
