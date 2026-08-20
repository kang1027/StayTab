import AppKit
import BetterSettings
import BetterShortcuts

/// StayTab's focused shortcut pane. BetterCmdTab's inherited scoped shortcuts,
/// per-shortcut behavior overrides and in-panel action bindings remain readable
/// at runtime for compatibility, but are not part of the product settings UI.
@MainActor
final class ProfilesSettingsViewController: SettingsTabViewController {

    override func setupContent() {
        let switching = addSection(title: String(localized: "Command-Tab"), anchor: SettingsAnchor.switching)

        addRow(
            to: switching,
            title: String(localized: "Switch apps"),
            subtitle: String(localized: "Hold the modifier and tap to move through apps."),
            accessory: BetterShortcuts.RecorderCocoa(for: .switchApps, policy: BetterShortcuts.recorderPolicy),
            searchItemID: SearchID.switchApps
        )

        addRow(
            to: switching,
            title: String(localized: "Switch windows"),
            subtitle: String(localized: "Hold the modifier and tap to move through windows."),
            accessory: BetterShortcuts.RecorderCocoa(for: .switchWindows, policy: BetterShortcuts.recorderPolicy),
            searchItemID: SearchID.switchWindows
        )
    }
}
