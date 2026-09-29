import CoreGraphics
import Testing
@testable import StayTab

/// Pure-logic coverage for the hold-modifier release decision. The timer +
/// `CGEventSource` read are impure and exercised manually; the transition logic
/// that decides "commit now" is isolated here so it stays testable.
@Suite("Hold modifier monitor")
struct HoldModifierMonitorTests {
    @Test func modifierReleased_onlyOnHeldToReleased() {
        #expect(HoldModifierMonitor.modifierReleased(previous: true, current: false))
        #expect(!HoldModifierMonitor.modifierReleased(previous: false, current: true))  // press
        #expect(!HoldModifierMonitor.modifierReleased(previous: true, current: true))   // still held
        #expect(!HoldModifierMonitor.modifierReleased(previous: false, current: false)) // still up
    }

    @Test func holdState_matchesMask() {
        #expect(HoldModifierMonitor.holdState(flags: [.maskCommand], mask: .maskCommand))
        #expect(!HoldModifierMonitor.holdState(flags: [.maskAlternate], mask: .maskCommand))
        #expect(HoldModifierMonitor.holdState(flags: [.maskAlternate], mask: .maskAlternate))
        // The hold modifier is considered down even with extra modifiers present.
        #expect(HoldModifierMonitor.holdState(flags: [.maskCommand, .maskShift], mask: .maskCommand))
        #expect(!HoldModifierMonitor.holdState(flags: [], mask: .maskCommand))
    }
}
