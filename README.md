<p align="right">
<a href="https://dotoca.net">
 		<img height="80" src="https://github.com/xvoland/xvoland/blob/main/images/paypal.png" alt="PayPal donations">
  </a>
</p>


> **⚠️ UNOFFICIAL BUILD.** This is a community fork of [Hidden Bar](https://github.com/dwarvesf/hidden) maintained by **Vitalii Tereshchuk (xVoLAnD)** — https://dotoca.net, with added support for **macOS 27 Golden Gate**. It is **not** the official Dwarves Foundation release. The macOS 27 hide-mechanism fix originates from upstream [PR #396](https://github.com/dwarvesf/hidden/pull/396) by Skyler (skuthus). Download the fork build from the [Releases](https://github.com/xvoland/hideout/releases) page.

<p align="center">
	<img width="200" height="200" margin-right="100%" src="img/icon_512@2x.png">
</p>
<p align="center">
<a href="https://github.com/xvoland/hidden/releases/latest">
		<img src="https://img.shields.io/badge/download-latest-brightgreen.svg" alt="download">
  </a>
</p>

## Maintainer (this fork)

| Role | Name | Contact |
| --- | --- | --- |
| Fork maintainer, build & macOS 27 verification | Vitalii Tereshchuk (xVoLAnD) | https://dotoca.net |

Upstream project: [dwarvesf/hidden](https://github.com/dwarvesf/hidden) © Dwarves Foundation. The macOS 27 Golden Gate hide-mechanism fix originates from upstream [PR #396](https://github.com/dwarvesf/hidden/pull/396) by Skyler (skuthus); this fork packages, builds, and verifies it for macOS 27.

## Hideout
Hideout lets you hide menu bar items to give your Mac a cleaner look.

<p align="center">
	<img width="400" src="img/screen1.png">
	<img width="400" src="img/screen2.png">
</p>

## 🚀 Install

###  App Store

[![AppStore](img/appstore.svg)](https://itunes.apple.com/app/hidden-bar/id1452453066)

### Others

The Hideout is notarized before distributed out side App Store. It's safe to use 👍

#### Using Homebrew

This fork ships its own Homebrew cask so you install **this** build — not the
upstream one:

```
brew install --cask https://raw.githubusercontent.com/xvoland/hidden/main/Casks/hideout.rb
```

This pulls the latest macOS 27 "Golden Gate" build from the
[xvoland/hidden Releases](https://github.com/xvoland/hidden/releases) page. The
build is **unsigned**, so before the first launch run:

```
xattr -dr com.apple.quarantine /Applications/Hidden\ Bar.app
```

> ⚠️ Do **not** use `brew install --cask hiddenbar` — that installs the upstream
> Dwarves Foundation release, which does **not** include the macOS 27 fork
> changes. The command above is the one for this fork.

#### Manual download

- [Download latest version](https://github.com/xvoland/hidden/releases/latest)
- Open and drag the app to the Applications folder.
- Launch Hidden and drag the icon in your menu bar (hold CMD) to the right so it is between some other icons.

## 🕹 Usage

* `⌘` + drag to move the Hidden icons around in the menu bar.
* Click the Arrow icon to hide menu bar items.

<p align="center">
	<img src="img/tutorial.gif">
</p>

## 📚 Documentation

- [Manual](docs/MANUAL.md): every setting, the hidden Terminal-only options, and troubleshooting.
- [Architecture](docs/ARCHITECTURE.md): how the hiding trick works, topology, and known limits.
- [Maintainer runbook](docs/RUNBOOK.md): build, behavioral verification, and release process.

## ✨<a href="https://github.com/xvoland/hidden/graphs/contributors">Contributors</a>

This project exists thanks to all the people who contribute. Thank you guys so much 👏

[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/0)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/0)[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/1)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/1)[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/2)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/2)[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/3)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/3)[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/4)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/4)[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/5)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/5)[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/6)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/6)[![](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/images/7)](https://sourcerer.io/fame/phucledien/dwarvesf/hidden/links/7)

Please read [this](CONTRIBUTING.md) before you make a contribution.

## Requirements
macOS version >= 13.0 (Ventura)

Running an older macOS? The last release supporting macOS 10.13 High Sierra
through 12 Monterey is [upstream v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10)
(published by the original Dwarves Foundation project; this fork does not ship
pre-Ventura builds). Later versions require macOS 13 because autostart moved to the
`SMAppService` API introduced there.

## You may also like
- [Blurred](https://github.com/dwarvesf/Blurred) - A macOS utility that helps reduce distraction by dimming your inactive noise
- [Micro Sniff](https://github.com/dwarvesf/micro-sniff) - An ultra-light macOS utility that notify whenever your micro-device is being used
- [VimMotion](https://github.com/dwarvesf/VimMotionPublic) Vim style shortcut for MacOS
## License

MIT &copy; [Dwarves Foundation](https://github.com/dwarvesf)
