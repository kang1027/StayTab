cask "staytab" do
  version "0.1.0"
  sha256 "329623b6b6f63c09611e02c880e208826a7839102347a00133ab439f16ccb46b"

  url "https://github.com/kang1027/StayTab/releases/download/v#{version}/StayTab-#{version}-20260820175413.dmg"
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
