#!/usr/bin/env bash
# Render a checksummed Homebrew Cask from a published StayTab DMG.
set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
	echo "Usage: scripts/render_homebrew_cask.sh <dmg> <version> <build> [output]" >&2
	exit 64
fi

dmg="$1"
version="$2"
build="$3"
output="${4:-Casks/staytab.rb}"

[[ -f "$dmg" ]] || { echo "DMG not found: $dmg" >&2; exit 1; }
[[ "$version" =~ ^[0-9]+(\.[0-9]+)+$ ]] || { echo "Invalid stable version: $version" >&2; exit 64; }
[[ "$build" =~ ^[0-9]+$ ]] || { echo "Invalid build number: $build" >&2; exit 64; }

sha256="$(shasum -a 256 "$dmg" | awk '{print $1}')"
output_dir="$(dirname "$output")"
mkdir -p "$output_dir"
tmp="${output}.tmp"

cat >"$tmp" <<EOF
cask "staytab" do
  version "${version},${build}"
  sha256 "${sha256}"

  url "https://github.com/kang1027/StayTab/releases/download/v#{version.csv.first}/StayTab-#{version.csv.first}-#{version.csv.second}.dmg",
      verified: "github.com/kang1027/StayTab/"
  name "StayTab"
  desc "Persistent app roster and launcher for Command-Tab switching"
  homepage "https://github.com/kang1027/StayTab"

  livecheck do
    url :url
    strategy :github_latest
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on macos: :ventura

  app "StayTab.app"

  zap trash: [
    "~/.config/staytab",
    "~/Library/Application Support/StayTab",
    "~/Library/Caches/com.kdh.StayTab",
    "~/Library/Preferences/com.kdh.StayTab.plist",
    "~/Library/Saved Application State/com.kdh.StayTab.savedState",
  ]
end
EOF

mv "$tmp" "$output"
echo "Rendered ${output} (${version}, build ${build})"
