import AppKit

/// The Theme tab's unsaved draft. It lives outside the tab's view controller:
/// Settings frees panes that aren't showing (`tabUnloadPolicy: .balanced`), and
/// a draft held by the pane would vanish on a visit to another tab. Nothing
/// here touches `Preferences` until `save`.
@MainActor
final class ThemeEditorSession {
    static let shared = ThemeEditorSession()

    /// An unblurred picture the editor bakes from. `base` is the saved file it
    /// came from; nil for one picked in this session and not saved yet.
    struct Source {
        let image: CGImage
        let name: String
        let base: String?
    }

    private(set) var draft = PanelTheme.standard
    private(set) var appearance = PanelAppearance.system
    private(set) var sources: [ThemeArea: Source] = [:]
    private(set) var isSaving = false
    var area: ThemeArea = .panel

    /// Called after any change, including sources finishing loading.
    var onChange: (() -> Void)?

    private var loadGeneration = 0
    private var started = false
    /// The saved values the draft started from; dirty means "differs from these".
    private var baseTheme = PanelTheme.standard
    private var baseAppearance = PanelAppearance.system

    private init() {}

    var isDirty: Bool {
        draft != baseTheme
            || appearance != baseAppearance
            || sources.values.contains { $0.base == nil }
    }

    /// Starts from the saved theme unless an unsaved draft is waiting. A clean
    /// draft reloads, so an import or config-file change made meanwhile shows up.
    func begin() {
        if !started || !isDirty { revert() }
        started = true
    }

    /// Lets go of the decoded pictures when nothing is unsaved, so a visit to
    /// the Theme tab doesn't keep up to three source bitmaps for the app's life.
    /// The next `begin` reloads them.
    func releaseIfClean() {
        guard !isDirty, !isSaving else { return }
        loadGeneration += 1
        sources = [:]
        started = false
    }

    /// Drops the draft and reloads the saved theme and its pictures.
    func revert() {
        let prefs = Preferences.shared
        baseTheme = prefs.panelTheme
        baseAppearance = prefs.panelAppearance
        draft = baseTheme
        appearance = baseAppearance
        sources = [:]
        loadSavedSources(prefs.themeImageFiles)
        onChange?()
    }

    func updateArea(_ change: (inout AreaTheme) -> Void) {
        var theme = draft[area: area]
        change(&theme)
        guard theme != draft[area: area] else { return }
        draft[area: area] = theme
        onChange?()
    }

    func resetArea() {
        draft[area: area] = AreaTheme.defaults(for: area)
        sources[area] = nil
        onChange?()
    }

    func setAccent(_ accent: ThemeAccent) {
        guard draft.accent != accent else { return }
        draft.accent = accent
        onChange?()
    }

    func setAppearance(_ value: PanelAppearance) {
        guard appearance != value else { return }
        appearance = value
        onChange?()
    }

    /// A newly picked picture for the current area, framed from the center.
    func setPicture(_ image: CGImage, name: String, strength: Double?) {
        sources[area] = Source(image: image, name: name, base: nil)
        var theme = draft[area: area]
        theme.backdrop = .image
        theme.focusX = 0.5
        theme.focusY = 0.5
        theme.zoom = 1
        if let strength { theme.strength = strength }
        draft[area: area] = theme
        onChange?()
    }

    /// Bakes every picture area, writes the files, then publishes the theme in
    /// one step so the switcher never pairs a new theme with old pictures.
    func save(completion: @escaping (Bool) -> Void) {
        guard !isSaving else { return }
        isSaving = true
        let draft = draft
        let appearance = appearance
        let sources = sources
        DispatchQueue.global(qos: .userInitiated).async {
            var files: [String: String] = [:]
            var written: [ThemeArea: String] = [:]
            var failed = false
            for area in ThemeArea.allCases where draft[area: area].backdrop == .image {
                guard let source = sources[area] else { continue }
                guard let baked = ThemeImageFiles.bake(source.image, area: area, theme: draft[area: area]),
                      let base = try? ThemeImageFiles.write(baked: baked, source: source.image, area: area)
                else {
                    failed = true
                    continue
                }
                files[area.rawValue] = base
                written[area] = base
            }
            ThemeImageFiles.removeFiles(except: Set(files.values))
            DispatchQueue.main.async {
                let prefs = Preferences.shared
                prefs.themeImageFiles = files
                prefs.panelTheme = draft
                prefs.panelAppearance = appearance
                self.baseTheme = draft
                self.baseAppearance = appearance
                for (area, base) in written {
                    if let source = self.sources[area] {
                        self.sources[area] = Source(image: source.image, name: source.name, base: base)
                    }
                }
                self.isSaving = false
                self.onChange?()
                completion(!failed)
            }
        }
    }

    private func loadSavedSources(_ files: [String: String]) {
        loadGeneration += 1
        let token = loadGeneration
        let wanted = ThemeArea.allCases.compactMap { area in files[area.rawValue].map { (area, $0) } }
        guard !wanted.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            var loaded: [ThemeArea: Source] = [:]
            for (area, base) in wanted {
                // Pictures saved before sources were kept fall back to the baked file.
                let image = ThemeImageFiles.sourceURL(base: base).flatMap(ThemeImageFiles.loadImage(at:))
                    ?? ThemeImageFiles.bakedURL(base: base).flatMap(ThemeImageFiles.loadImage(at:))
                if let image { loaded[area] = Source(image: image, name: String(localized: "Saved picture"), base: base) }
            }
            DispatchQueue.main.async {
                guard self.loadGeneration == token else { return }
                for (area, source) in loaded where self.sources[area] == nil {
                    self.sources[area] = source
                }
                self.onChange?()
            }
        }
    }
}
