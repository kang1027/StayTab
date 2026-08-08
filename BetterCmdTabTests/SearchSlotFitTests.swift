import Testing
@testable import BetterCmdTab

/// `SwitcherController.fitSearchSlots` — how the tab-expanded search ("Search
/// browser tabs") shares the pre-expansion slot count between canonical
/// window/app rows and the transient browser-tab rows.
@Suite("SearchSlotFit")
struct SearchSlotFitTests {

    /// Indices 0...n are rows; `tabs` marks which of them are transient tab rows.
    private func fit(_ matched: [Int], slots: Int, tabs: Set<Int>) -> [Int] {
        SwitcherController.fitSearchSlots(matched, slots: slots) { tabs.contains($0) }
    }

    @Test("tab rows never evict a canonical match")
    func canonicalRowsSurvive() {
        // 3 slots, a browser exploded into 5 matching tabs at the top, one app
        // match last: the app row must still be shown.
        let kept = fit([0, 1, 2, 3, 4, 9], slots: 3, tabs: [0, 1, 2, 3, 4])
        #expect(kept.contains(9))
        #expect(kept.count == 3)
        #expect(kept == [0, 1, 9])
    }

    @Test("order is preserved, only surplus tabs are dropped")
    func keepsOrder() {
        let kept = fit([7, 0, 1, 2, 8], slots: 3, tabs: [0, 1, 2])
        #expect(kept == [7, 0, 8])
    }

    @Test("more canonical matches than slots keeps them all and drops every tab")
    func canonicalOverflow() {
        // Can't happen from `refreshDisplay` (canonical rows ⊆ baseRows), but the
        // budget must not go negative and start letting tabs back in.
        #expect(fit([5, 6, 7, 0], slots: 2, tabs: [0]) == [5, 6, 7])
    }

    @Test("no matches, no rows")
    func empty() {
        #expect(fit([], slots: 4, tabs: []).isEmpty)
    }
}
