cask "staytab" do
  version "0.2.0"
  sha256 "e0709435367badfafe209929af4acd271df65674118cb84b1641f10e9c129604"

  url "https://github.com/kang1027/StayTab/releases/download/v#{version}/StayTab-#{version}-20261029170810.dmg"
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
