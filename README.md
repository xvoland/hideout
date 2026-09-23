


<p align="center">
	<img width="200" height="200" margin-right="100%" src="img/icon_512@2x.png">
</p>
<p align="center">
<a href="https://github.com/xvoland/hidden/releases/latest">
		<img src="https://img.shields.io/badge/download-latest-brightgreen.svg"  alt="download">
  </a>
</p>

<p align="center">
<a href="https://dotoca.net/hideout">
 		<img height="96" src="https://github.com/xvoland/hideout/blob/master/img/qr.png" style="height: 80px" alt="PayPal, Gumroad, QR-codes etc donations">
  </a>
</p>

<p align="center">
	<img src="img/tutorial.gif">
</p>

> [!WARNING]
> **⚠️ UNOFFICIAL BUILD.** This is a community fork of [Hidden Bar](https://github.com/dwarvesf/hidden) maintained by **Vitalii Tereshchuk (xVoLAnD)** — https://dotoca.net, with added support for **macOS 27 Golden Gate**. It is **not** the official Dwarves Foundation release. The macOS 27 hide-mechanism fix originates from upstream [PR #396](https://github.com/dwarvesf/hidden/pull/396) by Skyler (skuthus). Download the fork build from the [Releases](https://github.com/xvoland/hideout/releases) page.

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
brew install --cask https://raw.githubusercontent.com/xvoland/hideout/main/Casks/hideout.rb
```

This pulls the latest macOS 27 "Golden Gate" build from the
[xvoland/hidden Releases](https://github.com/xvoland/hideout/releases) page. The
build is **unsigned**, so before the first launch run:

```
xattr -dr com.apple.quarantine /Applications/Hideout.app
```

> ⚠️ Do **not** use `brew install --cask hiddenbar` — that installs the upstream
> Dwarves Foundation release, which does **not** include the macOS 27 fork
> changes. The command above is the one for this fork.

#### Manual download

- [Download latest version](https://github.com/xvoland/hideout/releases/latest)
- Open and drag the app to the Applications folder.
- Launch Hidden and drag the icon in your menu bar (hold CMD) to the right so it is between some other icons.

## ⚙️ Hiding (macOS 27)

macOS 27 Golden Gate rebuilt the menu bar as a single window. Hiding is always native since v1.19: Hidden Bar asks macOS's private `MenuBarClientCore` (assessment mode) to keep only an allow-list visible. macOS does the hiding/reflow itself — independent of display width, notch, or front app.

Requirements: the **direct (non-sandboxed) build** on **macOS 27** (this GitHub/ad-hoc release, compiled with `HIDDENBAR_NATIVE_VISIBILITY=1`), plus **Accessibility** permission (prompted on first collapse). Where unavailable (sandboxed builds, pre-27), collapsing reports unavailable and the arrow stays put.

## 🤔 Why native hiding?

macOS historically had **no public API** to hide other apps' menu-bar icons. Hidden Bar used a geometry hack: inflate a separator `NSStatusItem` so icons to its left slide out of view.

| macOS era | What changed | Consequence |
|-----------|--------------|-------------|
| **≤ 26 (Ventura/Sonoma/Sequoia)** | Each status item = its own window. Inflating the separator pushes icons off-screen. | Geometry hiding worked. |
| **27 Golden Gate** | Menu bar became **one window** with a native overflow (`«`). Inflating past half the screen width **drops** the item instead of clamping, and length changes no longer displace neighbours. | Geometry hiding is dead on 27 — hiding must go through the system. |
| **27 + private API** | macOS 27 introduced `MenuBarClientCore` (assessment mode) — a private framework that can restrict the menu bar to an allow-list. | **Native hiding** — asks macOS to hide everything except the allow-list. Width-independent, notch-aware. |

Native requires the **direct (non-sandboxed) build**, macOS 27+, and Accessibility permission. It uses a private API Apple may change. For macOS ≤ 26, upstream `dwarvesf/hidden` remains the path.

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
