import Testing
@testable import BetterCmdTab

/// Pure-logic coverage for `AppCatalogCache.statusPriority`'s bucketing — the
/// independent `sinkHiddenApps` ("Move hidden apps to the bottom") and
/// `sinkMinimizedWindows` ("Move minimized windows to the bottom") gates.
/// Exercises the primitive-typed core (not the `SwitcherRow` wrapper) since
/// `SwitcherRow.isHidden` reads a live `NSRunningApplication`, which can't be
/// faked as hidden for the test host process. The rule is `nonisolated`, so this
/// covers both the cached and the off-main cold path (`AppCatalog.snapshot`) —
/// they call the same function.
@Suite("AppCatalogCache statusPriority")
struct AppCatalogCacheStatusPriorityTests {

    @Test("hidden apps sink to the end when sinkHiddenApps is on")
    func hiddenSinksWhenOn() {
        let priority = AppCatalogCache.statusPriority(
            hasWindow: true, isPlaceholder: false, isHidden: true, isMinimized: false,
            sinkHiddenApps: true, sinkMinimizedWindows: true
        )
        #expect(priority == 2)
    }

    @Test("hidden apps keep their normal position when sinkHiddenApps is off")
    func hiddenStaysPutWhenOff() {
        let priority = AppCatalogCache.statusPriority(
            hasWindow: true, isPlaceholder: false, isHidden: true, isMinimized: false,
            sinkHiddenApps: false, sinkMinimizedWindows: true
        )
        #expect(priority == 0)
    }

    /// Pins the branch precedence: a hidden app whose window is also minimized
    /// belongs in the hidden bucket, not the minimized one. Swapping the two
    /// `statusPriority` branches would otherwise pass every other case here.
    @Test("hidden outranks minimized when both sinks are on")
    func hiddenBeatsMinimizedWhenBothOn() {
        let priority = AppCatalogCache.statusPriority(
            hasWindow: true, isPlaceholder: false, isHidden: true, isMinimized: true,
            sinkHiddenApps: true, sinkMinimizedWindows: true
        )
        #expect(priority == 2)
    }

    @Test("a hidden+minimized app falls to the minimized bucket when only the hidden sink is off")
    func hiddenMinimizedFallsToMinimizedBucket() {
        let priority = AppCatalogCache.statusPriority(
            hasWindow: true, isPlaceholder: false, isHidden: true, isMinimized: true,
            sinkHiddenApps: false, sinkMinimizedWindows: true
        )
        #expect(priority == 1)
    }

    @Test("a hidden+minimized app keeps its normal position when both sinks are off")
    func hiddenMinimizedStaysPutWhenBothOff() {
        let priority = AppCatalogCache.statusPriority(
            hasWindow: true, isPlaceholder: false, isHidden: true, isMinimized: true,
            sinkHiddenApps: false, sinkMinimizedWindows: false
        )
        #expect(priority == 0)
    }

    @Test("minimized windows sink above the hidden/windowless bucket when sinkMinimizedWindows is on")
    func minimizedSinksWhenOn() {
        let priority = AppCatalogCache.statusPriority(
            hasWindow: true, isPlaceholder: false, isHidden: false, isMinimized: true,
            sinkHiddenApps: true, sinkMinimizedWindows: true
        )
        #expect(priority == 1)
    }

    @Test("minimized windows keep their MRU position when sinkMinimizedWindows is off (#159)")
    func minimizedStaysPutWhenOff() {
        let priority = AppCatalogCache.statusPriority(
            hasWindow: true, isPlaceholder: false, isHidden: false, isMinimized: true,
            sinkHiddenApps: true, sinkMinimizedWindows: false
        )
        #expect(priority == 0)
    }

    /// The two preferences are independent: turning the hidden sink off must not
    /// stop minimized windows sinking, and vice versa.
    @Test("each sink preference acts independently of the other")
    func sinksAreIndependent() {
        // Hidden sink off, minimized sink on — hidden app stays, minimized sinks.
        #expect(AppCatalogCache.statusPriority(
            hasWindow: true, isPlaceholder: false, isHidden: true, isMinimized: false,
            sinkHiddenApps: false, sinkMinimizedWindows: true) == 0)
        #expect(AppCatalogCache.statusPriority(
            hasWindow: true, isPlaceholder: false, isHidden: false, isMinimized: true,
            sinkHiddenApps: false, sinkMinimizedWindows: true) == 1)
        // Hidden sink on, minimized sink off — hidden sinks, minimized stays.
        #expect(AppCatalogCache.statusPriority(
            hasWindow: true, isPlaceholder: false, isHidden: true, isMinimized: false,
            sinkHiddenApps: true, sinkMinimizedWindows: false) == 2)
        #expect(AppCatalogCache.statusPriority(
            hasWindow: true, isPlaceholder: false, isHidden: false, isMinimized: true,
            sinkHiddenApps: true, sinkMinimizedWindows: false) == 0)
    }

    @Test("windowless rows always sink to the end regardless of either preference")
    func windowlessAlwaysSinks() {
        for sinkHidden in [true, false] {
            for sinkMinimized in [true, false] {
                #expect(AppCatalogCache.statusPriority(
                    hasWindow: false, isPlaceholder: false, isHidden: false, isMinimized: false,
                    sinkHiddenApps: sinkHidden, sinkMinimizedWindows: sinkMinimized) == 2)
            }
        }
    }

    @Test("placeholders stay at normal priority even without a window")
    func placeholdersStayNormal() {
        #expect(AppCatalogCache.statusPriority(
            hasWindow: false, isPlaceholder: true, isHidden: false, isMinimized: false,
            sinkHiddenApps: true, sinkMinimizedWindows: true) == 0)
    }

    @Test("a visible, non-minimized app is always priority 0")
    func normalAppStaysAtFront() {
        #expect(AppCatalogCache.statusPriority(
            hasWindow: true, isPlaceholder: false, isHidden: false, isMinimized: false,
            sinkHiddenApps: true, sinkMinimizedWindows: true) == 0)
    }

    /// Both preferences default to `true`, and in that state the rule must be
    /// byte-identical to the pre-#159 unconditional behavior (`hidden -> 2`,
    /// `minimized -> 1`) across the whole input space. Guards the migration
    /// claim that shipping this needs no defaults change.
    @Test("with both sinks on, bucketing matches the historical unconditional rule")
    func defaultsMatchHistoricalRule() {
        for hasWindow in [true, false] {
            for isPlaceholder in [true, false] {
                for isHidden in [true, false] {
                    for isMinimized in [true, false] {
                        let expected: Int
                        if !hasWindow, !isPlaceholder { expected = 2 }
                        else if isHidden { expected = 2 }
                        else if isMinimized { expected = 1 }
                        else { expected = 0 }
                        #expect(AppCatalogCache.statusPriority(
                            hasWindow: hasWindow, isPlaceholder: isPlaceholder,
                            isHidden: isHidden, isMinimized: isMinimized,
                            sinkHiddenApps: true, sinkMinimizedWindows: true) == expected)
                    }
                }
            }
        }
    }
}
