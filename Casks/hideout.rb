# Hideout (Golden Gate fork) - macOS 27 build
cask "hideout" do
  version :latest
  sha256 :no_check

  url "https://github.com/xvoland/hideout/releases/latest/download/Hideout.app.zip"
  name "Hideout"
  homepage "https://github.com/xvoland/hideout"

  app "Hideout.app"
end
