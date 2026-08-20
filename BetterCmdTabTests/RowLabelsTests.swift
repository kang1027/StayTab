import Testing
@testable import BetterCmdTab

@Suite("RowLabels")
struct RowLabelsTests {

    private func input(
        _ appName: String,
        _ windowTitle: String = "",
        bundleID: String? = nil
    ) -> RowLabels.Input {
        RowLabels.Input(
            appName: appName,
            windowTitle: windowTitle,
            bundleIdentifier: bundleID
        )
    }

    @Test("unique first letters produce single-letter labels")
    func uniqueFirstLetter() {
        let labels = RowLabels.labels(forInputs: [
            input("Safari"),
            input("Terminal"),
            input("Notes")
        ])
        #expect(labels == ["s", "t", "n"])
    }

    @Test("colliding first letters expand to two-letter labels using app name fallback")
    func collisionViaAppName() {
        let labels = RowLabels.labels(forInputs: [
            input("Slack"),
            input("Safari")
        ])
        // Both start with "s" → secondary letter from app name (Slack→l, Safari→a)
        #expect(labels[0].first == "s")
        #expect(labels[1].first == "s")
        #expect(labels[0].count == 2)
        #expect(labels[1].count == 2)
        #expect(labels[0] != labels[1])
    }

    @Test("collision prefers window-title letter when available")
    func collisionPrefersWindowTitle() {
        let labels = RowLabels.labels(forInputs: [
            input("Safari", "GitHub"),
            input("Slack")
        ])
        // "Safari" + window "GitHub" → secondary from "g" (first letter of title)
        #expect(labels[0] == "sg")
    }

    @Test("reserved letters (w m h q) skipped when picking first letter")
    func reservedFirstSkipped() {
        let labels = RowLabels.labels(forInputs: [
            input("Mail"),  // m is reserved → falls through to "a"
            input("Word")   // w is reserved → falls through to "o"
        ])
        #expect(labels == ["a", "o"])
    }

    @Test("f is reserved (⌘F full screen) and never a letter-chain target")
    func fReservedSkipped() {
        let labels = RowLabels.labels(forInputs: [
            input("Figma"),  // f is reserved → falls through to "i"
            input("Notes")   // n
        ])
        #expect(labels == ["i", "n"])
    }

    @Test("diacritics fold to ASCII counterparts")
    func diacriticFolding() {
        // .diacriticInsensitive strips combining marks but not ligatures or
        // strokes. "Café" → "Cafe" (é→e), but "Łódź" keeps Ł, ó, ź. The first
        // ASCII letter wins, so behavior is letter-skip + fold combined.
        let labels = RowLabels.labels(forInputs: [
            input("Café"),       // é folds → c
            input("Naïve")       // ï folds → n
        ])
        #expect(labels == ["c", "n"])
    }

    @Test("name with no usable letters returns empty label")
    func noLetters() {
        let labels = RowLabels.labels(forInputs: [
            input("123 456"),
            input("---")
        ])
        #expect(labels == ["", ""])
    }

    @Test("secondary letter skips reserved chars too")
    func secondaryAvoidsReserved() {
        // Both start with "s"; secondary from "smh" should skip 'm','h' (reserved) → 's' for both
        // Edge case: when secondary candidates all reserved, falls back to single letter.
        let labels = RowLabels.labels(forInputs: [
            input("Smhw"),
            input("Sxy")
        ])
        // First: 's', then 'm','h','w' all reserved → no secondary → "s"
        // Second: 's' available, secondary 'x'
        #expect(labels[0] == "s")
        #expect(labels[1] == "sx")
    }

    @Test("empty input array returns empty array")
    func empty() {
        let labels = RowLabels.labels(forInputs: [])
        #expect(labels.isEmpty)
    }

    @Test("custom app letters override automatic hints")
    func customLettersOverrideAutomaticHints() {
        let labels = RowLabels.labels(
            forInputs: [
                input("ChatGPT", bundleID: "com.openai.chat"),
                input("Docker Desktop", bundleID: "com.docker.desktop"),
            ],
            customLetters: [
                "com.openai.chat": "C",
                "com.docker.desktop": "d",
            ]
        )
        #expect(labels == ["c", "d"])
    }

    @Test("automatic hints do not steal a custom letter")
    func automaticHintsSkipCustomLetters() {
        let labels = RowLabels.labels(
            forInputs: [
                input("ChatGPT", bundleID: "com.openai.chat"),
                input("Discord", bundleID: "com.discord"),
            ],
            customLetters: ["com.openai.chat": "d"]
        )
        #expect(labels == ["d", "i"])
    }

    @Test("custom digits override automatic letter hints")
    func customDigitsOverrideAutomaticHints() {
        let labels = RowLabels.labels(
            forInputs: [
                input("ChatGPT", bundleID: "com.openai.chat"),
                input("Docker", bundleID: "com.docker.desktop"),
            ],
            customLetters: ["com.openai.chat": "7"]
        )
        #expect(labels == ["7", "d"])
    }

    @Test("a reserved digit falls back to an automatic hint")
    func reservedCustomDigitFallsBack() {
        let labels = RowLabels.labels(
            forInputs: [input("ChatGPT", bundleID: "com.openai.chat")],
            customLetters: ["com.openai.chat": "7"],
            reserved: ["7"]
        )
        #expect(labels == ["c"])
    }

    @Test("two-key chains with a shared start stay distinct")
    func sharedCustomPrefix() {
        let labels = RowLabels.labels(
            forInputs: [
                input("Mail", bundleID: "com.apple.mail"),
                input("Music", bundleID: "com.apple.Music"),
            ],
            customLetters: [
                "com.apple.mail": "MA",
                "com.apple.Music": "mu",
            ]
        )
        #expect(labels == ["ma", "mu"])
    }

    @Test("a two-key chain may own a reserved first character")
    func reservedCustomPrefix() {
        let labels = RowLabels.labels(
            forInputs: [input("Mail", bundleID: "com.apple.mail")],
            customLetters: ["com.apple.mail": "ma"],
            reserved: ["m"]
        )
        #expect(labels == ["ma"])
    }

    @Test("live two-key chains expose their shared first character")
    func customChainPrefixSnapshot() {
        let prefixes = RowLabels.customChainPrefixes(
            customLetters: [
                "com.apple.mail": "MA",
                "com.apple.Music": "mu",
                "com.example.unpinned": "z1",
            ],
            allowedBundleIDs: ["com.apple.mail", "com.apple.Music"],
            reserved: ["m"]
        )
        #expect(prefixes == ["m"])
    }

    @Test("imported full-prefix conflicts fall back to automatic hints")
    func importedPrefixConflictFallsBack() {
        let labels = RowLabels.labels(
            forInputs: [
                input("Mail", bundleID: "com.apple.mail"),
                input("Music", bundleID: "com.apple.Music"),
            ],
            customLetters: [
                "com.apple.mail": "m",
                "com.apple.Music": "mu",
            ],
            reserved: []
        )
        #expect(labels == ["ma", "mu"])
    }

    @Test("invalid and action-reserved custom letters fall back to automatic hints")
    func invalidCustomLettersFallBack() {
        let labels = RowLabels.labels(
            forInputs: [
                input("ChatGPT", bundleID: "com.openai.chat"),
                input("Docker", bundleID: "com.docker.desktop"),
            ],
            customLetters: [
                "com.openai.chat": "123",
                "com.docker.desktop": "q",
            ]
        )
        #expect(labels == ["c", "d"])
    }
}
