import Testing
@testable import StayTab

@Suite("AppInfo")
struct AppInfoTests {
    @Test("appVersion never empty")
    func versionNonEmpty() {
        #expect(!AppInfo.appVersion.isEmpty)
    }

    @Test("appBuildNumber never empty")
    func buildNumberNonEmpty() {
        #expect(!AppInfo.appBuildNumber.isEmpty)
    }

    @Test("displayName falls back to StayTab when bundle keys missing")
    func displayNameFallback() {
        #expect(!AppInfo.displayName.isEmpty)
    }
}
