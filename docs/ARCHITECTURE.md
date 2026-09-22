# Architecture

Hidden Bar is a single-process AppKit menubar utility (~1.5k lines of
Swift, one dependency: [HotKey](https://github.com/soffes/HotKey)). There is no
helper app, no daemon, no network. Everything happens inside a handful of
`NSStatusItem`s (arrow, separator, optional always-hidden, plus macOS 27
spacers) and one window.

## The core trick

macOS offers no API to hide other apps' menubar icons. Hidden Bar fakes it with
geometry: a separator status item whose **length is inflated**, shoving every
icon to its left out of the visible bar. Collapsing and expanding is just
flipping that length between ~20pt and the inflated value.

On macOS 26 and earlier the inflated length is roughly twice the widest
attached screen, which pushes those icons off the left edge. On macOS 27 the
menu bar is one window with a native overflow (`«`), and the system **drops**
a status item whose length reaches half the display width. The collapse unit
is therefore sized just under half the **narrowest** attached screen, and
zero-length spacer items between the separator and the arrow inflate with it
so the total span still covers a wide or mixed-width setup. Icons the
separator displaces go into the system overflow menu rather than off-screen.

```mermaid
flowchart LR
    subgraph menubar [menu bar, right to left]
        direction RL
        ARROW["arrow item\n(toggle, variable length)"]
        SPACERS["macOS 27 spacers\n(hidden expanded / collapse-unit collapsed)"]
        SEP["separator item\n20pt expanded / collapse-unit collapsed"]
        HIDDEN["other apps' icons\noff-screen (pre-27) or native overflow (27)"]
        ALWAYS["always-hidden separator\n(optional)"]
    end
    ARROW --- SPACERS --- SEP --- HIDDEN --- ALWAYS
```

Key consequences of this design:

- The menubar replicates on every display. On macOS 26 and earlier the collapse
  length derives from the **widest** screen (`NSScreen.screens`), never
  `NSScreen.main`. On macOS 27 it derives from the **narrowest** (the only cliff
  every bar's copy of the item can clear), with spacers covering the rest. It is
  re-applied to the live item on `didChangeScreenParametersNotification`
  (display hot-plug).
- Pre-27 the length is bounded: `max(500, min(widestFrameWidth * 2, 10_000))`.
  macOS enforces a hard 10,000pt maximum on `NSStatusItem.length`. On 27 each
  item stays under `narrowest/2 - 64`.
- `isCollapsed` is derived state: `separator.length > 20`, deliberately not an
  equality check, so it survives the length being recomputed while collapsed.
- Icons macOS inserts to the LEFT of the separator (where new status items
  appear) are in the hidden zone by default; that is inherent to the trick.

## Topology

```mermaid
flowchart TD
    AD[AppDelegate] -->|owns| SBC[StatusBarController]
    AD -->|registers| SM["SMAppService.mainApp\n(login item, macOS 13+)"]
    AD -->|global hotkey| HK[HotKey lib]
    SBC -->|3 status items| NSB[NSStatusBar.system]
    SBC -->|auto-hide| T["one-shot Timer\n(re-arms while pointer in menubar)"]
    SBC -->|opt-in| HM["global mouseMoved monitor\n(hover-to-expand, only if pref on)"]
    PREFS[Preferences facade] -->|UserDefaults| UD[(UserDefaults)]
    PREFS -->|posts| NC{{NotificationCenter\n.prefsChanged / .alwayHideToggle}}
    NC --> SBC
    PVC[PreferencesViewController] --> PREFS
    SBC -->|context menu| PVC
```

- **`AppDelegate`** (entry): registers default prefs, sets up the global hotkey,
  runs the one-shot legacy login-item migration, owns the `StatusBarController`.
- **`StatusBarController`** (the product, ~370 lines): the three status items,
  collapse/expand, auto-hide timer, interaction-awareness, hover-to-expand,
  self-restore of dragged-off items.
- **`Preferences`** (facade enum): typed accessors over `UserDefaults`; setters
  post `NotificationCenter` notifications that the controller and prefs window
  observe. There is no other state store.
- **`PreferencesViewController` / `PreferencesWindowController`**: the only
  window (storyboard-based), shown on demand from the context menu.

## Behavior layers on the core trick

| Layer | Mechanism | Cost when unused |
|---|---|---|
| Auto-hide | one-shot `Timer` after expand; at fire, if the pointer sits in any screen's menubar band (`visibleFrame.maxY ... frame.maxY`), it re-arms instead of collapsing | none (single point-in-rect check at fire) |
| Hover-to-expand (opt-in) | global `.mouseMoved` monitor + 0.5s dwell timer; installed only when the `hoverToExpand` default is true at launch | zero: monitor not installed |
| Self-restore | `isVisible = true` forced on our items at launch; Cmd-dragging them off otherwise bricks the app (its only UI is those items) | none |
| Always-hidden section | a second separator item; its own length games, gated by `alwaysHiddenSectionEnabled` | item not created |

## Hiding engine selection (macOS 27)

There are two engines; `MenuBarEngineFactory` picks one:

- **`NativeVisibilityEngine`** — used on the **direct, non-sandboxed** build
  (`HIDDENBAR_NATIVE_VISIBILITY` defined) on macOS 27. It asks macOS's private
  `MenuBarClientCore` (assessment mode) to keep only an allow-list of status items
  visible. Because macOS does the hiding and reflow itself, this is **independent
  of display width, the notch, and the frontmost app's menus** — it fixes the
  "icons slide in from the far left on wide displays" artifact of the legacy path.
  Requires the Accessibility permission (read via the AX API) and does not work
  inside the App Sandbox (the sandbox denies the `axserver` mach-lookup).
- **`LegacyLengthEngine`** — the spacer-inflation trick. Works on every build and
  macOS version, but on macOS 27 it is capped under half the **narrowest** screen,
  so on wide/mixed-width setups some icons cannot be covered and leak into the
  system `«` overflow.

The user chooses via a segmented control in Preferences
(`Preferences.menuBarEnginePreference`: `auto` / `native` / `legacy`). `auto`
(resolved at construction) takes native when the build offers it, else legacy.
Forcing `native` on a build that cannot (sandboxed / pre-27) is **rejected** and
falls back to legacy — the control shows why. Changing the preference rebuilds the
engine live (`.enginePreferenceChanged` → `StatusBarController.rebuildEngineIfNeeded`)
and restores the current collapsed/expanded state.

**Distribution consequence:** the GitHub/direct (ad-hoc, unsigned) build is compiled
with `HIDDENBAR_NATIVE_VISIBILITY`, so it offers native hiding. The App Store (or
any sandboxed) lane cannot ship native hiding — it stays on the legacy engine and
inherits the width limit.

| Mode | Mechanism | Width-independent? | Needs | Used on |
|---|---|---|---|---|
| Auto | resolves to Native or Legacy | depends on resolution | — | default; Native on direct 27 build, else Legacy |
| Native | allow-list via `MenuBarClientCore` | yes | direct (non-sandboxed) build + Accessibility | macOS 27 direct build |
| Legacy | spacer-length inflation | no (capped at narrowest/2 on 27) | nothing | every build; pre-27 and sandboxed/App Store |


## Autostart

macOS 13+ `SMAppService.mainApp`: the app registers itself; the login item is
visible and revocable in System Settings > General > Login Items. On first
launch after upgrade, a one-shot migration deauthorizes the legacy
`com.dwarvesv.LauncherApplication` helper registration (the BTM database never
garbage-collects those; see Apple TN3111). The helper app itself is gone.

## Security posture

The App Store (sandboxed) lane is sandboxed (`com.apple.security.app-sandbox`),
hardened runtime, no network entitlement, no file I/O, no IPC surface, no shell or
subprocess use. The direct/ad-hoc GitHub build is **not** sandboxed (it must reach
the Accessibility server and the private `MenuBarClientCore` for native hiding) and
is distributed unsigned (`xattr -dr com.apple.quarantine` after install). The only
dependency is HotKey (a small Carbon `RegisterEventHotKey` wrapper) locked by the
committed `Package.resolved`. The opt-in hover monitor observes pointer position
only and discards event payloads. About-window links are hardcoded. A full-tree
audit (2026-06) scored 9/10 with hygiene-level findings only.

## Known architectural limits

- **The notch**: hidden icons sit "under" the notch area on notched Macs; the
  trick cannot reveal them there. The real fix is a spillover/second-bar design
  (tracked in issues #357/#341/#148; candidate implementations in PRs #350/#358).
- **macOS 27 always-hidden on wide displays**: the always-hidden separator
  still inflates as a single unit, so with the regular section expanded its
  icons can show on a display wider than twice that unit.
- **macOS 27 first launch after upgrade**: items register under `_v27` autosave
  names so spacers land between the arrow and the separator. Icons may need a
  one-time ⌘-drag past the separator, as on a fresh install.
- **Other apps' open menus**: interaction-awareness is pointer-position-based;
  a pointer deep inside another app's open dropdown is below the menubar band,
  so the collapse can still fire there.
