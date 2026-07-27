import Testing
@testable import BetterCmdTab

/// A display's desktop Space and the full-screen Spaces created from it are one
/// "place" for the Visible Spaces scope: going full screen must not hide the
/// desktop's windows from the switcher, and a full-screen window must not
/// disappear while its desktop is focused.
@Suite("Space grouping")
struct SpaceGroupTests {
    /// [Desktop 1, full-screen] — the shape WindowServer reports for one
    /// full-screen app on a single-desktop display.
    private let oneDesktopWithFullscreen: [(id: UInt64, isDesktop: Bool)] = [(1, true), (87, false)]

    @Test("full-screen Space groups with the desktop it was created from")
    func fullscreenGroupsWithItsDesktop() {
        #expect(PrivateAPI.spaceGroup(containing: 87, orderedSpaces: oneDesktopWithFullscreen) == [1, 87])
        #expect(PrivateAPI.spaceGroup(containing: 1, orderedSpaces: oneDesktopWithFullscreen) == [1, 87])
    }

    @Test("another desktop's Spaces stay out of the group")
    func otherDesktopsExcluded() {
        // [Desktop 1, full screen from it, Desktop 2, full screen from Desktop 2]
        let spaces: [(id: UInt64, isDesktop: Bool)] = [(1, true), (87, false), (2, true), (88, false)]
        #expect(PrivateAPI.spaceGroup(containing: 1, orderedSpaces: spaces) == [1, 87])
        #expect(PrivateAPI.spaceGroup(containing: 87, orderedSpaces: spaces) == [1, 87])
        #expect(PrivateAPI.spaceGroup(containing: 2, orderedSpaces: spaces) == [2, 88])
        #expect(PrivateAPI.spaceGroup(containing: 88, orderedSpaces: spaces) == [2, 88])
    }

    @Test("unknown or missing Space list falls back to the Space itself")
    func fallsBackToCurrent() {
        #expect(PrivateAPI.spaceGroup(containing: 5, orderedSpaces: []) == [5])
        #expect(PrivateAPI.spaceGroup(containing: 5, orderedSpaces: oneDesktopWithFullscreen) == [5])
    }
}
