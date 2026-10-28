# Maintainer runbook

Build, verify, and release Hideout. Assumes current Xcode on macOS 13+.

## Build

```sh
# CI-style build, no signing required
xcodebuild -project 'Hideout.xcodeproj' -scheme 'Hideout' \
  -configuration Release-Direct CODE_SIGNING_ALLOWED=NO build

# runnable local build (uses your Apple Development identity)
xcodebuild -project 'Hideout.xcodeproj' -scheme 'Hideout' \
  -configuration Debug-Direct build
```

Both must exit 0 with **no** `MACOSX_DEPLOYMENT_TARGET` override; the floor is
13.0 in the project file. Native hiding needs a `*-Direct` configuration
(`HIDDENBAR_NATIVE_VISIBILITY`); plain `Debug`/`Release` are sandboxed and
report hiding as unavailable. The single expected warning is the deliberately
deprecated `SMLoginItemSetEnabled(false)` call that cleans up legacy installs.

## Behavioral verification (no test target exists; this is the methodology)

The repo has no unit-test infrastructure; behavior is verified against the real
menu bar. Two building blocks make that scriptable:

1. **Truth signal**: the log. Collapse prints
   `NativeVisibility: arrow at x=…; visible […], hidden […], always hidden […]`
   followed by `VisibilityRestrictionAssertion session activated`, then
   `StatusBar: collapse completed (.collapsed)` and the arrow flips to `>`.
   Expand prints `expand requested` and drops the assertion. Any deviation
   (missing activation, `.unavailable`, arrow/model mismatch) is the bug.
2. **Real clicks, not AXPress**: `AXPress` on the arrow is a no-op because the
   action handler reads `NSApp.currentEvent` (nil under assistive synthesis;
   known accessibility defect). Post real `CGEvent` mouse clicks at the arrow's
   AX-reported coordinates instead.

Standard checks before any release:

- expand/collapse toggle flips the separator size both ways;
- with `numberOfSecondForAutoHide` set to 3, an expanded bar survives 2x the
  window while the pointer is parked in the menubar band, collapses within the
  window once the pointer leaves, and collapses normally if the pointer never
  entered;
- `hoverToExpand` off: no monitor log line, hover does nothing; on: dwell
  expands (synthesize a `mouseMoved` stream: cursor warping alone fires no
  events);
- autostart pref on -> `AutoStart: SMAppService.mainApp.status = 1` on stderr;
  off -> `= 0` (run the binary directly to capture stderr);
- localization tables stay parseable: `plutil -lint hidden/*.lproj/*.strings`;
- right-clicking the arrow opens the tray panel: grouped cards render in light
  and dark appearance; About links open the fork repo,
  <https://dotoca.net/hideout>, `mailto:adv@dotoca.net` and upstream; the
  pointer becomes a hand over them; the inline always-hidden tutorial text is
  legible on the gray card; both credit lines show without truncation.

When testing on a machine that runs Hideout daily: export the prefs domain
first (`defaults export net.dotoca.hideout backup.plist`), quit the
installed app, test the dev build, then re-import and relaunch.

## Release

1. Verify the stack: every PR reviewed, builds green, behavioral checks above run.
2. Tag and push; CI builds and publishes automatically:
   - `git tag vX.Y.Z-goldengate-test && git push origin vX.Y.Z-goldengate-test`
     publishes a prerelease;
   - `git tag vX.Y.Z && git push origin vX.Y.Z` publishes a full release.

   The version comes from the tag via `.github/scripts/bump-version.sh`; the
   workflow builds `Release-Direct`, packages `Hideout.app`, a DMG and a source
   archive, and creates the GitHub release.
3. Builds are **ad-hoc / unsigned**. Tell users to clear quarantine with
   `xattr -dr com.apple.quarantine "Hideout.app"`. Notarization is not wired
   up (it needs a Developer ID certificate and secrets).
4. App Store (separate lane): the MAS listing has lagged GitHub since v1.8
   (issues #281/#202); decide deliberately whether a release goes there too.
5. Homebrew: upstream has the official cask (`brew install --cask hiddenbar`);
   this fork's macOS 27 build ships via its own cask — see the
   [Casks](https://github.com/xvoland/hidden/blob/main/Casks) directory in this repo.
6. Before any public release after the SMAppService migration: one
   upgrade-path run from a launcher-era build (v1.9 or older) verifying System
   Settings shows no ghost LauncherApplication login item.

## Stacked-PR hygiene

Feature stacks land as chained PRs (`develop <- A <- B`). Merge the base PR
first, then retarget the next PR's base to `develop` BEFORE merging it;
deleting a merged branch auto-closes dependents otherwise.

## Issue triage map

The live clusters and their code areas are documented at the end of
[ARCHITECTURE.md](ARCHITECTURE.md#known-architectural-limits): notch, macOS 27
mechanism break, and pointer-vs-open-menu limits. Memory reports (#361 et al.)
have so far not reproduced as leaks (constraint-leak fix landed; `leaks` clean
over toggle stress); re-check with a 24h+ uptime `footprint` sample before
chasing further.
