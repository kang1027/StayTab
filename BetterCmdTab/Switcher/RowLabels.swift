import Foundation
import os

enum RowLabels {
    /// Letters reserved for in-panel action keys (close/minimize/hide/quit) plus
    /// the fixed ⌘F full-screen key — never assigned as letter-chain hints, so a
    /// hint is always reachable by typing it. Driven by the user's actual in-panel
    /// key bindings: `SwitcherController.pushPanelKeyBindings` recomputes it on
    /// launch and on every shortcut change (via `HotkeyTap.onReservedLettersChanged`),
    /// so rebinding an action frees its old letter back into the hint pool and
    /// reserves the new one. Defaults mirror the shipped bindings (w/m/h/q) + f
    /// until the first push. Lock-guarded: written on main, read during label
    /// generation which can run off-main.
    private static let reservedStore = OSAllocatedUnfairLock<Set<Character>>(
        initialState: ["w", "m", "h", "q", "f"]
    )
    static var reserved: Set<Character> { reservedStore.withLock { $0 } }
    static func setReserved(_ letters: Set<Character>) {
        reservedStore.withLock { $0 = letters }
    }

    /// Snapshot of the persisted app overrides. Kept beside the dynamic action
    /// keys so label generation never deserializes UserDefaults on the ⌘Tab
    /// hot path. `SwitcherController` updates it at launch and on preference
    /// changes.
    private static let customLettersStore = OSAllocatedUnfairLock<[String: String]>(initialState: [:])
    static func setCustomLetters(_ letters: [String: String]) {
        customLettersStore.withLock { $0 = letters }
    }

    /// Full a–z pool for disambiguation suffixes; reserved letters are filtered
    /// out at the point of use so the pool tracks the dynamic reservation.
    static let suffixAlphabet: [Character] = Array("abcdefghijklmnopqrstuvwxyz")

    struct Input {
        let appName: String
        let windowTitle: String
        let bundleIdentifier: String?

        init(appName: String, windowTitle: String, bundleIdentifier: String? = nil) {
            self.appName = appName
            self.windowTitle = windowTitle
            self.bundleIdentifier = bundleIdentifier
        }
    }

    static func labels(for rows: [SwitcherRow], customLetters: [String: String]? = nil) -> [String] {
        let resolvedCustomLetters = customLetters
            ?? customLettersStore.withLock { $0 }
        return labels(
            forInputs: rows.map {
                Input(
                    appName: $0.appName,
                    windowTitle: $0.windowTitle,
                    bundleIdentifier: $0.bundleIdentifier
                )
            },
            customLetters: resolvedCustomLetters
        )
    }

    static func labels(
        forInputs rows: [Input],
        customLetters: [String: String] = [:],
        reserved overrideReserved: Set<Character>? = nil
    ) -> [String] {
        var labels = [String](repeating: "", count: rows.count)
        guard !rows.isEmpty else { return labels }

        // Snapshot the reserved set once per call (one lock acquisition) and thread
        // it through the per-character loops below.
        let reserved = overrideReserved ?? Self.reserved

        let preliminaryCustom: [String?] = rows.map { row in
            guard let bundleID = row.bundleIdentifier,
                  let raw = customLetters[bundleID],
                  let sequence = normalizedCustomKey(raw),
                  isUsableCustomSequence(sequence, reserved: reserved) else { return nil }
            return sequence
        }

        // Imported config can bypass the settings editor. Drop every exact or
        // prefix-conflicting sequence ("m" vs "ma") back to automatic so no
        // displayed hint becomes impossible to commit. Shared prefixes of equal
        // length ("ma" / "mu") are valid and handled by the letter buffer.
        var conflictingCustomIndices = Set<Int>()
        for i in preliminaryCustom.indices {
            guard let lhs = preliminaryCustom[i] else { continue }
            for j in preliminaryCustom.indices where j > i {
                guard let rhs = preliminaryCustom[j] else { continue }
                if sequencesConflict(lhs, rhs) {
                    conflictingCustomIndices.insert(i)
                    conflictingCustomIndices.insert(j)
                }
            }
        }
        let customByIndex = preliminaryCustom.enumerated().map {
            conflictingCustomIndices.contains($0.offset) ? nil : $0.element
        }

        // A user-assigned sequence owns its first character. Automatic hints
        // skip that character so an unrelated single-key hint cannot become an
        // uncommittable prefix of a custom two-key chain.
        let customPrefixes = customByIndex.compactMap { $0?.first }
        let automaticReserved = reserved.union(customPrefixes)

        var firstLetterCount: [Character: Int] = [:]
        var firstLetters = [Character?](repeating: nil, count: rows.count)
        for i in 0..<rows.count {
            guard customByIndex[i] == nil else { continue }
            let c = firstAvailableLetter(rows[i].appName, reserved: automaticReserved)
            firstLetters[i] = c
            if let c { firstLetterCount[c, default: 0] += 1 }
        }

        for i in 0..<rows.count {
            if let custom = customByIndex[i] {
                labels[i] = custom
                continue
            }
            guard let first = firstLetters[i] else {
                labels[i] = ""
                continue
            }
            if (firstLetterCount[first] ?? 0) == 1 {
                labels[i] = String(first)
            } else if let secondary = secondaryLetter(rows[i], skipping: first, reserved: reserved) {
                labels[i] = String(first) + String(secondary)
            } else {
                labels[i] = String(first)
            }
        }

        disambiguateDuplicates(&labels, reserved: reserved)
        return labels
    }

    /// Normalize the settings field and imported config value. A custom direct
    /// jump accepts one or two ASCII letters/digits; automatic hints remain
    /// letters.
    /// Action-key conflicts are checked separately against the live `reserved`
    /// set.
    static func normalizedCustomKey(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard (1...2).contains(trimmed.count),
              trimmed.allSatisfy(isDirectJumpCharacter) else { return nil }
        return trimmed
    }

    /// Allocation-free character gate shared with the keyboard-event hot path.
    static func isDirectJumpCharacter(_ character: Character) -> Bool {
        guard let ascii = character.asciiValue else { return false }
        return (ascii >= 0x61 && ascii <= 0x7A)
            || (ascii >= 0x41 && ascii <= 0x5A)
            || (ascii >= 0x30 && ascii <= 0x39)
    }

    /// One-key custom jumps cannot claim an action key. A two-key chain may
    /// start with one: the explicit chain then owns that first key while the
    /// switcher is open. Its second key must stay unreserved so the chain can
    /// finish without being consumed by another panel action.
    static func isUsableCustomSequence(_ sequence: String, reserved: Set<Character>) -> Bool {
        guard let first = sequence.first else { return false }
        if sequence.count == 1 { return !reserved.contains(first) }
        guard let last = sequence.last else { return false }
        return !reserved.contains(last)
    }

    /// Exact duplicates and full-prefix pairs are ambiguous; equal-length
    /// sequences with only a shared start ("ma" / "mu") are not.
    static func sequencesConflict(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs || lhs.hasPrefix(rhs) || rhs.hasPrefix(lhs)
    }

    /// First characters of live two-key custom chains. The input layer uses
    /// this cold-path snapshot to let an explicit chain beat an action bound to
    /// the same first key (for example MA/MU over the default Minimize key M).
    static func customChainPrefixes(
        customLetters: [String: String],
        allowedBundleIDs: Set<String>,
        reserved: Set<Character>
    ) -> Set<Character> {
        let sequences: [(bundleID: String, sequence: String)] = customLetters.compactMap { bundleID, raw in
            guard allowedBundleIDs.contains(bundleID),
                  let sequence = normalizedCustomKey(raw),
                  isUsableCustomSequence(sequence, reserved: reserved) else { return nil }
            return (bundleID, sequence)
        }
        return Set(sequences.compactMap { candidate in
            guard candidate.sequence.count == 2 else { return nil }
            let conflicts = sequences.contains {
                $0.bundleID != candidate.bundleID
                    && sequencesConflict(candidate.sequence, $0.sequence)
            }
            return conflicts ? nil : candidate.sequence.first
        })
    }

    private static func disambiguateDuplicates(_ labels: inout [String], reserved: Set<Character>) {
        var groups: [String: [Int]] = [:]
        for (i, l) in labels.enumerated() where !l.isEmpty {
            groups[l, default: []].append(i)
        }
        for (base, indices) in groups where indices.count > 1 {
            let groupSet = Set(indices)
            var used = Set<String>()
            for (j, l) in labels.enumerated() {
                if groupSet.contains(j) { continue }
                if !l.isEmpty { used.insert(l) }
            }
            for idx in indices {
                for suffix in suffixAlphabet where !reserved.contains(suffix) {
                    let candidate = base + String(suffix)
                    if !used.contains(candidate) {
                        labels[idx] = candidate
                        used.insert(candidate)
                        break
                    }
                }
            }
        }
    }

    private static func firstAvailableLetter(_ raw: String, reserved: Set<Character>) -> Character? {
        let folded = raw.folding(options: .diacriticInsensitive, locale: nil).lowercased()
        for c in folded {
            if c.isASCII, c.isLetter, !reserved.contains(c) { return c }
        }
        return nil
    }

    private static func secondaryLetter(_ row: Input, skipping first: Character, reserved: Set<Character>) -> Character? {
        if !row.windowTitle.isEmpty {
            let folded = row.windowTitle.folding(options: .diacriticInsensitive, locale: nil).lowercased()
            for c in folded {
                if c.isASCII, c.isLetter, c != first, !reserved.contains(c) { return c }
            }
        }
        let appFolded = row.appName.folding(options: .diacriticInsensitive, locale: nil).lowercased()
        var seenFirst = false
        for c in appFolded {
            if c.isASCII, c.isLetter, !reserved.contains(c) {
                if !seenFirst { seenFirst = true; continue }
                if c != first { return c }
            }
        }
        return nil
    }
}
