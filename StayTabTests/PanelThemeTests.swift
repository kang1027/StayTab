import AppKit
import Foundation
import Testing
@testable import StayTab

/// The Theme tab's model and math: storage form, picture placement, colors and
/// the contrast estimate the editor shows.
@Suite("Panel theme")
struct PanelThemeTests {

    // MARK: - Storage

    @Test("an area survives its dictionary round trip, unknown keys included")
    func dictionaryRoundTrip() {
        var theme = AreaTheme.defaults(for: .always)
        theme.backdrop = .image
        theme.hue = 42
        theme.tint = 0.3
        theme.border = 0.5
        theme.focusX = 0.25
        theme.focusY = 0.75
        theme.zoom = 1.5
        theme.blur = 2.5
        theme.strength = 0.7
        theme.tone = true
        theme.scrim = 0.12
        theme.title = "Daily"
        theme.symbol = "star.fill"
        theme.passthrough = ["futureKey": "x"]
        #expect(AreaTheme(dictionary: theme.dictionary, area: .always) == theme)
    }

    @Test("decoding clamps numbers, wraps hue and keeps defaults for junk")
    func decodeClamps() {
        let theme = AreaTheme(dictionary: [
            "backdrop": "neon", "hue": "-30", "tint": "9", "zoom": "0.2",
            "blur": "nan", "strength": "0", "scrim": "-1",
        ], area: .panel)
        let defaults = AreaTheme.defaults(for: .panel)
        #expect(theme.backdrop == .standard)
        #expect(theme.hue == 330)
        #expect(theme.tint == AreaTheme.tintRange.upperBound)
        #expect(theme.zoom == 1)
        #expect(theme.blur == defaults.blur)
        #expect(theme.strength == AreaTheme.strengthRange.lowerBound)
        #expect(theme.scrim == 0)
        #expect(theme.passthrough.isEmpty)
    }

    @Test("a section title is one trimmed line of bounded length")
    func titleCleaning() {
        #expect(AreaTheme.cleanTitle("  Work\nstuff  ") == "Work stuff")
        #expect(AreaTheme.cleanTitle(String(repeating: "x", count: 50)).count == AreaTheme.titleMaxLength)
        let theme = AreaTheme(dictionary: ["title": "  Mine ", "symbol": "../evil"], area: .always)
        #expect(theme.title == "Mine")
        #expect(theme.symbol.isEmpty)
    }

    @Test("stored numbers don't depend on the locale and drop trailing zeros")
    func numberFormat() {
        #expect(AreaTheme.format(200) == "200")
        #expect(AreaTheme.format(0.18) == "0.18")
        #expect(AreaTheme.format(0.12345) == "0.123")
    }

    @Test("an untouched theme stores nothing; a changed area stores only itself")
    @MainActor
    func storeOmitsDefaults() throws {
        let suite = "PanelThemeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        Preferences.storePanelTheme(.standard, in: defaults)
        #expect(defaults.object(forKey: Preferences.Keys.themePanel) == nil)
        #expect(defaults.object(forKey: Preferences.Keys.themeAccent) == nil)

        var theme = PanelTheme.standard
        theme.running.backdrop = .color
        theme.running.hue = 20
        theme.accent = .background
        Preferences.storePanelTheme(theme, in: defaults)
        #expect(defaults.object(forKey: Preferences.Keys.themePanel) == nil)
        #expect(defaults.dictionary(forKey: Preferences.Keys.themeRunning) != nil)
        #expect(Preferences.loadPanelTheme(defaults) == theme)
    }

    // MARK: - Picture placement

    @Test("a wide picture in a wide area keeps its full height at zoom 1")
    func cropFillsHeight() {
        let rect = ThemeCrop.visibleRect(imageSize: CGSize(width: 1600, height: 1000),
                                         viewSize: CGSize(width: 300, height: 250),
                                         focus: CGPoint(x: 0.5, y: 0.5), zoom: 1)
        #expect(abs(rect.height - 1) < 0.0001)
        #expect(abs(rect.width - 1200.0 / 1600) < 0.0001)
        #expect(abs(rect.midX - 0.5) < 0.0001)
    }

    @Test("the focus can't push the visible part off the picture")
    func cropClampsFocus() {
        let rect = ThemeCrop.visibleRect(imageSize: CGSize(width: 1000, height: 1000),
                                         viewSize: CGSize(width: 100, height: 100),
                                         focus: CGPoint(x: 1, y: 0), zoom: 2)
        #expect(abs(rect.width - 0.5) < 0.0001)
        #expect(abs(rect.maxX - 1) < 0.0001)
        #expect(abs(rect.minY) < 0.0001)
    }

    @Test("the layer rect flips to a bottom-left origin")
    func layerRectFlips() {
        let rect = ThemeCrop.layerContentsRect(CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.3))
        #expect(abs(rect.minY - 0.5) < 0.0001)
        #expect(abs(rect.minX - 0.1) < 0.0001)
    }

    // MARK: - Colors and contrast

    @Test("zero chroma is a neutral grey and contrast spans 1–21")
    func colorBasics() {
        let grey = ThemeColor.oklch(0.6, 0, 123)
        #expect(abs(grey.r - grey.g) < 0.001 && abs(grey.g - grey.b) < 0.001)
        #expect(abs(ThemeColor.contrastRatio(1, 0) - 21) < 0.001)
        #expect(abs(ThemeColor.contrastRatio(0.3, 0.3) - 1) < 0.001)
    }

    @Test("samples keep the picture's top row first")
    func samplesOrientation() throws {
        let image = try #require(Self.twoBandImage(top: .white, bottom: .black))
        let samples = try #require(ThemeImageSamples(image: image, maxEdge: 8))
        let top = ThemeLegibility.average(samples.pixels(in: CGRect(x: 0, y: 0, width: 1, height: 0.4)))
        let bottom = ThemeLegibility.average(samples.pixels(in: CGRect(x: 0, y: 0.6, width: 1, height: 0.4)))
        #expect(top.r > 0.9)
        #expect(bottom.r < 0.1)
    }

    @Test("a bright opaque picture under light text fails and a boost fixes it")
    func legibilityOfBrightPicture() throws {
        let image = try #require(Self.twoBandImage(top: .white, bottom: .white))
        var theme = PanelTheme.standard
        theme.panel.backdrop = .image
        theme.panel.strength = 1
        let check = ThemeLegibility(theme: theme, desktop: ThemeRGB(r: 0.4, g: 0.4, b: 0.4), dark: true,
                                    samples: [.panel: try #require(ThemeImageSamples(image: image))],
                                    sizes: [.panel: CGSize(width: 600, height: 300)])
        #expect(check.worstContrast(.panel) < ThemeLegibility.target)
        let boost = try #require(check.suggestedScrim(.panel))
        #expect(check.worstContrast(.panel, scrim: boost) >= ThemeLegibility.target)
    }

    @Test("a dark picture prefers light text")
    func picturePrefersDark() {
        #expect(PanelAppearance.picturePrefersDark(meanLightness: 0.3))
        #expect(!PanelAppearance.picturePrefersDark(meanLightness: 0.9))
    }

    /// A 4×4 image whose top half and bottom half are flat colors.
    private static func twoBandImage(top: NSColor, bottom: NSColor) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 16,
                                      space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        // Core Graphics puts y = 0 at the bottom.
        context.setFillColor(bottom.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 2))
        context.setFillColor(top.cgColor)
        context.fill(CGRect(x: 0, y: 2, width: 4, height: 2))
        return context.makeImage()
    }
}
