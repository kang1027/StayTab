import AppKit
import Testing
@testable import BetterCmdTab

/// Guards the two motions the grid re-flow is made of — the tiles gliding to
/// their new slots (a window closing, a search filter) and the row block
/// gliding when a strip claims height. The panel measures itself by laying the
/// view out inside a `CATransaction` with actions disabled, so the tile glide
/// has to opt back in; without that nesting the tiles cut straight to their new
/// slots, which is the whole bug this covers.
///
/// Unlike the rest of the suite these cases are not pure logic: `armReflow`
/// gates on `window?.isVisible`, so they need a real window on a real
/// WindowServer and will not pass headless — nor with macOS Reduce Motion on,
/// which `SwitcherMotion.isEnabled` honors on top of the app's own preference.
@MainActor
@Suite("Switcher reflow")
struct SwitcherReflowTests {
    private static let metrics = SwitcherMetrics.forScale(1.0, layoutMode: .gridView)

    private func rows(_ count: Int) -> [SwitcherRow] {
        (0..<count).map {
            SwitcherRow(launchable: InstalledApp(name: "App\($0)",
                                                 bundleID: "test.app\($0)",
                                                 url: URL(fileURLWithPath: "/tmp/App\($0).app")))
        }
    }

    private func tiles(_ root: NSView) -> [NSView] {
        var found: [NSView] = []
        func walk(_ view: NSView) {
            if view is SwitcherIconItemView { found.append(view) }
            view.subviews.forEach(walk)
        }
        walk(root)
        return found
    }

    /// Runs `body` against a switcher view hosted in a real, ordered-in window
    /// with the animation preference forced either way, restoring the
    /// preference afterwards (the test bundle shares the debug app's domain).
    private func withHostedView(animations: Bool, _ body: (SwitcherView) -> Void) {
        let saved = Preferences.shared.animationsEnabled
        defer { Preferences.shared.animationsEnabled = saved }
        Preferences.shared.animationsEnabled = animations

        let view = SwitcherView(frame: NSRect(x: 0, y: 0, width: 600, height: 300))
        let window = NSWindow(contentRect: view.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = view
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        body(view)
    }

    private func configure(_ view: SwitcherView, _ rows: [SwitcherRow],
                           strip: [TabStripItem] = []) {
        view.configure(rows: rows, labels: rows.map(\.appName), selectedIndex: 0,
                       metrics: Self.metrics, effective: .defaults,
                       tabStripItems: strip.isEmpty ? nil : strip)
    }

    /// Drops the first row the way closing a window does, laying out exactly as
    /// `SwitcherPanel.present()` does, and returns how many tiles are gliding.
    private func movingTilesAfterRowDrop(animations: Bool) -> Int {
        var moving = 0
        withHostedView(animations: animations) { view in
            let all = rows(8)
            configure(view, all)
            view.layoutSubtreeIfNeeded()
            tiles(view).forEach { $0.layer?.removeAllAnimations() }

            configure(view, Array(all.dropFirst()))
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            view.layoutSubtreeIfNeeded()
            CATransaction.commit()
            moving = tiles(view).filter { $0.layer?.animation(forKey: "position") != nil }.count
        }
        return moving
    }

    @Test func tilesGlideIntoTheGapLeftByAClosedWindow() {
        // Seven rows survive the drop and every one of them changes slot.
        #expect(movingTilesAfterRowDrop(animations: true) == 7)
    }

    @Test func animationsOffKeepsTheReflowAHardCut() {
        #expect(movingTilesAfterRowDrop(animations: false) == 0)
    }

    /// The tab strip claiming height at the bottom moves every row on screen
    /// without moving a single tile inside the block, so the block itself is
    /// what has to glide — the tile-level animation above cannot cover this.
    @Test func theRowBlockGlidesWhenTheTabStripClaimsHeight() {
        withHostedView(animations: true) { view in
            let all = rows(8)
            configure(view, all)
            view.layoutSubtreeIfNeeded()
            let block = tiles(view).first?.superview
            block?.layer?.removeAllAnimations()

            configure(view, all, strip: (0..<3).map { TabStripItem(title: "Tab\($0)", faviconKey: nil) })
            // In the app the panel resizing around the new strip is what drives
            // this pass; standalone there is no panel to ask for it.
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
            #expect(block?.layer?.animation(forKey: "reflowGlide") != nil)
        }
    }
}
