# staytab

Installs [StayTab](https://github.com/kang1027/StayTab), a macOS ⌘Tab switcher that keeps your pinned apps in place, even after you quit them.

```sh
npx staytab
```

The installer downloads the StayTab release that matches this package's version from GitHub Releases. It installs the app into `/Applications` only after `codesign` confirms StayTab's Developer ID signature and Gatekeeper accepts the notarized app. It then opens StayTab. On first launch, grant Accessibility access when macOS asks.

| Option | Effect |
| --- | --- |
| `--dir <path>` | Install into another folder, such as `~/Applications` |
| `--force` | Reinstall even if this version is already installed |
| `--no-open` | Don't launch StayTab afterwards |

You only need the installer once. After that, StayTab updates itself from **Settings → General → Check for updates**.

Requires macOS 13 Ventura or later and Node.js 18.3 or later. StayTab is GPL-3.0 software, a modified distribution of [BetterCmdTab](https://github.com/rokartur/BetterCmdTab).
