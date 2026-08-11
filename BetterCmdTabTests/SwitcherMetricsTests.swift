import CoreGraphics
import Foundation
import Testing
@testable import BetterCmdTab

@Suite("SwitcherMetrics")
struct SwitcherMetricsTests {

    @Test("reserveTabBand: on when always-expanded, or transiently while searching with the search-tab feature")
    func reserveTabBand() {
        typealias M = SwitcherMetrics
        // Always-expand reserves the band regardless of search.
        #expect(M.reserveTabBand(expandAsWindows: true, applicationsOnly: false, searchActive: false, searchExpandsTabs: false))
        // Search-tab feature: band only while actually searching.
        #expect(!M.reserveTabBand(expandAsWindows: false, applicationsOnly: false, searchActive: false, searchExpandsTabs: true))
        #expect(M.reserveTabBand(expandAsWindows: false, applicationsOnly: false, searchActive: true, searchExpandsTabs: true))
        // Neither feature → never.
        #expect(!M.reserveTabBand(expandAsWindows: false, applicationsOnly: false, searchActive: true, searchExpandsTabs: false))
        // Applications-only collapses to one row per app, so the band is never reserved.
        #expect(!M.reserveTabBand(expandAsWindows: true, applicationsOnly: true, searchActive: false, searchExpandsTabs: false))
        #expect(!M.reserveTabBand(expandAsWindows: false, applicationsOnly: true, searchActive: true, searchExpandsTabs: true))
    }

    @Test("scale 1.0 yields baseline values")
    func baseline() {
        let m = SwitcherMetrics.forScale(1.0)
        #expect(m.scale == 1.0)
        #expect(m.rowHeight == SwitcherMetrics.baseRowHeight)
        #expect(m.rowWidth == SwitcherMetrics.baseRowWidth)
        #expect(m.iconSize == SwitcherMetrics.baseIconSize)
        #expect(m.appNameWidth == SwitcherMetrics.baseAppNameWidth)
    }

    @Test("hiding app names zeroes the column and narrows the list row")
    func hideAppNamesNarrowsList() {
        let shown = SwitcherMetrics.forScale(1.0, layoutMode: .list, showAppNames: true)
        let hidden = SwitcherMetrics.forScale(1.0, layoutMode: .list, showAppNames: false)

        #expect(shown.appNameWidth == SwitcherMetrics.baseAppNameWidth)
        #expect(hidden.appNameWidth == 0)
        // List panel width drops by the freed app-name column plus its inter-gap.
        #expect(hidden.rowWidth == SwitcherMetrics.baseRowWidth
                - SwitcherMetrics.baseAppNameWidth - SwitcherMetrics.baseInterGap)
        #expect(shown.rowWidth == SwitcherMetrics.baseRowWidth)
    }

    @Test("showAppNames does not affect grid/preview metrics")
    func hideAppNamesGridUnaffected() {
        let shown = SwitcherMetrics.forScale(1.0, layoutMode: .gridView, showAppNames: true)
        let hidden = SwitcherMetrics.forScale(1.0, layoutMode: .gridView, showAppNames: false)
        #expect(shown.rowWidth == hidden.rowWidth)
        #expect(shown.tileSize == hidden.tileSize)
    }

    @Test("grid tile label area: full → compact when one hidden → zero when both hidden")
    func gridCompactLabelArea() {
        let full = SwitcherMetrics.forScale(1.0, layoutMode: .gridView, showAppNames: true, showWindowTitles: true)
        let nameOff = SwitcherMetrics.forScale(1.0, layoutMode: .gridView, showAppNames: false, showWindowTitles: true)
        let titleOff = SwitcherMetrics.forScale(1.0, layoutMode: .gridView, showAppNames: true, showWindowTitles: false)
        let bothOff = SwitcherMetrics.forScale(1.0, layoutMode: .gridView, showAppNames: false, showWindowTitles: false)
        // Two stacked lines only when both labels are shown.
        #expect(full.tileLabelArea == SwitcherMetrics.baseTileLabelArea)
        // Hiding one label drops a line; the surviving label + glyphs ride a single
        // slim row.
        #expect(nameOff.tileLabelArea == SwitcherMetrics.baseTileCompactLabelArea)
        #expect(titleOff.tileLabelArea == SwitcherMetrics.baseTileCompactLabelArea)
        // Hiding both drops the label area entirely → bare icon-only tile.
        #expect(bothOff.tileLabelArea == 0)
    }

    @Test("hidden app names reserve a list column for the hover action bar")
    func hiddenNamesReserveHoverColumn() {
        // No hover actions → the name column fully collapses (panel stays narrow).
        let none = SwitcherMetrics.forScale(1.0, layoutMode: .list, showAppNames: false, hoverActionCount: 0)
        #expect(none.appNameWidth == 0)

        // Six dots: reserve the part of the bar that doesn't fit the letter column.
        let many = SwitcherMetrics.forScale(1.0, layoutMode: .list, showAppNames: false, hoverActionCount: 6)
        let barW = HoverActionBar.contentWidth(visibleCount: 6, scale: 1.0)
        let expected = max(0, barW - SwitcherMetrics.baseLetterColumnWidth - SwitcherMetrics.baseInterGap)
        #expect(expected > 0)
        #expect(many.appNameWidth == expected)
        // The reserved column is added back to the row width vs the no-hover collapse.
        #expect(many.rowWidth == SwitcherMetrics.baseRowWidth - SwitcherMetrics.baseAppNameWidth + expected)
    }

    @Test("traffic-light glyph is centered on its dot and lands on the pixel grid")
    func hoverDotGlyphCentering() {
        // `plus` renders as a non-square image (13x12 at its 21pt dot size). The
        // old NSImageView hosting centered it in a non-square layout box, which
        // pushed the glyph visibly up and right inside the green circle.
        for d in [CGFloat(14), 16, 17, 21, 28] {
            let circle = NSRect(x: 0, y: 0, width: d, height: d).insetBy(dx: 0.5, dy: 0.5)
            let r = TrafficLightDot.glyphRect(in: circle, imageSize: NSSize(width: 13, height: 12), backingScale: 2)
            // Centered to within half a device pixel — exact whenever the
            // fitted size is an even number of pixels, off by that half when
            // it isn't (the grid snap wins there: it rasterizes symmetrically,
            // a mathematically-centered fractional rect does not).
            #expect(abs(r.midX - circle.midX) <= 0.25)
            #expect(abs(r.midY - circle.midY) <= 0.25)
            #expect(r.width <= circle.width * 0.62 + 0.5)
            // On the backing grid: every edge is a whole device pixel.
            for v in [r.minX, r.minY, r.width, r.height] {
                #expect(abs((v * 2).rounded() - v * 2) < 0.001)
            }
        }
    }

    @Test("a glyph smaller than its box is never upscaled")
    func hoverDotGlyphNoUpscale() {
        let circle = NSRect(x: 0, y: 0, width: 40, height: 40)
        let r = TrafficLightDot.glyphRect(in: circle, imageSize: NSSize(width: 9, height: 8), backingScale: 2)
        #expect(r.size == NSSize(width: 9, height: 8))
    }

    @Test("preview label area collapses to 0 whenever the window title is hidden")
    func previewLabelAreaCollapse() {
        let full = SwitcherMetrics.forScale(1.0, layoutMode: .windowPreview, showAppNames: true, showWindowTitles: true)
        let nameOff = SwitcherMetrics.forScale(1.0, layoutMode: .windowPreview, showAppNames: false, showWindowTitles: true)
        let titleOff = SwitcherMetrics.forScale(1.0, layoutMode: .windowPreview, showAppNames: true, showWindowTitles: false)
        let bothOff = SwitcherMetrics.forScale(1.0, layoutMode: .windowPreview, showAppNames: false, showWindowTitles: false)
        #expect(full.previewLabelArea == SwitcherMetrics.basePreviewLabelArea)
        #expect(nameOff.previewLabelArea == SwitcherMetrics.basePreviewLabelArea)   // title shown → keep the band
        // The preview band only ever shows the window title (the app icon is
        // decorative), so hiding the title reclaims the band regardless of the
        // app-name toggle — symmetric to letterHints collapsing the top strip.
        #expect(titleOff.previewLabelArea == 0)
        #expect(bothOff.previewLabelArea == 0)
    }

    @Test("preview label band survives both-labels-off when browser tabs are expanded")
    func previewLabelAreaKeptForBrowserTabs() {
        // Browser-tab tiles share the parent app icon + thumbnail, so the tab title
        // is the only distinguisher — the band must stay even with both labels off.
        let bothOffExpanded = SwitcherMetrics.forScale(
            1.0, layoutMode: .windowPreview,
            showAppNames: false, showWindowTitles: false, browserTabsExpanded: true)
        #expect(bothOffExpanded.previewLabelArea == SwitcherMetrics.basePreviewLabelArea)

        // Expansion only matters for the both-off preview case; grid ignores it and
        // still drops its label area to zero (icon-only) when both labels are hidden.
        let grid = SwitcherMetrics.forScale(
            1.0, layoutMode: .gridView,
            showAppNames: false, showWindowTitles: false, browserTabsExpanded: true)
        #expect(grid.tileLabelArea == 0)
    }

    @Test("forScale takes the requested scale verbatim — no clamping")
    func noClamp() {
        // The screen-derived multiplier and its 1.0…1.8 clamp are gone (#170);
        // panelScalePercent is the only input, already bounded by its own range.
        #expect(SwitcherMetrics.forScale(2.5).scale == 2.5)
        #expect(SwitcherMetrics.forScale(0.5).scale == 0.5)
    }

    @Test("Size 100% is the native macOS Cmd+Tab geometry (#170)")
    func hundredPercentIsNativeSize() {
        // Measured off the native switcher on a 2x display: tile pitch 134pt against our
        // baseTileSize + baseTileGap = 90, which gives 1.5. Icon and plate are compared as
        // drawn, not as raw constants: the plate is the tile minus the selection inset on
        // both sides, and the icon is the visible artwork rather than the canvas it is
        // drawn into — those differ by the transparent margin Apple bakes into app icons.
        // Same for the two distances a user actually sees: icon to icon, and icon to the
        // panel edge. Both fall out of the artwork, so they are checked, not assumed.
        #expect(SwitcherMetrics.scale(forPercent: 100) == SwitcherMetrics.nativeScale)
        let grid = SwitcherMetrics.forScale(SwitcherMetrics.scale(forPercent: 100), layoutMode: .gridView)
        let plate = grid.tileSize - 2 * grid.tileSelectionInset
        #expect(abs((grid.tileSize + grid.tileGap) - 134) <= 2)   // native pitch
        #expect(abs(plate - 120) <= 2)                            // native selection plate
        let artwork = grid.tileIconSize * SwitcherMetrics.iconArtworkRatio
        #expect(abs(artwork - 104) <= 2)                          // native artwork
        #expect(abs((grid.tileSize + grid.tileGap - artwork) - 30) <= 2)   // native icon-to-icon gap
        // Icon to panel edge: the tile's own margin around the artwork plus the padding.
        #expect(abs((grid.outerPadding + (grid.tileSize - artwork) / 2) - 36) <= 2)
        // Shipping default is the native size, and it is inside the slider range.
        #expect(Preferences.defaultPanelScalePercent == 100)
        #expect(Preferences.panelScalePercentRange.contains(Preferences.defaultPanelScalePercent))
    }

    @Test("every panelScalePercent maps proportionally onto the base geometry")
    func panelScalePercentRangeIsHonored() {
        // Absolute expectations on purpose: re-deriving these as
        // `nativeScale * percent / 100` would restate the implementation and keep
        // passing if `nativeScale` itself regressed, which is the number #170 turns on.
        let expected: [Int: CGFloat] = [35: 0.525, 75: 1.125, 100: 1.5, 125: 1.875, 150: 2.25]
        for (percent, scale) in expected {
            #expect(SwitcherMetrics.scale(forPercent: percent) == scale)
            let m = SwitcherMetrics.forScale(scale)
            #expect(m.scale == scale)
            #expect(m.iconSize == (SwitcherMetrics.baseIconSize * scale).rounded())
        }
        // The slider's ends are the ends of that table, so a range change lands here.
        #expect(Preferences.panelScalePercentRange.lowerBound == 35)
        #expect(Preferences.panelScalePercentRange.upperBound == 150)
        // The old 50 % floor is still reachable: it was 0.50 effective, 35 % is 0.525.
        #expect(SwitcherMetrics.scale(forPercent: 35) < 0.55)
    }

    @Test("the selection plate's corner radius never exceeds half the plate")
    func selectionCornerRadiusFitsPlate() {
        // Beyond half the side a `.continuous` rounded rect stops being a squircle and
        // starts clipping; the radius is derived from two constants that have already
        // moved twice, so pin the invariant rather than the number.
        for percent in [Preferences.panelScalePercentRange.lowerBound, 100,
                        Preferences.panelScalePercentRange.upperBound] {
            let grid = SwitcherMetrics.forScale(SwitcherMetrics.scale(forPercent: percent),
                                                layoutMode: .gridView)
            let plate = grid.tileSize - 2 * grid.tileSelectionInset
            #expect(grid.tileSelectionCornerRadius <= plate / 2)
            #expect(grid.tileSelectionCornerRadius > 0)
        }
    }

    @Test("default scale 1.0 is the untouched base geometry")
    func baseScale() {
        let m = SwitcherMetrics.forScale(1.0)
        #expect(m.scale == 1.0)
        #expect(m.rowHeight == SwitcherMetrics.baseRowHeight)
    }

    @Test("baseline static matches forScale(1.0)")
    func baselineMatchesForScale1() {
        let a = SwitcherMetrics.baseline
        let b = SwitcherMetrics.forScale(1.0)
        #expect(a == b)
    }

    @Test("scale 1.5 produces 1.5x integer-rounded dimensions")
    func scale1_5() {
        let m = SwitcherMetrics.forScale(1.5)
        #expect(m.scale == 1.5)
        #expect(m.rowHeight == (SwitcherMetrics.baseRowHeight * 1.5).rounded())
        #expect(m.iconSize == (SwitcherMetrics.baseIconSize * 1.5).rounded())
    }

    @Test("Equatable conformance: same scale → equal")
    func equatable() {
        #expect(SwitcherMetrics.forScale(1.2) == SwitcherMetrics.forScale(1.2))
        #expect(SwitcherMetrics.forScale(1.2) != SwitcherMetrics.forScale(1.3))
    }

    @Test("scale below 1.0 shrinks the panel")
    func panelScaleSmall() {
        let m = SwitcherMetrics.forScale(0.85)
        #expect(m.scale == 0.85)
        #expect(m.iconSize == (SwitcherMetrics.baseIconSize * 0.85).rounded())
    }

    @Test("minimum panel scale proportionally shrinks panel geometry")
    func panelScaleMinimum() {
        let m = SwitcherMetrics.forScale(0.5)
        #expect(m.scale == 0.5)
        #expect(m.iconSize == (SwitcherMetrics.baseIconSize * 0.5).rounded())
        #expect(m.outerPadding == (SwitcherMetrics.baseOuterPadding * 0.5).rounded())
        #expect(m.interGap == (SwitcherMetrics.baseInterGap * 0.5).rounded())
        #expect(m.fontSize == SwitcherMetrics.baseFontSize * 0.5)
    }

    @Test("panel scale above 1.0 enlarges the panel")
    func panelScaleLarge() {
        let m = SwitcherMetrics.forScale(1.2)
        #expect(m.scale == 1.2)
        #expect(m.tileIconSize < m.tileSize)
    }

    /// Grid selection on macOS 26 is a fill with no border, so it only exists where it
    /// shows *around* the artwork: the plate has to stay wider than the artwork at every
    /// slider position, including the small end where both round independently. (The
    /// canvas may overhang the plate — that part of the icon is transparent margin. Older
    /// systems, which can hand back artwork drawn edge to edge, keep a hairline border.)
    @Test("the selection plate leaves a visible ring at every slider position")
    func iconCanvasFitsSelectionPlate() {
        for percent in Preferences.panelScalePercentRange {
            let grid = SwitcherMetrics.forScale(SwitcherMetrics.scale(forPercent: percent), layoutMode: .gridView)
            let plate = grid.tileSize - 2 * grid.tileSelectionInset
            #expect(grid.tileIconSize * SwitcherMetrics.iconArtworkRatio <= plate - 4)
        }
    }

    /// Grid and preview size the panel to their results, so a query specific enough to
    /// leave one match used to shrink the panel to a single tile and squeeze the query
    /// chip. The floor has to clear that case at every slider position, not just the
    /// default one — the preview tile is the tight one, it clears by a fifth of what
    /// the grid tile does. The list is sized by its own width slider instead of by the
    /// match count, so the floor must never widen even the narrowest one.
    @Test("the search width floor outgrows a one-tile panel and spares the list")
    func searchFloorClearsASingleTile() {
        for percent in Preferences.panelScalePercentRange {
            let scale = SwitcherMetrics.scale(forPercent: percent)
            let grid = SwitcherMetrics.forScale(scale, layoutMode: .gridView)
            #expect(grid.searchMinPanelWidth > grid.tileSize + grid.outerPadding * 2)

            let previews = SwitcherMetrics.forScale(scale, layoutMode: .windowPreview)
            #expect(previews.searchMinPanelWidth
                > previews.previewTileWidth + previews.outerPadding * 2)

            let list = SwitcherMetrics.forScale(scale, layoutMode: .list)
            let narrowest = list.resolvedRowWidth(percent: Preferences.listWidthPercentRange.lowerBound)
            #expect(list.searchMinPanelWidth <= narrowest + list.outerPadding * 2)
        }
    }

    /// A preview tile fills its box — thumbnail across the width, window title under it —
    /// so it needs a wider margin than the grid, whose tile is mostly air around a centred
    /// plate. Sharing the grid's padding put window titles on the panel edge.
    @Test("window previews keep a wider panel margin than the grid")
    func previewPanelMarginClearsTitles() {
        let grid = SwitcherMetrics.forScale(1.5, layoutMode: .gridView)
        let previews = SwitcherMetrics.forScale(1.5, layoutMode: .windowPreview)
        #expect(previews.outerPadding > grid.outerPadding)
        #expect(previews.cornerRadius != grid.cornerRadius)
    }

    /// The unread badge is measured against the native ⌘Tab panel, where it is just under
    /// half the icon it hangs off. It used to be a base length scaled by the *label font*
    /// preference, so it drifted off the icon at every size but the default.
    @Test("the badge keeps its share of the icon at every slider position and font size")
    func badgeTracksTheIcon() {
        for percent in Preferences.panelScalePercentRange {
            for fontScale in [0.8, 1.0, 1.4] {
                let grid = SwitcherMetrics.forScale(
                    SwitcherMetrics.scale(forPercent: percent),
                    layoutMode: .gridView,
                    fontScale: fontScale
                )
                let artwork = grid.tileIconSize * SwitcherMetrics.iconArtworkRatio
                #expect(abs(grid.tileBadgeSize / artwork - SwitcherMetrics.badgeIconRatio) < 0.02)
            }
        }
    }

    @Test("corner-radius pref: 0 = automatic, -1 = square, > 0 = explicit points")
    func resolvedCornerRadius() {
        let m = SwitcherMetrics.forScale(1.0)
        #expect(m.resolvedCornerRadius(pref: 0) == m.cornerRadius)
        #expect(m.resolvedCornerRadius(pref: -1) == 0)
        #expect(m.resolvedCornerRadius(pref: 17) == 17)
        // Grid derives a different automatic radius; square must still win.
        let grid = SwitcherMetrics.forScale(1.0, layoutMode: .gridView)
        #expect(grid.resolvedCornerRadius(pref: 0) == grid.cornerRadius)
        #expect(grid.cornerRadius != m.cornerRadius)
        #expect(grid.resolvedCornerRadius(pref: -1) == 0)
    }

    @Test("list width percent: 100 = automatic width, lower narrows proportionally, never widens")
    func resolvedRowWidth() {
        // Ultrawide-style metrics: scale 1.8 gives a 1296 pt automatic row (#124).
        let m = SwitcherMetrics.forScale(1.8)
        #expect(m.resolvedRowWidth(percent: 100) == m.rowWidth)
        #expect(m.resolvedRowWidth(percent: 50) == round(m.rowWidth / 2))
        // Values past 100 never widen the row.
        #expect(m.resolvedRowWidth(percent: 250) == m.rowWidth)
        // Clamp keeps the pref inside the slider range.
        #expect(Preferences.clampListWidthPercent(0) == Preferences.listWidthPercentRange.lowerBound)
        #expect(Preferences.clampListWidthPercent(9999) == Preferences.listWidthPercentRange.upperBound)
        #expect(Preferences.clampListWidthPercent(70) == 70)
    }

    @Test("app-name column shares a row's narrowing so the title column keeps space")
    func fittedAppNameWidth() {
        let m = SwitcherMetrics.forScale(1.8)
        // Full-width row: the metric column as-is.
        #expect(m.fittedAppNameWidth(actualRowWidth: m.rowWidth) == m.appNameWidth)
        // Wider than natural never grows the column.
        #expect(m.fittedAppNameWidth(actualRowWidth: m.rowWidth * 2) == m.appNameWidth)
        // Half-width row halves the column instead of starving the title.
        #expect(m.fittedAppNameWidth(actualRowWidth: m.rowWidth / 2) == round(m.appNameWidth / 2))
        // Hidden names stay collapsed regardless of row width.
        let hidden = SwitcherMetrics.forScale(1.8, showAppNames: false)
        #expect(hidden.fittedAppNameWidth(actualRowWidth: 300) == 0)
    }

    @Test("fontScale defaults to 1.0 (no behavior change)")
    func fontScaleDefaultIdentity() {
        #expect(SwitcherMetrics.forScale(1.2) == SwitcherMetrics.forScale(1.2, fontScale: 1.0))
        #expect(SwitcherMetrics.forScale(1.0) == SwitcherMetrics.forScale(1.0, fontScale: 1.0))
    }

    @Test("fontScale multiplies every font size (#62)")
    func fontScaleScalesAllFonts() {
        let m = SwitcherMetrics.forScale(1.0, fontScale: 1.3)
        #expect(m.fontSize == SwitcherMetrics.baseFontSize * 1.3)
        #expect(m.letterFontSize == SwitcherMetrics.baseLetterFontSize * 1.3)
        #expect(m.tileNameFontSize == SwitcherMetrics.baseTileNameFontSize * 1.3)
        #expect(m.tileTitleFontSize == SwitcherMetrics.baseTileTitleFontSize * 1.3)
        #expect(m.tileLetterFontSize == SwitcherMetrics.baseTileLetterFontSize * 1.3)
        #expect(m.previewNameFontSize == SwitcherMetrics.basePreviewNameFontSize * 1.3)
    }

    @Test("fontScale grows the areas that hold text, not the tile geometry")
    func fontScaleGrowsTextAreas() {
        let m = SwitcherMetrics.forScale(1.0, fontScale: 1.3)
        #expect(m.labelHeight == round(SwitcherMetrics.baseLabelHeight * 1.3))
        #expect(m.letterColumnWidth == round(SwitcherMetrics.baseLetterColumnWidth * 1.3))
        #expect(m.previewLabelArea == round(SwitcherMetrics.basePreviewLabelArea * 1.3))
        let grid = SwitcherMetrics.forScale(1.0, layoutMode: .gridView, fontScale: 1.3)
        #expect(grid.tileLabelArea == round(SwitcherMetrics.baseTileLabelArea * 1.3))
        #expect(grid.tileLetterArea == round(SwitcherMetrics.baseTileLetterArea * 1.3))
        // Icon/tile geometry stays on the panel scale alone.
        #expect(grid.tileSize == SwitcherMetrics.baseTileSize)
        #expect(grid.tileIconSize == SwitcherMetrics.baseTileIconSize)
        #expect(m.iconSize == SwitcherMetrics.baseIconSize)
    }

    @Test("shrinking text keeps the icon-driven row height, growing raises it")
    func fontScaleShrinkKeepsRowHeight() {
        let small = SwitcherMetrics.forScale(1.0, fontScale: 0.85)
        #expect(small.fontSize == SwitcherMetrics.baseFontSize * 0.85)
        #expect(small.rowHeight == SwitcherMetrics.baseRowHeight)
        let big = SwitcherMetrics.forScale(1.0, fontScale: 1.3)
        #expect(big.rowHeight == round(SwitcherMetrics.baseRowHeight * 1.3))
    }

    @Test("forScale passes fontScale through to the fonts")
    func forScalePassesFontScale() {
        let m = SwitcherMetrics.forScale(1.0, fontScale: 0.85)
        #expect(m.fontSize == SwitcherMetrics.baseFontSize * 0.85)
        #expect(m.fontScale == 0.85)
    }
}

@Suite("Switcher grid/preview column fitting")
struct SwitcherFitColumnsTests {

    @Test("stays at the preferred columns when the rows already fit the height")
    func fitsWithoutExpansion() {
        // 12 tiles, 6 preferred cols → 2 rows, well under the 5-row cap.
        #expect(SwitcherView.fitColumns(count: 12, preferredCols: 6, tilesPerRow: 10, maxRows: 5) == 6)
        // A user's smaller column choice is honored when it doesn't overflow.
        #expect(SwitcherView.fitColumns(count: 8, preferredCols: 4, tilesPerRow: 10, maxRows: 4) == 4)
    }

    @Test("adds columns past the preferred count to keep rows within the height")
    func expandsToFitHeight() {
        // 40 tiles, 4 preferred cols → 10 rows > 5 cap → needs ceil(40/5)=8 cols.
        #expect(SwitcherView.fitColumns(count: 40, preferredCols: 4, tilesPerRow: 10, maxRows: 5) == 8)
        // After expansion the rows actually fit.
        let cols = SwitcherView.fitColumns(count: 20, preferredCols: 2, tilesPerRow: 10, maxRows: 4)
        #expect(cols == 5)
        #expect(Int(ceil(Double(20) / Double(cols))) <= 4)
    }

    @Test("never exceeds the width-driven column maximum (extreme counts)")
    func cappedByWidth() {
        // 100 tiles want ceil(100/5)=20 cols, but only 6 fit horizontally.
        #expect(SwitcherView.fitColumns(count: 100, preferredCols: 4, tilesPerRow: 6, maxRows: 5) == 6)
    }

    @Test("clamps a preferred column count above what the width holds")
    func preferredAboveWidth() {
        // preferredCols 12 but width holds only 6; rows then fit → 6.
        #expect(SwitcherView.fitColumns(count: 10, preferredCols: 12, tilesPerRow: 6, maxRows: 10) == 6)
    }

    @Test("gridFit expands columns past a user cap to keep rows within the height")
    func gridFitExpandsPastCap() {
        // tileW 100 + gap 10 → 8 cols fit the 870-wide area; itemH 100 + gap 10 →
        // 2 rows fit the 250-tall area. User cap 2 would need 6 rows (overflow),
        // so columns expand from 2 → 6 to land 12 tiles in 2 rows.
        let f = SwitcherView.gridFit(count: 12, tileW: 100, itemH: 100, gap: 10,
                                     maxListWidth: 870, maxListHeight: 250, userCap: 2)
        #expect(f.cols == 6)
        #expect(f.rowsCount == 2)
        #expect(f.listHeight <= 250)   // fits the visible height after expansion
    }

    @Test("gridFit never exceeds the width-driven column max (shrink-to-fit handles the rest)")
    func gridFitWidthCapped() {
        // 100 tiles want 50 cols to fit 2 rows, but only 5 fit the 540-wide area,
        // so cols cap at 5 and the rows overflow here — the configure-time fit
        // scale then shrinks the tiles. gridFit just reports the packing.
        let f = SwitcherView.gridFit(count: 100, tileW: 100, itemH: 100, gap: 10,
                                     maxListWidth: 540, maxListHeight: 250, userCap: 0)
        #expect(f.cols == 5)
        #expect(f.rowsCount == 20)
    }

    @Test("listFit never lets a single column outrun the screen width (#170)")
    func listFitClampsSingleColumn() {
        // A 1280pt-wide MacBook Air at the top of the Size slider: the base row is
        // wider than the screen allows and there is no second column to divide it
        // across, so the single column must clamp instead of hanging off both edges.
        let scale = SwitcherMetrics.scale(forPercent: Preferences.panelScalePercentRange.upperBound)
        let metrics = SwitcherMetrics.forScale(scale)
        let maxW: CGFloat = 1280 * 0.92 - metrics.outerPadding * 2
        let maxH: CGFloat = 800 * 0.85 - metrics.outerPadding * 2
        let fit = SwitcherView.listFit(count: 3, rowH: metrics.rowHeight,
                                       baseRowW: metrics.rowWidth, scale: scale,
                                       maxListWidth: maxW, maxListHeight: maxH)
        #expect(fit.cols == 1)
        #expect(metrics.rowWidth > maxW)      // the case that used to overflow
        #expect(fit.listWidth <= maxW)
    }

    @Test("listFit reports the overflow that the fit-shrink then resolves")
    func listFitReportsHeightOverflow() {
        // 40 apps at a large scale on a short screen: columns cap out on width, so
        // the packing overflows the height and configure()'s shrink loop takes over.
        let over = SwitcherView.listFit(count: 40, rowH: 63, baseRowW: 1620, scale: 2.25,
                                        maxListWidth: 1170, maxListHeight: 650)
        #expect(over.listHeight > 650)
        // Half the scale fits within both bounds — so the shrink loop terminates.
        let ok = SwitcherView.listFit(count: 40, rowH: 31.5, baseRowW: 810, scale: 1.125,
                                      maxListWidth: 1170, maxListHeight: 650)
        #expect(ok.listHeight <= 650)
        #expect(ok.listWidth <= 1170)
    }
}
