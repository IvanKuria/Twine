cask "twine" do
  version "0.1.0"

  # Replace PLACEHOLDER with the SHA-256 printed by scripts/build-dmg.sh:
  #   shasum -a 256 build/Twine-0.1.0.dmg
  sha256 "PLACEHOLDER"

  url "https://github.com/IvanKuria/Twine/releases/download/v#{version}/Twine-#{version}.dmg"
  name "Twine"
  desc "Visualise everywhere you have been — a poster-quality travel map for Mac"
  homepage "https://github.com/IvanKuria/Twine"

  app "Twine.app"

  zap trash: [
    "~/Library/Preferences/com.ivankuria.twine.plist",
    "~/Library/Caches/com.ivankuria.twine",
    "~/Library/Application Support/Twine",
    "~/Library/Saved Application State/com.ivankuria.twine.savedState",
    "~/Library/HTTPStorages/com.ivankuria.twine",
  ]
end
