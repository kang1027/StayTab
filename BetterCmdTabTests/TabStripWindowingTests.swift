import AppKit
import Testing
@testable import BetterCmdTab

/// The strip lays its tabs out arithmetically and only builds cells for the
/// ones the clip view can show, so a browser window with hundreds of tabs must
/// not turn into hundreds of views — and every index the rest of the app asks
/// about must still resolve, materialized or not.
///
/// These cases drive a real `NSView` hierarchy inside an `NSWindow`, so they
/// need a WindowServer and will not pass headless.
@MainActor
@Suite("Tab strip windowing")
struct TabStripWindowingTests {
    /// The cell class is private to `TabStripView`; matching by class name keeps
    /// the production API free of a test-only accessor.
    private func cells(_ root: NSView) -> [NSView] {
        let own = (String(describing: type(of: root)) == "TabStripCell" && !root.isHidden) ? [root] : []
        return root.subviews.reduce(own) { $0 + cells($1) }
    }

    /// The window has to outlive the assertions — `index(atWindowPoint:)`
    /// converts through it.
    private func hosted(tabs: Int, width: CGFloat = 600) -> (window: NSWindow, strip: TabStripView) {
        let frame = NSRect(x: 0, y: 0, width: width, height: TabStripView.stripHeight)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        let strip = TabStripView(frame: frame)
        window.contentView = strip
        strip.configure(items: (0..<tabs).map { TabStripItem(title: "Tab \($0)", faviconKey: nil) },
                        selectedIndex: 0)
        strip.layoutSubtreeIfNeeded()
        return (window, strip)
    }

    @Test func hundredsOfTabsCostAHandfulOfCells() {
        let (window, strip) = hosted(tabs: 300)
        _ = window
        // 600pt / 110pt minimum ≈ 5 tabs on screen, plus a margin cell per side.
        #expect(cells(strip).count <= 8)
    }

    @Test func everyTabGetsACellWhenTheyAllFit() {
        let (window, strip) = hosted(tabs: 4)
        _ = window
        #expect(cells(strip).count == 4)
    }

    @Test func pointsMapToTheTabUnderThem() {
        // 300 tabs at 600pt means each tab is the 110pt minimum wide.
        let (window, strip) = hosted(tabs: 300)
        _ = window
        #expect(strip.index(atWindowPoint: NSPoint(x: 5, y: 15)) == 0)
        #expect(strip.index(atWindowPoint: NSPoint(x: 115, y: 15)) == 1)
        #expect(strip.index(atWindowPoint: NSPoint(x: 5, y: 200)) == nil)
    }

    /// A strip whose tabs all fit keeps the same visible range at any width, so
    /// only the cell width tells it to lay out again.
    @Test func cellsFollowTheStripWhenItResizes() {
        let (window, strip) = hosted(tabs: 4)
        strip.setFrameSize(NSSize(width: 800, height: TabStripView.stripHeight))
        window.contentView?.layoutSubtreeIfNeeded()
        #expect(cells(strip).map(\.frame.maxX).max() == 800)
    }
}

/// Ordering native window tabs against the titles their tab bar shows. Pure
/// logic — the AX reads that produce the titles live in `orderedTabWindows`.
@Suite("Native tab window ordering")
struct TabWindowOrderingTests {
    private func refs(_ titles: [String]) -> [TabWindowRef] {
        titles.enumerated().map { index, title in
            TabWindowRef(ref: AXUIElementCreateSystemWide(), title: title, cgWindowID: CGWindowID(index + 1))
        }
    }

    private func order(_ windows: [String], by titles: [String]) -> [CGWindowID] {
        WindowEnumerator.orderTabWindows(refs(windows), byTitles: titles).map(\.cgWindowID)
    }

    @Test func windowsFollowTheTabBar() {
        // Front tab first from the caller, second in the bar.
        #expect(order(["Docs", "Home", "Work"], by: ["Home", "Docs", "Work"]) == [2, 1, 3])
    }

    @Test func duplicateTitlesKeepTheirRelativeOrder() {
        #expect(order(["Home", "Home", "Work"], by: ["Work", "Home", "Home"]) == [3, 1, 2])
    }

    @Test func anUnnamedWindowLeavesTheOrderAlone() {
        // Terminal can show a shorter tab title than its window title; ordering
        // only part of the stack would be worse than not ordering it.
        #expect(order(["Docs", "Home", "Work"], by: ["Home", "Docs"]) == [1, 2, 3])
    }
}
