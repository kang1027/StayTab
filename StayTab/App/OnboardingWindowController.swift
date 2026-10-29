import AppKit
import BetterSettings

/// First-run walkthrough: Accessibility permission, a first set of pinned apps,
/// then a real ⌘Tab. It is a one-shot window — nothing here runs on the ⌘Tab
/// path, and the only live hook is `SwitcherController.onDidReveal`, wired only
/// while this window is open.
@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {

    /// Marks the walkthrough as seen, so it never reopens.
    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: Preferences.Keys.onboardingCompleted)
    }

    static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: Preferences.Keys.onboardingCompleted)
    }

    /// Fired once when the window closes (finished, skipped, or dismissed).
    var onClose: (() -> Void)?

    private static let maxCandidates = 8

    private var steps: [OnboardingStep]
    private var index = 0
    private var candidates: [OnboardingPolicy.AppCandidate] = []
    private var candidateIcons: [String: NSImage] = [:]
    private var selected = Set<String>()
    private var switcherOpened = false

    private let stepLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(wrappingLabelWithString: "")
    private let accessoryHost = NSView()
    private let skipButton = NSButton()
    private let primaryButton = NSButton()
    private var statusLabel: NSTextField?
    private var statusIcon: NSImageView?
    private var spinner: NSProgressIndicator?

    init(accessibilityTrusted: Bool) {
        steps = OnboardingStep.sequence(accessibilityTrusted: accessibilityTrusted)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Welcome to StayTab")
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildLayout()
        render()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Presentation

    func present() {
        // An accessory app can't take focus for its window; promote to
        // `.regular` while it is open (reverted in `windowWillClose`).
        NSApp.setActivationPolicy(.regular)
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// The permission was just granted (the waiter's poll fired).
    func accessibilityGranted() {
        guard currentStep == .accessibility else { return }
        render()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            guard let self, self.currentStep == .accessibility else { return }
            self.advance()
        }
    }

    /// The switcher panel opened for real.
    func switcherRevealed() {
        guard currentStep == .tryIt, !switcherOpened else { return }
        switcherOpened = true
        applyTryItStatus()
    }

    func windowWillClose(_ notification: Notification) {
        Self.markCompleted()
        // Settings reverts the policy itself when it closes; don't demote the
        // app underneath it.
        let settingsOpen = NSApp.windows.contains { $0 is SettingsWindow && $0.isVisible }
        if !settingsOpen { NSApp.setActivationPolicy(.accessory) }
        onClose?()
    }

    // MARK: - Layout

    private var currentStep: OnboardingStep { steps[index] }

    private func buildLayout() {
        guard let contentView = window?.contentView else { return }

        stepLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        stepLabel.textColor = .secondaryLabelColor
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.maximumNumberOfLines = 0

        skipButton.title = String(localized: "Skip")
        skipButton.bezelStyle = .rounded
        skipButton.target = self
        skipButton.action = #selector(skipClicked)
        primaryButton.bezelStyle = .rounded
        primaryButton.keyEquivalent = "\r"
        primaryButton.target = self
        primaryButton.action = #selector(primaryClicked)

        accessoryHost.translatesAutoresizingMaskIntoConstraints = false

        let buttons = NSStackView(views: [skipButton, NSView(), primaryButton])
        buttons.orientation = .horizontal

        let stack = NSStackView(views: [stepLabel, titleLabel, bodyLabel, accessoryHost, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.setCustomSpacing(18, after: bodyLabel)
        stack.setCustomSpacing(18, after: accessoryHost)
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 28, bottom: 24, right: 28)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bodyLabel.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -56),
            accessoryHost.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -56),
            accessoryHost.heightAnchor.constraint(equalToConstant: 190),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -56),
        ])
    }

    // MARK: - Steps

    private func render() {
        stepLabel.stringValue = String(
            format: String(localized: "Step %d of %d"), index + 1, steps.count
        ).uppercased()
        accessoryHost.subviews.forEach { $0.removeFromSuperview() }
        statusLabel = nil
        statusIcon = nil
        spinner?.stopAnimation(nil)
        spinner = nil
        skipButton.isHidden = false
        primaryButton.isEnabled = true

        switch currentStep {
        case .accessibility: renderAccessibility()
        case .pinApps: renderPinApps()
        case .tryIt: renderTryIt()
        }
    }

    private func pinAccessory(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        accessoryHost.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: accessoryHost.topAnchor),
            view.leadingAnchor.constraint(equalTo: accessoryHost.leadingAnchor),
            view.trailingAnchor.constraint(lessThanOrEqualTo: accessoryHost.trailingAnchor),
        ])
    }

    private func renderAccessibility() {
        titleLabel.stringValue = String(localized: "Allow Accessibility access")
        bodyLabel.stringValue = String(localized: "StayTab needs it to read your windows and take over ⌘Tab. It continues on its own once you allow it.")

        let trusted = AccessibilityCheck.isTrusted
        let icon = NSImageView(image: NSImage(
            systemSymbolName: trusted ? "checkmark.circle.fill" : "lock.shield",
            accessibilityDescription: nil
        ) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 18, weight: .regular)
        icon.contentTintColor = trusted ? .systemGreen : .secondaryLabelColor
        let label = NSTextField(labelWithString: trusted
            ? String(localized: "Access granted")
            : String(localized: "Waiting for permission…"))
        label.font = .systemFont(ofSize: 13)
        var views: [NSView] = [icon, label]
        if !trusted {
            let spinner = NSProgressIndicator()
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.isIndeterminate = true
            spinner.startAnimation(nil)
            self.spinner = spinner
            views.append(spinner)
        }
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.spacing = 8
        statusLabel = label
        statusIcon = icon
        pinAccessory(row)

        primaryButton.title = trusted
            ? String(localized: "Continue")
            : String(localized: "Open Accessibility Settings")
        skipButton.isHidden = trusted
    }

    private func renderPinApps() {
        titleLabel.stringValue = String(localized: "Choose apps to keep in ⌘Tab")
        bodyLabel.stringValue = String(localized: "Pinned apps stay in the list after they quit and launch from the same slot. You can change this any time in Apps settings.")
        loadCandidatesIfNeeded()

        guard !candidates.isEmpty else {
            let empty = NSTextField(wrappingLabelWithString: String(localized: "No other apps are running. You can pin apps later in Apps settings."))
            empty.font = .systemFont(ofSize: 13)
            empty.textColor = .tertiaryLabelColor
            pinAccessory(empty)
            primaryButton.title = String(localized: "Continue")
            skipButton.isHidden = true
            return
        }

        var cells: [NSView] = []
        for (offset, candidate) in candidates.enumerated() {
            let icon = NSImageView(image: candidateIcons[candidate.bundleID] ?? NSImage())
            icon.imageScaling = .scaleProportionallyUpOrDown
            icon.widthAnchor.constraint(equalToConstant: 22).isActive = true
            icon.heightAnchor.constraint(equalToConstant: 22).isActive = true
            let box = NSButton(checkboxWithTitle: candidate.name, target: self, action: #selector(candidateToggled(_:)))
            box.tag = offset
            box.state = selected.contains(candidate.bundleID) ? .on : .off
            box.lineBreakMode = .byTruncatingTail
            let cell = NSStackView(views: [icon, box])
            cell.orientation = .horizontal
            cell.spacing = 8
            cells.append(cell)
        }
        var rows: [[NSView]] = []
        for start in stride(from: 0, to: cells.count, by: 2) {
            let pair = Array(cells[start..<min(start + 2, cells.count)])
            rows.append(pair.count == 2 ? pair : [pair[0], NSGridCell.emptyContentView])
        }
        let grid = NSGridView(views: rows)
        grid.columnSpacing = 24
        grid.rowSpacing = 10
        pinAccessory(grid)

        primaryButton.title = String(localized: "Pin Selected Apps")
        primaryButton.isEnabled = !selected.isEmpty
    }

    private func renderTryIt() {
        titleLabel.stringValue = String(localized: "Try it")
        bodyLabel.stringValue = String(localized: "Hold ⌘ and press Tab. Pinned apps stay in the list even after they quit.")

        let keys = NSStackView(views: [
            KeycapView("⌘", minWidth: 64),
            NSTextField(labelWithString: "+"),
            KeycapView("Tab ⇥", minWidth: 88),
        ])
        keys.orientation = .horizontal
        keys.spacing = 12
        keys.alignment = .centerY

        let icon = NSImageView()
        icon.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 12)
        let status = NSStackView(views: [icon, label])
        status.orientation = .horizontal
        status.spacing = 6
        statusIcon = icon
        statusLabel = label

        let column = NSStackView(views: [keys, status])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 20
        pinAccessory(column)

        primaryButton.title = String(localized: "Done")
        skipButton.isHidden = true
        applyTryItStatus()
    }

    private func applyTryItStatus() {
        guard currentStep == .tryIt else { return }
        statusIcon?.image = NSImage(
            systemSymbolName: switcherOpened ? "checkmark.circle.fill" : "ellipsis.circle",
            accessibilityDescription: nil
        )
        statusIcon?.contentTintColor = switcherOpened ? .systemGreen : .secondaryLabelColor
        statusLabel?.stringValue = switcherOpened
            ? String(localized: "That's it — you're all set.")
            : String(localized: "Waiting for you to open the switcher…")
        statusLabel?.textColor = switcherOpened ? .labelColor : .secondaryLabelColor
    }

    private func loadCandidatesIfNeeded() {
        guard candidates.isEmpty else { return }
        let ownID = Bundle.main.bundleIdentifier
        var all: [OnboardingPolicy.AppCandidate] = []
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular {
            guard let bundleID = app.bundleIdentifier, bundleID != ownID else { continue }
            all.append(.init(bundleID: bundleID, name: app.localizedName ?? ""))
            if let icon = app.icon { candidateIcons[bundleID] = icon }
        }
        candidates = OnboardingPolicy.pinCandidates(
            from: all,
            excluding: Set(Preferences.shared.pinnedBundleIDs),
            limit: Self.maxCandidates
        )
    }

    // MARK: - Actions

    private func advance() {
        if index + 1 < steps.count {
            index += 1
            render()
        } else {
            close()
        }
    }

    @objc private func candidateToggled(_ sender: NSButton) {
        guard candidates.indices.contains(sender.tag) else { return }
        let id = candidates[sender.tag].bundleID
        if sender.state == .on { selected.insert(id) } else { selected.remove(id) }
        primaryButton.isEnabled = !selected.isEmpty
    }

    @objc private func skipClicked() {
        advance()
    }

    @objc private func primaryClicked() {
        switch currentStep {
        case .accessibility:
            if AccessibilityCheck.isTrusted {
                advance()
            } else {
                AccessibilityCheck.promptIfNeeded()
                AccessibilityCheck.openSystemSettings()
            }
        case .pinApps:
            if !selected.isEmpty {
                // Keep the order the candidates are listed in, appended after any
                // existing pins.
                let chosen = candidates.map(\.bundleID).filter(selected.contains)
                Preferences.shared.pinnedBundleIDs = OnboardingPolicy.pins(
                    adding: chosen, to: Preferences.shared.pinnedBundleIDs
                )
            }
            advance()
        case .tryIt:
            close()
        }
    }
}

/// A key drawn as a rounded cap. Colors resolve in `updateLayer`, so the cap
/// follows light/dark changes instead of freezing the appearance it was built in.
private final class KeycapView: NSView {

    init(_ text: String, minWidth: CGFloat) {
        super.init(frame: .zero)
        wantsLayer = true
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth),
            heightAnchor.constraint(equalToConstant: 52),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 14),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        guard let layer else { return }
        layer.cornerRadius = 10
        layer.borderWidth = 1
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer.backgroundColor = NSColor.controlBackgroundColor.cgColor
            layer.borderColor = NSColor.separatorColor.cgColor
        }
    }
}
