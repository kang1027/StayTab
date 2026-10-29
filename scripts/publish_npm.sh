#!/usr/bin/env bash
# Publish the `staytab` npm installer for a published GitHub release tag.
# The installer fetches the release matching its own version, so the version
# comes from the tag. Prereleases go to the `beta` dist-tag.
set -euo pipefail

if [[ $# -lt 1 ]]; then
	echo "Usage: scripts/publish_npm.sh <tag> [npm publish options, e.g. --dry-run]" >&2
	exit 64
fi

tag="$1"
shift
version="${tag#v}"
[[ "$tag" == v* && "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$ ]] || {
	echo "Invalid release tag: $tag" >&2
	exit 64
}

dist_tag="latest"
[[ "$version" == *-* ]] && dist_tag="beta"

if npm view "staytab@${version}" version >/dev/null 2>&1; then
	echo "staytab@${version} is already on npm"
	exit 0
fi

zips="$(gh release view "$tag" --repo kang1027/StayTab --json assets \
	--jq '[.assets[].name | select(test("^StayTab-.+\\.zip$"))] | length')"
[[ "$zips" == 1 ]] || {
	echo "Release $tag should carry one StayTab zip; found $zips" >&2
	exit 1
}

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -R "$root/npm/." "$work/"
cp "$root/LICENSE" "$work/LICENSE"
(cd "$work" && npm version "$version" --no-git-tag-version --allow-same-version >/dev/null)
(cd "$work" && npm publish --access public --tag "$dist_tag" "$@")
