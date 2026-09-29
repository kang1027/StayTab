cask "staytab" do
  version "0.1.2"
  sha256 "148aecd0679197364f6b881093c71a915d42adcb7ed3bcfa104189341b4fbfc4"

  url "https://github.com/kang1027/StayTab/releases/download/v#{version}/StayTab-#{version}-20260929131026.dmg"
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
