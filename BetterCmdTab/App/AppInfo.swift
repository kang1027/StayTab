import Foundation

/// App version/build/name read from the main bundle. Previously lived in the
/// updater's `UpdaterLogging.swift`; relocated here when the updater moved to
/// the BetterUpdater Swift package.
enum AppInfo {
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    static let appBuildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    static let displayName = (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
        ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String)
        ?? "BetterCmdTab"

    /// Short git SHA, stamped into Info.plist by `scripts/build_release.sh`
    /// (`GIT_COMMIT` build setting). Absent for local Xcode builds.
    static let gitCommit: String? = {
        let value = Bundle.main.infoDictionary?["GitCommit"] as? String ?? ""
        return value.isEmpty ? nil : value
    }()

    /// Build number, plus the commit it was built from on release builds:
    /// `"20260103120000"` or `"20260103120000 (a1b2c3d)"`.
    static let buildLabel = gitCommit.map { "\(appBuildNumber) (\($0))" } ?? appBuildNumber
}
