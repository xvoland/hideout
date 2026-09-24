# Backlog

Durable, committed index of open work. The detailed planning layer
(`_meta/megagoals/issue-list-clearing/` and `.claude/`) is local-only and gitignored,
so this file is the version that survives a machine switch and a fresh clone. Keep it
short: one line per item, pointing at the issue, SPEC, or file that holds the detail.

Source of the current state: the v1.11 issue-clearing pass (2026-06-12), branch
`fix/v1-11-batch` / draft PR #365, and SPEC-003. Core-model changes (separator length
math, collapse state machine) are HIGH RISK and require a mandatory review-team pass.

## macOS 27 (landed, residual)

- **Hide mechanism restored (#360), native-only since v1.19** (Legacy engine
  deleted; pre-27 path: upstream). Residual: always-hidden presentation with
  separators shown; one-time ⌘-drag after upgrade (autosave names).

## Blocked on external-display hardware

- **#351 external-monitor visible-bar (26.4) verification.** The widest-attached-screen
  fix is code-only; the 26.4 + external-display reproduction was never run. Confirm no
  full-width bar leak on a real second monitor.

## Actionable now (no special hardware)

- **UAT + merge draft PR #365.** Per the local `UAT.md` (one row per fix, click-through
  steps). Merge order matters (stacked dependency). Merge is Han's action, not the agent's.
- **Cut the v1.11 release.** Version + CHANGELOG staged in #365. Needs a Developer ID for
  notarization + App Store submission. Shipping answers the "is this still maintained?"
  issues and unblocks the round-2 close sweep.
- **Upgrade-path BTM verification before any signed release.** Install a pre-v1.11 build,
  update to v1.11, confirm Login Items shows no leftover `LauncherApplication` row (the
  one-shot `SMLoginItemSetEnabled(..., false)` deauth was added but never run on hardware).
- **AXPress accessibility defect.** VoiceOver users cannot toggle the bar: the arrow's
  `AXPress` handler reads `NSApp.currentEvent`, which is nil under assistive synthesis.
- **`hoverToExpand` Preferences checkbox.** Shipped as a Terminal-only `defaults write`;
  add a proper checkbox in `PreferencesViewController`.
- **Surface the `SMAppService` error contract in the prefs UI.** On `register()` failure
  (unsigned build, or user denies in System Settings), the checkbox stays on while the
  system says off; the error is swallowed into NSLog. Fix when the prefs UI is next touched.
  `Common/Util.swift:29-31`.
- **Round-2 issue close sweep (~35 issues).** Obsolete-OS + meta/support candidates,
  deferred until v1.11 ships so the closures carry the strongest answer.
- **24h memory dogfood (#361).** Instruments stress-cycling found no leak; run v1.11 as
  the daily driver for 24h on the Air to close the open report.
- **Old branch decision.** `feature/menubarDetection` (PR #115) and `feature/ghost-mode`
  (PR #57) were kept per never-delete. Review or discard, Han's call.

## v1.12 standalone wins (no Option D needed)

- **#207 show clock/date when collapsed.** Loudest single feature ask (18+ comments).
- **#355** prefs window layout overlap. **#324** single-instance guard. **#276** Cmd+W
  closes the prefs window. Appearance bundle via community PR #194.

## Architectural epic (Option D, #366)

- **Managed-overflow / second-bar redesign.** The real fix that gates ~30 issues across
  four clusters: icon-drift (#28, #156, #181, #230, #231, #239, #252, #254, #275, #283,
  #321, #334), always-hidden (#171, #224, #242, #288), notch (#206, #225, #228, #245,
  #267, #269, #280, #292, #330), and macOS 27 (#360). Replaces length-inflation with a
  managed overflow bar, likely via Accessibility. Needs a design decision from Han +
  macOS 27 hardware. Design + folded M1 (pin icons, persist order) / M2 (decouple
  always-hidden from `areSeparatorsHidden`, recover stuck items) in SPEC-003.
- **Security + behavior review of community PRs #358 and #350 first.** #358 (second bar,
  +1160 lines) and #350 (notch overflow, +429 lines) are the existing starting points.
  Do not merge on description alone; #358 especially needs a real review.
- **#242 permanent icon-loss repro.** Needs a throwaway defaults profile (live repro
  risks losing real menu-bar icons). Required before the always-hidden decouple lands.

## Hideout fork — session state 2026-09-24 (develop @ v1.20.18, releasing v1.21.0)

- **Shipped v1.20.1–v1.20.18, consolidated as v1.21.0.** Newcomer visibility
  while collapsed (NSWorkspace + 120s window + bundle-diff/positional watch,
  3s polling; classified bundles excluded from the union); separator restored
  as the visible boundary (fresh `hideout_separator` slot, 8pt width,
  cache/arrow fallbacks); Always Hidden hardening (frame cache + frozen-zone
  heal, newcomer union excludes classified bundles, one-time enforcement on
  enable, keep-don't-recreate separator item); reveal paths (unified click
  handling, flags latch, Preferences button); fail-open on empty census;
  init-order RTL/frame races fixed (post-snapshot reads); settle-gated +
  64px-threshold move verification; CI tag-only (no branch builds).
- **Still OPEN (unchanged):** version stamping (MARKETING_VERSION 1.18.5 fossil;
  Dev-suffix + commit-back declined for now — DO NOT implement without an
  explicit go-ahead); AX-invisible icons (Player ▶, deferred, same path as
  before); PRIVACY_POLICY one-liner (owner wording); Hideout-source.zip
  keep-or-drop question; wide-display always-hidden leak.
- **CLOSED (owner declined):** UpdateChecker docs in MANUAL/README/CHANGELOG;
  debug-log trim.
- **Standing (unchanged):** new .swift files need pbxproj registration;
  verification via CI only (no local Xcode); single-file LSP
  "cannot find in scope" is noise, verify via build; re-release =
  `git tag -f vX.Y.Z && git push -f origin vX.Y.Z` (CI rebuilds + republishes);
  no master merges without explicit request.

## Hideout fork — session state 2026-09-23 (develop @ 4a3569b)

- **v1.20.0 re-released** (tag force-moved 92ea180 → 4a3569b, full release): update
  checker (launch + weekly throttle, stable-only, manual button in Preferences General),
  UI grammar fixes, visible-rebrand leftovers (About/Hide/Quit menu, login checkbox).
  Same version number → the in-app checker will NOT flag it to existing v1.20.0 installs.
- **OPEN — version stamping.** Repo MARKETING_VERSION is a 1.18.5 fossil;
  bump-version.sh patches tag builds ephemerally and never commits back, so dev builds
  show 1.18.5 in About. Dev-suffix + commit-back was proposed; status unclear after the
  build-revert request — DO NOT implement without an explicit go-ahead.
- **DEFERRED — AX-invisible icons (Player ▶).** The allow-list API can only keep named
  bundles; unknowns cannot be kept, and ⌘-drag does not help them (sections come from
  the AX census). Path if revived: identify the owner (running-apps diff / « overflow /
  user report) + persistent always-visible bundle set. Fail-open-for-unknowns rejected
  (kills the no-fail-open guarantee).
- **OPEN — PRIVACY_POLICY one-liner** disclosing update checks (api.github.com, launch +
  weekly). Needs the owner's wording.
- **OPEN — Hideout-source.zip in releases:** keep or drop so a release holds exactly two
  files? Unanswered.
- **CLOSED (owner declined):** UpdateChecker docs in MANUAL/README/CHANGELOG; debug-log
  trim (diagnostic logs stay as-is).
- **Standing:** new .swift files need pbxproj registration (PBXFileReference +
  PBXBuildFile + group children + Sources); verification via CI only (no local Xcode);
  single-file LSP "cannot find in scope" is noise, verify via build; re-release =
  `git tag -f vX.Y.Z && git push -f origin vX.Y.Z` (CI rebuilds + republishes).
