import AppKit
import Testing
@testable import BetterCmdTab

@Suite("LiquidGlassVariant raw values")
struct LiquidGlassVariantTests {

    /// Raw values are passed to `_variant` on NSGlassEffectView via setValue(forKey:).
    /// Changing them silently breaks glass rendering on macOS 26+. Pin them.
    @Test("variant raw values stable")
    func rawValuesStable() {
        #expect(LiquidGlassVariant.regular.rawValue == 0)
        #expect(LiquidGlassVariant.clear.rawValue == 1)
        #expect(LiquidGlassVariant.dock.rawValue == 2)
        #expect(LiquidGlassVariant.sidebar.rawValue == 16)
        #expect(LiquidGlassVariant.control.rawValue == 19)
    }

    @Test("ScrimState raw values stable")
    func scrimRaw() {
        #expect(ScrimState.off.rawValue == 0)
        #expect(ScrimState.on.rawValue == 1)
    }

    @Test("SubduedState raw values stable")
    func subduedRaw() {
        #expect(SubduedState.normal.rawValue == 0)
        #expect(SubduedState.subdued.rawValue == 1)
    }

    @Test("all variant cases enumerate")
    func allCasesEnumerable() {
        // CaseIterable conformance — protect against accidental case removal.
        #expect(LiquidGlassVariant.allCases.count >= 24)
    }
}

/// `setGlassValue` exists only so a renamed or removed private property on
/// `NSGlassEffectView` degrades into a skipped write instead of
/// `setValue:forUndefinedKey:` → NSUndefinedKeyException → SIGABRT. That guard is the
/// whole point of the helper and nothing else exercises it. Runs on any OS: a plain
/// `NSView` has none of the glass properties, which is exactly the shape of the
/// failure being guarded against.
@MainActor
@Suite("Liquid Glass KVC guard")
struct LiquidGlassValueGuardTests {

    @Test("a property the view does not have is skipped, not written")
    func missingPropertyIsSkipped() {
        let view = NSView(frame: .zero)
        #expect(setGlassValue(1, forKey: "_variant", on: view) == false)
        #expect(setGlassValue(1, forKey: "_scrimState", on: view) == false)
        #expect(setGlassValue("nope", forKey: "definitelyNotAProperty", on: view) == false)
    }

    @Test("a real property still round-trips through KVC")
    func presentPropertyIsWritten() {
        // Without this the negative case above would also pass if the helper had
        // regressed into always returning false.
        let view = NSView(frame: .zero)
        #expect(setGlassValue(true, forKey: "hidden", on: view))
        #expect(view.isHidden)
    }
}
