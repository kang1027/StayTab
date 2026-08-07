import Testing
@testable import BetterCmdTab

/// The "Show status icons" preference (#149) hides exactly the window-state
/// glyphs — the audio, Launch and Reopen cues are never suppressed.
@Suite("Switcher indicators")
struct SwitcherIndicatorTests {

    @Test("only the window-state glyphs are hidden by the status-icon preference")
    func windowStateClassification() {
        #expect(SwitcherIndicator.allCases.filter(\.isWindowState) == [.hidden, .minimized, .noWindow, .fullscreen])
        #expect(SwitcherIndicator.allCases.filter { !$0.isWindowState } == [.audio, .launch, .reopen])
    }
}
