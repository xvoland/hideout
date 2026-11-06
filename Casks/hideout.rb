# Hideout (Golden Gate fork) — macOS 27 menu-bar hiding.
#
# NOTE: version + sha256 are pinned by CI on every full `vX.Y.Z` release tag
# (see .github/workflows/build.yml, "Pin cask version + sha256"). Do not edit.
# Homebrew does not apply the quarantine attribute to cask installs, so this
# ad-hoc-signed app runs with no Gatekeeper prompt and no `xattr` cleanup.
cask "hideout" do
  version "1.25.0"
  sha256 "49c7943424fd675f4d7bc17f8026dc1484982326abd0a0c5b2281086da7e9e0d"

  url "https://github.com/xvoland/hideout/releases/download/v#{version}/Hideout.app.zip"
  name "Hideout"
  desc "Menu bar app that hides macOS menu-bar icons (macOS 27 fork of Hidden Bar)"
  homepage "https://github.com/xvoland/hideout"

  depends_on macos: :ventura

  app "Hideout.app"

  zap trash: [
    "~/Library/Application Support/net.dotoca.hideout",
    "~/Library/Preferences/net.dotoca.hideout.plist",
  ]
end
