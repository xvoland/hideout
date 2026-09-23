# Changelog

## v1.18.7 (2026-09-23)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Fixed
- Native collapse hides reliably on macOS 27: the allow-list always keeps Apple
  system host bundles (MenuBarAgent, Control Center, SystemUIServer), so Time
  Machine and similar Apple extras no longer vanish; the kept system-item
  window widened 64 → 4096.
- The arrow flips only on confirmed collapse; presses during native calibration
  are ignored instead of stacking superseded activations.
- Legacy no longer eats its own arrow: spacers verified at/after the arrow stay
  deflated, spacer blocks are removed on engine rebuild instead of leaking
  invisible items, and the block size is back to the full 10+10 that displaces.

### Changed
- Hiding diagnostics are readable (`log stream` shows plain text via an
  `AppLog` helper) and identify the exact code (`diagRev`), the resolved
  engine, per-collapse sections with coordinates, and Legacy order checks.
- Branch builds upload the test app as an artifact; `develop` pushes trigger CI.

### Known limitations
- Legacy length inflation is inert on macOS 27.0 (26A428): inflated items render
  (a blank gap on wide displays) but displace nothing — use Native on direct
  builds. Pre-27 behavior is unchanged.
- Items macOS cannot attribute to an app stay visible: team-prefixed ids
  (1Password helper), icons hosted in another process (Cotypist, SpamSieve),
  extras invisible to Accessibility. Apple system items are always kept.

## v1.18.6 (2026-09-23)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Fixed
- GitHub releases actually include native hiding now: CI built the sandboxed `Release` config (without `HIDDENBAR_NATIVE_VISIBILITY`), so Auto and Native silently fell back to Legacy and collapse hid nothing on macOS 27. CI now builds `Release-Direct`.
- Silent wrong-engine reports are gone: the factory logs preference/resolved/nativeAvailable at startup, and Legacy collapse logs its lengths and screens — a misbuilt app is now distinguishable from a broken engine.
- Diagnostics are readable: hiding-path logging moved from NSLog (rendered as `<private>` in `log stream`) to public unified logging via an `AppLog` helper.

### Changed
- `develop` pushes trigger CI and upload the test build (zip + DMG) as an artifact for 14 days; published releases remain tag-driven prereleases.

## v1.18.5 (2026-09-22)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Added
- Hiding-engine selector in Preferences (Auto / Native / Legacy). Auto uses native hiding on the direct macOS 27 build and falls back to Legacy otherwise; Native can be forced (rejected on sandboxed/pre-27 builds, with an explanation) and Legacy always works. The engine rebuilds live when changed. Native hiding is width-independent and fixes icons leaking from the system overflow on wide displays. See `docs/MANUAL.md` for what each mode does.

### Fixed
- The hiding-engine selector now actually appears in Preferences: its container outlet was never wired in the storyboard, so the control was silently dropped. It is connected to the Settings stack and the active segment is selected by index.
- Right-clicking the expand/collapse arrow now opens the same context menu as the separator, so Preferences is reachable from the control you already click.

### Changed
- Start-at-login now uses `SMAppService` (macOS 13+); the legacy launcher helper was removed and any leftover login item is deauthorized automatically on first launch.
- Pinned the HotKey dependency to an exact version and removed an unused file-access entitlement and dead code (no behavior change).

## v1.11 (unreleased)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Added
- Opt-in hover-to-expand: set `defaults write com.dwarvesv.minimalbar hoverToExpand -bool true` to expand the bar when the pointer dwells in the menu bar.
- Hiding-engine selector in Preferences (Auto / Native / Legacy) — see v1.18.5 for the shipped version.

### Fixed
- macOS 27 Golden Gate: hiding works again with the new single-window menu bar and native overflow button (#360). The separator stays under half the display width (macOS 27 drops items at that cliff) and spacer items cover wide and mixed-width displays; displaced icons go into the system `«` overflow instead of off-screen. macOS 27 Golden Gate support contributed by Vitalii Tereshchuk (https://dotoca.net) on this fork.
- Multi-display: the collapse width is now sized for the widest attached screen, so icons no longer leak on wider external monitors; the width re-applies on display hot-plug.
- Auto-collapse no longer fires while you are interacting with the menu bar (the timer defers and re-arms while the pointer is in the bar).
- The Preferences window no longer closes when auto-collapse fires with "use full menu bar on expanding" enabled (#170, #66, #151).
- Status items that were dragged off the bar are restored at launch instead of leaving the app unreachable.
- Fixed constraint and observer leaks in the tutorial view rebuild.
- Tutorial strings and F-key shortcut labels now render correctly (no more private-use glyphs).

### Changed
- Start-at-login now uses `SMAppService` (macOS 13+); the legacy launcher helper was removed and any leftover login item is deauthorized automatically on first launch.
- Pinned the HotKey dependency to an exact version and removed an unused file-access entitlement and dead code (no behavior change).

### Known / in progress
- New menu-bar icons can appear in the hidden zone because macOS inserts them at the far left; ⌘-drag them to the right of the separator (see the manual). A built-in pin is part of the planned redesign.
- On macOS 27 the always-hidden separator still inflates as a single unit, so with the regular section expanded its icons can show on a very wide display.
