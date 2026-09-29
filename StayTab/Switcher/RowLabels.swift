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

        // Imported config can bypass the settings editor. Exact duplicates are
        // ambiguous, so every owner of one falls back to automatic. Prefix pairs
        // are valid: the shorter sequence commits when the input timer expires,
        // while the longer one commits as soon as its final character arrives.
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

        // Explicit assignments reserve their complete sequences first. Automatic
        // hints then claim the shortest free *name prefix* in row order, up to
        // three characters. This keeps the result predictable and stable for the
        // pinned roster: Kakao -> K; Figma -> FI when F is an action key; and if
        // S then SE are already owned, Settings -> SET. Prefix pairs may coexist,
        // but exact duplicates may not.
        var used = Set(customByIndex.compactMap { $0 })
        for i in 0..<rows.count {
            if let custom = customByIndex[i] {
                labels[i] = custom
                continue
            }
            for candidate in automaticCandidates(rows[i].appName) {
                guard isUsableCustomSequence(candidate, reserved: reserved),
                      !used.contains(candidate) else { continue }
                labels[i] = candidate
                used.insert(candidate)
                break
            }
        }
        return labels
    }

    /// Normalize the settings field and imported config value. A custom direct
    /// jump accepts one to three ASCII letters/digits. Automatic hints use the
    /// same character set and length ceiling.
    /// Action-key conflicts are checked separately against the live `reserved`
    /// set.
    static func normalizedCustomKey(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard (1...3).contains(trimmed.count),
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

    /// One-key custom jumps cannot claim an action key. A multi-key chain may
    /// start with one: the explicit chain then owns that first key while the
    /// switcher is open. Its final key must stay unreserved so the chain can
    /// finish without being consumed by another panel action.
    static func isUsableCustomSequence(_ sequence: String, reserved: Set<Character>) -> Bool {
        guard let first = sequence.first else { return false }
        if sequence.count == 1 { return !reserved.contains(first) }
        guard let last = sequence.last else { return false }
        return !reserved.contains(last)
    }

    /// Exact duplicates are ambiguous. Full-prefix pairs are valid because the
    /// input timeout commits the shorter sequence when no further key arrives.
    static func sequencesConflict(_ lhs: String, _ rhs: String) -> Bool {
        lhs == rhs
    }

    /// First characters of live multi-key custom chains. The input layer uses
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
            guard candidate.sequence.count > 1 else { return nil }
            let conflicts = sequences.contains {
                $0.bundleID != candidate.bundleID
                    && sequencesConflict(candidate.sequence, $0.sequence)
            }
            return conflicts ? nil : candidate.sequence.first
        })
    }

    /// Lower-case ASCII alphanumerics from the app name, preserving order and
    /// dropping punctuation/spaces. Returns each leading prefix up to length 3.
    private static func automaticCandidates(_ raw: String) -> [String] {
        let folded = raw.folding(options: .diacriticInsensitive, locale: nil).lowercased()
        var prefix = ""
        var candidates: [String] = []
        candidates.reserveCapacity(3)
        for character in folded where isDirectJumpCharacter(character) {
            prefix.append(character)
            candidates.append(prefix)
            if candidates.count == 3 { break }
        }
        return candidates
    }
}
