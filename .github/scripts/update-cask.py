#!/usr/bin/env python3
"""Regenerate Casks/hideout.rb pinned to a release tag and artifact sha256.

Usage: update-cask.py <tag> <version> <sha256>
Example: update-cask.py v1.25.0 1.25.0 78451e13...
Called by CI on full (non-prerelease) `v*` tags so tap users can
`brew update && brew upgrade hideout`.
"""
import sys
from pathlib import Path

TEMPLATE = """\
# Hideout (Golden Gate fork) — macOS 27 menu-bar hiding.
#
# NOTE: version + sha256 are pinned by CI on every full `vX.Y.Z` release tag
# (see .github/workflows/build.yml, "Pin cask version + sha256"). Do not edit.
# Homebrew does not apply the quarantine attribute to cask installs, so this
# ad-hoc-signed app runs with no Gatekeeper prompt and no `xattr` cleanup.
cask "hideout" do
  version "{version}"
  sha256 "{sha256}"

  url "https://github.com/xvoland/hideout/releases/download/v#{{version}}/Hideout.app.zip"
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
"""


def main() -> None:
    if len(sys.argv) != 4:
        sys.exit(f"Usage: {sys.argv[0]} <tag> <version> <sha256>")
    tag, version, sha256 = sys.argv[1:4]
    path = Path(__file__).resolve().parent.parent.parent / "Casks" / "hideout.rb"
    path.write_text(TEMPLATE.format(tag=tag, version=version, sha256=sha256))
    print(f"--- Generated {path} ({tag}, {sha256}) ---")
    print(path.read_text(), end="")


if __name__ == "__main__":
    main()
