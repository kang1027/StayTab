import Foundation
import os

/// Run a `@MainActor` teardown from a `deinit`.
///
/// A `deinit` is never actor-isolated — the last release can land on whatever
/// thread drops the final reference — so touching main-actor state from one
/// needs `MainActor.assumeIsolated`, which *traps* when that assumption is
/// wrong. Every owner in this app is main-owned today, so the assumption holds;
/// but a teardown backstop must not be the thing that takes the app down if it
/// ever stops holding. An off-main deallocation therefore skips the cleanup and
/// logs it, trading a leaked observer on a dying object for a crash on the
/// ⌘Tab hot path.
///
/// Called from `deinit`, so it must not resurrect `self`: pass only the cleanup
/// closure, never escape it.
func tearDownOnMainActor(
    _ cleanup: @MainActor () -> Void,
    file: StaticString = #fileID
) {
    guard Thread.isMainThread else {
        Log.ui.error("\(String(describing: file), privacy: .public): deallocated off the main thread, teardown skipped")
        return
    }
    MainActor.assumeIsolated(cleanup)
}
