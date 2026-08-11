import AppKit

struct SwitcherMetrics: Equatable {
    let layoutMode: SwitcherLayoutMode
    let scale: CGFloat
    /// Extra multiplier applied to text sizes (and the areas that hold text)
    /// only (#62) — icons, tiles, and spacing keep following `scale`.
    let fontScale: CGFloat
    let rowHeight: CGFloat
    let rowWidth: CGFloat
    let iconSize: CGFloat
    let appNameWidth: CGFloat
    let interGap: CGFloat
    let horizontalInset: CGFloat
    let fontSize: CGFloat
    let outerPadding: CGFloat
    let cornerRadius: CGFloat
    let highlightCornerRadius: CGFloat
    let highlightInset: CGFloat
    let labelHeight: CGFloat
    let letterColumnWidth: CGFloat
    let letterFontSize: CGFloat

    // Icon-dock layout metrics
    let tileSize: CGFloat
    let tileIconSize: CGFloat
    let tileGap: CGFloat
    let tileLabelArea: CGFloat
    let tileLetterArea: CGFloat
    let tileNameFontSize: CGFloat
    let tileTitleFontSize: CGFloat
    let tileLetterFontSize: CGFloat
    let tileBadgeSize: CGFloat
    let tileSelectionInset: CGFloat
    let tileSelectionCornerRadius: CGFloat

    // Window-preview (alt-tab) layout metrics
    let previewTileWidth: CGFloat
    let previewThumbHeight: CGFloat
    let previewGap: CGFloat
    let previewLabelArea: CGFloat
    let previewLetterArea: CGFloat
    let previewIconSize: CGFloat
    let previewNameFontSize: CGFloat
    let previewThumbCornerRadius: CGFloat
    let previewSelectionInset: CGFloat
    let previewSelectionCornerRadius: CGFloat

    static let baseRowHeight: CGFloat = 28
    static let baseRowWidth: CGFloat = 720
    static let baseIconSize: CGFloat = 18
    static let baseAppNameWidth: CGFloat = 200
    static let baseInterGap: CGFloat = 10
    static let baseHorizontalInset: CGFloat = 14
    static let baseFontSize: CGFloat = 13
    static let baseOuterPadding: CGFloat = 8
    static let baseCornerRadius: CGFloat = 12
    static let baseHighlightCornerRadius: CGFloat = 6
    static let baseHighlightInset: CGFloat = 4
    static let baseLabelHeight: CGFloat = 18
    static let baseLetterColumnWidth: CGFloat = 34
    static let baseLetterFontSize: CGFloat = 11

    // Icon-dock base metrics (sized to match macOS-default Cmd+Tab proportions).
    // At `nativeScale` these land within a point or two of the measured native geometry:
    // 135 pt tile pitch (native 134), a 120 pt selection plate (native 120, exact) and
    // 103 pt of visible icon artwork (native 104 — see `baseTileIconSize`). The pitch is
    // what sets panel width, so it is split between the tile and a deliberately tiny gap —
    // the space you see between two icons is the gap plus the transparent margin baked
    // into the icons, which is why the gap alone reads so much smaller than the 30 pt
    // that shows up.
    static let baseTileSize: CGFloat = 88
    /// How far the icon canvas sits inside the tile. The icon is measured off the tile,
    /// not off the selection plate, so the plate can be tightened around the artwork
    /// without the icon shrinking with it. Nearly zero because the tile pitch is native's
    /// and so is the artwork — what separates two icons is `baseTileGap` plus the
    /// transparent margin Apple bakes into the icons themselves.
    static let baseTileIconMargin: CGFloat = 1
    /// Canvas we draw the icon image into — not the size the icon appears to be. Apple
    /// bakes a transparent margin into every app icon, so the visible artwork is only
    /// `iconArtworkRatio` of this: 86 canvas → 69.2 artwork. At the native scale `forScale`
    /// rounds the tile and the margin first, which gives a 128 pt canvas and 103 pt of
    /// artwork — not 69.2 × 1.5.
    ///
    /// Sized so the artwork lands near native's 104 pt at the native scale, which also puts
    /// the gap between two icons at 32 pt against native's 30 — pitch is shared, so icon
    /// size and gap are the same knob. Measured on macOS 26: unselected artwork 208 px and
    /// pitch 268 px at 2x, against a selection plate of 120 pt.
    ///
    /// Do not scale this constant yourself — `forScale` re-derives it from the *rounded*
    /// tile and insets, which is not the same number.
    static let baseTileIconSize: CGFloat = baseTileSize - 2 * baseTileIconMargin
    /// Fraction of an app-icon canvas the visible artwork covers, fitted against the
    /// macOS 26 system icon masks (412 of 512 px).
    static let iconArtworkRatio: CGFloat = 412.0 / 512.0
    static let baseTileGap: CGFloat = 2
    static let baseTileLabelArea: CGFloat = 34
    /// Collapsed label area for grid tiles when both the app name and the window
    /// title are hidden — one slim row that still fits status glyphs and
    /// Launch/Reopen cues, dropping the (now empty) name line's height.
    static let baseTileCompactLabelArea: CGFloat = 18
    /// Top strip above each tile's icon that holds the type-to-jump letter, so
    /// the letter never overlaps the icon.
    static let baseTileLetterArea: CGFloat = 16
    static let baseTileNameFontSize: CGFloat = 11
    static let baseTileTitleFontSize: CGFloat = 10
    static let baseTileLetterFontSize: CGFloat = 11
    /// Dock-badge diameter as a fraction of the icon's *visible artwork*, measured off
    /// the native ⌘Tab panel (Mail's "3": a 100 px badge on the 208 px icon square, @2x).
    /// Tied to the icon rather than to a base length of its own so the badge tracks the
    /// icon at every slider position — it used to scale with the label font instead.
    static let badgeIconRatio: CGFloat = 0.48
    /// How far the badge's center sits inside the artwork's top-right corner, in the same
    /// fraction of the artwork (native: 28 px on that 208 px square). The rest of the
    /// badge's radius is the overhang, so a bigger badge hangs further out — anchoring
    /// the corner instead pushes small badges off into the tile's empty corner.
    static let badgeCornerInsetRatio: CGFloat = 0.135
    /// Leaves the plate at exactly native's 120 pt; against the 103 pt of artwork the
    /// canvas actually produces, that is an 8.5 pt ring (native 8).
    static let baseTileSelectionInset: CGFloat = 4
    /// Corner radius of a macOS 26 app icon as a fraction of its artwork's side: a
    /// `.continuous` squircle of 107 px on the 412 px artwork, fitted against the
    /// system icon masks (Music / Notes / System Settings / Maps) like
    /// `iconArtworkRatio`. Not the iOS figure — measure, don't reuse.
    static let iconCornerRatio: CGFloat = 107.0 / 412.0
    /// Selection plate corner radius. The plate nests concentrically around the icon
    /// artwork — outer radius = inner radius + the gap — so the two corners share a
    /// centre and the margin stays even the whole way round, instead of the plate
    /// looking pinched at `iconCornerRatio` of its own, larger side.
    static let baseTileSelectionCornerRadius: CGFloat = {
        let artwork = baseTileIconSize * iconArtworkRatio
        let plate = baseTileSize - 2 * baseTileSelectionInset
        return artwork * iconCornerRatio + (plate - artwork) / 2
    }()
    /// Padding around the tile row, set so the *artwork* clears the panel edge by native's
    /// 36 pt (measured: panel edge 987 px, first icon 1060 px at 2x). The tile carries the
    /// icon's transparent margin on top of this, so the two are not the same number.
    static let baseTileOuterPadding: CGFloat = 14
    /// Concentric with the selection plate, the same way the plate is concentric with the
    /// icon: the panel edge runs `baseTileOuterPadding + baseTileSelectionInset` outside
    /// the outermost plate, so adding that distance to the plate's radius keeps the two
    /// curves parallel instead of having a tight corner sit inside a rounder one.
    static let baseTileCornerRadius: CGFloat =
        baseTileSelectionCornerRadius + baseTileOuterPadding + baseTileSelectionInset

    // Window-preview base metrics. A uniform tile: jump-letter strip on top, a
    // 16:10 thumbnail area in the middle (the live capture is aspect-fit and
    // letterboxed inside it), and a label row (small app icon + window title)
    // below. Only the panel-radius rule is shared with the grid (plate radius + outer
    // padding + selection inset), taken off the preview tile's own gap/inset/plate radius.
    // The padding is not: `basePreviewOuterPadding` is derived (gap + inset = 12 + 3),
    // while the grid's `baseTileOuterPadding` is a tuned literal 14, not its own
    // gap + inset. A preview tile fills its box with a thumbnail and a full-width title,
    // so the grid's tight margin would put the title on the panel edge.
    static let basePreviewTileWidth: CGFloat = 208
    static let basePreviewThumbHeight: CGFloat = 130
    static let basePreviewGap: CGFloat = 12
    static let basePreviewLabelArea: CGFloat = 24
    static let basePreviewIconSize: CGFloat = 18
    static let basePreviewNameFontSize: CGFloat = 11
    static let basePreviewThumbCornerRadius: CGFloat = 8
    static let basePreviewSelectionInset: CGFloat = 3
    static let basePreviewSelectionCornerRadius: CGFloat = 12
    static let basePreviewOuterPadding: CGFloat = basePreviewGap + basePreviewSelectionInset
    static let basePreviewCornerRadius: CGFloat =
        basePreviewSelectionCornerRadius + basePreviewOuterPadding + basePreviewSelectionInset

    static let baseline = SwitcherMetrics.forScale(1.0, layoutMode: .list)

    /// Resolve the panel-corner-radius preference against this metrics set:
    /// `0` follows the size-derived radius, `-1` pins square corners (#129),
    /// anything above is an explicit point value.
    func resolvedCornerRadius(pref: Int) -> CGFloat {
        pref == 0 ? cornerRadius : CGFloat(max(0, pref))
    }

    /// Resolve the list width-percent preference against this metrics set:
    /// `100` keeps the screen-scaled row width, lower values narrow the list
    /// proportionally without touching text or icon sizes (#124). Values at or
    /// above 100 are the identity, so rows never grow past the automatic width.
    func resolvedRowWidth(percent: Int) -> CGFloat {
        percent >= 100 ? rowWidth : round(rowWidth * CGFloat(max(0, percent)) / 100)
    }

    /// Height of the fuzzy-search bar, and with it of the query pill that fills it.
    /// Sized for a pill shrink-wrapped around the query rather than the full-width
    /// slab this used to be: at the old 30 the strip put too much air between the
    /// query and the first row of icons. Lives here so the fitting pass, which runs
    /// against *candidate* metrics rather than the live ones, reserves exactly what
    /// the layout will later draw — the two drifting apart is what oversized the
    /// panel on a search reveal once already.
    var searchBarHeight: CGFloat { round(24 * scale) }

    /// Strip the layout reserves above the list for the search bar plus the padding
    /// above it (the bar sits flush with the bottom of the reservation, so the list
    /// starts where the chip ends). Same reason as `searchBarHeight`: the fitting pass
    /// and the layout pass have to spell the reservation once, not twice.
    func reservedSearchHeight(active: Bool) -> CGFloat {
        active ? searchBarHeight + outerPadding : 0
    }

    /// Floor on the panel's width while search is open. The grid and preview
    /// layouts size the panel to their results, so without a floor the panel
    /// narrowed to a single tile as the query got more specific — squeezing the
    /// query chip exactly when it was longest, and resizing the window on every
    /// keystroke that changed the match count. The list never collapses that way:
    /// its width is the user's own slider (#124), which at the low end is narrower
    /// than this floor, so flooring it would widen the panel on the search key for
    /// exactly the people who asked for a narrow one.
    var searchMinPanelWidth: CGFloat { layoutMode == .list ? 0 : round(280 * scale) }

    /// App-name column width for a list row that is actually `actualRowWidth`
    /// wide. The column is metric-fixed, so on a row narrowed below the natural
    /// `rowWidth` (#124 width slider, multi-column shrink) it must share the
    /// shortfall proportionally — otherwise it starves the window-title column
    /// into a bare ellipsis while itself keeping a mostly-empty gap.
    func fittedAppNameWidth(actualRowWidth: CGFloat) -> CGFloat {
        guard appNameWidth > 0, rowWidth > 0, actualRowWidth < rowWidth else { return appNameWidth }
        return round(appNameWidth * max(0, actualRowWidth) / rowWidth)
    }

    /// Whether the Window Preview label band must be reserved (the
    /// `browserTabsExpanded` input to `forScale`): always when tabs
    /// are expanded as windows, and transiently while searching with the
    /// search-tab feature — the matched tab rows then need their title (the only
    /// thing distinguishing sibling tabs) shown even when "show window title" is
    /// off. The controller evaluates this once; fitted view metrics preserve the
    /// resulting label band instead of re-deriving mode-specific state.
    static func reserveTabBand(expandAsWindows: Bool, applicationsOnly: Bool,
                               searchActive: Bool, searchExpandsTabs: Bool) -> Bool {
        (expandAsWindows || (searchActive && searchExpandsTabs)) && !applicationsOnly
    }

    /// Panel scale at which the Grid layout reproduces the macOS Cmd+Tab geometry,
    /// so Settings → Size 100 % means "the size of the switcher this replaces".
    ///
    /// Measured off a screenshot of the native switcher on a 2× display: its tile
    /// pitch is ≈133.5 pt against our 90 pt (`baseTileSize` + `baseTileGap`), which
    /// lands on 1.5, and the resulting 4-app panel is 579 pt wide against the native
    /// 576 pt — 4×round(88×1.5) + 3×round(2×1.5) + 2×round(14×1.5) = 528 + 9 + 42. The icon and plate sizes inside that pitch are pinned by the `base*`
    /// constants above, which were fitted to the same screenshot at this scale.
    /// The `base*` constants stay the unit grid they always were; this is the one
    /// place that says what a user-facing percentage is a percentage *of*.
    static let nativeScale: CGFloat = 1.5

    /// `Preferences.panelScalePercent` → panel scale. The only screen-independent
    /// input the panel has: it used to be multiplied by `screen.frame.width / 1440`,
    /// which double-counted, because AppKit points already carry the display's scale
    /// factor. A fixed point size is already roughly a fixed physical size, so scaling
    /// by the point width on top of that made every display past a laptop overshoot —
    /// a 5K at its default "looks like 2560×1440" landed at 1.78× base, a 4K at 1:1
    /// hit the old 1.8× ceiling (#170).
    ///
    /// Points are only *roughly* physically constant: effective points-per-inch still
    /// ranges about ±30% (≈92 on a 24" 1080p, ≈127 on a 14" MacBook Pro), so the panel
    /// is not literally identical in millimetres everywhere. Closing that gap needs
    /// real physical size via `CGDisplayScreenSize`, which reports 0×0 for displays
    /// without EDID — not worth the fallback path until someone asks.
    static func scale(forPercent percent: Int) -> CGFloat {
        nativeScale * CGFloat(percent) / 100
    }

    /// `letterHints == false` collapses the space the jump-letter occupies — the
    /// top strip on tiles and the left column in the list — so the panel reflows
    /// tighter when the user turned letter hints off.
    static func forScale(_ scale: CGFloat, layoutMode: SwitcherLayoutMode = .list, fontScale: CGFloat = 1.0, letterHints: Bool = true, showAppNames: Bool = true, showWindowTitles: Bool = true, hoverActionCount: Int = 0, browserTabsExpanded: Bool = false) -> SwitcherMetrics {
        // Text-only multiplier (#62): every *font* size scales by `f`, and every
        // container whose height/width exists to hold that text scales by
        // `scale * f` so text never clips. Icon sizes, tile geometry, paddings,
        // and gaps stay on `scale` alone. Row height floors at `f == 1` so
        // shrinking text never squeezes the icon-driven row.
        let f = fontScale
        let outerPadding: CGFloat
        let cornerRadius: CGFloat
        switch layoutMode {
        case .list:
            outerPadding = round(baseOuterPadding * scale)
            cornerRadius = round(baseCornerRadius * scale)
        case .gridView:
            outerPadding = round(baseTileOuterPadding * scale)
            cornerRadius = round(baseTileCornerRadius * scale)
        case .windowPreview:
            outerPadding = round(basePreviewOuterPadding * scale)
            cornerRadius = round(basePreviewCornerRadius * scale)
        }

        let letterColumnW = letterHints ? round(baseLetterColumnWidth * scale * f) : 0

        // Hiding app names removes the List layout's dedicated name column so the
        // panel narrows. But the hover action bar floats over that column; with no
        // column the dots overlap the window title. So when names are hidden we
        // reserve just enough width for the bar's dots that don't already fit in
        // the letter column — scaling with how many hover actions are enabled.
        // Grid/Previews ignore appNameWidth and don't key panel width off rowWidth.
        let fullAppNameW = round(baseAppNameWidth * scale)
        let appNameW: CGFloat
        if showAppNames {
            appNameW = fullAppNameW
        } else if layoutMode == .list, hoverActionCount > 0 {
            let barW = HoverActionBar.contentWidth(visibleCount: hoverActionCount, scale: scale)
            appNameW = max(0, barW - letterColumnW - round(baseInterGap * scale))
        } else {
            appNameW = 0
        }
        // Reclaim whatever the name column gave up (and its trailing inter-gap when
        // the column fully collapses) from the row width.
        let rowW = layoutMode == .list
            ? round(baseRowWidth * scale) - (fullAppNameW - appNameW) - (appNameW == 0 ? round(baseInterGap * scale) : 0)
            : round(baseRowWidth * scale)

        // The grid tile stacks the app name over a secondary line (window title +
        // status glyphs). Two lines are needed only when both labels are shown;
        // hiding one collapses the area to a single slim row (the surviving label
        // rides the secondary line with the glyphs, losing nothing), and hiding both
        // drops the area entirely for a bare icon-only tile — the status glyphs go
        // with it. Either way the tile shrinks by the freed height.
        let tileLabelAreaH: CGFloat
        if layoutMode == .gridView, !showAppNames, !showWindowTitles {
            tileLabelAreaH = 0
        } else if layoutMode == .gridView, !(showAppNames && showWindowTitles) {
            tileLabelAreaH = round(baseTileCompactLabelArea * scale * f)
        } else {
            tileLabelAreaH = round(baseTileLabelArea * scale * f)
        }

        // Preview tiles carry a single label row: small app icon + window title.
        // The app-name toggle never adds text here (the icon stands in for the app),
        // so the only thing the band shows is the window title. When the title is
        // hidden, drop the band entirely — symmetric to letterHints collapsing the
        // top letter strip — so the tile is thumbnail-only and shorter, reclaiming
        // the bottom space. Exception: when browser tabs are expanded as windows,
        // every tab tile shares the parent app icon and thumbnail, so the tab title
        // is the *only* sibling distinguisher — keep the band (uniformly, so tile
        // heights stay aligned) even with the title otherwise hidden.
        let previewLabelAreaH = (layoutMode == .windowPreview && !showWindowTitles && !browserTabsExpanded)
            ? 0
            : round(basePreviewLabelArea * scale * f)

        // Derive the icon canvas from the *rounded* tile rather than scaling
        // `baseTileIconSize` on its own: rounding the two independently drifts them apart
        // by a point at some slider positions, and the margin between icon and tile edge
        // is small enough that a stray point is visible. The canvas is allowed to overhang
        // the selection plate — that part of an icon is transparent margin, and the ring
        // is measured against the artwork (see `iconArtworkRatio`), not the canvas.
        let tileSideLength = round(baseTileSize * scale)
        let tileSelectionInsetLength = round(baseTileSelectionInset * scale)
        let tileIconLength = tileSideLength - 2 * round(baseTileIconMargin * scale)

        return SwitcherMetrics(
            layoutMode: layoutMode,
            scale: scale,
            fontScale: f,
            rowHeight: round(baseRowHeight * scale * max(1.0, f)),
            rowWidth: rowW,
            iconSize: round(baseIconSize * scale),
            appNameWidth: appNameW,
            interGap: round(baseInterGap * scale),
            horizontalInset: round(baseHorizontalInset * scale),
            fontSize: baseFontSize * scale * f,
            outerPadding: outerPadding,
            cornerRadius: cornerRadius,
            highlightCornerRadius: round(baseHighlightCornerRadius * scale),
            highlightInset: round(baseHighlightInset * scale),
            labelHeight: round(baseLabelHeight * scale * f),
            letterColumnWidth: letterColumnW,
            letterFontSize: baseLetterFontSize * scale * f,
            tileSize: tileSideLength,
            tileIconSize: tileIconLength,
            tileGap: round(baseTileGap * scale),
            tileLabelArea: tileLabelAreaH,
            tileLetterArea: letterHints ? round(baseTileLetterArea * scale * f) : 0,
            tileNameFontSize: baseTileNameFontSize * scale * f,
            tileTitleFontSize: baseTileTitleFontSize * scale * f,
            tileLetterFontSize: baseTileLetterFontSize * scale * f,
            tileBadgeSize: round(tileIconLength * iconArtworkRatio * badgeIconRatio),
            tileSelectionInset: tileSelectionInsetLength,
            tileSelectionCornerRadius: round(baseTileSelectionCornerRadius * scale),
            previewTileWidth: round(basePreviewTileWidth * scale),
            previewThumbHeight: round(basePreviewThumbHeight * scale),
            previewGap: round(basePreviewGap * scale),
            previewLabelArea: previewLabelAreaH,
            previewLetterArea: letterHints ? round(baseTileLetterArea * scale * f) : 0,
            previewIconSize: round(basePreviewIconSize * scale),
            previewNameFontSize: basePreviewNameFontSize * scale * f,
            previewThumbCornerRadius: round(basePreviewThumbCornerRadius * scale),
            previewSelectionInset: round(basePreviewSelectionInset * scale),
            previewSelectionCornerRadius: round(basePreviewSelectionCornerRadius * scale)
        )
    }
}
