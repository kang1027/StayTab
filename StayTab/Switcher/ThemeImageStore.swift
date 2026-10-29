import AppKit
import Combine
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// A theme picture ready to hand to a layer, with its brightness measured once.
struct ThemePicture: @unchecked Sendable {
    let image: CGImage
    let samples: ThemeImageSamples?

    init(image: CGImage) {
        self.image = image
        self.samples = ThemeImageSamples(image: image)
    }
}

/// Reads, bakes and writes theme pictures. All of it runs off the main thread:
/// picking a file, saving a theme and loading at launch are the only callers, and
/// none of them sit on the ⌘Tab path.
enum ThemeImageFiles {
    /// Longest edge a source picture is decoded to. ImageIO decodes straight to
    /// this size, so a 48-megapixel photo never lands in memory whole.
    static let sourceMaxEdge = 1600

    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StayTab", isDirectory: true)
            .appendingPathComponent("Themes", isDirectory: true)
    }

    /// The baked picture the switcher draws.
    static func bakedURL(base: String) -> URL? {
        guard isSafe(base) else { return nil }
        return directory.appendingPathComponent(base + ".jpg")
    }

    /// The unblurred original the editor re-bakes from.
    static func sourceURL(base: String) -> URL? {
        guard isSafe(base) else { return nil }
        return directory.appendingPathComponent(base + "-source.jpg")
    }

    private static func isSafe(_ base: String) -> Bool {
        !base.isEmpty && URL(fileURLWithPath: base).lastPathComponent == base && !base.hasPrefix(".")
    }

    /// Stored size for an area. Sections are smaller than the panel, and a blurred
    /// picture loses nothing at a lower resolution.
    static func bakedMaxEdge(for area: ThemeArea, blur: Double) -> Int {
        let soft = blur >= 4
        switch area {
        case .panel: return soft ? 800 : 1600
        case .always, .running: return soft ? 600 : 1000
        }
    }

    /// Decodes any image file ImageIO reads (HEIC included), downscaled and
    /// rotated upright.
    static func loadSource(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: sourceMaxEdge,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func loadImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceShouldCacheImmediately: true]
        return CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary)
    }

    private static let ciContext = CIContext(options: [.cacheIntermediates: false])

    /// Scales, blurs and recolors `source` the way the area shows it. The blur
    /// radius is proportional to the output size, so a preview baked smaller
    /// looks the same as the stored picture.
    static func bake(_ source: CGImage, area: ThemeArea, theme: AreaTheme, maxEdge: Int? = nil) -> CGImage? {
        let edge = maxEdge ?? bakedMaxEdge(for: area, blur: theme.blur)
        let scale = min(1, Double(edge) / Double(max(source.width, source.height)))
        var image = CIImage(cgImage: source)
        if scale < 1 {
            image = image.applyingFilter("CILanczosScaleTransform", parameters: [
                kCIInputScaleKey: scale,
                kCIInputAspectRatioKey: 1,
            ])
        }
        let extent = image.extent.integral
        let radius = theme.blur * 2 * Double(max(extent.width, extent.height)) / Double(sourceMaxEdge)
        if radius > 0.1 {
            image = image.clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: extent)
        }
        if theme.tone {
            let tone = ThemeColor.tone(hue: theme.hue)
            image = image.applyingFilter("CIColorMonochrome", parameters: [
                kCIInputColorKey: CIColor(red: tone.r, green: tone.g, blue: tone.b),
                kCIInputIntensityKey: 1,
            ])
        }
        return ciContext.createCGImage(image, from: extent)
    }

    /// Whether two looks of an area bake to the same picture. Focus and zoom
    /// aren't baked in; the layer crops at draw time.
    static func bakesAlike(_ a: AreaTheme, _ b: AreaTheme) -> Bool {
        a.blur == b.blur && a.tone == b.tone && (!a.tone || a.hue == b.hue)
    }

    /// Writes the baked picture and its source under a fresh base name. A new
    /// name per save means a running switcher never reads a half-written file.
    /// A source already saved under `sourceBase` is copied, not re-encoded, so
    /// saving again never costs it quality.
    static func write(baked: CGImage, source: CGImage, sourceBase: String?, area: ThemeArea) throws -> String {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = area.rawValue + "-" + UUID().uuidString.prefix(8).lowercased()
        guard let bakedURL = bakedURL(base: base), let sourceURL = sourceURL(base: base) else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        try writeJPEG(baked, to: bakedURL)
        if let saved = sourceBase.flatMap(Self.sourceURL(base:)), manager.fileExists(atPath: saved.path) {
            try manager.copyItem(at: saved, to: sourceURL)
        } else {
            try writeJPEG(source, to: sourceURL)
        }
        return base
    }

    private static func writeJPEG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }

    /// Deletes every theme file whose base name isn't in `keep`.
    static func removeFiles(except keep: Set<String>) {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: directory.path) else { return }
        for name in names where name.hasSuffix(".jpg") {
            let base = name.replacingOccurrences(of: "-source.jpg", with: "").replacingOccurrences(of: ".jpg", with: "")
            guard !keep.contains(base) else { continue }
            try? manager.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}

/// The saved theme with its pictures, decoded once and held for the live
/// switcher. Decoding runs off the main thread, and a theme is published only
/// once every picture it names is ready, so the switcher never pairs a new
/// theme with the previous pictures.
@MainActor
final class ThemeImageStore: ObservableObject {
    static let shared = ThemeImageStore()

    struct Snapshot {
        let theme: PanelTheme
        let pictures: [ThemeArea: ThemePicture]
    }

    @Published private(set) var snapshot: Snapshot

    /// Base name → decoded picture; nil marks a file that failed to decode.
    private var decoded: [String: ThemePicture?] = [:]
    private var decoding: Set<String> = []
    private var latest: (theme: PanelTheme, wanted: [ThemeArea: String])
    private var cancellable: AnyCancellable?

    private init() {
        let prefs = Preferences.shared
        latest = (prefs.panelTheme, [:])
        snapshot = Snapshot(theme: prefs.panelTheme, pictures: [:])
        cancellable = prefs.$panelTheme.combineLatest(prefs.$themeImageFiles)
            .sink { [weak self] theme, files in self?.reload(theme: theme, files: files) }
    }

    private func reload(theme: PanelTheme, files: [String: String]) {
        var wanted: [ThemeArea: String] = [:]
        for area in ThemeArea.allCases where theme[area: area].backdrop == .image {
            if let base = files[area.rawValue] { wanted[area] = base }
        }
        latest = (theme, wanted)
        let missing = Set(wanted.values).subtracting(decoded.keys).subtracting(decoding)
        if !missing.isEmpty { decode(missing) }
        publishIfReady()
    }

    private func decode(_ bases: Set<String>) {
        decoding.formUnion(bases)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var pictures: [String: ThemePicture?] = [:]
            for base in bases {
                pictures[base] = ThemeImageFiles.bakedURL(base: base)
                    .flatMap(ThemeImageFiles.loadImage(at:))
                    .map(ThemePicture.init(image:))
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.decoding.subtract(bases)
                let wanted = Set(self.latest.wanted.values)
                for (base, picture) in pictures where wanted.contains(base) {
                    self.decoded[base] = picture
                }
                self.publishIfReady()
            }
        }
    }

    private func publishIfReady() {
        let wanted = latest.wanted
        guard wanted.values.allSatisfy({ decoded.keys.contains($0) }) else { return }
        let used = Set(wanted.values)
        decoded = decoded.filter { used.contains($0.key) }
        snapshot = Snapshot(theme: latest.theme, pictures: wanted.compactMapValues { decoded[$0] ?? nil })
    }
}
