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

    @Test("later collisions expand along the app-name prefix")
    func collisionViaAppName() {
        let labels = RowLabels.labels(forInputs: [
            input("Slack"),
            input("Safari")
        ])
        #expect(labels == ["s", "sa"])
    }

    @Test("window titles do not change app-prefix labels")
    func collisionIgnoresWindowTitle() {
        let labels = RowLabels.labels(forInputs: [
            input("Safari", "GitHub"),
            input("Slack")
        ])
        #expect(labels == ["s", "sl"])
    }

    @Test("a reserved first character expands to an app-name prefix")
    func reservedFirstExpands() {
        let labels = RowLabels.labels(forInputs: [
            input("Mail"),
            input("Word")
        ])
        #expect(labels == ["ma", "wo"])
    }

    @Test("Figma becomes FI when F is reserved")
    func fReservedExpands() {
        let labels = RowLabels.labels(forInputs: [
            input("Figma"),
            input("Notes")
        ])
        #expect(labels == ["fi", "n"])
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

    @Test("automatic prefixes accept digits and ignore punctuation")
    func digitsAndPunctuation() {
        let labels = RowLabels.labels(forInputs: [
            input("123 456"),
            input("---")
        ])
        #expect(labels == ["1", ""])
    }

    @Test("only the final prefix character must be free")
    func finalCharacterMustBeFree() {
        let labels = RowLabels.labels(forInputs: [
            input("Smhw"),
            input("Sxy")
        ])
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
        #expect(labels == ["d", "di"])
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

    @Test("imported full-prefix pairs remain usable")
    func importedPrefixPairRemainsCustom() {
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
        #expect(labels == ["m", "mu"])
    }

    @Test("invalid and action-reserved custom letters fall back to automatic hints")
    func invalidCustomLettersFallBack() {
        let labels = RowLabels.labels(
            forInputs: [
                input("ChatGPT", bundleID: "com.openai.chat"),
                input("Docker", bundleID: "com.docker.desktop"),
            ],
            customLetters: [
                "com.openai.chat": "1234",
                "com.docker.desktop": "q",
            ]
        )
        #expect(labels == ["c", "d"])
    }

    @Test("automatic labels use the shortest free prefix up to three characters")
    func shortestFreePrefix() {
        let labels = RowLabels.labels(
            forInputs: [
                input("Slack"),
                input("Session", bundleID: "com.example.session"),
                input("Settings"),
                input("Kakao"),
                input("Figma"),
            ],
            customLetters: ["com.example.session": "se"]
        )
        #expect(labels == ["s", "se", "set", "k", "fi"])
    }

    @Test("automatic label is empty when all three prefixes are occupied")
    func automaticPrefixCeiling() {
        let labels = RowLabels.labels(
            forInputs: [
                input("One", bundleID: "one"),
                input("Two", bundleID: "two"),
                input("Three", bundleID: "three"),
                input("Settings"),
            ],
            customLetters: ["one": "s", "two": "se", "three": "set"],
            reserved: []
        )
        #expect(labels == ["s", "se", "set", ""])
    }
}
