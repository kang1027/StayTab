# StayTab product scope

This document defines which parts of the inherited switching engine belong to StayTab's product promise and which remain internal compatibility features.

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

## Inherited compatibility features

The following BetterCmdTab-derived capabilities remain readable at runtime for existing or imported configurations, but are not part of StayTab's settings surface:

- per-shortcut profiles and scoped switching;
- direct app activation and window-arrangement shortcuts;
- detailed content, Space, minimized-window, search, mouse, and hover behavior;
- native and browser-tab expansion, previews, and tab-level recency;
- experimental trackpad gestures and specialized window-management actions.

The inherited Shortcuts, Controls, and Tabs panes are intentionally not registered. StayTab exposes only the app/window switch triggers instead of the previous multi-profile editor. Stored preferences remain compatible so an upgrade does not silently rewrite an existing configuration.

## Non-goals

- replacing Spotlight or becoming a general application launcher;
- collecting app-usage analytics or syncing window history to a service;
- hiding macOS permission requirements or silently bypassing system controls;
- removing upstream copyright, license, or contribution history;
- expanding window management at the expense of reliable app switching.
