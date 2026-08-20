cask "staytab" do
  version "0.1.1"
  sha256 "9ae20d89d711efb814395a3cdd178ee54475e1e0e75d3517b28935b50c261a08"

  url "https://github.com/kang1027/StayTab/releases/download/v#{version}/StayTab-#{version}-20260820192837.dmg"
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
