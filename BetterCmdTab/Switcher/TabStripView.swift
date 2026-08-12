import AppKit

struct TabStripItem: Equatable, Sendable {
    let title: String
    let faviconKey: String?
}

/// Horizontal strip of tab titles (plus favicons, for browsers) shown below the
/// switcher list while the user is drilled into a tabbed row — a browser window
/// or an app using native window tabs (Finder, Terminal, TextEdit).
///
/// Modeled on the macOS 26 native tab bar (Finder/Safari): no track of its own,
/// tabs split the width equally with centered titles, hairline separators
/// between neighbours, and the selection as a single Liquid Glass capsule that
/// slides between tabs (one glass sampler for the whole strip, not one per tab,
/// and the slide is what the system tab bar does on selection change). Past
/// `minCellWidth` tabs stop shrinking and the strip scrolls instead, with its
/// edges fading to advertise that. Selection is owned by `SwitcherController`;
/// the strip renders it.
///
/// Tabs are equal width by construction, so every position in the strip is
/// arithmetic off `cellWidth` and only the tabs the clip view can show are
/// built as views — a 300-tab browser window costs the same handful of cells as
/// a 3-tab one.
///
/// Clicks and hover arrive as bare points from `SwitcherView` (whose `hitTest`
/// override pins every mouse event to the panel), so the cells carry no mouse
/// machinery of their own — see `index(atWindowPoint:)`.
@MainActor
final class TabStripView: NSView {
    private let scrollView = NSScrollView()
    private let document = NSView()
    /// The selection capsule. Lives inside the scroll document, so it tracks
    /// scrolling for free and gets clipped/faded with the tabs.
    private let selection: NSView
    /// Every tab, whether or not it currently has a cell.
    private var items: [TabStripItem] = []
    /// Cell pool, one per materialized item — `cells[i]` shows item
    /// `materialized.lowerBound + i`.
    private var cells: [TabStripCell] = []
    private var materialized: Range<Int> = 0..<0
    /// The `cellWidth` the materialized cells were laid out against; `nil` once
    /// the items themselves changed, so the same range gets rebuilt.
    private var laidOutCellWidth: CGFloat?
    private var selectedIndex: Int = 0
    /// Resolved once per `configure` rather than per cell (#90, #62).
    private var cellFont: NSFont = .systemFont(ofSize: 12, weight: .medium)
    private var truncation: NSLineBreakMode = .byTruncatingTail
    /// Alpha mask that fades whichever rail edge still has content behind it.
    /// Only installed while the strip overflows, so the common (few tabs) case
    /// pays no offscreen render pass.
    private let edgeFade = CAGradientLayer()
    /// Counts of tabs scrolled out past each edge ("‹ 3"), overlaid on the fade.
    private let leadingCount = TabStripView.makeCountLabel()
    private let trailingCount = TabStripView.makeCountLabel()

    /// Everything `updateOverflow` draws, so a scroll frame that changes none
    /// of it costs one comparison.
    private struct OverflowState: Equatable {
        let hiddenLeading: Int
        let hiddenTrailing: Int
        let fadesLeading: Bool
        let fadesTrailing: Bool
        let fadeWidth: CGFloat
        let maskBounds: CGRect
    }
    private var overflowState: OverflowState?
    private static let fadeOpaque = NSColor.black.cgColor
    private static let fadeClear = NSColor.clear.cgColor

    static let stripHeight: CGFloat = 30
    /// Below this a title is unreadable, so the strip scrolls rather than
    /// shrink further — same trade the native tab bar makes.
    private static let minCellWidth: CGFloat = 110
    private static let cellHeight = stripHeight - 2

    override init(frame frameRect: NSRect) {
        // The panel's own backdrop is *clear* glass; the capsule wants the
        // frosted `.regular` material so it reads as a control resting on it.
        let rim = GlassRimView()
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = Self.cellHeight / 2
            // The effect view pins its content view to its own bounds.
            glass.contentView = rim
            selection = glass
        } else {
            let plain = NSView()
            plain.wantsLayer = true
            plain.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
            plain.layer?.cornerRadius = Self.cellHeight / 2
            plain.layer?.cornerCurve = .continuous
            rim.autoresizingMask = [.width, .height]
            rim.frame = plain.bounds
            plain.addSubview(rim)
            selection = plain
        }
        super.init(frame: frameRect)
        wantsLayer = true
        selection.isHidden = true

        edgeFade.startPoint = NSPoint(x: 0, y: 0.5)
        edgeFade.endPoint = NSPoint(x: 1, y: 0.5)

        scrollView.wantsLayer = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        scrollView.scrollerStyle = .overlay

        document.addSubview(selection)
        scrollView.documentView = document

        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        addSubview(leadingCount)
        addSubview(trailingCount)
        NSLayoutConstraint.activate([
            leadingCount.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            leadingCount.centerYAnchor.constraint(equalTo: centerYAnchor),
            trailingCount.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            trailingCount.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(clipBoundsChanged),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private static func makeCountLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.isHidden = true
        return label
    }

    func configure(items: [TabStripItem], selectedIndex: Int) {
        self.items = items
        self.selectedIndex = selectedIndex
        laidOutCellWidth = nil
        // Ellipsis position (#90) and text size/face (#62): global preferences
        // only (the per-shortcut override deliberately does not reach the
        // strip). One pref read + one memoized font resolve per drill-in.
        let prefs = Preferences.shared
        truncation = prefs.titleTruncationMode.lineBreakMode
        cellFont = SwitcherFont.font(ofSize: round(12 * prefs.fontScale.multiplier),
                                     weight: .medium,
                                     design: prefs.fontFace)
        // Everything else waits for `layout()`: until `SwitcherView` lays the
        // strip out it is still at the previous drill-in's width, and scrolling
        // the selection into view needs the real one.
        needsLayout = true
    }

    func setSelectedIndex(_ index: Int) {
        guard items.indices.contains(index) else { return }
        selectedIndex = index
        for cell in cells.prefix(materialized.count) {
            cell.setSelected(cell.itemIndex == index)
            cell.showsSeparator = separatorVisible(at: cell.itemIndex)
        }
        updateSelection(animated: true)
        scrollSelectedIntoView()
    }

    /// Width every tab gets: the strip split evenly, or `minCellWidth` once
    /// there are too many tabs for that to stay readable.
    private var cellWidth: CGFloat {
        guard !items.isEmpty else { return 0 }
        return max(bounds.width / CGFloat(items.count), Self.minCellWidth)
    }

    private func cellFrame(at index: Int) -> NSRect {
        NSRect(x: CGFloat(index) * cellWidth, y: 1, width: cellWidth, height: Self.cellHeight)
    }

    /// A separator marks the seam between two plain tabs only — the capsule
    /// provides its own edge, and the last tab has no neighbour.
    private func separatorVisible(at index: Int) -> Bool {
        index != selectedIndex && index != selectedIndex - 1 && index != items.count - 1
    }

    /// Sizes the scroll document and builds cells for the tabs the clip view can
    /// show, plus one on each side so a flick never reveals a blank slot.
    private func layoutStrip() {
        let width = max(bounds.width, CGFloat(items.count) * Self.minCellWidth)
        let docFrame = NSRect(x: 0, y: 0, width: width, height: Self.stripHeight)
        if document.frame != docFrame { document.frame = docFrame }
        guard !items.isEmpty, width > 1 else {
            for cell in cells { cell.isHidden = true }
            materialized = 0..<0
            return
        }
        let visible = scrollView.contentView.bounds
        let last = min(items.count - 1, Int(ceil(visible.maxX / cellWidth)))
        let first = min(max(0, Int(floor(visible.minX / cellWidth)) - 1), last)
        let range = first..<(last + 1)
        // Cell geometry is `cellWidth` all the way down, so a strip that keeps
        // the same tabs on screen at a new width still has to be re-laid out.
        guard range != materialized || cellWidth != laidOutCellWidth else { return }
        materialized = range
        laidOutCellWidth = cellWidth

        while cells.count < range.count {
            let cell = TabStripCell()
            document.addSubview(cell)
            cells.append(cell)
        }
        for offset in range.count..<cells.count { cells[offset].isHidden = true }
        for (offset, index) in range.enumerated() {
            let cell = cells[offset]
            cell.isHidden = false
            cell.itemIndex = index
            cell.frame = cellFrame(at: index)
            cell.showsSeparator = separatorVisible(at: index)
            let item = items[index]
            cell.configure(title: item.title.isEmpty ? String(localized: "Untitled") : item.title,
                           favicon: BrowserFaviconCache.image(forKey: item.faviconKey),
                           selected: index == selectedIndex,
                           truncation: truncation,
                           font: cellFont)
        }
    }

    /// Parks the capsule over the selected tab. Animated only on a selection
    /// change (a slide during (re)layout would chase the tab widths instead)
    /// and only while switcher motion is on.
    private func updateSelection(animated: Bool) {
        guard items.indices.contains(selectedIndex) else {
            selection.isHidden = true
            return
        }
        let target = cellFrame(at: selectedIndex)
        guard target.width > 1 else { return }
        // A capsule that was hidden has nowhere to slide from, so it is placed.
        let wasVisible = !selection.isHidden
        selection.isHidden = false
        if animated, wasVisible, window != nil, SwitcherMotion.isEnabled {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = SwitcherMotion.duration
                context.timingFunction = SwitcherMotion.timing
                selection.animator().frame = target
            }
        } else {
            selection.frame = target
        }
    }

    /// Drop the tab list after dismissal. The cell pool is bounded by what the
    /// strip can show (a handful either way), so it is kept for the next
    /// drill-in rather than rebuilt on that hot path.
    func releaseIdleResources() {
        selection.isHidden = true
        items = []
        materialized = 0..<0
        laidOutCellWidth = nil
        for cell in cells { cell.isHidden = true }
        selectedIndex = 0
        overflowState = nil
    }

    /// The cell index containing `windowPoint` (in window coordinates), or nil.
    /// Used by `SwitcherView`'s manual hit testing — its `hitTest` override
    /// keeps mouse events at the panel level, so cells never receive their own
    /// `mouseDown`. Mirrors `HoverActionBar.action(atWindowPoint:)`.
    func index(atWindowPoint windowPoint: NSPoint) -> Int? {
        guard !items.isEmpty else { return nil }
        // The document is as wide as all the tabs, so containment has to be
        // tested against what the clip view actually shows — otherwise a point
        // in the panel's margin maps onto a tab scrolled out of sight.
        let clip = scrollView.contentView
        guard clip.bounds.contains(clip.convert(windowPoint, from: nil)) else { return nil }
        let local = document.convert(windowPoint, from: nil)
        guard document.bounds.contains(local) else { return nil }
        let index = Int(local.x / cellWidth)
        return items.indices.contains(index) ? index : nil
    }

    /// Routes a scroll event (delivered to `SwitcherView` by its `hitTest`
    /// override) into the horizontal scroll view so an overflowing strip stays
    /// reachable with the wheel/trackpad.
    func handleScrollWheel(_ event: NSEvent) {
        scrollView.scrollWheel(with: event)
    }

    override func layout() {
        super.layout()
        // A new width re-pitches every tab, so wherever the selection was
        // scrolled to no longer holds.
        let widthChanged = cellWidth != laidOutCellWidth
        layoutStrip()
        updateSelection(animated: false)
        if widthChanged { scrollSelectedIntoView() }
        updateOverflow()
    }

    @objc private func clipBoundsChanged() {
        layoutStrip()
        updateOverflow()
    }

    private func scrollSelectedIntoView() {
        guard items.indices.contains(selectedIndex) else { return }
        document.scrollToVisible(cellFrame(at: selectedIndex).insetBy(dx: -16, dy: 0))
    }

    /// Fades whichever edge still hides tabs and counts them there, so an
    /// overflowing strip reads as scrollable without a scroller. No overflow
    /// means no mask and no counters at all.
    ///
    /// Runs on every clip bounds change, i.e. once per scroll frame, so it
    /// early-outs on an unchanged result: between two frames of the same flick
    /// the counters and the fade usually say exactly what they already say.
    private func updateOverflow() {
        guard let hostLayer = scrollView.layer else { return }
        let visible = scrollView.contentView.bounds
        let overflow = document.frame.width - visible.width
        guard overflow > 1, visible.width > 1, !items.isEmpty else {
            if hostLayer.mask != nil { hostLayer.mask = nil }
            leadingCount.isHidden = true
            trailingCount.isHidden = true
            overflowState = nil
            return
        }
        // Tabs are equal width, so what's off-screen is arithmetic — no need to
        // walk the cells on every scroll tick.
        let state = OverflowState(
            hiddenLeading: max(0, Int(floor((visible.minX + 0.5) / cellWidth))),
            hiddenTrailing: max(0, items.count - Int(ceil((visible.maxX - 0.5) / cellWidth))),
            fadesLeading: visible.minX > 1,
            fadesTrailing: visible.minX < overflow - 1,
            fadeWidth: min(34, visible.width / 4) / visible.width,
            maskBounds: hostLayer.bounds
        )
        guard state != overflowState else { return }
        overflowState = state

        leadingCount.stringValue = "‹ \(state.hiddenLeading)"
        trailingCount.stringValue = "\(state.hiddenTrailing) ›"
        leadingCount.isHidden = state.hiddenLeading == 0
        trailingCount.isHidden = state.hiddenTrailing == 0

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        edgeFade.frame = state.maskBounds
        edgeFade.colors = [state.fadesLeading ? Self.fadeClear : Self.fadeOpaque,
                           Self.fadeOpaque,
                           Self.fadeOpaque,
                           state.fadesTrailing ? Self.fadeClear : Self.fadeOpaque]
        edgeFade.locations = [0,
                              NSNumber(value: state.fadeWidth),
                              NSNumber(value: 1 - state.fadeWidth),
                              1]
        if hostLayer.mask !== edgeFade { hostLayer.mask = edgeFade }
        CATransaction.commit()
    }
}

@MainActor
private final class TabStripCell: NSView {
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let separator = NSView()
    private var isSelected = false
    /// Which tab this pooled cell currently shows.
    var itemIndex = 0

    /// Hairline on the trailing seam. Owned by `TabStripView`, which knows which
    /// seams sit next to the selected capsule.
    var showsSeparator = true {
        didSet {
            guard showsSeparator != oldValue else { return }
            separator.isHidden = !showsSeparator
        }
    }

    init() {
        super.init(frame: .zero)
        // Font and truncation come from `configure`, which resolves them once
        // per drill-in from the user's preferences.
        label.maximumNumberOfLines = 1
        label.alignment = .center
        // Let the title shrink into an ellipsis instead of pushing the centered
        // icon+title group past the tab's edges.
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        iconView.imageScaling = .scaleProportionallyDown
        // Native window tabs (Finder, Terminal) carry no favicon at all, so the
        // slot starts collapsed and `configure` only opens it for a real image.
        iconView.isHidden = true

        // A hidden arranged subview drops out of the layout, so a tab without a
        // favicon centers its title on its own — no zero-width icon slot.
        let content = NSStackView(views: [iconView, label])
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 6
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),
            content.centerXAnchor.constraint(equalTo: centerXAnchor),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 10),
            content.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.centerYAnchor.constraint(equalTo: centerYAnchor),
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: 14),
        ])
        applyAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    func configure(title: String, favicon: NSImage?, selected: Bool, truncation: NSLineBreakMode, font: NSFont) {
        if label.lineBreakMode != truncation {
            label.lineBreakMode = truncation
        }
        if label.font != font {
            label.font = font
        }
        if label.stringValue != title {
            label.stringValue = title
        }
        if iconView.image !== favicon {
            iconView.image = favicon
            iconView.isHidden = favicon == nil
        }
        setSelected(selected)
    }

    /// Every arrow keystroke re-tells all cells whether they are selected, and
    /// all but two are saying the same thing as last time.
    func setSelected(_ selected: Bool) {
        guard isSelected != selected else { return }
        isSelected = selected
        applyAppearance()
    }

    /// The selected tab's surface is the strip's shared glass capsule, so a cell
    /// only ever changes its own text/icon weight.
    private func applyAppearance() {
        label.textColor = isSelected ? .labelColor : .secondaryLabelColor
        iconView.alphaValue = isSelected ? 1 : 0.6
    }
}
