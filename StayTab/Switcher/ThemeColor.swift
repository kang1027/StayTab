import AppKit

/// Plain sRGB color, components `0...1`. Theme math works on these instead of
/// `NSColor` so it stays pure and testable off the main actor.
struct ThemeRGB: Equatable, Sendable {
    var r: Double
    var g: Double
    var b: Double

    static let black = ThemeRGB(r: 0, g: 0, b: 0)
    static let white = ThemeRGB(r: 1, g: 1, b: 1)

    func mixed(with other: ThemeRGB, _ t: Double) -> ThemeRGB {
        ThemeRGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    /// WCAG 2 relative luminance.
    var relativeLuminance: Double {
        0.2126 * Self.linear(r) + 0.7152 * Self.linear(g) + 0.0722 * Self.linear(b)
    }

    /// OKLab lightness `L`, the perceptual axis the theme hues are built on.
    var oklabLightness: Double {
        let lr = Self.linear(r), lg = Self.linear(g), lb = Self.linear(b)
        let l = cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
        let m = cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
        let s = cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
        return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    }

    func nsColor(alpha: Double = 1) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
    }

    static func linear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    static func encoded(_ c: Double) -> Double {
        let x = c.clamped(to: 0...1)
        return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
    }
}

/// The handful of colors a theme derives from one hue. Everything goes through
/// OKLCH so turning the hue never makes a color jump in brightness.
enum ThemeColor {
    static func oklch(_ lightness: Double, _ chroma: Double, _ hueDegrees: Double) -> ThemeRGB {
        let h = hueDegrees * .pi / 180
        let a = chroma * cos(h), b = chroma * sin(h)
        let l = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)
        return ThemeRGB(
            r: ThemeRGB.encoded(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
            g: ThemeRGB.encoded(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
            b: ThemeRGB.encoded(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
        )
    }

    /// Fill and tint color of an area.
    static func tint(hue: Double) -> ThemeRGB { oklch(0.6, 0.13, hue) }
    /// Section title and icon color.
    static func title(hue: Double, dark: Bool) -> ThemeRGB { oklch(dark ? 0.82 : 0.45, 0.14, hue) }
    static func accent(hue: Double, dark: Bool) -> ThemeRGB { oklch(dark ? 0.76 : 0.55, 0.14, hue) }
    /// The color a "tinted" picture is recolored into.
    static func tone(hue: Double) -> ThemeRGB { oklch(0.6, 0.14, hue) }

    /// Accent that re-resolves for light and dark like a system color. Named per
    /// hue so caches keyed on the color's description tell two hues apart.
    static func dynamicAccent(hue: Double) -> NSColor {
        let rounded = Int(hue.rounded())
        return NSColor(name: "StayTabThemeAccent\(rounded)") { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return accent(hue: Double(rounded), dark: dark).nsColor()
        }
    }

    static func contrastRatio(_ a: Double, _ b: Double) -> Double {
        (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// Picture placement. The panel and its sections change shape as apps come and
/// go, so a theme stores a focus point and a zoom rather than a fixed crop.
enum ThemeCrop {
    /// The part of an image, as a unit rect with a top-left origin, that
    /// aspect-fills `viewSize` around `focus`, `zoom` times closer.
    static func visibleRect(imageSize: CGSize, viewSize: CGSize, focus: CGPoint, zoom: CGFloat) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        let aspect = viewSize.width / viewSize.height
        // `min` keeps a rounding error from making the crop a hair larger than
        // the picture, which would invert the clamp ranges below.
        var w = imageSize.width, h = imageSize.height
        if imageSize.width / imageSize.height > aspect {
            w = min(imageSize.width, imageSize.height * aspect)
        } else {
            h = min(imageSize.height, imageSize.width / aspect)
        }
        let z = max(1, zoom)
        w /= z
        h /= z
        let cx = (focus.x * imageSize.width).clamped(to: (w / 2)...(imageSize.width - w / 2))
        let cy = (focus.y * imageSize.height).clamped(to: (h / 2)...(imageSize.height - h / 2))
        return CGRect(
            x: (cx - w / 2) / imageSize.width,
            y: (cy - h / 2) / imageSize.height,
            width: w / imageSize.width,
            height: h / imageSize.height
        )
    }

    /// `visibleRect` flipped for `CALayer.contentsRect`, whose unit space has a
    /// bottom-left origin in an unflipped layer.
    static func layerContentsRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: 1 - rect.maxY, width: rect.width, height: rect.height)
    }
}

/// A coarse grid of a picture's colors, enough to estimate brightness and text
/// contrast without touching the full bitmap.
struct ThemeImageSamples: Sendable {
    let columns: Int
    let rows: Int
    let pixels: [ThemeRGB]
    let imageSize: CGSize

    init(columns: Int, rows: Int, pixels: [ThemeRGB], imageSize: CGSize) {
        self.columns = columns
        self.rows = rows
        self.pixels = pixels
        self.imageSize = imageSize
    }

    init?(image: CGImage, maxEdge: Int = 48) {
        let scale = Double(maxEdge) / Double(max(image.width, image.height))
        let columns = max(1, Int((Double(image.width) * scale).rounded()))
        let rows = max(1, Int((Double(image.height) * scale).rounded()))
        var bytes = [UInt8](repeating: 0, count: columns * rows * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: buffer.baseAddress, width: columns, height: rows,
                                          bitsPerComponent: 8, bytesPerRow: columns * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: columns, height: rows))
            return true
        }
        guard drawn else { return nil }
        // Bitmap memory starts at the top row, so index 0 is the top-left pixel.
        var pixels: [ThemeRGB] = []
        pixels.reserveCapacity(columns * rows)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            pixels.append(ThemeRGB(r: Double(bytes[i]) / 255, g: Double(bytes[i + 1]) / 255, b: Double(bytes[i + 2]) / 255))
        }
        self.init(columns: columns, rows: rows, pixels: pixels, imageSize: CGSize(width: image.width, height: image.height))
    }

    /// Samples inside a unit rect with a top-left origin.
    func pixels(in rect: CGRect) -> [ThemeRGB] {
        let x0 = Int((rect.minX * Double(columns)).rounded(.down)).clamped(to: 0...(columns - 1))
        let y0 = Int((rect.minY * Double(rows)).rounded(.down)).clamped(to: 0...(rows - 1))
        let x1 = max(x0 + 1, Int((rect.maxX * Double(columns)).rounded(.up)).clamped(to: 1...columns))
        let y1 = max(y0 + 1, Int((rect.maxY * Double(rows)).rounded(.up)).clamped(to: 1...rows))
        var out: [ThemeRGB] = []
        out.reserveCapacity((x1 - x0) * (y1 - y0))
        for y in y0..<y1 {
            for x in x0..<x1 { out.append(pixels[y * columns + x]) }
        }
        return out
    }

    var meanLightness: Double {
        guard !pixels.isEmpty else { return 0.5 }
        return pixels.reduce(0) { $0 + $1.oklabLightness } / Double(pixels.count)
    }
}

/// Estimates how readable the switcher's text is over a theme, compositing each
/// area's layers in the order `SwitcherView` stacks them. A recommendation, never
/// a gate: the editor shows the number and a fix, and saving stays allowed.
struct ThemeLegibility {
    /// WCAG AA for body text — app names are small.
    static let target = 4.5

    var theme: PanelTheme
    /// Average color of the desktop behind the panel.
    var desktop: ThemeRGB
    /// Light text on a dark panel.
    var dark: Bool
    var samples: [ThemeArea: ThemeImageSamples] = [:]
    /// Current size of each area, for the visible part of its picture.
    var sizes: [ThemeArea: CGSize] = [:]
    /// The accent the default Always plate is filled with.
    var accent: ThemeRGB = ThemeRGB(r: 0.04, g: 0.52, b: 1)

    /// Composited backdrop samples behind the area's text.
    func backdrop(_ area: ThemeArea, scrim overrideScrim: Double? = nil) -> [ThemeRGB] {
        let t = theme[area: area]
        let scrim = overrideScrim ?? t.scrim
        let veil = dark ? ThemeRGB.black : ThemeRGB.white
        let tinted = { (c: ThemeRGB) -> ThemeRGB in
            (t.backdrop == .color || (t.backdrop == .image && !t.tone)) ? c.mixed(with: ThemeColor.tint(hue: t.hue), t.tint) : c
        }
        if area == .panel {
            let haze = dark ? ThemeRGB(r: 0.1, g: 0.1, b: 0.125) : ThemeRGB(r: 0.95, g: 0.95, b: 0.965)
            let glass = desktop.mixed(with: haze, dark ? 0.5 : 0.55)
            let dim = (0.2 + scrim).clamped(to: 0...0.95)
            let finish = { (c: ThemeRGB) in tinted(c).mixed(with: veil, dim) }
            if t.backdrop == .image, let picture = picturePixels(area, t) {
                return picture.map { finish(glass.mixed(with: $0, t.strength)) }
            }
            return [finish(glass)]
        }
        let under = Self.average(backdrop(.panel))
        let finish = { (c: ThemeRGB) in scrim > 0 ? c.mixed(with: veil, scrim.clamped(to: 0...0.95)) : c }
        switch t.backdrop {
        case .standard:
            let fill = area == .always
                ? under.mixed(with: accent, 0.12)
                : under.mixed(with: dark ? .white : .black, 0.045)
            return [finish(fill)]
        case .color:
            return [finish(tinted(under))]
        case .image:
            guard let picture = picturePixels(area, t) else { return [finish(tinted(under))] }
            return picture.map { finish(tinted(under.mixed(with: $0, t.strength))) }
        }
    }

    /// Contrast of the label color over the worst tenth of the area.
    func worstContrast(_ area: ThemeArea, scrim: Double? = nil) -> Double {
        let label = dark ? ThemeRGB.white : ThemeRGB.black
        let alpha = dark ? 0.92 : 0.86
        let ratios = backdrop(area, scrim: scrim).map { bg in
            ThemeColor.contrastRatio(bg.mixed(with: label, alpha).relativeLuminance, bg.relativeLuminance)
        }.sorted()
        guard !ratios.isEmpty else { return 21 }
        return ratios[ratios.count / 10]
    }

    /// The smallest extra veil that brings the area to `target`, if any does.
    func suggestedScrim(_ area: ThemeArea) -> Double? {
        var step = 0.0
        while step <= AreaTheme.scrimRange.upperBound + 0.0001 {
            if worstContrast(area, scrim: step) >= Self.target { return (step * 100).rounded() / 100 }
            step += 0.01
        }
        return nil
    }

    private func picturePixels(_ area: ThemeArea, _ t: AreaTheme) -> [ThemeRGB]? {
        guard let samples = samples[area] else { return nil }
        let size = sizes[area] ?? CGSize(width: 3, height: 2)
        let rect = ThemeCrop.visibleRect(imageSize: samples.imageSize, viewSize: size,
                                         focus: CGPoint(x: t.focusX, y: t.focusY), zoom: t.zoom)
        let pixels = samples.pixels(in: rect)
        guard t.tone else { return pixels }
        return pixels.map { ThemeColor.oklch($0.oklabLightness, 0.12, t.hue) }
    }

    static func average(_ colors: [ThemeRGB]) -> ThemeRGB {
        guard !colors.isEmpty else { return .black }
        let n = Double(colors.count)
        let sum = colors.reduce(ThemeRGB.black) { ThemeRGB(r: $0.r + $1.r, g: $0.g + $1.g, b: $0.b + $1.b) }
        return ThemeRGB(r: sum.r / n, g: sum.g / n, b: sum.b / n)
    }
}

extension PanelAppearance {
    /// Whether a picture this bright reads better with light text.
    static func picturePrefersDark(meanLightness: Double) -> Bool {
        meanLightness < 0.62
    }
}
