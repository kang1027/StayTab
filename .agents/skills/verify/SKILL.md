---
name: verify
description: Verify BetterCmdTab app changes at the live macOS surface. Use when a product-source diff needs end-to-end runtime evidence.
---

# Verify BetterCmdTab

A **witness** is a captured observation from the freshly built app after real
user input crosses every changed seam. Build and test results are setup; the
witness decides the verdict. Run the repository's narrow checks separately.

## 1. Bind the claim

Read the full requested range, including staged, unstaged, and branch commits.
Map every changed product file to:

1. the user action that reaches it; and
2. the observable outcome that should change or remain unchanged.

Treat tests as specifications for what to drive. A diff with no runtime surface
(docs, tests, or compile-time metadata only) is `SKIP`.

**Complete when:** every changed product file belongs to one explicit runtime
claim, or has an explicit reason it cannot affect runtime behavior.

## 2. Build and launch a witness process

Use the Debug lane by default. Use the Release lane for Liquid Glass/macOS 26,
release-configuration, updater-install, signing, or performance claims.

```bash
VERIFY_ROOT="$PWD/build/verify"
SCHEME="BetterCmdTab Debug"
CONFIGURATION="Debug"
PRODUCT="BetterCmdTab Debug"

# Release lane:
# SCHEME="BetterCmdTab"; CONFIGURATION="Release"; PRODUCT="BetterCmdTab"

DERIVED_DATA="$VERIFY_ROOT/DerivedData-$CONFIGURATION"
mkdir -p "$VERIFY_ROOT"
if ! xcodebuild -project BetterCmdTab.xcodeproj \
  -scheme "$SCHEME" -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" build \
  >"$VERIFY_ROOT/build.log" 2>&1; then
  tail -80 "$VERIFY_ROOT/build.log"
  exit 1
fi

APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/$PRODUCT.app"
EXEC="$APP/Contents/MacOS/$PRODUCT"
test -x "$EXEC"
```

Launch the bundle executable directly so the verification process gets isolated
preferences and config. Keep the state directory for any restart/persistence
check in this run.

```bash
STATE="$VERIFY_ROOT/state"
rm -rf "$STATE"
mkdir -p "$STATE/home" "$STATE/xdg"

CFFIXED_USER_HOME="$STATE/home" \
XDG_CONFIG_HOME="$STATE/xdg" \
"$EXEC" -GitHubUpdater.checkInterval manual \
  >"$VERIFY_ROOT/app.stdout.log" 2>&1 &
echo $! >"$VERIFY_ROOT/app.pid"
```

The installed BetterCmdTab and the witness compete for global shortcuts:

- For a Settings-only flow, the installed app may stay running; append
  `-BetterShortcuts_switchApps false -BetterShortcuts_switchWindows false` to
  the witness launch.
- For a switcher, shortcut-settings, window-management, or Release flow, ask
  before quitting the installed app. Record its executable path and restore it
  after verification.

Open Debug Settings through the running process with:

```bash
osascript -e 'tell application id "pro.bettercmdtab.BetterCmdTab.debug" to reopen'
```

The switcher becomes ready only after Accessibility trust. Panel appearance
after the real chord is the readiness check; if macOS prompts, grant access and
let `AccessibilityWaiter` observe it without restarting.

**Complete when:** the recorded PID resolves to `EXEC`, the intended surface is
driveable, verification state is outside the user's real defaults and XDG
config, and the installed app is either untouched or stopped with approval.

## 3. Drive the changed seam

Reach the behavior through its real boundary: CGEvent/Carbon input, an AppKit
control, a watched file, or an Accessibility window action. Calling an internal
Swift function is a test, not a witness.

| Changed area | Drive | Witness |
| --- | --- | --- |
| `Input/`, `Switcher/` | Hold and send the actual configured chord with System Events; use a real password field for Secure Event Input and ask the user for a real trackpad gesture | Cropped panel capture plus the selected/cancelled app or window outcome |
| `Settings/`, `Preferences` | Reopen Settings, operate the control, restart with the same isolated state, then exercise its downstream behavior | Restored control state and the changed live behavior |
| `Catalog/`, `Windows/` | Prepare named real apps/windows, open the switcher, then select or act on one | Visible rows and resulting frontmost app/window state |
| `ConfigFile`, import/export | Seed `$STATE/xdg/bettercmdtab/config.json` or use the real import/export UI | File contents and the live setting/behavior after reload |
| updater/About | Use the manual UI action against a safe target | UI result and relevant unified-log lines |
| hot-path performance | Drive the same scenario on base and changed Release builds under Instruments using the `Log.reveal` points of interest | Comparable sample counts and median/p95 latency, CPU, or allocation numbers |

Drive the claimed path once, then one adjacent probe suggested by the change:
cancel, repeat, stale state, empty input, rapid input, or the neighboring error
case. For a visual change, inspect the capture for clipping, stale/blank frames,
focus, contrast, and the macOS 13 fallback when that path changed.

Destructive actions use a temporary target or dry run. Publishing, notarizing,
installing an update, deleting user data, or changing shared system state
requires approval before the action.

**Complete when:** every runtime claim has an observed expected outcome and at
least one adjacent probe has an observed outcome at the same surface.

## 4. Preserve evidence and restore the machine

Capture the smallest useful window/region with `screencapture`; read every image
before using it as evidence. Capture nonvisual outcomes from app state or
Unified Logging filtered to the witness process. Keep the relevant output
inline; a local path alone is not evidence for a remote reader.

Quit the recorded witness PID gracefully so `applicationWillTerminate` restores
macOS symbolic hotkeys. Cleanup targets recorded PIDs and `$STATE` only. Restore
the exact installed app path when it was stopped with approval.

**Complete when:** each reported step has reviewed evidence, the witness process
is gone, temporary state is removed, and the installed app is back in its
original running/stopped state.

## 5. Report the verdict

```markdown
## Verification: <one-line claim>

**Verdict:** PASS | FAIL | BLOCKED | SKIP
**Build:** <scheme/configuration, ref, executable path>
**Claim:** <expected user-visible behavior>

### Runtime steps
1. ✅ <real action> → <observation and evidence>
2. 🔍 <adjacent probe> → <observation and evidence>

**Witness:** <attached screenshot or inline state/log excerpt>
**Findings:** <runtime surprises, friction, or “none”>
```

- `PASS`: every claim was witnessed and the probe held.
- `FAIL`: the running app contradicted a claim, regressed adjacent behavior, or
  produced ambiguous evidence.
- `BLOCKED`: the surface could not be reached; include the exact build,
  permission, automation, or environment failure.
- `SKIP`: no runtime surface exists; give the reason in one line.

**Complete when:** the verdict follows these definitions, every claim from step
1 is accounted for, and the evidence reaches the reader.
