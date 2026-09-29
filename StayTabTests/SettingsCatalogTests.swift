import BetterSettings
import Foundation
import Testing
@testable import StayTab

/// The search index is a hand-maintained table: every row that wants to be
/// findable repeats its id, tab and section anchor in `SettingsCatalog`, far
/// from the controller that builds the row. BetterSettings resolves a search
/// hit by looking the tab up by id and then scrolling to the anchor — and when
/// either misses it silently falls back to the top of a pane, so a typo ships
/// as "search jumps somewhere random" with no crash and no log. These check the
/// three ways the table can drift out of sync with the panes.
@MainActor
@Suite("Settings catalog")
struct SettingsCatalogTests {

    @Test("search item ids are unique")
    func uniqueIDs() {
        let ids = SettingsCatalog.searchItems.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate ids: \(duplicates(in: ids))")
    }

    @Test("every search item points at a tab that exists")
    func tabsExist() {
        let tabIDs = Set(SettingsCatalog.tabs.map(\.id))
        for item in SettingsCatalog.searchItems {
            #expect(tabIDs.contains(item.tabID), "\(item.id) points at unknown tab \(item.tabID)")
        }
    }

    @Test("settings expose only StayTab's focused product surface")
    func focusedTabsOnly() {
        #expect(SettingsCatalog.tabs.map(\.id) == [
            SettingsTabID.general,
            SettingsTabID.profiles,
            SettingsTabID.switcher,
            SettingsTabID.apps,
            SettingsTabID.appearance,
            SettingsTabID.privacy,
            SettingsTabID.about,
        ])

        let searchIDs = Set(SettingsCatalog.searchItems.map(\.id))
        #expect(!searchIDs.contains(SearchID.scopedSwitch))
        #expect(!searchIDs.contains(SearchID.panelKeys))
        #expect(!searchIDs.contains(SearchID.fullDiskAccess))
        #expect(!searchIDs.contains(SearchID.tabPermissions))
    }

    /// Anchors are namespaced `<tab>.<section>`, so the prefix catches a row
    /// that moved panes without its anchor following.
    @Test("every section anchor belongs to the item's own tab")
    func anchorsMatchTabs() {
        for item in SettingsCatalog.searchItems {
            #expect(item.sectionAnchor.hasPrefix(item.tabID + "."),
                    "\(item.id) is on tab \(item.tabID) but anchored at \(item.sectionAnchor)")
        }
    }

    @Test("the Show Details choice survives the defaults key rename")
    func showDetailsKeyMigrates() throws {
        let suite = "StayTabTests.showDetails.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(false, forKey: SettingsCatalog.legacyShowDetailsDefaultsKey)
        SettingsCatalog.migrateShowDetailsKey(in: defaults)

        #expect(defaults.object(forKey: SettingsCatalog.showDetailsDefaultsKey) as? Bool == false)
        #expect(defaults.object(forKey: SettingsCatalog.legacyShowDetailsDefaultsKey) == nil)
    }

    @Test("a value already under the new key wins over the legacy one")
    func showDetailsKeyKeepsCurrentValue() throws {
        let suite = "StayTabTests.showDetails.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(true, forKey: SettingsCatalog.showDetailsDefaultsKey)
        defaults.set(false, forKey: SettingsCatalog.legacyShowDetailsDefaultsKey)
        SettingsCatalog.migrateShowDetailsKey(in: defaults)

        #expect(defaults.object(forKey: SettingsCatalog.showDetailsDefaultsKey) as? Bool == true)
        #expect(defaults.object(forKey: SettingsCatalog.legacyShowDetailsDefaultsKey) == nil)
    }

    private func duplicates(in ids: [String]) -> [String] {
        Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
    }
}
