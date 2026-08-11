import AppKit
import ObjectiveC.runtime
import os

/// KVC-write a property on `NSGlassEffectView`, but only after proving both the
/// `@property` and its setter still exist. Everything here is either private API
/// or a public property Apple could still rename between macOS 26 betas:
/// `responds(to:)` catches a renamed setter and `class_getProperty` catches an
/// outright removal, which would otherwise turn the write into
/// `setValue:forUndefinedKey:` → NSUndefinedKeyException → SIGABRT.
/// Underscore keys work as-is: KVC maps `_variant` to `set_variant:`.
@discardableResult
func setGlassValue(_ value: Any, forKey key: String, on view: NSView) -> Bool {
    let setter = Selector("set" + key.prefix(1).uppercased() + key.dropFirst() + ":")
    guard view.responds(to: setter),
          key.withCString({ class_getProperty(type(of: view), $0) != nil }) else {
        Log.ui.warning("NSGlassEffectView has no settable '\(key, privacy: .public)', skipping")
        return false
    }
    view.setValue(value, forKey: key)
    return true
}

/// Picks the `NSVisualEffectView` material for the pre-macOS-26 fallback. These
/// raw values also exist as `NSGlassEffectView._variant`, but do not assume the
/// names describe what that private knob does: sweeping 0...23 on macOS 26 renders
/// only a handful of distinct materials, and `dock` measures as one of the most
/// transparent of them rather than as the Dock's own backdrop.
enum LiquidGlassVariant: Int, CaseIterable, Sendable {
    case regular = 0
    case clear = 1
    case dock = 2
    case appIcons = 3
    case widgets = 4
    case text = 5
    case avPlayer = 6
    case faceTime = 7
    case controlCenter = 8
    case notificationCenter = 9
    case monogram = 10
    case bubbles = 11
    case identity = 12
    case focusBorder = 13
    case focusPlatter = 14
    case keyboard = 15
    case sidebar = 16
    case abuttedSidebar = 17
    case inspector = 18
    case control = 19
    case loupe = 20
    case slider = 21
    case camera = 22
    case cartouchePopover = 23

    static var bestSupportedVariant: LiquidGlassVariant {
        if #available(macOS 26.2, *) {
            return .clear
        }
        return .regular
    }
}

enum ScrimState: Int {
    case off = 0
    case on = 1
}

enum SubduedState: Int {
    case normal = 0
    case subdued = 1
}
