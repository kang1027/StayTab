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

    @Test("one ASCII digit is accepted")
    func validDigit() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: " 7 ", bundleID: "chatgpt", assignments: assignments,
            reservedLetters: reserved
        ) == .valid("7"))
    }

    @Test("three characters are accepted and four are invalid")
    func invalid() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "123", bundleID: "chatgpt", assignments: assignments,
            reservedLetters: reserved
        ) == .valid("123"))
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "1234", bundleID: "chatgpt", assignments: assignments,
            reservedLetters: reserved
        ) == .invalid)
    }

    @Test("two-key chains may share their first character")
    func sharedPrefixChains() {
        let existing = ["mail": "ma"]
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "MU", bundleID: "music", assignments: existing,
            reservedLetters: ["m"]
        ) == .valid("mu"))
    }

    @Test("a two-key chain may start with a switcher control key")
    func actionKeyPrefix() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "MA", bundleID: "mail", assignments: [:],
            reservedLetters: ["m"]
        ) == .valid("ma"))
    }

    @Test("a two-key chain cannot end with a switcher control key")
    func actionKeySuffix() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "MQ", bundleID: "mail", assignments: [:],
            reservedLetters: ["q"]
        ) == .reserved("q"))
    }

    @Test("switcher control letters report a reserved-key rejection")
    func reservedKey() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "W", bundleID: "chatgpt", assignments: assignments,
            reservedLetters: reserved
        ) == .reserved("w"))
    }

    @Test("a key owned by another app reports a conflict")
    func conflict() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "D", bundleID: "chatgpt", assignments: assignments,
            reservedLetters: reserved
        ) == .conflict("d"))
    }

    @Test("a shorter key may prefix a longer key")
    func prefixPair() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "C7", bundleID: "docker", assignments: assignments,
            reservedLetters: reserved
        ) == .valid("c7"))
    }

    @Test("an unusable imported assignment does not block a valid chain")
    func invalidImportedAssignmentDoesNotConflict() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "MA", bundleID: "mail", assignments: ["legacy": "m"],
            reservedLetters: ["m"]
        ) == .valid("ma"))
    }

    @Test("an app may keep its own existing key")
    func ownKey() {
        #expect(JumpKeyAssignmentValidation.evaluate(
            rawValue: "C", bundleID: "chatgpt", assignments: assignments,
            reservedLetters: reserved
        ) == .valid("c"))
    }
}
