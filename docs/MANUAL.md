# Manual

Everything Hidden Bar can do, including the parts with no UI.

## Basics

- **Left-click the arrow** (`<` / `>`): expand or collapse the hidden section.
- **Right-click the arrow** or **left-click the separator** (`|`): context menu
  (Preferences, Toggle Auto Collapse, Quit).
- **⌘-drag** icons in the menu bar to move them across the separator: icons to
  the separator's left are hidden when collapsed.
- **Option-click the arrow**: show/hide the separators and the always-hidden
  area without expanding.

## Preferences window

| Setting | What it does |
|---|---|
| Start Hidden Bar when I log in | Login item via System Settings (macOS 13+ `SMAppService`); revocable in System Settings > General > Login Items |
| Show preferences on launch | Open this window at app start |
| Auto collapse | Re-hide automatically after the chosen delay |
| Global shortcut | System-wide expand/collapse hotkey (F-keys display as F18, not Fn18) |
| Enable always hidden section | A second zone whose icons stay hidden even when expanded; revealed by option-clicking the arrow |
| Use full menu bar on expanding | App becomes briefly "regular" while expanded (helps on tight menubars) |


> **Always-hidden section:** enabling it hides the separators once, so the zone
> holds even when expanded — no option-click needed. To arrange it,
> option-click the arrow to show the separators (everything becomes visible
> for ⌘-dragging), then option-click again to re-hide and re-enforce. If
> hiding does nothing, the always-hidden separator is misplaced: ⌘-drag it
> left of the arrow and retry (the log says so explicitly). Avoid placing
> critical icons in the always-hidden zone: a stuck off-screen item has to be
> recovered by ⌘-dragging it back (macOS persists its position per app).

## Hiding (macOS 27)

Hiding is always native since v1.19 (the engine selector was removed): macOS
itself keeps only an allow-list of status items visible, using the private
`MenuBarClientCore` framework (assessment mode). macOS does the hiding and
the reflow, so:

- hiding is **independent of display width, the notch, and the frontmost app's
  menus**;
- it requires the **direct build** of Hidden Bar (the GitHub/ad-hoc, unsigned
  release) on **macOS 27**, plus the **Accessibility** permission (read once,
  to learn which apps you placed in each section). On the first collapse macOS
  prompts you; until granted, hiding reports "unavailable" and the bar is left
  expanded rather than half-hidden. On builds without the native API
  (sandboxed, pre-27) collapsing reports unavailable and the arrow stays put;
- hiding is **per app bundle** for classification: if an app has several icons,
  they all hide or show together (the most-visible icon wins). What stays is
  decided by the allow-list (own, visible-section, hosts, indices) — Apple
  bundle extras hide like normal apps; indexed/host system items (clock,
  Wi-Fi, Bluetooth, battery, Control Center, …) stay. To remove those, use
  System Settings → Control Center ("Don't show in menu bar");
- everything left of the separator hides on collapse: macOS hides every item not
  on the allow-list — app bundles, helper ids and hosted icons alike, given
  reflow time. Allow longer than feels necessary before judging: the
  Accessibility snapshot alone takes up to ~10s and macOS reflows after
  activation. Only indexed/host system items stay, unconditionally;
- sections are read only while the bar is expanded, so an app launched while
  collapsed stays hidden until the next read.

## Behaviors you get for free

- **It won't collapse mid-use**: while your pointer is anywhere in the menu bar,
  the auto-collapse countdown defers and restarts; it resumes when you leave.
- **Self-repair**: if the arrow or separator was ⌘-dragged off the bar (which
  used to make the app unreachable forever), they come back on next launch.
- **Display changes**: plugging in or removing monitors drops the cached
  sections; they are re-read from the unrestricted bar on the next collapse.

## Hidden settings (Terminal)

All via `defaults`; quit and relaunch the app after changing them.

```sh
# expand by hovering the menu bar for ~0.5s (off by default)
defaults write net.dotoca.hideout hoverToExpand -bool true

# auto-collapse delay in seconds (the UI offers a fixed list; any value works)
defaults write net.dotoca.hideout numberOfSecondForAutoHide -float 5

# force the app language regardless of system order (issue #287)
defaults write net.dotoca.hideout AppleLanguages '(en)'
```

To undo any of them: `defaults delete net.dotoca.hideout <key>`.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Icons I want visible got hidden after an update | ⌘-drag them to the right of the separator |
| Login item missing after denying it once | System Settings > General > Login Items: re-enable Hidden Bar, then toggle the pref off/on |
| A ghost "LauncherApplication" login item from old versions | Launch the current version once; it deauthorizes the legacy item automatically |
| App language stuck | See the `AppleLanguages` command above, or System Settings > General > Language & Region > Applications |
| Nothing hides on macOS 27 after upgrading Hidden Bar | ⌘-drag icons to the right of the separator once. macOS 27 uses new item names so positions reset like a fresh install |
| Nothing hides after updating to v1.20.6+ | Same one-time arrangement: the separator got a fresh slot next to the arrow (its old slot went stale while it stayed invisible). ⌘-drag the `\|` where you want the boundary, then collapse |
| Hidden icons on macOS 27 appear under the system `«` chevron while collapsed | Expected: macOS 27's native overflow is where displaced icons go. Click Hidden Bar's arrow to bring them back onto the bar |
| A new or just-updated app's icon shows up already hidden | Expected, see "Why new icons start hidden" below; ⌘-drag it to the right of the separator once |
| App won't open: "damaged" or "unidentified developer" | The fork build is **unsigned**. Remove the quarantine flag before first launch: `xattr -dr com.apple.quarantine /Applications/Hidden\ Bar.app`, then open it |

### Why new icons start hidden

Hidden Bar hides icons by widening its separator so everything to the *left* of
it slides off-screen. macOS always inserts a brand-new menu-bar icon at the
far-left slot, which is inside that hidden zone, so a freshly launched or updated
app can appear "swallowed". This is macOS positioning behavior, not Hidden Bar
moving your icon: there is no way for one app to reposition another app's menu-bar
icon. The one-time fix is to ⌘-drag the icon to the right of the separator;
macOS remembers that placement per app. A built-in way to keep chosen icons
pinned is being explored as part of the larger menu-bar redesign.

## Requirements

macOS 13 Ventura or later. Pre-Ventura (10.13 - 12.x): use
[upstream release v1.10](https://github.com/dwarvesf/hidden/releases/tag/v1.10), the last
release published by the original Dwarves Foundation project (the fork does not ship pre-Ventura builds).
