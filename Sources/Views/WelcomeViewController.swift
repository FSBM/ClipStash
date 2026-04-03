import Cocoa

final class WelcomeViewController: NSViewController {
    var onComplete: (() -> Void)?

    private var axRow: PermissionRow!
    private var imRow: PermissionRow!
    private var checkTimer: Timer?

    override func loadView() {
        let blurView = NSVisualEffectView(frame: NSRect(
            x: 0, y: 0, width: Layout.panelWidth, height: Layout.panelHeight
        ))
        blurView.material = .hudWindow
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        blurView.wantsLayer = true
        blurView.layer?.cornerRadius = Layout.cornerRadius
        blurView.layer?.masksToBounds = true
        blurView.layer?.borderColor = NSColor(white: 1, alpha: 0.1).cgColor
        blurView.layer?.borderWidth = 1
        self.view = blurView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        startPermissionPolling()
    }

    private func buildUI() {
        // Bird logo
        let resourcePath = Bundle.main.resourcePath ?? ""
        let birdView = NSImageView()
        if let img = NSImage(contentsOfFile: resourcePath + "/intro-bird.png") {
            birdView.image = img
            birdView.imageScaling = .scaleProportionallyUpOrDown
        }
        birdView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(birdView)

        let titleLabel = NSTextField(labelWithString: "Welcome to ClipStash")
        titleLabel.font = Theme.font(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: "Your clipboard history, always at hand")
        subtitleLabel.font = Theme.font(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = NSColor(white: 1, alpha: 0.5)
        subtitleLabel.alignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        let permLabel = NSTextField(labelWithString: "PERMISSIONS REQUIRED")
        permLabel.font = Theme.font(ofSize: 10, weight: .medium)
        permLabel.textColor = NSColor(white: 1, alpha: 0.3)
        permLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(permLabel)

        // Permission rows
        axRow = PermissionRow(title: "Accessibility") { [weak self] in
            self?.grantAccessibility()
        }
        imRow = PermissionRow(title: "Input Monitoring") { [weak self] in
            self?.grantInputMonitoring()
        }
        axRow.translatesAutoresizingMaskIntoConstraints = false
        imRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(axRow)
        view.addSubview(imRow)

        // Get Started
        let startBtn = NSView()
        startBtn.wantsLayer = true
        startBtn.layer?.cornerRadius = 10
        startBtn.layer?.backgroundColor = NSColor.white.cgColor
        startBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(startBtn)

        let startLabel = NSTextField(labelWithString: "Get Started")
        startLabel.font = Theme.font(ofSize: 14, weight: .bold)
        startLabel.textColor = .black
        startLabel.alignment = .center
        startLabel.translatesAutoresizingMaskIntoConstraints = false
        startBtn.addSubview(startLabel)

        let startClick = NSClickGestureRecognizer(target: self, action: #selector(startApp))
        startBtn.addGestureRecognizer(startClick)

        NSLayoutConstraint.activate([
            birdView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            birdView.topAnchor.constraint(equalTo: view.topAnchor, constant: 30),
            birdView.widthAnchor.constraint(equalToConstant: 140),
            birdView.heightAnchor.constraint(equalToConstant: 180),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: birdView.bottomAnchor, constant: 14),

            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),

            permLabel.leadingAnchor.constraint(equalTo: axRow.leadingAnchor, constant: 4),
            permLabel.bottomAnchor.constraint(equalTo: axRow.topAnchor, constant: -8),

            axRow.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            axRow.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 36),
            axRow.widthAnchor.constraint(equalToConstant: 300),
            axRow.heightAnchor.constraint(equalToConstant: 44),

            imRow.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imRow.topAnchor.constraint(equalTo: axRow.bottomAnchor, constant: 10),
            imRow.widthAnchor.constraint(equalToConstant: 300),
            imRow.heightAnchor.constraint(equalToConstant: 44),

            startBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30),
            startBtn.widthAnchor.constraint(equalToConstant: 300),
            startBtn.heightAnchor.constraint(equalToConstant: 44),

            startLabel.centerXAnchor.constraint(equalTo: startBtn.centerXAnchor),
            startLabel.centerYAnchor.constraint(equalTo: startBtn.centerYAnchor),
        ])

        updatePermissionStates()
    }

    private func updatePermissionStates() {
        axRow.setGranted(AXIsProcessTrusted())
        imRow.setGranted(KeystrokeMonitor.shared.isActive)
    }

    private func grantAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func grantInputMonitoring() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startPermissionPolling() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updatePermissionStates()
        }
    }

    @objc private func startApp() {
        checkTimer?.invalidate()
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        onComplete?()
    }
}

// MARK: - Permission Row (custom view for proper icon alignment)

private class PermissionRow: NSView {
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let title: String
    private let onClick: () -> Void
    private var granted = false

    init(title: String, onClick: @escaping () -> Void) {
        self.title = title
        self.onClick = onClick
        super.init(frame: .zero)
        buildLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildLayout() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = NSColor(white: 1, alpha: 0.15).cgColor
        layer?.backgroundColor = NSColor(white: 1, alpha: 0.05).cgColor

        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        label.font = Theme.font(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(click)

        setGranted(false)
    }

    func setGranted(_ isGranted: Bool) {
        granted = isGranted
        if isGranted {
            label.stringValue = title
            label.textColor = .white
            layer?.borderColor = NSColor(white: 1, alpha: 0.3).cgColor
            setIcon("checkmark.circle.fill", tint: .white)
        } else {
            label.stringValue = "\(title) — tap to grant"
            label.textColor = NSColor(white: 1, alpha: 0.5)
            layer?.borderColor = NSColor(white: 1, alpha: 0.15).cgColor
            setIcon("circle", tint: NSColor(white: 1, alpha: 0.3))
        }
    }

    private func setIcon(_ name: String, tint: NSColor) {
        if let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            iconView.image = img.withSymbolConfiguration(config)
            iconView.contentTintColor = tint
        }
    }

    @objc private func tapped() {
        if !granted { onClick() }
    }
}
