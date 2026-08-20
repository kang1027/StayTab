#!/usr/bin/env bash
# Copy the StayTab BetterUpdater private key from macOS Keychain to GitHub Actions.
set -euo pipefail

repo="${1:-kang1027/StayTab}"
service="StayTab BetterUpdater Signing Key"
account="kang1027"

command -v gh >/dev/null 2>&1 || { echo "gh CLI is required" >&2; exit 1; }
gh auth status >/dev/null
gh repo view "$repo" --json nameWithOwner >/dev/null

if ! security find-generic-password -a "$account" -s "$service" >/dev/null 2>&1; then
	echo "Keychain entry not found: ${service}" >&2
	exit 1
fi

# gh reads the secret from stdin. The private key is never printed or placed in
# a command-line argument where another process could inspect it.
security find-generic-password -w -a "$account" -s "$service" |
	gh secret set BETTERUPDATER_PRIVATE_KEY --repo "$repo"

echo "Configured BETTERUPDATER_PRIVATE_KEY for ${repo}"
