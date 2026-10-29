import Testing
@testable import StayTab

@Suite("Onboarding")
struct OnboardingModelTests {

    @Test("a fresh install without Accessibility walks through every step")
    func fullSequence() {
        #expect(OnboardingStep.sequence(accessibilityTrusted: false) == [.accessibility, .pinApps, .tryIt])
    }

    @Test("an already-trusted Mac skips the permission step")
    func trustedSequence() {
        #expect(OnboardingStep.sequence(accessibilityTrusted: true) == [.pinApps, .tryIt])
    }

    @Test("shows on a fresh install, never after completion")
    func showsOnFreshInstallOnly() {
        #expect(OnboardingPolicy.shouldShow(completed: false, accessibilityTrusted: false, pinnedCount: 0))
        #expect(!OnboardingPolicy.shouldShow(completed: true, accessibilityTrusted: false, pinnedCount: 0))
    }

    @Test("an existing setup (trusted and pinned) is not interrupted")
    func existingSetupSkipped() {
        #expect(!OnboardingPolicy.shouldShow(completed: false, accessibilityTrusted: true, pinnedCount: 3))
        // Trusted but nothing pinned is still worth the pin picker.
        #expect(OnboardingPolicy.shouldShow(completed: false, accessibilityTrusted: true, pinnedCount: 0))
        // Pins imported before the permission grant still need the permission step.
        #expect(OnboardingPolicy.shouldShow(completed: false, accessibilityTrusted: false, pinnedCount: 3))
    }

    @Test("pin candidates drop pinned apps, duplicates and blank names, then sort and cap")
    func candidates() {
        let running = [
            OnboardingPolicy.AppCandidate(bundleID: "c", name: "Slack"),
            OnboardingPolicy.AppCandidate(bundleID: "a", name: "notion"),
            OnboardingPolicy.AppCandidate(bundleID: "a", name: "Notion"),
            OnboardingPolicy.AppCandidate(bundleID: "p", name: "Pinned"),
            OnboardingPolicy.AppCandidate(bundleID: "b", name: "Figma"),
            OnboardingPolicy.AppCandidate(bundleID: "z", name: ""),
        ]
        let result = OnboardingPolicy.pinCandidates(from: running, excluding: ["p"], limit: 2)
        #expect(result.map(\.bundleID) == ["b", "a"])
    }

    @Test("a zero or negative limit yields no candidates")
    func zeroLimit() {
        let running = [OnboardingPolicy.AppCandidate(bundleID: "a", name: "Notion")]
        #expect(OnboardingPolicy.pinCandidates(from: running, excluding: [], limit: 0).isEmpty)
        #expect(OnboardingPolicy.pinCandidates(from: running, excluding: [], limit: -3).isEmpty)
    }

    @Test("new pins append after the existing order without duplicating")
    func appendsPins() {
        #expect(OnboardingPolicy.pins(adding: ["b", "a", "c"], to: ["a", "x"]) == ["a", "x", "b", "c"])
        #expect(OnboardingPolicy.pins(adding: [], to: ["a"]) == ["a"])
    }
}
