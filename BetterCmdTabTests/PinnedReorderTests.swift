import Testing
@testable import BetterCmdTab

/// The pure array-move behind the pinned-apps drag reorder. `to` is the
/// NSTableView `.above` drop index in pre-removal space, so downward moves shift
/// the destination by one.
@Suite("PinnedReorder")
struct PinnedReorderTests {

    @Test("drop below shifts destination left by one")
    func moveDown() {
        let ids = ["a", "b", "c", "d"]
        // Drag "a" (0) to sit above index 2 (before "c").
        #expect(PinnedReorder.apply(ids, movingRowAt: 0, to: 2) == ["b", "a", "c", "d"])
    }

    @Test("move to bottom")
    func moveToBottom() {
        let ids = ["a", "b", "c"]
        #expect(PinnedReorder.apply(ids, movingRowAt: 0, to: 3) == ["b", "c", "a"])
    }

    @Test("move up to a higher slot")
    func moveUp() {
        let ids = ["a", "b", "c"]
        #expect(PinnedReorder.apply(ids, movingRowAt: 2, to: 0) == ["c", "a", "b"])
    }

    @Test("move to top from the middle")
    func moveToTop() {
        let ids = ["a", "b", "c"]
        #expect(PinnedReorder.apply(ids, movingRowAt: 1, to: 0) == ["b", "a", "c"])
    }

    @Test("drop onto own slot is a no-op")
    func dropOnSelf() {
        let ids = ["a", "b", "c"]
        #expect(PinnedReorder.apply(ids, movingRowAt: 1, to: 1) == ids)
    }

    @Test("drop just below own slot is a no-op")
    func dropBelowSelf() {
        let ids = ["a", "b", "c"]
        // Dropping "b" (1) above index 2 lands it back where it started.
        #expect(PinnedReorder.apply(ids, movingRowAt: 1, to: 2) == ids)
    }

    @Test("out-of-range source index leaves the list unchanged")
    func outOfRange() {
        let ids = ["a"]
        #expect(PinnedReorder.apply(ids, movingRowAt: 5, to: 0) == ids)
    }
}

@Suite("Pinned jump-key validation")
struct JumpKeyAssignmentValidationTests {
    private let assignments = ["chatgpt": "c", "docker": "d"]
    private let reserved: Set<Character> = ["w", "q"]

    @Test("empty input clears the custom key")
    func cleared() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "  ", bundleID: "chatgpt", assignments: assignments,
            reservedLetters: reserved
        ) == .cleared)
    }

    @Test("one ASCII letter is normalized")
    func valid() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: " Z ", bundleID: "chatgpt", assignments: assignments,
            reservedLetters: reserved
        ) == .valid("z"))
    }

    @Test("non-letter and multi-letter input is invalid")
    func invalid() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "12", bundleID: "chatgpt", assignments: assignments,
            reservedLetters: reserved
        ) == .invalid)
    }

    @Test("switcher control letters report a reserved-key rejection")
    func reservedKey() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "W", bundleID: "chatgpt", assignments: assignments,
            reservedLetters: reserved
        ) == .reserved("w"))
    }

    @Test("a key owned by another app reports a duplicate")
    func duplicate() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "D", bundleID: "chatgpt", assignments: assignments,
            reservedLetters: reserved
        ) == .duplicate("d"))
    }

    @Test("an app may keep its own existing key")
    func ownKey() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "C", bundleID: "chatgpt", assignments: assignments,
            reservedLetters: reserved
        ) == .valid("c"))
    }
}
