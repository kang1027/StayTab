import Foundation

/// One screen of the first-run walkthrough.
enum OnboardingStep: Int, CaseIterable {
    case accessibility
    case pinApps
    case tryIt

    /// The screens to walk through. Once Accessibility is already granted the
    /// permission screen has nothing to ask, so the walkthrough starts at the
    /// pin picker.
    static func sequence(accessibilityTrusted: Bool) -> [OnboardingStep] {
        accessibilityTrusted ? [.pinApps, .tryIt] : allCases
    }
}

/// Pure decisions behind the first-run walkthrough, kept out of the window so
/// they can be tested without a live WindowServer.
enum OnboardingPolicy {

    struct AppCandidate: Equatable {
        let bundleID: String
        let name: String
    }

    /// The walkthrough is for fresh installs. A Mac that already trusts StayTab
    /// and has pinned apps is an existing setup (an upgrade), so it never sees
    /// it — and is marked done so removing every pin later doesn't trigger it.
    static func shouldShow(completed: Bool, accessibilityTrusted: Bool, pinnedCount: Int) -> Bool {
        guard !completed else { return false }
        return !(accessibilityTrusted && pinnedCount > 0)
    }

    /// Running apps worth offering as first pins: not StayTab itself, not
    /// already pinned, one entry per bundle, alphabetical, capped so the picker
    /// stays one screen.
    static func pinCandidates(
        from running: [AppCandidate],
        excluding bundleIDs: Set<String>,
        limit: Int
    ) -> [AppCandidate] {
        var seen = bundleIDs
        let unique = running.filter { !$0.name.isEmpty && seen.insert($0.bundleID).inserted }
        let sorted = unique.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return Array(sorted.prefix(max(limit, 0)))
    }

    /// Append `selected` to the existing pins, keeping the existing order and
    /// never duplicating a bundle.
    static func pins(adding selected: [String], to existing: [String]) -> [String] {
        var seen = Set(existing)
        return existing + selected.filter { seen.insert($0).inserted }
    }
}
