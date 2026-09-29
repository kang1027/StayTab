import AppKit
import BetterSettings

/// Shared accessory builders for the settings panes — the switch/popup wiring
/// every pane repeats, plus the "slider + editable value" rows — so styling and
/// input parsing stay in one place.
extension SettingsTabViewController {

    /// Opens a pane with the reminder that its rows are the switcher's global
    /// defaults and a profile can override many of them (#74).
    func addGlobalDefaultNote() {
        let note = addSection(title: nil, anchor: nil)
        addRow(to: note, icon: "slider.horizontal.3",
               title: SettingsCatalog.globalDefaultNoteTitle,
               subtitle: SettingsCatalog.globalDefaultNoteSubtitle)
    }

    /// Small switch wired to `action` on this controller.
    func configureSwitch(_ toggle: NSSwitch, action: Selector) {
        toggle.controlSize = .small
        toggle.target = self
        toggle.action = action
    }

    /// Small popup filled with `titles` and wired to `action` on this controller.
    func configurePopup(_ popup: NSPopUpButton, titles: [String], action: Selector) {
        popup.controlSize = .small
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.setContentHuggingPriority(.required, for: .horizontal)
        popup.removeAllItems()
        popup.addItems(withTitles: titles)
        popup.target = self
        popup.action = action
    }

    /// Slider (fixed 140pt wide) plus an editable value field with a unit suffix
    /// — the shape every "ms" / "%" row in the settings window uses.
    func makeValueSlider(_ slider: NSSlider,
                         field: NSTextField,
                         range: ClosedRange<Int>,
                         unit: String,
                         label: String,
                         sliderAction: Selector,
                         fieldAction: Selector) -> NSStackView {
        slider.minValue = Double(range.lowerBound)
        slider.maxValue = Double(range.upperBound)
        slider.isContinuous = true
        slider.controlSize = .small
        slider.target = self
        slider.action = sliderAction
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.setAccessibilityLabel(label)
        slider.widthAnchor.constraint(equalToConstant: 140).isActive = true

        configureIntegerField(field, action: fieldAction, accessibilityLabel: label)

        let stack = NSStackView(views: [slider, unitInput(for: field, unit: unit)])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        return stack
    }

    /// Small right-aligned integer field that commits on Return and on
    /// end-editing.
    func configureIntegerField(_ field: NSTextField,
                               action: Selector,
                               accessibilityLabel: String) {
        field.controlSize = .small
        field.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        field.alignment = .right
        field.target = self
        field.action = action
        field.cell?.sendsActionOnEndEditing = true
        field.translatesAutoresizingMaskIntoConstraints = false
        field.setContentHuggingPriority(.required, for: .horizontal)
        field.setAccessibilityLabel(accessibilityLabel)
        field.widthAnchor.constraint(equalToConstant: 52).isActive = true
    }

    /// The field with a trailing unit label ("ms", "%").
    func unitInput(for field: NSTextField, unit: String) -> NSStackView {
        let unitLabel = NSTextField(labelWithString: unit)
        unitLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        unitLabel.textColor = .secondaryLabelColor
        unitLabel.setContentHuggingPriority(.required, for: .horizontal)

        let stack = NSStackView(views: [field, unitLabel])
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.alignment = .centerY
        return stack
    }

    /// Parses the committed field text as an integer, tolerating surrounding
    /// whitespace and localized digits/grouping ("1 000", "٨٠"). Beeps and
    /// returns nil when the text isn't a number, so callers revert the field
    /// to the stored value.
    func committedInteger(from sender: NSTextField) -> Int? {
        let trimmed = sender.stringValue.trimmingCharacters(in: .whitespaces)
        if let value = Int(trimmed) { return value }
        if let number = Self.localizedIntegerFormatter.number(from: trimmed) {
            return number.intValue
        }
        NSSound.beep()
        return nil
    }

    private static let localizedIntegerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.isLenient = true
        return formatter
    }()
}

/// A switch wired straight to a `Preferences` flag: it declares which preference
/// it edits at the point it is created, writes that flag when flipped, and reads
/// it back on `sync()`.
///
/// Most settings toggles do nothing but store a `Bool`, and each one used to cost
/// a `configureSwitch` call plus a one-line `@objc` trampoline in its pane. Reach
/// for a plain `NSSwitch` + `configureSwitch(_:action:)` instead when flipping the
/// toggle has to do more than store the value — prompt for a permission, enable a
/// dependent row, refresh a list.
final class PreferenceSwitch: NSSwitch {
    private let preference: ReferenceWritableKeyPath<Preferences, Bool>

    init(bind preference: ReferenceWritableKeyPath<Preferences, Bool>) {
        self.preference = preference
        super.init(frame: .zero)
        controlSize = .small
        // Self-targeting: `target` is a weak reference, so this is not a cycle,
        // and it keeps the binding alive exactly as long as the control itself.
        target = self
        action = #selector(flip)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("PreferenceSwitch is code-only") }

    /// Push the stored preference back into the control, for `viewWillAppear` and
    /// for changes made outside this pane (a profile switch, an import).
    func sync() {
        state = Preferences.shared[keyPath: preference] ? .on : .off
    }

    @objc private func flip() {
        Preferences.shared[keyPath: preference] = (state == .on)
    }
}
