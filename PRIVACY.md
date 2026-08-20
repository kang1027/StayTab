# Privacy

StayTab is designed to work locally and does not operate an analytics or telemetry service.

## Data processed on the Mac

To build and operate the switcher, StayTab may read the following local information:

- running and installed application names, bundle identifiers, icons, and state;
- window titles, window identifiers, minimized state, Space placement, and focus state;
- browser-tab titles and URLs when the browser-tab features are enabled;
- the app order, pinned roster, shortcuts, and preferences you configure.

This information is used in memory or in local preference and configuration files. StayTab does not send app usage, window titles, browser history, shortcut input, or settings to the maintainer.

## Permissions

- **Accessibility** is required to observe the switching shortcut and focus or manage the selected window.
- **Automation** may be requested to select a browser tab when the relevant integration is enabled.
- **Full Disk Access** may be requested for browser-tab metadata that a browser stores in protected locations.

StayTab does not use these permissions to inspect document contents or collect user activity for a remote service.

## Network access

The only supported network request is an opt-in check for StayTab updates on GitHub Releases. No account is required. The app contains no advertising, analytics, or crash-reporting SDK.

## Screen sharing

The optional “Hide from screen sharing” setting marks the switcher window as non-shareable where supported by macOS. This is a best-effort platform control and should not be treated as a substitute for checking what a capture application is sharing.

## Questions

For ordinary privacy questions, use [GitHub Discussions](https://github.com/kang1027/StayTab/discussions). Report a security issue privately as described in [SECURITY.md](SECURITY.md).
