---
name: release
description: Ship a StayTab release end to end. Use when the user wants a new version or beta published on GitHub.
---

# Release runbook

`RELEASING.md` holds the one-time setup and the publish checklist; this skill
is the order of operations and the failure points around it.

## 1. Preflight

Working tree clean on `main`, `HEAD` equal to `origin/main`, App CI green, and
the unit suite green:

```bash
xcodebuild -scheme "StayTab Debug" -destination 'platform=macOS' test
```

`scripts/set_version.sh --show` prints the current version. Tags are
`v<version>` for stable (`v0.1.1`) and `v<version>-beta.<n>` for betas.

## 2. Bump the version (stable releases)

```bash
scripts/set_version.sh <version>            # edits project.pbxproj only
scripts/set_version.sh <version> --commit   # also commits just that file
```

Push the bump before packaging: `--auto-release` refuses a `HEAD` that differs
from `origin/main`. Skip this for betas — `build_release.sh --beta` derives the
next `beta.N` from the existing GitHub release tags.

## 3. Write the notes

Produce the release body with the `release-changelog` skill and save it to a
file (e.g. `notes.md` in the scratchpad). It follows the changelog format in
`CLAUDE.md` and keeps the GPL-3.0 / BetterCmdTab attribution.

## 4. Build, sign, notarize

```bash
scripts/build_release.sh --clean          # stable
scripts/build_release.sh --beta --clean   # beta
```

The first step is `scripts/release_quality_gate.sh`: a Release-configuration
compile that fails on high-risk concurrency/Sendable warnings, plus (stable
only) the localization audit — fix the reported issue, don't bypass the gate.
Signing needs the `Developer ID Application: DongHyeon Kang (GGR9HG6DB8)`
certificate and the `StayTabNotarization` notarytool profile. Without them use
`--skip-notarization` (local test package only — it refuses `--auto-release`).

Artifacts land in `build/release/`. Each build stamps a timestamp
`CURRENT_PROJECT_VERSION` into the archive without editing the project
(`--build-number` overrides it). Install the DMG and check it by hand before
publishing.

## 5. Publish

Publishing is outward-facing: confirm with the user first.

```bash
scripts/build_release.sh --skip-build --auto-release --notes-file notes.md          # stable
scripts/build_release.sh --beta --skip-build --auto-release --notes-file notes.md   # beta (prerelease)
```

This reuses the verified package, requires the `BETTERUPDATER_PRIVATE_KEY`
Actions secret, and creates the `v…` tag and GitHub Release on
`kang1027/StayTab`. It never commits or pushes. `sign-release.yml` then
attaches the signed BetterUpdater manifest, and for stable releases
`update-homebrew-cask.yml` refreshes `Casks/staytab.rb`.

**Complete when:** the GitHub release exists with the notarized DMG/ZIP and the
BetterUpdater manifest attached, and the notes match the changelog format.
