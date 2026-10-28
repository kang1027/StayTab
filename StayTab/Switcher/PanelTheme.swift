import Foundation

/// An area of the switcher a theme can restyle: the panel's own backdrop, or one
/// of the two roster section plates.
enum ThemeArea: String, CaseIterable, Sendable {
    case panel
    case always
    case running

    var displayName: String {
        switch self {
        case .panel: return String(localized: "Background")
        case .always: return String(localized: "Always")
        case .running: return String(localized: "Running now")
        }
    }
}

/// What fills a themed area. `.standard` is the shipped look, untouched.
enum ThemeBackdrop: String, CaseIterable, Sendable {
    case standard
    case color
    case image

    var displayName: String {
        switch self {
        case .standard: return String(localized: "Default")
        case .color: return String(localized: "Color")
        case .image: return String(localized: "Image")
        }
    }
}

/// Where the jump letters, list selection and the default Always plate take
/// their color from.
enum ThemeAccent: String, CaseIterable, Sendable {
    case system
    case background

    var displayName: String {
        switch self {
        case .system: return String(localized: "macOS Accent")
        case .background: return String(localized: "Match Background")
        }
    }
}

/// One area's theme. Stored as `[String: String]` like `ShortcutOverride`, so the
/// generic settings export carries it untouched and keys a newer build adds
/// survive a round trip through this one (`passthrough`).
struct AreaTheme: Equatable, Sendable {
    static let tintRange: ClosedRange<Double> = 0...0.6
    static let borderRange: ClosedRange<Double> = 0...1
    static let zoomRange: ClosedRange<Double> = 1...3
    static let blurRange: ClosedRange<Double> = 0...8
    static let strengthRange: ClosedRange<Double> = 0.2...1
    static let scrimRange: ClosedRange<Double> = 0...0.6
    static let titleMaxLength = 32
    static let noSymbol = "none"

    var showsTitle: Bool { title.map { !$0.isEmpty } ?? true }
    var showsIcon: Bool { symbol != Self.noSymbol }

    var backdrop: ThemeBackdrop = .standard
    /// OKLCH hue in degrees, `0..<360`.
    var hue: Double = 200
    /// Panel: tint over the backdrop. Sections: fill strength.
    var tint: Double = 0.18
    /// Section outline strength; unused by the panel.
    var border: Double = 0.35
    /// Picture focus in unit image coordinates, origin top-left.
    var focusX: Double = 0.5
    var focusY: Double = 0.5
    var zoom: Double = 1
    /// Blur baked into the stored picture, in points.
    var blur: Double = 4
    var strength: Double = 0.85
    /// Recolor the picture into one hue instead of keeping its own colors.
    var tone: Bool = false
    /// Extra veil behind the text, on top of the panel's standard dim.
    var scrim: Double = 0
    /// Section header text: nil keeps the standard name, empty hides it.
    var title: String?
    /// SF Symbol for the section header: empty keeps the standard one,
    /// `noSymbol` hides it.
    var symbol = ""
    var passthrough: [String: String] = [:]

    static func defaults(for area: ThemeArea) -> AreaTheme {
        var theme = AreaTheme()
        switch area {
        case .panel:
            break
        case .always:
            theme.hue = 255
            theme.tint = 0.24
            theme.strength = 0.6
        case .running:
            theme.hue = 150
            theme.tint = 0.24
            theme.strength = 0.6
        }
        return theme
    }

    static let knownKeys: Set<String> = [
        "backdrop", "hue", "tint", "border", "focusX", "focusY",
        "zoom", "blur", "strength", "tone", "scrim", "title", "symbol",
    ]

    var dictionary: [String: String] {
        var d = passthrough
        d["backdrop"] = backdrop.rawValue
        d["hue"] = Self.format(hue)
        d["tint"] = Self.format(tint)
        d["border"] = Self.format(border)
        d["focusX"] = Self.format(focusX)
        d["focusY"] = Self.format(focusY)
        d["zoom"] = Self.format(zoom)
        d["blur"] = Self.format(blur)
        d["strength"] = Self.format(strength)
        d["tone"] = tone ? "true" : "false"
        d["scrim"] = Self.format(scrim)
        if let title { d["title"] = title }
        if !symbol.isEmpty { d["symbol"] = symbol }
        return d
    }

    init() {}

    /// Missing or unparsable fields keep the area's defaults; numbers are clamped.
    init(dictionary: [String: String], area: ThemeArea) {
        self = .defaults(for: area)
        let number = { (key: String) in dictionary[key].flatMap(Double.init).flatMap { $0.isFinite ? $0 : nil } }
        if let value = dictionary["backdrop"].flatMap(ThemeBackdrop.init(rawValue:)) { backdrop = value }
        if let value = number("hue") { hue = Self.normalizedHue(value) }
        if let value = number("tint") { tint = value.clamped(to: Self.tintRange) }
        if let value = number("border") { border = value.clamped(to: Self.borderRange) }
        if let value = number("focusX") { focusX = value.clamped(to: 0...1) }
        if let value = number("focusY") { focusY = value.clamped(to: 0...1) }
        if let value = number("zoom") { zoom = value.clamped(to: Self.zoomRange) }
        if let value = number("blur") { blur = value.clamped(to: Self.blurRange) }
        if let value = number("strength") { strength = value.clamped(to: Self.strengthRange) }
        if let value = dictionary["tone"] { tone = value == "true" }
        if let value = number("scrim") { scrim = value.clamped(to: Self.scrimRange) }
        if let value = dictionary["title"] { title = Self.cleanTitle(value) }
        if let value = dictionary["symbol"], !value.contains("/") { symbol = value }
        passthrough = dictionary.filter { !Self.knownKeys.contains($0.key) }
    }

    /// One line, trimmed, at most `titleMaxLength` characters.
    static func cleanTitle(_ value: String) -> String {
        let line = value.components(separatedBy: .newlines).joined(separator: " ")
        return String(line.trimmingCharacters(in: .whitespaces).prefix(titleMaxLength))
    }

    static func normalizedHue(_ value: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    /// Three decimals, no trailing zeros, always a `.` separator — the stored
    /// form must not depend on the user's locale.
    static func format(_ value: Double) -> String {
        let rounded = (value * 1000).rounded() / 1000
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(rounded)
    }
}

/// The whole switcher theme: one `AreaTheme` per area plus the accent source.
struct PanelTheme: Equatable, Sendable {
    var panel = AreaTheme.defaults(for: .panel)
    var always = AreaTheme.defaults(for: .always)
    var running = AreaTheme.defaults(for: .running)
    var accent: ThemeAccent = .system

    static let standard = PanelTheme()

    subscript(area area: ThemeArea) -> AreaTheme {
        get {
            switch area {
            case .panel: return panel
            case .always: return always
            case .running: return running
            }
        }
        set {
            switch area {
            case .panel: panel = newValue
            case .always: always = newValue
            case .running: running = newValue
            }
        }
    }

    /// Whether any area draws a picture.
    var usesImages: Bool {
        ThemeArea.allCases.contains { self[area: $0].backdrop == .image }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(range.upperBound, max(range.lowerBound, self))
    }
}
