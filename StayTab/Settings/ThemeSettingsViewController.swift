import AppKit
import BetterSettings
import UniformTypeIdentifiers

/// Theme pane — colors and pictures for the panel and its two section plates.
/// Unlike the other panes it edits a draft (`ThemeEditorSession`): pictures are
/// baked when you save, so changes show in the pinned preview first and reach
/// the switcher on Save.
@MainActor
final class ThemeSettingsViewController: SettingsTabViewController {
    private let session = ThemeEditorSession.shared

    // Pinned above the scrolling rows.
    private let header = NSView()
    private let previewBox = ThemePreviewBox()
    private let areaControl = NSSegmentedControl()
    private var previewView: SwitcherView?
    private var previewRows: [SwitcherRow] = []
    private var previewHeight: NSLayoutConstraint?
    private let expandButton = ThemeSettingsViewController.overlayButton()
    private let actualSizeButton = ThemeSettingsViewController.overlayButton()
    /// The draft at its real size and position, over the real desktop.
    private var actualPanel: SwitcherPanel?
    private var actualView: SwitcherView?
    private var actualSizeMonitors: [Any] = []
    private static let previewHeights: (compact: CGFloat, expanded: CGFloat) = (210, 400)
    /// Drives the bigger/smaller preview: the box height steps every frame and
    /// the preview is laid out again at each step. Glass ignores ancestor
    /// scaling, so a zoom transform can't do this.
    private var resizeTimer: Timer?
    /// The scale the last layout settled on and the box it fitted, so the next
    /// layout (each step of a resize) starts close and converges in a pass or two.
    private var lastFit: (scale: CGFloat, design: NSSize)?
    private var resize: (start: CFTimeInterval, from: CGFloat, to: CGFloat, duration: CFTimeInterval)?
    private var previewPersistentCount = 0
    private let alwaysCount = PreviewCountControl(symbol: "infinity",
                                                  help: String(localized: "Sample apps in the Always section"))
    private let runningCount = PreviewCountControl(symbol: "bolt.fill",
                                                   help: String(localized: "Sample apps in the Running now section"))

    // Label
    private var labelSection: SettingsSectionView?
    private let titleField = NSTextField(string: "")
    private let symbolPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private static let sectionSymbols: [(symbol: String, name: String)] = [
        ("infinity", String(localized: "Infinity")),
        ("pin.fill", String(localized: "Pin")),
        ("star.fill", String(localized: "Star")),
        ("heart.fill", String(localized: "Heart")),
        ("bolt.fill", String(localized: "Bolt")),
        ("flame.fill", String(localized: "Flame")),
        ("sparkles", String(localized: "Sparkles")),
        ("leaf.fill", String(localized: "Leaf")),
        ("moon.fill", String(localized: "Moon")),
        ("bookmark.fill", String(localized: "Bookmark")),
    ]
    private var configuredAppearance: PanelAppearance?
    private var configuredAccent: ThemeAccent?
    /// Which section labels the last layout had; showing or hiding one changes
    /// the preview's size, so it needs a fresh fit.
    private var configuredLabels: [Bool] = []

    // Pinned below them.
    private let saveBar = NSView()
    private let saveLabel = NSTextField(labelWithString: String(localized: "Unsaved theme changes"))
    private let revertButton = NSButton(title: String(localized: "Revert"), target: nil, action: nil)
    private let saveButton = NSButton(title: String(localized: "Save"), target: nil, action: nil)
    private var saveBarHeight: NSLayoutConstraint?

    // Style
    private let styleControl = NSSegmentedControl()
    private var swatches: [ThemeSwatchButton] = []
    private let hueSlider = NSSlider(), hueValue = ThemeSettingsViewController.valueLabel()
    private let tintSlider = NSSlider(), tintValue = ThemeSettingsViewController.valueLabel()
    private let borderSlider = NSSlider(), borderValue = ThemeSettingsViewController.valueLabel()
    private let resetButton = NSButton(title: String(localized: "Reset"), target: nil, action: nil)
    private var presetRow: SettingsRowView?
    private var hueRow: SettingsRowView?
    private var tintRow: SettingsRowView?
    private var borderRow: SettingsRowView?

    // Picture
    private var pictureSection: SettingsSectionView?
    private let thumbnail = NSImageView()
    private let pictureName = NSTextField(labelWithString: "")
    private let chooseButton = NSButton(title: String(localized: "Choose…"), target: nil, action: nil)
    private let cropView = ThemeCropView()
    private let zoomSlider = NSSlider(), zoomValue = ThemeSettingsViewController.valueLabel()
    private let blurSlider = NSSlider(), blurValue = ThemeSettingsViewController.valueLabel()
    private let strengthSlider = NSSlider(), strengthValue = ThemeSettingsViewController.valueLabel()
    private let tonePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private var tintPictureRow: SettingsRowView?

    // Readability and panel
    private let scrimSlider = NSSlider(), scrimValue = ThemeSettingsViewController.valueLabel()
    private let contrastLabel = NSTextField(labelWithString: "")
    private let fixButton = NSButton(title: String(localized: "Fix"), target: nil, action: nil)
    private let accentPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let appearancePopup = NSPopUpButton(frame: .zero, pullsDown: false)

    private let accents = ThemeAccent.allCases
    private let appearances = PanelAppearance.allCases

    private var previewPictures: [ThemeArea: ThemePicture] = [:]
    private var bakedKeys: [ThemeArea: BakeKey] = [:]
    private static let bakeQueue = DispatchQueue(label: "StayTab.themePreviewBake", qos: .userInitiated)
    private var desktopColor = ThemeRGB(r: 0.33, g: 0.35, b: 0.42)
    private var refreshScheduled = false
    private var suggestedScrim: Double?

    /// What a baked preview depends on; a slider that changes none of it (focus,
    /// zoom, strength, tint) costs a layer property, not a bake.
    private struct BakeKey: Equatable {
        let source: ObjectIdentifier
        let blur: Double
        let tone: Bool
        let toneHue: Double
    }

    private static let presets: [(name: String, hue: Double, tint: Double)] = [
        (String(localized: "Neutral"), 240, 0),
        (String(localized: "Mint"), 175, 0.22),
        (String(localized: "Dawn"), 268, 0.26),
        (String(localized: "Dusk"), 38, 0.24),
        (String(localized: "Moss"), 135, 0.2),
        (String(localized: "Ink"), 250, 0.07),
    ]

    // MARK: - Building the pane

    override func setupContent() {
        let style = addSection(title: String(localized: "Style"), anchor: SettingsAnchor.themeStyle)
        styleControl.segmentCount = ThemeBackdrop.allCases.count
        for (index, backdrop) in ThemeBackdrop.allCases.enumerated() {
            styleControl.setLabel(backdrop.displayName, forSegment: index)
        }
        styleControl.trackingMode = .selectOne
        styleControl.controlSize = .small
        styleControl.target = self
        styleControl.action = #selector(styleChanged)
        addRow(to: style, title: String(localized: "Style"),
               subtitle: String(localized: "Default keeps the standard glass."),
               accessory: styleControl, searchItemID: SearchID.themeStyle)

        swatches = Self.presets.enumerated().map { index, preset in
            let color = preset.tint == 0
                ? NSColor.systemGray
                : ThemeColor.oklch(0.66, 0.12, preset.hue).nsColor()
            let button = ThemeSwatchButton(color: color, name: preset.name)
            button.tag = index
            button.target = self
            button.action = #selector(presetChosen(_:))
            return button
        }
        let swatchStack = NSStackView(views: swatches)
        swatchStack.spacing = 6
        presetRow = addRow(to: style, title: String(localized: "Preset"),
                           subtitle: String(localized: "Sets the hue and its strength together."),
                           accessory: swatchStack)
        hueRow = addRow(to: style, title: String(localized: "Hue"),
                        accessory: slider(hueSlider, value: hueValue, range: 0...360, label: String(localized: "Hue")))
        tintRow = addRow(to: style, title: String(localized: "Tint"),
                         subtitle: String(localized: "How strongly the color shows."),
                         accessory: slider(tintSlider, value: tintValue, range: 0...60, label: String(localized: "Tint")))
        borderRow = addRow(to: style, title: String(localized: "Border"),
                           subtitle: String(localized: "Outline around the section."),
                           accessory: slider(borderSlider, value: borderValue, range: 0...100, label: String(localized: "Border")))
        configureButton(resetButton, action: #selector(resetArea))
        addRow(to: style, title: String(localized: "Reset"),
               subtitle: String(localized: "Back to the standard look for this area. Nothing changes until you save."),
               accessory: resetButton)

        let picture = addSection(title: String(localized: "Picture"), anchor: SettingsAnchor.themePicture)
        pictureSection = picture
        thumbnail.imageScaling = .scaleProportionallyUpOrDown
        thumbnail.wantsLayer = true
        thumbnail.layer?.cornerRadius = 4
        thumbnail.layer?.masksToBounds = true
        thumbnail.translatesAutoresizingMaskIntoConstraints = false
        pictureName.textColor = .secondaryLabelColor
        pictureName.font = .systemFont(ofSize: 11)
        pictureName.lineBreakMode = .byTruncatingMiddle
        pictureName.translatesAutoresizingMaskIntoConstraints = false
        configureButton(chooseButton, action: #selector(choosePicture))
        let pictureStack = NSStackView(views: [thumbnail, pictureName, chooseButton])
        pictureStack.spacing = 8
        pictureStack.alignment = .centerY
        NSLayoutConstraint.activate([
            thumbnail.widthAnchor.constraint(equalToConstant: 48),
            thumbnail.heightAnchor.constraint(equalToConstant: 30),
            pictureName.widthAnchor.constraint(lessThanOrEqualToConstant: 150),
        ])
        addRow(to: picture, title: String(localized: "Picture"),
               subtitle: String(localized: "PNG, JPEG or HEIC. Kept on this Mac only."),
               accessory: pictureStack, searchItemID: SearchID.themePicture)

        cropView.translatesAutoresizingMaskIntoConstraints = false
        cropView.heightAnchor.constraint(equalToConstant: 260).isActive = true
        cropView.onFocusChange = { [weak self] focus in
            self?.session.updateArea { $0.focusX = focus.x; $0.focusY = focus.y }
        }
        cropView.onDropFile = { [weak self] url in self?.loadPicture(from: url) }
        addRow(to: picture, title: String(localized: "Visible area"),
               subtitle: String(localized: "Drag the frame, or drop a picture on it. The frame keeps the area's shape as apps come and go."))
        // Full card width: framing a picture needs room more than any other row.
        picture.addContent(cropView)
        addRow(to: picture, title: String(localized: "Zoom"),
               accessory: slider(zoomSlider, value: zoomValue, range: 100...300, label: String(localized: "Zoom")))
        addRow(to: picture, title: String(localized: "Blur"),
               subtitle: String(localized: "Baked into the picture when you save."),
               accessory: slider(blurSlider, value: blurValue, range: 0...8, label: String(localized: "Blur")))
        addRow(to: picture, title: String(localized: "Strength"),
               subtitle: String(localized: "How much of the picture shows through."),
               accessory: slider(strengthSlider, value: strengthValue, range: 20...100, label: String(localized: "Strength")))
        configurePopup(tonePopup, titles: [String(localized: "Original"), String(localized: "Tinted")], action: #selector(toneChanged))
        tintPictureRow = addRow(to: picture, title: String(localized: "Colors"),
                                subtitle: String(localized: "Tinted turns the picture into the area's hue."),
                                accessory: tonePopup)

        let label = addSection(title: String(localized: "Label"), anchor: SettingsAnchor.themeLabel)
        labelSection = label
        titleField.controlSize = .small
        titleField.delegate = self
        // Live edits arrive through the delegate; the action also catches a
        // value set at once (paste, accessibility) when editing ends.
        titleField.target = self
        titleField.action = #selector(titleCommitted)
        titleField.cell?.sendsActionOnEndEditing = true
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.widthAnchor.constraint(equalToConstant: 180).isActive = true
        titleField.setAccessibilityLabel(String(localized: "Title"))
        titleField.placeholderString = String(localized: "No title")
        addRow(to: label, title: String(localized: "Title"),
               subtitle: String(localized: "Clear it to hide the title. Reset brings back the standard name."),
               accessory: titleField, searchItemID: SearchID.themeLabel)
        symbolPopup.controlSize = .small
        symbolPopup.removeAllItems()
        symbolPopup.addItem(withTitle: String(localized: "Default"))
        symbolPopup.addItem(withTitle: String(localized: "None"))
        for entry in Self.sectionSymbols {
            symbolPopup.addItem(withTitle: entry.name)
            symbolPopup.lastItem?.image = NSImage(systemSymbolName: entry.symbol, accessibilityDescription: nil)
        }
        symbolPopup.target = self
        symbolPopup.action = #selector(symbolChanged)
        addRow(to: label, title: String(localized: "Icon"), accessory: symbolPopup)

        let readability = addSection(title: String(localized: "Readability"), anchor: SettingsAnchor.themeReadability)
        addRow(to: readability, title: String(localized: "Legibility boost"),
               subtitle: String(localized: "Darkens or lightens the area behind the text."),
               accessory: slider(scrimSlider, value: scrimValue, range: 0...60, label: String(localized: "Legibility boost")))
        contrastLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        configureButton(fixButton, action: #selector(applyFix))
        let contrastStack = NSStackView(views: [contrastLabel, fixButton])
        contrastStack.spacing = 8
        contrastStack.alignment = .centerY
        addRow(to: readability, title: String(localized: "Text contrast"),
               subtitle: String(localized: "The worst tenth of this area. 4.5:1 or higher reads well."),
               accessory: contrastStack)

        let panel = addSection(title: String(localized: "Panel"), anchor: SettingsAnchor.themePanel)
        configurePopup(accentPopup, titles: accents.map(\.displayName), action: #selector(accentChanged))
        addRow(to: panel, title: String(localized: "Accent color"),
               subtitle: String(localized: "Jump letters, list selection and the default Always section."),
               accessory: accentPopup, searchItemID: SearchID.themeAccent)
        configurePopup(appearancePopup, titles: appearances.map(\.displayName), action: #selector(appearanceChanged))
        addRow(to: panel, title: String(localized: "Appearance"),
               subtitle: String(localized: "Match Picture picks light or dark text from the background picture."),
               accessory: appearancePopup, searchItemID: SearchID.themeAppearance)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        installHeaderAndSaveBar()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        session.onChange = { [weak self] in self?.scheduleRefresh() }
        session.begin()
        if previewView == nil { buildPreview() }
        loadDesktopPicture()
        refresh()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        // The draft stays in the session; only this pane stops listening.
        session.onChange = nil
        hideActualSize()
    }

    override func prepareForMemoryRelease() {
        super.prepareForMemoryRelease()
        session.onChange = nil
        hideActualSize()
        resizeTimer?.invalidate()
        resizeTimer = nil
        session.releaseIfClean()
        previewView?.releaseIdleResources()
        previewView?.removeFromSuperview()
        previewView = nil
        previewRows = []
        previewPictures = [:]
        bakedKeys = [:]
    }

    /// Pins the preview above the scrolling rows and the save bar below them by
    /// re-anchoring the base class's scroll view.
    private func installHeaderAndSaveBar() {
        guard let scroll = view.subviews.first(where: { $0 is NSScrollView }) else { return }
        for constraint in view.constraints where (constraint.firstItem as? NSView) === scroll
            && (constraint.firstAttribute == .top || constraint.firstAttribute == .bottom) {
            constraint.isActive = false
        }

        areaControl.segmentCount = ThemeArea.allCases.count
        for (index, area) in ThemeArea.allCases.enumerated() {
            areaControl.setLabel(area.displayName, forSegment: index)
            areaControl.setImageScaling(.scaleProportionallyDown, forSegment: index)
        }
        areaControl.trackingMode = .selectOne
        areaControl.segmentDistribution = .fillEqually
        areaControl.target = self
        areaControl.action = #selector(areaChanged)
        areaControl.setAccessibilityLabel(String(localized: "Area"))

        previewBox.onClick = { [weak self] point in
            guard let self, let area = self.previewView?.themeArea(atWindowPoint: point) else { return }
            self.view.window?.makeFirstResponder(nil)
            self.session.area = area
            self.refresh()
        }
        previewBox.onLayout = { [weak self] in self?.layoutPreview() }
        expandButton.target = self
        expandButton.action = #selector(toggleExpandedPreview)
        actualSizeButton.target = self
        actualSizeButton.action = #selector(showActualSize)
        actualSizeButton.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: nil)
        actualSizeButton.toolTip = String(localized: "Show at actual size. Click anywhere or press Esc to close.")
        actualSizeButton.setAccessibilityLabel(String(localized: "Show at actual size"))
        updateExpandButton()
        for control in [alwaysCount, runningCount] {
            control.stepper.target = self
            control.stepper.action = #selector(sampleCountChanged)
        }
        // A strip under the picture rather than over it, so nothing covers the
        // panel however wide a long roster makes it.
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let toolbar = NSStackView(views: [alwaysCount, runningCount, spacer, actualSizeButton, expandButton])
        toolbar.spacing = 6
        toolbar.alignment = .centerY

        for subview in [previewBox, toolbar, areaControl] as [NSView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview(subview)
        }
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        saveLabel.font = .systemFont(ofSize: 12, weight: .medium)
        configureButton(revertButton, action: #selector(revert))
        configureButton(saveButton, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        let saveStack = NSStackView(views: [saveLabel, NSView(), revertButton, saveButton])
        saveStack.spacing = 8
        saveStack.alignment = .centerY
        saveStack.translatesAutoresizingMaskIntoConstraints = false
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        saveBar.addSubview(divider)
        saveBar.addSubview(saveStack)
        saveBar.translatesAutoresizingMaskIntoConstraints = false
        saveBar.wantsLayer = true
        saveBar.layer?.masksToBounds = true
        view.addSubview(saveBar)

        let previewHeight = previewBox.heightAnchor.constraint(
            equalToConstant: session.previewExpanded ? Self.previewHeights.expanded : Self.previewHeights.compact)
        self.previewHeight = previewHeight
        let saveBarHeight = saveBar.heightAnchor.constraint(equalToConstant: 0)
        self.saveBarHeight = saveBarHeight
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            previewBox.topAnchor.constraint(equalTo: header.topAnchor),
            previewBox.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            previewBox.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            previewHeight,
            toolbar.topAnchor.constraint(equalTo: previewBox.bottomAnchor, constant: 8),
            toolbar.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            areaControl.topAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: 8),
            areaControl.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            areaControl.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            areaControl.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            scroll.bottomAnchor.constraint(equalTo: saveBar.topAnchor),
            saveBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            saveBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            saveBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            saveBarHeight,
            divider.topAnchor.constraint(equalTo: saveBar.topAnchor),
            divider.leadingAnchor.constraint(equalTo: saveBar.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: saveBar.trailingAnchor),
            saveStack.leadingAnchor.constraint(equalTo: saveBar.leadingAnchor, constant: 20),
            saveStack.trailingAnchor.constraint(equalTo: saveBar.trailingAnchor, constant: -20),
            saveStack.centerYAnchor.constraint(equalTo: saveBar.centerYAnchor),
        ])
    }

    private func buildPreview() {
        let preview = SwitcherView(frame: .zero, allowsWindowCapture: false, followsSavedTheme: false, drawsInWindow: true)
        preview.acceptsPointer = false
        // Every change here re-fits the whole preview; gliding rows between
        // those passes is what made it shake.
        preview.reflowGlides = false
        previewBox.addSubview(preview, positioned: .below, relativeTo: previewBox.clickCatcher)
        previewView = preview
        rebuildPreviewRows()
        configuredAppearance = nil
    }

    private func rebuildPreviewRows() {
        let counts = session.previewCounts ?? Self.defaultSampleCounts()
        session.previewCounts = counts
        let built = Self.makePreviewRows(always: counts.always, running: counts.running)
        previewRows = built.rows
        previewPersistentCount = built.persistent
        lastFit = nil
        alwaysCount.count = counts.always
        runningCount.count = counts.running
    }

    /// Starts from the user's own roster size: their pinned apps, and the apps
    /// running beside them.
    private static func defaultSampleCounts() -> (always: Int, running: Int) {
        let pinned = Preferences.shared.pinnedBundleIDs
        let running = regularRunningApps().filter { !pinned.contains($0.bundleIdentifier ?? "") }.count
        let limit = Int(PreviewCountControl.range.upperBound)
        return (pinned.isEmpty ? 3 : min(pinned.count, limit), running == 0 ? 3 : min(running, limit))
    }

    private static func regularRunningApps() -> [NSRunningApplication] {
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications.filter { app in
            guard !app.isTerminated, app.activationPolicy == .regular, app.localizedName?.isEmpty == false else { return false }
            return seen.insert(app.bundleIdentifier ?? "pid.\(app.processIdentifier)").inserted
        }
    }

    /// Sample rows for the preview. Always starts with the user's pinned apps
    /// (a closed one draws as it does in the switcher, dashed with Launch) and
    /// Running now with unpinned running apps; past that, running apps repeat
    /// so a section can be grown to any length the user wants to see.
    private static func makePreviewRows(always: Int, running: Int) -> (rows: [SwitcherRow], persistent: Int) {
        let pinned = Preferences.shared.pinnedBundleIDs
        let apps = regularRunningApps()
        let pool = apps.isEmpty ? [NSRunningApplication.current] : apps
        let byBundle = Dictionary(apps.compactMap { app in app.bundleIdentifier.map { ($0, app) } }, uniquingKeysWith: { first, _ in first })
        let row = { (app: NSRunningApplication) in
            SwitcherRow(app: app, window: nil, windowTitle: "", isMinimized: false, isPlaceholder: true)
        }
        var alwaysRows: [SwitcherRow] = []
        for bundleID in pinned where alwaysRows.count < always {
            if let app = byBundle[bundleID] {
                alwaysRows.append(row(app))
            } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                let name = FileManager.default.displayName(atPath: url.path)
                    .replacingOccurrences(of: ".app", with: "")
                alwaysRows.append(SwitcherRow(launchable: InstalledApp(name: name, bundleID: bundleID, url: url)))
            }
        }
        var index = 0
        while alwaysRows.count < always {
            alwaysRows.append(row(pool[index % pool.count]))
            index += 1
        }
        let unpinned = apps.filter { !pinned.contains($0.bundleIdentifier ?? "") }
        var runningRows: [SwitcherRow] = []
        index = 0
        while runningRows.count < running {
            let app = index < unpinned.count ? unpinned[index] : pool[(index - unpinned.count) % pool.count]
            runningRows.append(row(app))
            index += 1
        }
        if alwaysRows.isEmpty && runningRows.isEmpty { runningRows = [row(pool[0])] }
        return (alwaysRows + runningRows, alwaysRows.count)
    }

    /// Configures the preview at a scale that fits the box and centers it.
    private func layoutPreview() {
        guard let previewView, previewBox.bounds.width > 40 else { return }
        let prefs = Preferences.shared
        var override = ShortcutOverride()
        override.panelAppearance = session.appearance
        let effective = prefs.effectiveSettings(for: override)
        let design = NSSize(width: previewBox.bounds.width - 28, height: previewBox.bounds.height - 24)
        let base = SwitcherMetrics.scale(forPercent: effective.panelScalePercent)
        var scale = base
        if let lastFit, lastFit.design.width > 0, lastFit.design.height > 0 {
            // Optimistic: grow by the roomier axis, and let the loop below step
            // back down if the other axis was the one that bound.
            let growth = max(design.width / lastFit.design.width, design.height / lastFit.design.height)
            scale = min(base, lastFit.scale * max(growth, 0.5))
        }
        var fitting = NSSize.zero
        // Before configuring, so the rows pick up the draft's accent.
        previewView.setTheme(session.draft, pictures: previewPictures)
        // The switcher also shrinks itself to fit the screen, so the size doesn't
        // follow the requested scale linearly: step down until it fits the box.
        // One transaction, no implicit animations: only the final pass shows.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        for _ in 0..<8 {
            let metrics = SwitcherMetrics.forScale(
                scale,
                layoutMode: effective.layoutMode,
                fontScale: effective.fontScale.multiplier,
                letterHints: effective.letterHintsEnabled,
                showAppNames: effective.showApplicationNames,
                showWindowTitles: effective.showWindowTitleLabel,
                hoverActionCount: 0
            )
            previewView.configure(
                rows: previewRows,
                labels: RowLabels.labels(for: previewRows),
                selectedIndex: 0,
                metrics: metrics,
                effective: effective,
                persistentRowCount: previewPersistentCount
            )
            previewView.layoutSubtreeIfNeeded()
            fitting = previewView.fittingSize
            let shrink = min(design.width / max(fitting.width, 1), design.height / max(fitting.height, 1))
            if shrink >= 1 { break }
            scale *= max(0.5, shrink * 0.97)
        }
        lastFit = (scale, design)
        let size = NSSize(width: ceil(min(fitting.width, design.width)), height: ceil(min(fitting.height, design.height)))
        previewView.frame = NSRect(origin: Self.centeredOrigin(of: size, in: previewBox.bounds.size), size: size)
        configuredAppearance = session.appearance
        configuredAccent = session.draft.accent
        configuredLabels = labelSignature()
        previewView.setTheme(session.draft, pictures: previewPictures)
    }

    private func labelSignature() -> [Bool] {
        let draft = session.draft
        return [draft.always.showsTitle, draft.always.showsIcon, draft.running.showsTitle, draft.running.showsIcon]
    }

    private static func centeredOrigin(of size: NSSize, in box: NSSize) -> NSPoint {
        NSPoint(x: ((box.width - size.width) / 2).rounded(), y: ((box.height - size.height) / 2).rounded())
    }

    private func loadDesktopPicture() {
        guard let screen = view.window?.screen ?? NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = ThemeImageFiles.loadSource(from: url) else { return }
            let samples = ThemeImageSamples(image: image, maxEdge: 24)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.previewBox.desktopImage = image
                if let samples { self.desktopColor = ThemeLegibility.average(samples.pixels) }
                self.scheduleRefresh()
            }
        }
    }

    // MARK: - Refresh

    private func scheduleRefresh() {
        guard !refreshScheduled else { return }
        refreshScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshScheduled = false
            self.refresh()
        }
    }

    private func refresh() {
        guard isViewLoaded else { return }
        let area = session.area
        let theme = session.draft[area: area]
        let source = session.sources[area]

        areaControl.selectedSegment = ThemeArea.allCases.firstIndex(of: area) ?? 0
        styleControl.selectedSegment = ThemeBackdrop.allCases.firstIndex(of: theme.backdrop) ?? 0
        let colored = theme.backdrop != .standard
        presetRow?.isHidden = !colored
        hueRow?.isHidden = !colored
        tintRow?.isHidden = !colored || (theme.backdrop == .image && theme.tone && source != nil)
        borderRow?.isHidden = !colored || area == .panel
        tintRow?.update(title: area == .panel ? String(localized: "Tint") : String(localized: "Fill"))
        pictureSection?.isHidden = theme.backdrop != .image
        labelSection?.isHidden = area == .panel
        let shownTitle = theme.title ?? area.displayName
        if titleField.currentEditor() == nil, titleField.stringValue != shownTitle {
            titleField.stringValue = shownTitle
        }
        let symbolIndex = theme.symbol == AreaTheme.noSymbol
            ? 1 : Self.sectionSymbols.firstIndex { $0.symbol == theme.symbol }.map { $0 + 2 } ?? 0
        symbolPopup.selectItem(at: symbolIndex)
        for (index, swatch) in swatches.enumerated() {
            let preset = Self.presets[index]
            swatch.isChosen = colored && preset.hue == theme.hue && preset.tint == theme.tint
        }
        set(hueSlider, hueValue, theme.hue, text: "\(Int(theme.hue.rounded()))°")
        set(tintSlider, tintValue, theme.tint * 100, text: "\(Int((theme.tint * 100).rounded())) %")
        set(borderSlider, borderValue, theme.border * 100, text: "\(Int((theme.border * 100).rounded())) %")
        set(zoomSlider, zoomValue, theme.zoom * 100, text: "\(Int((theme.zoom * 100).rounded())) %")
        set(blurSlider, blurValue, theme.blur, text: AreaTheme.format(theme.blur) + " pt")
        set(strengthSlider, strengthValue, theme.strength * 100, text: "\(Int((theme.strength * 100).rounded())) %")
        set(scrimSlider, scrimValue, theme.scrim * 100, text: "+\(Int((theme.scrim * 100).rounded())) %")
        tonePopup.selectItem(at: theme.tone ? 1 : 0)
        accentPopup.selectItem(at: accents.firstIndex(of: session.draft.accent) ?? 0)
        appearancePopup.selectItem(at: appearances.firstIndex(of: session.appearance) ?? 0)

        thumbnail.image = source.map { NSImage(cgImage: $0.image, size: .zero) }
        pictureName.stringValue = source?.name ?? ""
        cropView.image = source?.image
        cropView.focus = CGPoint(x: theme.focusX, y: theme.focusY)
        cropView.zoom = CGFloat(theme.zoom)
        if let size = previewView?.themeAreaSize(area), size.height > 0 {
            cropView.areaAspect = size.width / size.height
        }

        updatePreviewPictures()
        if actualPanel != nil { renderActualSize() }
        // Light/dark and the accent reach the rows only through a configure pass;
        // everything else is a theme property on the existing preview.
        if configuredAppearance != session.appearance || configuredAccent != session.draft.accent
            || configuredLabels != labelSignature() {
            layoutPreview()
        } else {
            previewView?.setTheme(session.draft, pictures: previewPictures)
        }
        updateReadability()

        let dirty = session.isDirty
        saveBarHeight?.constant = dirty ? 48 : 0
        saveBar.isHidden = !dirty
        saveButton.isEnabled = !session.isSaving && !session.isLoading
        revertButton.isEnabled = !session.isSaving
    }

    private func updatePreviewPictures() {
        for area in ThemeArea.allCases {
            let theme = session.draft[area: area]
            guard theme.backdrop == .image, let source = session.sources[area] else {
                previewPictures[area] = nil
                bakedKeys[area] = nil
                continue
            }
            let key = BakeKey(source: ObjectIdentifier(source.image), blur: theme.blur, tone: theme.tone,
                              toneHue: theme.tone ? theme.hue : 0)
            guard bakedKeys[area] != key else { continue }
            bakedKeys[area] = key
            let image = source.image
            let edge = min(800, ThemeImageFiles.bakedMaxEdge(for: area, blur: theme.blur))
            Self.bakeQueue.async {
                let baked = ThemeImageFiles.bake(image, area: area, theme: theme, maxEdge: edge)
                let picture = baked.map(ThemePicture.init(image:))
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.bakedKeys[area] == key else { return }
                    self.previewPictures[area] = picture
                    self.previewView?.setTheme(self.session.draft, pictures: self.previewPictures)
                    self.updateReadability()
                }
            }
        }
    }

    /// Contrast of every area, as warning marks on the area tabs, and the
    /// current area's number with a one-click fix.
    private func updateReadability() {
        guard let previewView else { return }
        let dark = previewView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        var sizes: [ThemeArea: CGSize] = [:]
        var samples: [ThemeArea: ThemeImageSamples] = [:]
        for area in ThemeArea.allCases {
            sizes[area] = previewView.themeAreaSize(area)
            samples[area] = previewPictures[area]?.samples
        }
        let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB)
        let check = ThemeLegibility(
            theme: session.draft, desktop: desktopColor, dark: dark, samples: samples, sizes: sizes,
            accent: accent.map { ThemeRGB(r: $0.redComponent, g: $0.greenComponent, b: $0.blueComponent) }
                ?? ThemeRGB(r: 0.04, g: 0.52, b: 1)
        )
        for (index, area) in ThemeArea.allCases.enumerated() {
            let ratio = check.worstContrast(area)
            let low = ratio < ThemeLegibility.target
            areaControl.setImage(low ? NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                                              accessibilityDescription: String(localized: "Low")) : nil,
                                 forSegment: index)
            areaControl.setToolTip(String(format: "%.1f:1", ratio), forSegment: index)
        }
        let ratio = check.worstContrast(session.area)
        let status: String
        if ratio >= ThemeLegibility.target {
            status = String(localized: "Pass")
        } else if ratio >= 3 {
            status = String(localized: "Low")
        } else {
            status = String(localized: "Hard to read")
        }
        contrastLabel.stringValue = String(format: "%.1f:1", ratio) + " · " + status
        contrastLabel.textColor = ratio >= ThemeLegibility.target ? .labelColor : .systemOrange
        suggestedScrim = ratio >= ThemeLegibility.target ? nil : check.suggestedScrim(session.area)
        fixButton.isHidden = suggestedScrim.map { $0 <= session.draft[area: session.area].scrim } ?? true
    }

    /// ttheme's rule for a new picture: the highest strength whose text still
    /// passes, so the picture starts as present as it can be while readable.
    private func suggestedStrength(for samples: ThemeImageSamples?) -> Double? {
        guard let samples, let previewView else { return nil }
        let area = session.area
        let dark = previewView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        var theme = session.draft
        theme[area: area].backdrop = .image
        var check = ThemeLegibility(theme: theme, desktop: desktopColor, dark: dark,
                                    samples: [area: samples],
                                    sizes: [area: previewView.themeAreaSize(area) ?? CGSize(width: 2, height: 1)])
        var strength = AreaTheme.strengthRange.upperBound
        while strength >= AreaTheme.strengthRange.lowerBound {
            check.theme[area: area].strength = strength
            if check.worstContrast(area) >= ThemeLegibility.target { return strength }
            strength -= 0.05
        }
        return 0.6
    }

    // MARK: - Actions

    @objc private func areaChanged() {
        let index = areaControl.selectedSegment
        guard ThemeArea.allCases.indices.contains(index) else { return }
        view.window?.makeFirstResponder(nil)
        session.area = ThemeArea.allCases[index]
        refresh()
    }

    @objc private func styleChanged() {
        let index = styleControl.selectedSegment
        guard ThemeBackdrop.allCases.indices.contains(index) else { return }
        let backdrop = ThemeBackdrop.allCases[index]
        session.updateArea { $0.backdrop = backdrop }
        guard backdrop == .image else { return }
        // The picture rows open below the fold; bring them up, and with no
        // picture yet go straight to choosing one.
        refresh()
        view.layoutSubtreeIfNeeded()
        if let pictureSection { scrollToView(pictureSection, animated: true) }
        if session.sources[session.area] == nil { choosePicture() }
    }

    @objc private func presetChosen(_ sender: ThemeSwatchButton) {
        let preset = Self.presets[sender.tag]
        session.updateArea {
            $0.hue = preset.hue
            $0.tint = preset.tint
            if $0.backdrop == .standard { $0.backdrop = .color }
        }
    }

    @objc private func sliderMoved(_ sender: NSSlider) {
        let value = sender.doubleValue
        session.updateArea { theme in
            switch sender {
            case hueSlider: theme.hue = AreaTheme.normalizedHue(value.rounded())
            case tintSlider: theme.tint = (value.rounded() / 100).clamped(to: AreaTheme.tintRange)
            case borderSlider: theme.border = (value.rounded() / 100).clamped(to: AreaTheme.borderRange)
            case zoomSlider: theme.zoom = (value.rounded() / 100).clamped(to: AreaTheme.zoomRange)
            case blurSlider: theme.blur = ((value * 2).rounded() / 2).clamped(to: AreaTheme.blurRange)
            case strengthSlider: theme.strength = (value.rounded() / 100).clamped(to: AreaTheme.strengthRange)
            case scrimSlider: theme.scrim = (value.rounded() / 100).clamped(to: AreaTheme.scrimRange)
            default: break
            }
        }
    }

    @objc private func toneChanged() {
        let tone = tonePopup.indexOfSelectedItem == 1
        session.updateArea { $0.tone = tone }
    }

    @objc private func resetArea() {
        view.window?.makeFirstResponder(nil)
        session.resetArea()
    }

    @objc private func applyFix() {
        guard let suggestedScrim else { return }
        session.updateArea { $0.scrim = suggestedScrim }
    }

    @objc private func accentChanged() {
        let index = accentPopup.indexOfSelectedItem
        guard accents.indices.contains(index) else { return }
        session.setAccent(accents[index])
    }

    @objc private func appearanceChanged() {
        let index = appearancePopup.indexOfSelectedItem
        guard appearances.indices.contains(index) else { return }
        session.setAppearance(appearances[index])
    }

    @objc private func choosePicture() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let handle: (NSApplication.ModalResponse) -> Void = { [weak self, weak panel] response in
            guard response == .OK, let url = panel?.url else { return }
            self?.loadPicture(from: url)
        }
        if let window = view.window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    private func loadPicture(from url: URL) {
        let area = session.area
        DispatchQueue.global(qos: .userInitiated).async {
            let image = ThemeImageFiles.loadSource(from: url)
            let samples = image.flatMap { ThemeImageSamples(image: $0) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard let image else {
                    self.showError(String(localized: "StayTab couldn't open that picture. Choose a PNG, JPEG or HEIC file."))
                    return
                }
                self.session.area = area
                self.session.setPicture(image, name: url.lastPathComponent, strength: self.suggestedStrength(for: samples))
            }
        }
    }

    @objc private func sampleCountChanged() {
        session.previewCounts = (alwaysCount.stepper.integerValue, runningCount.stepper.integerValue)
        rebuildPreviewRows()
        layoutPreview()
        if actualPanel != nil { renderActualSize() }
        updateReadability()
    }

    @objc private func titleCommitted() {
        let title = AreaTheme.storedTitle(titleField.stringValue, defaultName: session.area.displayName)
        session.updateArea { $0.title = title }
    }

    @objc private func symbolChanged() {
        let index = symbolPopup.indexOfSelectedItem
        let symbol: String
        switch index {
        case 1: symbol = AreaTheme.noSymbol
        case 2...(Self.sectionSymbols.count + 1): symbol = Self.sectionSymbols[index - 2].symbol
        default: symbol = ""
        }
        session.updateArea { $0.symbol = symbol }
    }

    @objc private func revert() {
        view.window?.makeFirstResponder(nil)
        session.revert()
    }

    @objc private func save() {
        session.save { [weak self] succeeded in
            guard !succeeded else { return }
            self?.showError(String(localized: "StayTab couldn't save the theme pictures. The other theme changes were saved."))
        }
        refresh()
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        if let window = view.window {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    // MARK: - Bigger previews

    @objc private func toggleExpandedPreview() {
        session.previewExpanded.toggle()
        updateExpandButton()
        let target = session.previewExpanded ? Self.previewHeights.expanded : Self.previewHeights.compact
        let current = previewHeight?.constant ?? target
        resizeTimer?.invalidate()
        guard SwitcherMotion.isEnabled else {
            previewHeight?.constant = target
            view.layoutSubtreeIfNeeded()
            return
        }
        resize = (CACurrentMediaTime(), current, target, 0.25)
        resizeTimer = Timer.scheduledTimer(timeInterval: 1.0 / 60, target: self,
                                           selector: #selector(resizeStep), userInfo: nil, repeats: true)
    }

    @objc private func resizeStep() {
        guard let resize else {
            resizeTimer?.invalidate()
            return
        }
        let t = min(1, (CACurrentMediaTime() - resize.start) / resize.duration)
        let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewHeight?.constant = (resize.from + (resize.to - resize.from) * CGFloat(eased)).rounded()
        view.layoutSubtreeIfNeeded()
        CATransaction.commit()
        guard t >= 1 else { return }
        resizeTimer?.invalidate()
        resizeTimer = nil
        self.resize = nil
    }

    private func updateExpandButton() {
        let expanded = session.previewExpanded
        expandButton.image = NSImage(
            systemSymbolName: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
            accessibilityDescription: nil)
        let label = expanded ? String(localized: "Smaller preview") : String(localized: "Larger preview")
        expandButton.toolTip = label
        expandButton.setAccessibilityLabel(label)
    }

    /// Floats the draft as the real switcher would show it — actual size,
    /// centered, over the real desktop — until the next click or key press.
    @objc private func showActualSize() {
        guard actualPanel == nil else { return }
        let switcher = SwitcherView(frame: .zero, allowsWindowCapture: false, followsSavedTheme: false)
        switcher.acceptsPointer = false
        let panel = SwitcherPanel()
        panel.contentView = switcher
        panel.ignoresMouseEvents = true
        actualPanel = panel
        actualView = switcher
        renderActualSize()
        panel.orderFrontRegardless()
        let dismiss: (NSEvent) -> NSEvent? = { [weak self] _ in
            self?.hideActualSize()
            return nil
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown], handler: dismiss) {
            actualSizeMonitors.append(local)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            self?.hideActualSize()
        }) {
            actualSizeMonitors.append(global)
        }
    }

    private func renderActualSize() {
        guard let panel = actualPanel, let switcher = actualView else { return }
        var override = ShortcutOverride()
        override.panelAppearance = session.appearance
        let effective = Preferences.shared.effectiveSettings(for: override)
        let screen = view.window?.screen ?? SwitcherPanel.preferredScreen()
        panel.targetScreen = screen
        let metrics = SwitcherMetrics.forScale(
            SwitcherMetrics.scale(forPercent: effective.panelScalePercent),
            layoutMode: effective.layoutMode,
            fontScale: effective.fontScale.multiplier,
            letterHints: effective.letterHintsEnabled,
            showAppNames: effective.showApplicationNames,
            showWindowTitles: effective.showWindowTitleLabel,
            hoverActionCount: 0
        )
        switcher.setTheme(session.draft, pictures: previewPictures)
        switcher.configure(
            rows: previewRows,
            labels: RowLabels.labels(for: previewRows),
            selectedIndex: 0,
            metrics: metrics,
            effective: effective,
            persistentRowCount: previewPersistentCount
        )
        switcher.layoutSubtreeIfNeeded()
        switcher.setTheme(session.draft, pictures: previewPictures)
        let visible = screen.visibleFrame
        let fitting = switcher.fittingSize
        let size = NSSize(width: min(fitting.width, visible.width), height: min(fitting.height, visible.height))
        panel.setFrame(NSRect(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
                              width: size.width, height: size.height).integral, display: true)
        panel.alphaValue = CGFloat(effective.panelOpacity) / 100
    }

    private func hideActualSize() {
        for monitor in actualSizeMonitors { NSEvent.removeMonitor(monitor) }
        actualSizeMonitors.removeAll()
        actualPanel?.orderOut(nil)
        actualView?.releaseIdleResources()
        actualPanel = nil
        actualView = nil
    }

    /// Small icon button for the strip under the preview.
    private static func overlayButton() -> NSButton {
        let button = NSButton()
        button.bezelStyle = .texturedRounded
        button.controlSize = .small
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 28),
            button.heightAnchor.constraint(equalToConstant: 26),
        ])
        return button
    }

    // MARK: - Control helpers

    private static func valueLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 46).isActive = true
        return label
    }

    private func slider(_ slider: NSSlider, value: NSTextField, range: ClosedRange<Double>, label: String) -> NSStackView {
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.isContinuous = true
        slider.controlSize = .small
        slider.target = self
        slider.action = #selector(sliderMoved(_:))
        slider.setAccessibilityLabel(label)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 140).isActive = true
        let stack = NSStackView(views: [slider, value])
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    private func set(_ slider: NSSlider, _ label: NSTextField, _ value: Double, text: String) {
        if slider.doubleValue != value { slider.doubleValue = value }
        label.stringValue = text
    }

    private func configureButton(_ button: NSButton, action: Selector) {
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.target = self
        button.action = action
    }
}

extension ThemeSettingsViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        guard (notification.object as? NSTextField) === titleField else { return }
        titleCommitted()
    }
}

/// "∞ 10 ⇅" under the preview: how many sample apps a section holds, so a long
/// roster can be tried out before it exists.
final class PreviewCountControl: NSView {
    static let range: ClosedRange<Double> = 0...40
    let stepper = NSStepper()
    private let countLabel = NSTextField(labelWithString: "")

    var count: Int {
        get { stepper.integerValue }
        set {
            stepper.integerValue = newValue
            countLabel.stringValue = "\(newValue)"
        }
    }

    init(symbol: String, help: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 7
        toolTip = help
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = .secondaryLabelColor
        icon.symbolConfiguration = .init(pointSize: 10, weight: .semibold)
        countLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        countLabel.textColor = .labelColor
        countLabel.alignment = .right
        countLabel.widthAnchor.constraint(equalToConstant: 18).isActive = true
        stepper.controlSize = .small
        stepper.minValue = Self.range.lowerBound
        stepper.maxValue = Self.range.upperBound
        stepper.increment = 1
        stepper.valueWraps = false
        stepper.setAccessibilityLabel(help)
        let stack = NSStackView(views: [icon, countLabel, stepper])
        stack.spacing = 4
        stack.alignment = .centerY
        stack.edgeInsets = NSEdgeInsets(top: 2, left: 8, bottom: 2, right: 4)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    /// A `CGColor` doesn't follow light/dark by itself, so re-resolve it here.
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        }
    }
}

/// The preview's stage: the user's desktop picture with the switcher on top,
/// and a transparent layer above both that turns clicks into area picks.
final class ThemePreviewBox: NSView {
    let clickCatcher = ClickCatcher()
    var onClick: ((NSPoint) -> Void)? {
        get { clickCatcher.onClick }
        set { clickCatcher.onClick = newValue }
    }
    var onLayout: (() -> Void)?
    private var lastLaidOutSize = NSSize.zero

    var desktopImage: CGImage? {
        didSet { layer?.contents = desktopImage }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        layer?.contentsGravity = .resizeAspectFill
        layer?.backgroundColor = NSColor(srgbRed: 0.2, green: 0.22, blue: 0.3, alpha: 1).cgColor
        clickCatcher.autoresizingMask = [.width, .height]
        addSubview(clickCatcher)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func layout() {
        super.layout()
        clickCatcher.frame = bounds
        guard bounds.size != lastLaidOutSize else { return }
        lastLaidOutSize = bounds.size
        onLayout?()
    }

    final class ClickCatcher: NSView {
        var onClick: ((NSPoint) -> Void)?
        override func mouseDown(with event: NSEvent) { onClick?(event.locationInWindow) }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }
}
