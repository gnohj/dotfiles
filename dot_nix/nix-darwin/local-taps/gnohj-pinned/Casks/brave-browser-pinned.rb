cask "brave-browser-pinned" do
  version "1.91.168"
  sha256 "7b85fd3d16837c205f7e26631e0f8c5cd921bcbd0f9a2632fd90c6b52b14648c"

  url "https://github.com/brave/brave-browser/releases/download/v#{version}/Brave-Browser-arm64.dmg",
      verified: "github.com/brave/brave-browser/"
  name "Brave Browser"
  desc "Privacy-focused web browser, pinned to a specific version"
  homepage "https://brave.com/"

  # auto_updates true tells Homebrew that the app self-updates,
  # so `brew upgrade --cask` will skip it. We separately disable
  # Brave's in-app updater via system.defaults.CustomSystemPreferences.
  auto_updates true
  depends_on macos: :big_sur

  app "Brave Browser.app"

  uninstall quit:      [
              "com.brave.Browser",
              "com.brave.Browser.framework.AlertNotificationService",
              "com.brave.Browser.framework.NotificationService",
            ],
            launchctl: [
              "com.brave.Browser",
              "com.brave.Browser.helper.Renderer",
            ]

  zap trash: [
    "/Library/Caches/com.brave.Browser",
    "~/Library/Application Support/BraveSoftware",
    "~/Library/Caches/BraveSoftware",
    "~/Library/Caches/com.brave.Browser",
    "~/Library/Caches/com.brave.Browser.helper",
    "~/Library/HTTPStorages/com.brave.Browser",
    "~/Library/Preferences/com.brave.Browser.plist",
    "~/Library/Saved Application State/com.brave.Browser.savedState",
    "~/Library/WebKit/com.brave.Browser",
  ]
end
