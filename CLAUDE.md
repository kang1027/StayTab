## Product

The shipped app is **StayTab**. The Xcode project, schemes, source module, and some
upstream compatibility identifiers intentionally retain the BetterCmdTab name.
StayTab's defining behavior is a persistent app-level ⌘Tab roster: pinned apps remain
visible and launchable after quitting, while unpinned apps appear only while running.

## Project priority — performance first

Performance, optimization, and minimal resource usage are the top priority for every change
in this project. It is a ⌘Tab hot-path app: prefer the solution that uses the least CPU,
memory, and energy, keep work off the main thread (or measure it), avoid allocations and
polling on hot paths, and don't add a dependency or background task when a lighter approach
works. When two designs are equally correct, ship the cheaper one.

## Build / test / run

Xcode 26+ and the macOS 26 SDK are required (Liquid Glass paths are SDK-gated; deployment
target is macOS 13.0, which falls back to `NSVisualEffectView` at runtime). Two schemes
exist: `BetterCmdTab Debug` and `BetterCmdTab`.

```bash
# Build
xcodebuild -scheme "BetterCmdTab Debug" -configuration Debug build
xcodebuild -scheme "BetterCmdTab" -configuration Release build   # ships Liquid Glass

# Test (whole suite)
xcodebuild -scheme "BetterCmdTab Debug" -destination 'platform=macOS' test

# Single test class / method
xcodebuild -scheme "BetterCmdTab Debug" -destination 'platform=macOS' \
  test -only-testing:BetterCmdTabTests/FuzzyMatchTests
xcodebuild -scheme "BetterCmdTab Debug" -destination 'platform=macOS' \
  test -only-testing:BetterCmdTabTests/FuzzyMatchTests/noMatch
```

Tests use **Swift Testing** (`import Testing`, `@Suite`/`@Test`), not XCTest — there are
no `testXxx()` methods, so select a single case by its Swift function name (e.g. `noMatch`,
`appNameSubsequence`), not by a `test`-prefixed name.

Tests cover **pure logic** (switcher metrics, row labels, catalog filtering, fuzzy
match, updater parsing, Liquid Glass selection, settings portability), plus a small
AppKit-hosted set — `TabStripWindowingTests`, `SwitcherReflowTests` — that needs a live
WindowServer and macOS Reduce Motion off. The rest of the UI is verified manually: the
switcher needs Accessibility permission, so that surface fails in headless/CI and is not
part of the unit run.

## Release / version

```bash
scripts/set_version.sh 0.1.0              # set MARKETING_VERSION; review before committing
scripts/set_version.sh --show             # print current version & build
scripts/build_release.sh                  # build + sign + notarize + dmg/zip → build/release/
scripts/build_release.sh --beta           # beta build, auto-detects next beta.N from GitHub tags
scripts/build_release.sh --skip-build --auto-release --notes-file notes.md
scripts/build_release.sh --skip-notarization   # dev build, no notarize (refuses --auto-release)
scripts/update-packages.sh                # bump SPM deps (clears Package.resolved, re-resolves)
```

`set_version.sh` does not commit unless `--commit` is explicitly passed. `build_release.sh`
stamps a timestamp `CURRENT_PROJECT_VERSION` into the archive without mutating the project.
Signing/notarization needs `Developer ID Application: DongHyeon Kang (GGR9HG6DB8)` and the
`StayTabNotarization` notarytool Keychain profile. See `RELEASING.md` for the one-time setup.

### Changelog format (the release body)

The changelog is the GitHub Release body (no `CHANGELOG.md`). Pass its file path through
`--notes-file`. Tags use `v<version>` for stable (`v0.1.0`) and
`v<version>-beta.<n>` for prereleases (`v0.2.0-beta.1`). Release scripts never commit or push.

This is an end-user app, so bullets are
**user-facing and outcome-first**, not internal symbol names:

- **First line** is `## Highlights` — a one/two-sentence summary of what the release delivers.
- Then `### Added`, `### Changed`, `### Fixed`, `### Removed` as they apply (omit empty sections).
- Each bullet describes the observable behavior change for the user — what now works / changed,
  not which type was renamed. Exclude `chore`/`refactor`/`build`/`test`/`ci`/`docs`-only changes.
- End with a compare footer for any release with a predecessor (blank line before it):

  ```
  **Full changelog:** https://github.com/kang1027/StayTab/compare/<prev-tag>...<tag>
  ```

## Architecture

macOS menu-bar (`.accessory`) app, **AppKit only** — no SwiftUI, no Catalyst, no
third-party UI frameworks. `AppDelegate` (`App/AppDelegate.swift`) wires everything at
launch and owns the single `SwitcherController`. Three SPM packages, all first-party
(`rokartur/*`): `BetterSettings`, `BetterUpdater`, `BetterShortcuts` (`swift-argument-parser`
shows up in the resolved graph only as their transitive dep — not used by the app directly).

`AppDelegate.main()` sets `.accessory` (no Dock icon) and calls `app.run()`, but the
`SwitcherController` does **not** boot until Accessibility is trusted: `AccessibilityWaiter`
polls `AXIsProcessTrusted()` and then calls `bootController()`. A switcher that "does
nothing" almost always means the AX permission was not granted.

Data + control flow on the ⌘Tab hot path:

- **Input** (`Input/`) — `HotkeyTap` is a CGEvent tap on its **own thread** that detects
  the ⌘Tab chord and suppresses the native switcher. The tap goes deaf under **Secure
  Event Input** (password fields), so `CarbonHotkeyTrigger` (Carbon `RegisterEventHotKey`)
  is the survivor trigger that still opens the panel in that state. `DirectActivation` /
  `ScopedSwitch` handle
  per-app hotkeys and scoped cycling without opening the panel. `SwipeTrigger` +
  `SpaceSwipeSuppressor` drive the three-finger trackpad gesture. `WindowManagement` moves
  windows across displays.
- **Catalog** (`Catalog/`) — `AppCatalog` enumerates apps/windows via the Accessibility
  API. `AppCatalogCache` keeps an incremental cache fed by AX observers and MRU bumps so
  the panel opens instantly. `CatalogFilter` applies pin/hide/scope rules; `IconCache` and
  `InstalledAppsIndex` back icons and the launch-any-app search.
- **Switcher** (`Switcher/`) — `SwitcherController` is the state machine (selection,
  letter-jump, fuzzy search, tab drill-in). `SwitcherPanel` is the non-activating panel.
  `SwitcherView` lays out the three layouts (list / grid / window previews) via the
  per-layout item views. `WindowThumbnailCache` backs preview thumbnails; `TabStripView` +
  `Windows/BrowserTabs` implement the `\` tab drill-in.
- **Windows** (`Windows/`) — `Activator` performs activate/raise/close/hide/quit.
  `MRUTracker` / `WindowMRUTracker` order apps and windows by recency;
  `RecentlyClosedStore` powers reopen-recently-closed; `WindowEnumerator` lists windows.
- **System** (`System/`) — `PrivateAPIs` isolates all private CGS/SkyLight glue (kept in
  one file for review). `AccessibilityCheck` gates on the AX permission. `Log` is the
  `os.Logger` wrapper — use `Log.*`, never `print`. Plus audio-activity, Dock-badge,
  symbolic-hotkey-guard, and launch-at-login helpers.
- **Settings** (`Settings/`) — native AppKit settings window with seven visible panes:
  General, Shortcuts, Switcher, Apps, Appearance, Privacy, and About. The Shortcuts pane
  exposes only the app/window switch triggers. BetterCmdTab's inherited global-shortcut,
  detailed-controls, browser-tabs, scoped-profile, and browser-permission surfaces are not
  registered, while their runtime preferences remain readable for imported-config
  compatibility. `SwitcherPanesViewController` still owns the hidden Controls/Tabs
  implementations until the inherited engine is removed in a separate audited change.

## Preferences, persistence & i18n

- **Preferences** — `App/Preferences.swift` is a `@MainActor` `ObservableObject` singleton
  (`Preferences.shared`) whose `@Published` properties persist to `UserDefaults` via `didSet`.
  All keys live in a `Keys` enum under the `"Switcher."` prefix. Hot-path consumers
  (`CatalogFilter`, `SwitcherController`) read some keys (sort order, app exceptions,
  expand-tabs) **directly off the main actor** from `UserDefaults`, so the key strings are
  the contract — don't rename one without updating both sides.
- **Portability** — `App/SettingsPortability.swift` exports/imports the whole `Switcher.*`
  namespace as flat prefix-free JSON (`.json`); import also accepts the legacy versioned
  `.cmdtab` envelope (`schemaVersion`, UTI `pro.bettercmdtab.settings`). Import is partial
  (absent keys keep their current value) and calls `reloadFromDefaults()` to refresh live
  subscribers. `App/ConfigFile.swift` two-way-syncs the same flat format with
  `~/.config/bettercmdtab/config.json` (`$XDG_CONFIG_HOME` honored) when that file exists —
  event-driven watcher + debounced write-back, dormant when absent (#117). It also writes a
  sidecar `schema.json` (referenced by the config's `$schema` key) generated from the live
  snapshot — types only, open-ended, so a new preference needs no schema edit.
- **Localization** — user-facing strings use `String(localized: "…")` and live in the
  version-controlled `BetterCmdTab/Localizable.xcstrings` (native Xcode string catalog,
  macOS 13+). Enum display names (layout mode, accent, etc.) are localized too.

## Running locally

Run the `BetterCmdTab Debug` scheme from Xcode. The app is `.accessory` — no Dock icon, it
lives in the menu bar. On first launch grant **Accessibility** under System Settings →
Privacy & Security → Accessibility, then quit/relaunch (or wait for `AccessibilityWaiter`
to pick it up). Without that permission the switcher never boots and ⌘Tab does nothing.

## Conventions (from CONTRIBUTING.md)

- AppKit only; no telemetry/analytics/background network. Only allowed network calls are
  opt-in GitHub Releases update checks.
- Deployment target stays macOS 13.0. New-OS features must be `if #available`-gated with a
  graceful fallback.
- Hot-path work (anything on ⌘Tab) stays off the main thread or must be measured.
- Logging via `os.Logger` through `Log.*` — no leftover `print`.
- Commits: `type: short summary` (`fix:`/`feat:`/`perf:`/`refactor:`/`docs:`/`chore:`),
  body wrapped ~72 chars explaining *why*. One logical change per PR.
- New pure-logic behavior ships with at least one test.

## web/ and docs/

These directories are inherited BetterCmdTab website sources and are not part of StayTab's
release pipeline. Their GitHub Pages workflows are intentionally disabled. Do not publish them
under the StayTab repository without a separate branding, attribution, and URL review.
