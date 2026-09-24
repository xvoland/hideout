# Changelog

## v1.20.10 (2026-09-24)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Fixed
- Never hide on a blind snapshot. An empty menu-bar census (cold AX server,
  timeouts at login) resolved to empty sections and latched an allow-list that
  hides everything — re-applied from cache on every later expand/collapse, so
  all icons stayed gone after launch. Both activation paths now refuse an empty
  inventory and fail open instead (collapse reports unavailable, expanded
  presentation leaves the bar unrestricted) (diagnostics `diagRev=19`).

## v1.20.9 (2026-09-24)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Fixed
- Option-click now works on all three bar items (arrow and both `|` separators),
  not just the arrow. Previously only the arrow had a click handler, so
  option-clicking a separator went nowhere and there was no way to reveal the
  always-hidden zone for arranging if you missed the arrow. Plain clicks keep
  their documented behavior (arrow toggles, separator opens the menu); the
  toggle path and the expanded hold/release decision are now logged
  (diagnostics `diagRev=18`).

## v1.20.8 (2026-09-24)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Fixed
- "Always Hidden" now works out of the box. The zone only holds while expanded
  when separators are hidden, but nothing ever hid them for you — if you never
  option-clicked, every expand released the restriction and the icons were
  always visible. Enabling the section now hides the separators once (later
  option-clicks untouched); option-click itself was reordered to expand first
  so its placement guard reads live geometry instead of silently no-op'ing
  from a collapsed bar (a block is now logged explicitly) (diagnostics
  `diagRev=17`).

## v1.20.7 (2026-09-24)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Fixed
- "Always Hidden" icons no longer pop back visible on their own. Two leaks fed
  them into the allow-list: (1) every process launch was tracked for 120s, so
  helpers/agents that restart often (1Password, SpamSieve, Atoll…) were
  unioned into every restriction and immediately re-shown while collapsed —
  now only bundles never classified at the last collapse are tracked, the rest
  keep their zone; (2) collapsing while a restriction was already held
  (expanded with separators hidden + always-hidden on) recorded an empty
  bundle baseline, after which the newcomer watch treated everything as new —
  now the live inventory (identity stays reliable under a restriction) seeds
  the baseline while sections stay cached (diagnostics `diagRev=16`).

## v1.20.6 (2026-09-24)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Fixed
- Collapse hides again. v1.20.5 restored the separator as the boundary, but its
  autosave slot had gone stale while it stayed invisible (v1.19–v1.20.4) —
  parked far left of the arranged icons, so the whole bar classified visible
  and nothing hid. The separator now uses a fresh slot name and lays out
  adjacent to the arrow; one-time ⌘-drag of the `|` to taste, then collapse
  (diagnostics `diagRev=15`, census logs `sepX=`).

## v1.20.5 (2026-09-24)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Fixed
- The regular `|` separator is visible again and is the hidden/visible
  boundary once more (upstream UX): ⌘-drag icons across it, left-click it for
  the context menu. Since v1.19 the code classified against the arrow while the
  separator stayed invisible, so dragging icons across the only visible `|`
  (the always-hidden one) changed nothing on collapse — exactly the reported
  "nothing happens". The boundary now reads the separator frame (cached while
  collapsed, arrow as last-resort fallback), both separators show while
  expanded, and the manual matches the behavior again (diagnostics `diagRev=14`).

## v1.20.4 (2026-09-24)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Fixed
- "Always hide" section now keeps working across collapse cycles. On macOS 27
  the whole menu bar is one window, and the always-hidden separator at zero
  length reports a collapsed (neighbour-snapped) frame, so the second collapse
  re-classified the always-hidden zone from the wrong position — icons you had
  parked there started behaving like ordinary hidden icons. The separator frame
  is now cached while it has real length (expanded, or before a collapse hides
  it) and reused for the next census instead of the collapsed live frame
  (diagnostics `diagRev=13`).

## v1.20.3 (2026-09-24)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Fixed
- Newly launched icons now appear within a few seconds of launch instead of
  waiting for the next manual collapse. Agent apps (LSUIElement, e.g.
  BetterDisplay) never post `didLaunch`, so they can only be caught by re-scanning
  the bar — the newcomer watch now polls every 3s for as long as the bar stays
  collapsed (previously a handful of one-off checks +12/+30/60/120s, which is why
  an icon could surface only minutes later). Any bundle absent from the last
  collapse census is re-allowed; the next collapse re-reads everything from a
  fresh bar, so a wrongly shown icon self-heals (diagnostics `diagRev=12`).

## v1.20.2 (2026-09-24)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Fixed
- Newly launched apps now show their icon without expanding first. The previous
  positional newcomer watch was blind: hidden items report stale frames while
  the restriction is active, so a freshly hidden icon could never be told apart
  from a new one. The signal is now the bundle set — any bundle absent from the
  last collapse census is re-allowed, which also covers launches that predate
  the observer and icons that appear without a process launch (diagnostics
  `diagRev=11`).

## v1.20.1 (2026-09-24)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Added
- Icons of newly launched apps appear without expanding first. Launches are
  observed via NSWorkspace and remembered for 120 seconds; while collapsed,
  the restriction is re-activated to include them, and a positional newcomer
  watch (+12/+30/+60/+120s) additionally catches slow starters and icons that
  appear without a fresh process launch. The next collapse re-classifies
  everything from a fresh census, so a wrongly shown icon self-heals.

## v1.20.0 (2026-09-23)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

### Changed
- **Rebrand to Hideout identity**: bundle id `com.dwarvesv.minimalbar` →
  `net.dotoca.hideout`, status-item slots `hiddenbar_*` → `hideout_*`.
  Settings auto-migrate on first launch (the old domain is copied, never
  modified — downgrading keeps the old settings). Two things cannot migrate
  and need one manual step each: re-grant Accessibility in System Settings
  (macOS ties it to the bundle id and re-prompts automatically), and ⌘-drag
  icons into place once (slot positions reset with the new names). Upstream
  attribution (Dwarves Foundation, dwarvesf/hidden, skuthus) is unchanged.

### Removed
- Legacy hiding engine and the Hiding engine selector: hiding is always native
  since v1.19 (direct macOS 27 builds). Pre-27 and sandboxed builds report
  hiding unavailable instead of silently falling back; upstream
  dwarvesf/hidden remains the path there.

(Re-released 2026-09-23 on updated code: that build also ships the stable-only
update checker (launch + weekly, manual check in Preferences), UI grammar
fixes, and the remaining visible rebrand leftovers.)

## v1.18.8 (2026-09-23)

Requires macOS 13 Ventura or later. (Pre-Ventura users: stay on
[v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10).)

First full (non-test) Golden Gate release.

### Changed
- Verified Legacy behavior documented honestly (notch displays vs wide
  notchless externals) in the engine note, the manual and the backlog.
- Release process: `vX.Y.Z-goldengate-test` tags keep publishing as
  prereleases; clean `vX.Y.Z` tags now publish as full releases.

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
