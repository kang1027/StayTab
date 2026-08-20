# StayTab product scope

This document defines which parts of the inherited switching engine belong to StayTab's product promise and which remain advanced compatibility features.

## Core promise

StayTab gives frequent applications a stable, persistent home in Command-Tab.

1. Pinned apps remain visible and ordered after quitting.
2. Selecting a closed pinned app launches it from the same slot.
3. Temporary apps appear only while running and remain visually separate.
4. Quick Command-Tab preserves the native previous-app workflow.
5. The selected window receives keyboard focus without an additional click.
6. One-to-three-character jump keys provide predictable direct selection.

## Core settings

The default settings experience should prioritize:

- startup, updates, backup, and recovery;
- switch-app and switch-window shortcuts;
- pinned apps, app rules, ordering, and jump keys;
- the switcher layout and visual appearance;
- permissions, screen-sharing privacy, and project information.

## Advanced compatibility features

The following BetterCmdTab-derived capabilities remain supported but are not the primary StayTab workflow:

- per-shortcut profiles and scoped switching;
- direct app activation and window-arrangement shortcuts;
- detailed content, Space, minimized-window, search, mouse, and hover behavior;
- native and browser-tab expansion, previews, and tab-level recency;
- experimental trackpad gestures and specialized window-management actions.

These settings should move behind a clearly labeled Advanced surface instead of competing with pinned apps in the default navigation. Their stored preferences and runtime behavior must remain compatible when the information architecture changes.

## Non-goals

- replacing Spotlight or becoming a general application launcher;
- collecting app-usage analytics or syncing window history to a service;
- hiding macOS permission requirements or silently bypassing system controls;
- removing upstream copyright, license, or contribution history;
- expanding window management at the expense of reliable app switching.
