//
//  NativeVisibilityEngine.swift
//  Hidden Bar
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//  macOS 27 Golden Gate fork — xVoLAnD (https://dotoca.net)
//

import AppKit

// macOS 27 hiding for the direct (non-App Store) build. Instead of inflating the
// separator, which macOS 27 ejects from the layout once it is too wide (#360),
// this reads which apps the user placed in each section and asks macOS to show
// only the allowed ones through the menu-bar visibility restriction behind
// assessment mode. macOS then hides the rest and reflows the bar itself, so the
// result does not depend on display width, the notch or the frontmost app's menus.
//
// The `|` separator is the boundary: apps left of it (LTR) are hidden, apps
// right of it stay visible — ⌘-drag icons across it to arrange sections. The
// arrow is only the toggle. The always-hidden separator, when enabled, marks
// the third section; it shows while expanded so it can be ⌘-dragged, and drops
// to zero width while collapsed, where macOS has already removed everything it
// would separate. It keeps its slot because its position is what defines that
// section.
//
// Limits, all from what macOS 27 exposes:
// - Hiding is per app: an app with several icons hides or shows them together
//   (the most visible section wins).
// - Kept means allow-listed (own, visible-section, hosts, indices) — anything
//   else hides given reflow time, Apple bundle extras included. Position only
//   feeds the allow-list; there is no fail-open.
// - Sections are read only while nothing is hidden, because hidden items report
//   stale positions. They are re-read on the next collapse from an unrestricted
//   bar; until then recent launches (120s window, any state) are optimistically
//   kept visible, plus a positional newcomer watch while collapsed — didLaunch
//   can long precede the icon for slow starters, predate the observer, or be
//   absent entirely when an already-running app shows its icon; census presence
//   alone cannot be the signal (hidden icons stay present in AX), so the
//   newcomer watch re-allows any bundle that was not present at the last
//   collapse instead of relying on position.
final class NativeVisibilityEngine: MenuBarEngine {
    // System item identifiers to keep visible. Unknown identifiers are ignored,
    // so the window is deliberately wide: Apple extras live past index 63 on
    // 27.0 (Time Machine vanished with 0..<64 and still with 0..<256), and
    // numbering differs per Mac.
    static let systemItemsToKeep = Array(0..<4096)

    // Whether the running build can offer native hiding at all (direct,
    // non-sandboxed build linked with HIDDENBAR_NATIVE_VISIBILITY on 27).
    static var nativeVisibilityAvailable: Bool {
        #if HIDDENBAR_NATIVE_VISIBILITY
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
        #else
        return false
        #endif
    }

    private weak var items: MenuBarItemProvider?
    private let inventory: MenuBarInventoryProviding
    private let visibility: NativeVisibilityProviding
    private let ownBundleIdentifier: String?
    private let itemFrame: (NSStatusItem) -> CGRect?
    private let isLTR: () -> Bool

    private let expandedLength: CGFloat = 20

    // .calibrating stands for "an activation is in flight".
    private(set) var state: MenuBarEngineState = .expanded
    private(set) var layout: MenuBarLayout?

    private var assertion: NativeVisibilityAssertion?
    // Bumped whenever a pending activation must no longer win (an expand, a newer
    // activation); a late success is then invalidated straight away.
    private var generation = 0
    private var lastUnavailableReason: String?

    // Base of the currently held restriction (visible-section snapshot, or
    // visible+hidden for the expanded always-hidden presentation). A launch
    // re-activation re-allows this base plus recent launches.
    private var baseAllowedBundles: [String] = []
    // Every launch is remembered for a bounded window, in any state. didLaunch
    // fires at process start, which for slow starters (BetterDisplay needs
    // tens of seconds before its icon registers) can long precede the icon —
    // so launch-while-collapsed alone misses them. Presence in the census
    // cannot be the signal either: hidden-section icons stay present in AX
    // while collapsed. The allow-list unions recent launches; the next fresh
    // census classifies properly and supersedes the optimism (a wrongly shown
    // icon self-heals on the following collapse). Bundles without menu-bar
    // items are harmless no-ops in the allow-list.
    private static let recentLaunchWindow: TimeInterval = 120
    private var recentLaunches: [String: Date] = [:]
    private var launchObserver: NSObjectProtocol?
    // Bundles present in the bar at the moment of the last collapse census.
    // Hidden items report stale positions while a restriction is active, so a
    // positional test cannot tell a freshly hidden icon from a brand-new one —
    // but bundle identity is reliable. Any bundle absent here that appears later
    // is a newcomer (launched, or shown without a launch) and is re-allowed.
    private var lastCollapseBundles: Set<String> = []
    // Cached frame of the always-hidden separator. While collapsed its length is
    // 0, and on macOS 27 (one menu-bar window) a zero-length live frame collapses
    // onto a neighbour, so re-reading it on the next collapse mis-locates the
    // always-hidden zone. We refresh it only while it has real length (expanded,
    // or the brief moment before a collapse hides it) and reuse the cache then.
    private var cachedAlwaysHiddenFrame: CGRect?
    // Cached frame of the regular `|` separator, the hidden/visible boundary the
    // user ⌘-drags icons across. Like the always-hidden one it is hidden while
    // collapsed, so the live frame is only trustworthy while expanded; refresh
    // the cache from a real frame and reuse it otherwise (arrow as last resort).
    // Separator frames that produced the frozen `layout` below. Our own items
    // are readable without Accessibility, so every held-path use verifies them:
    // a dragged (or reflowed) separator silently misclassifies otherwise, and
    // nothing else would ever notice.
    private var layoutSeparatorFrame: CGRect?
    private var layoutAHFrame: CGRect?
    private var cachedSeparatorFrame: CGRect?
    // A repeating poll that runs for as long as the bar stays collapsed. Agent
    // apps (LSUIElement) never post didLaunch, so their icons can only be caught
    // by re-scanning the bar; polling every few seconds makes a freshly
    // registered icon appear promptly instead of waiting for the next collapse.
    private var watchTimer: Timer?

    private var alwaysHiddenEnabled = false
    private var alwaysHiddenSeparatorHidden = false

    init(items: MenuBarItemProvider,
         inventory: MenuBarInventoryProviding = AccessibilityMenuBarInventory(),
         visibility: NativeVisibilityProviding = NativeVisibilityBridge(),
         ownBundleIdentifier: String? = Bundle.main.bundleIdentifier,
         itemFrame: @escaping (NSStatusItem) -> CGRect? = {
            guard let button = $0.button, let origin = button.getOrigin else { return nil }
            return CGRect(origin: origin, size: button.bounds.size)
         },
         isLTR: @escaping () -> Bool = { Constant.isUsingLTRLanguage }) {
        self.items = items
        self.inventory = inventory
        self.visibility = visibility
        self.ownBundleIdentifier = ownBundleIdentifier
        self.itemFrame = itemFrame
        self.isLTR = isLTR
        items.separatorItem.isVisible = false
        launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main) { [weak self] note in
            // Delivery receipt (bundle is only known after parsing in the
            // handler): distinguishes "never delivered" from "parsed out".
            AppLog.info("NativeVisibility: workspace didLaunch received")
            self?.handleAppLaunch(note)
        }
    }

    func collapse(completion: @escaping (CollapseResult) -> Void) {
        switch state {
        case .collapsed:
            return completion(.collapsed)
        case .calibrating:
            // The activation in flight answers the request that started it.
            return
        case .expanded, .unavailable:
            break
        }
        setSeparatorsVisible(true)

        guard visibility.isAvailable else {
            logUnavailableOnce("the native menu-bar visibility API is not available in this build or on this macOS")
            state = .unavailable
            return completion(.unavailable)
        }
        guard inventory.isAuthorized else {
            // Without Accessibility the sections cannot be read, and guessing would
            // hide icons the user kept visible. Not latched: it works as soon as
            // the permission is granted.
            inventory.requestAuthorization()
            logUnavailableOnce("Accessibility permission is needed to read the menu-bar sections")
            return completion(.unavailable)
        }
        state = .calibrating
        // Fresh cycle: the census below classifies every running app; entries
        // older than the window are superseded, recent ones stay unioned in
        // case their icons have not registered yet.
        pruneRecentLaunches()
        withLayout { [weak self] layout, inventory, _ in
            guard let self = self else { return }
            guard let layout = layout else {
                self.logUnavailableOnce("the arrow's position cannot be read yet")
                self.state = .expanded
                return completion(.unavailable)
            }
            // Never hide on a blind snapshot: an empty census (cold AX server,
            // timeouts at login) would resolve to empty sections and latch an
            // allow-list that hides everything, re-applied on every later
            // expand/collapse from cache. Fail open instead — the user retries.
            guard !inventory.isEmpty else {
                self.logUnavailableOnce("the menu-bar census came back empty — refusing to hide blind")
                self.state = .expanded
                return completion(.unavailable)
            }
            // Per-icon pre-collapse census: ordinal left-to-right, section
            // (VISIBLE/HIDDEN/ALWAYSHIDDEN from the layout above), and the
            // visible flag (everything reads from an unrestricted bar here).
            let ordered = inventory.sorted { $0.frame.midX < $1.frame.midX }
            let preLine = ordered.enumerated().map { (i, item) -> String in
                let id = item.bundleIdentifier ?? "?"
                let section: String
                if let bundle = item.bundleIdentifier, let s = layout.sections[bundle] {
                    section = s == .visible ? "V" : (s == .hidden ? "H" : "A")
                } else {
                    section = "?"
                }
                return "[\(i)]\(id)@\(Int(item.frame.midX)):\(section):visible:true"
            }.joined(separator: " ")
            AppLog.info("NativeVisibility: pre-collapse \(preLine)")
             let preBundles = Set(inventory.compactMap { $0.bundleIdentifier })
             let preCounts = Dictionary(grouping: inventory.compactMap { $0.bundleIdentifier }, by: { $0 }).mapValues { $0.count }
             self.lastCollapseBundles = preBundles
             // Optimism is only for icons not yet registered: anything already in
             // the census gets its real zone, so drop it from the recent window.
             // Otherwise a login storm (empty baseline, everything tracked) would
             // union the whole storm into the first collapse permanently.
             self.recentLaunches = self.recentLaunches.filter { !preBundles.contains($0.key) }
             self.activate(allowing: layout.bundles(in: [.visible])) { [weak self] succeeded in
                guard let self = self else { return }
                self.state = succeeded ? .collapsed : .expanded
                if succeeded {
                    self.setSeparatorsVisible(false)
                    self.items?.alwaysHiddenItem?.isVisible = false
                    self.logPostCollapse(pre: preBundles, preCounts: preCounts, generation: self.generation)
                    self.startNewcomerWatch()
                }
                completion(succeeded ? .collapsed : .unavailable)
            }
        }
    }

    func expand() {
        stopNewcomerWatch()
        setSeparatorsVisible(true)
        // In arrange mode the separator has full length: capture its frame for
        // the next collapse so the always-hidden zone is read from a real
        // position. In normal mode it stays hidden (see setSeparatorsVisible).
        if alwaysHiddenEnabled,
           let ah = items?.alwaysHiddenItem,
           let frame = itemFrame(ah), frame.width > 0 {
            cachedAlwaysHiddenFrame = frame
        }
        state = .expanded
        applyExpandedPresentation()
    }

    func updateAlwaysHiddenSection(enabled: Bool, separatorHidden: Bool) {
        alwaysHiddenEnabled = enabled
        alwaysHiddenSeparatorHidden = separatorHidden
        if state != .collapsed {
            setSeparatorsVisible(true)
        }
        if state == .expanded {
            applyExpandedPresentation()
        }
    }

    // Native hiding does not depend on display geometry, so only drop the cached
    // sections; the next read from an unrestricted bar replaces them.
    func invalidateLayout() {
        if assertion == nil {
            layout = nil
        }
    }

    // Expanded shows the hidden section; the always-hidden section stays hidden
    // while "hide separators" is on, otherwise everything is revealed by dropping
    // the restriction altogether.
    private func applyExpandedPresentation() {
        guard alwaysHiddenEnabled && alwaysHiddenSeparatorHidden, visibility.isAvailable, inventory.isAuthorized else {
            AppLog.info("NativeVisibility: expanded presentation released (alwaysHiddenEnabled=\(alwaysHiddenEnabled) separatorsHidden=\(alwaysHiddenSeparatorHidden))")
            return releaseAssertion()
        }
        AppLog.info("NativeVisibility: expanded presentation holding visible+hidden (always-hidden stays hidden)")
        withLayout { [weak self] layout, inventory, _ in
            guard let self = self else { return }
            guard let layout = layout else {
                return self.releaseAssertion()
            }
            guard !inventory.isEmpty else {
                AppLog.info("NativeVisibility: expanded presentation skipped — census came back empty, leaving the bar unrestricted")
                return self.releaseAssertion()
            }
            // Fresh layout classifies every running app; only the recent window
            // stays unioned for icons that have not registered yet.
            self.pruneRecentLaunches()
            let present = Set(inventory.compactMap { $0.bundleIdentifier })
            self.recentLaunches = self.recentLaunches.filter { !present.contains($0.key) }
            self.activate(allowing: layout.bundles(in: [.visible, .hidden])) { _ in }
        }
    }

    // The sections as the user arranged them. Read fresh only from an
    // unrestricted bar; while a restriction is active the cached ones stand in.
    // Superseded by any later expand or activation, like an activation is.
    // Anything that reflows the bar (visibility toggles, restriction changes)
    // makes live separator frames untrustworthy for a beat: a just-reshown
    // item still reports its parked slot, a just-reflowed one a transient.
    // Verification runs only against settled frames — otherwise every
    // transition "detects" a move and re-reads forever (feedback loop).
    private static let settleInterval: TimeInterval = 1.5
    private var lastBarDisturbance: Date?
    // The bar reflows our thin separator between two adjacent slots depending
    // on restriction state (observed: settled 1028 released, 1060 held — a
    // systematic ~32px flip, not a drag). Trigger only past a threshold no
    // reflow can span: intentional drags move hundreds of px, and anything
    // smaller self-corrects on the next separators-shown cycle (which always
    // re-reads fresh). An unreadable live frame means "can't tell", never
    // "moved".
    private static let moveThreshold: CGFloat = 64
    // True only on positive evidence of movement (both frames readable and
    // apart): an unreadable live frame means "can't tell", never "moved".
    private func separatorsMovedSinceFreeze() -> Bool {
        if let last = lastBarDisturbance, Date().timeIntervalSince(last) < Self.settleInterval {
            return false
        }
        let tolerance: CGFloat = Self.moveThreshold
        if let stored = layoutSeparatorFrame,
           let sep = items?.separatorItem,
           let live = itemFrame(sep), live.width > 0,
           abs(live.midX - stored.midX) > tolerance {
            AppLog.info("NativeVisibility: main separator moved since freeze (was \(Int(stored.midX)), now \(Int(live.midX))) — re-reading fresh")
            return true
        }
        if alwaysHiddenEnabled,
           let storedAH = layoutAHFrame,
           let ah = items?.alwaysHiddenItem,
           ah.length > 0,
           let liveAH = itemFrame(ah), liveAH.width > 0,
           abs(liveAH.midX - storedAH.midX) > tolerance {
            AppLog.info("NativeVisibility: always-hidden separator moved since freeze (was \(Int(storedAH.midX)), now \(Int(liveAH.midX))) — re-reading fresh")
            return true
        }
        return false
    }

    private func withLayout(_ body: @escaping (MenuBarLayout?, [MenuBarInventoryItem], CGFloat?) -> Void) {
        if assertion != nil, !separatorsMovedSinceFreeze() {
            // A restriction is already held (e.g. collapse from expanded with
            // separators hidden and always-hidden on): positions would be stale
            // so sections stay cached — but bundle identity is still reliable.
            // Pass the live inventory so callers can baseline bundle sets; an
            // empty baseline would make the newcomer watch re-allow everything.
            generation += 1
            let generation = self.generation
            inventory.snapshot { [weak self] census in
                guard let self = self, generation == self.generation else { return }
                self.healAlwaysHiddenZone(with: census)
                body(self.layout, census, nil)
            }
            return
        }
        if assertion != nil {
            // Separators moved under a held restriction: the frozen sections no
            // longer match the arrangement. Drop the restriction and fall
            // through to a fresh census instead of misclassifying silently.
            releaseAssertion()
            layout = nil
        }
        // Frames AND layout direction are read only after the snapshot
        // completes. The ~1s Accessibility walk gives AppKit time to lay out
        // freshly shown items (a just-created separator reports a degenerate
        // frame synchronously) and lets applicationDidFinishLaunching resolve
        // the real layout direction first — reading it during init sees the
        // false default and mirror-classifies the whole bar. Positions are
        // then contemporaneous with the inventory itself.
        generation += 1
        let generation = self.generation
        inventory.snapshot { [weak self] inventory in
            guard let self = self, generation == self.generation else { return }
            guard let arrow = self.items?.toggleItem,
                  let arrowFrame = self.itemFrame(arrow) else { return body(nil, [], nil) }
            // The `|` separator is the boundary users arrange icons against; the
            // arrow is only the toggle. Prefer its live frame, then the cache, then
            // the arrow (pre-v1.20.5 behavior) so a missing frame never blocks.
            if let sep = self.items?.separatorItem,
               let frame = self.itemFrame(sep), frame.width > 0 {
                self.cachedSeparatorFrame = frame
            }
            let boundary = self.cachedSeparatorFrame ?? arrowFrame
            // Refresh the cache only from a real-length frame; never from the
            // collapsed zero-length one, which would corrupt the always-hidden zone.
            // A zero-width live frame (marker hidden) must not classify: fall
            // back to the cache, else an empty zone.
            let liveAHRaw: CGRect? = self.alwaysHiddenEnabled ? self.items?.alwaysHiddenItem.flatMap(self.itemFrame) : nil
            let liveAHFrame: CGRect? = (liveAHRaw?.width ?? 0) > 0 ? liveAHRaw : nil
            if self.alwaysHiddenEnabled,
               let ah = self.items?.alwaysHiddenItem,
               ah.length > 0,
               let frame = self.itemFrame(ah), frame.width > 0 {
                self.cachedAlwaysHiddenFrame = frame
            }
            let alwaysHiddenFrame = self.alwaysHiddenEnabled ? (self.cachedAlwaysHiddenFrame ?? liveAHFrame) : nil
            let ahDiag: String
            switch (self.alwaysHiddenEnabled, alwaysHiddenFrame) {
            case (false, _): ahDiag = "off"
            case (true, .some(let f)): ahDiag = "x=\(Int(f.midX))w=\(Int(f.width))"
            case (true, nil): ahDiag = "nil-frame"
            }
            let isLTR = self.isLTR()
            let dump = inventory.sorted { $0.frame.midX < $1.frame.midX }.map { "\($0.bundleIdentifier ?? "?")@\(Int($0.frame.midX))" }.joined(separator: " ")
            AppLog.info("NativeVisibility: inventory [\(dump)] sepX=\(Int(boundary.midX))")
            let layout = MenuBarLayoutResolver.resolve(inventory: inventory,
                                                       separatorFrame: boundary,
                                                       alwaysHiddenSeparatorFrame: alwaysHiddenFrame,
                                                       isLTR: isLTR,
                                                       excludingBundle: self.ownBundleIdentifier)
            AppLog.info("NativeVisibility: separator at x=\(boundary.midX) ahZone=\(ahDiag); visible \(layout.bundles(in: [.visible])), hidden \(layout.bundles(in: [.hidden])), always hidden \(layout.bundles(in: [.alwaysHidden]))")
            self.layout = layout
            self.layoutSeparatorFrame = boundary
            self.layoutAHFrame = alwaysHiddenFrame
            body(layout, inventory, boundary.midX)
        }
    }

    // Heals a frozen layout whose always-hidden zone predates a usable
    // separator frame: right after the separator is (re)created it has no
    // laid-out frame yet, so the seeding census records an empty zone and every
    // later held-path collapse inherits it. Once the cached frame validates,
    // promote hidden-zone bundles sitting on its always-hidden side. Visible
    // bundles are never demoted, and the next fresh census supersedes
    // unconditionally.
    private func healAlwaysHiddenZone(with census: [MenuBarInventoryItem]) {
        guard let ahFrame = cachedAlwaysHiddenFrame,
              let frozen = layout,
              frozen.bundles(in: [.alwaysHidden]).isEmpty else { return }
        let ltr = isLTR()
        var sections = frozen.sections
        var healed = false
        for item in census {
            guard let bundle = item.bundleIdentifier,
                  sections[bundle] == .hidden else { continue }
            let onAHHiddenSide = ltr ? item.frame.midX < ahFrame.midX : item.frame.midX > ahFrame.midX
            if onAHHiddenSide {
                sections[bundle] = .alwaysHidden
                healed = true
            }
        }
        if healed {
            layout = MenuBarLayout(sections: sections)
            layoutAHFrame = cachedAlwaysHiddenFrame
            AppLog.info("NativeVisibility: healed always-hidden zone from cached separator frame")
        }
    }

    // Activates the new restriction before dropping the old one, so switching
    // between collapsed and expanded never flashes the whole bar visible.
    private func activate(allowing bundles: [String], completion: @escaping (Bool) -> Void) {
        baseAllowedBundles = bundles
        pruneRecentLaunches()
        generation += 1
        let generation = self.generation
        // System hosts (MenuBarAgent, Control Center, SystemUIServer) own
        // Apple's extras — including ones Accessibility never exposes (Time
        // Machine) — so they are always kept. No third-party item can squat
        // these Apple-only namespaces. Recent launches are optimistically kept
        // visible until the next fresh census classifies them.
        let allowed = ((ownBundleIdentifier.map { [$0] } ?? []) + bundles + Array(recentLaunches.keys) + Array(MenuBarLayoutResolver.systemItemOwners)).sorted()
        AppLog.info("NativeVisibility: allowing \(allowed)")
        visibility.activate(allowedSystemItems: Self.systemItemsToKeep,
                            allowedBundleIdentifiers: allowed) { [weak self] result in
            guard let self = self, generation == self.generation else {
                if case .success(let stale) = result { stale.invalidate() }
                return
            }
            switch result {
            case .success(let newAssertion):
                let old = self.assertion
                self.assertion = newAssertion
                old?.invalidate()
                // A new restriction reflows the bar: live frames read within
                // the settle window are transients, not drags.
                self.lastBarDisturbance = Date()
                completion(true)
            case .failure(let error):
                // Fail open: never leave icons hidden after an error.
                AppLog.info("NativeVisibility: activation failed: \(error.localizedDescription)")
                self.releaseAssertion()
                completion(false)
            }
        }
    }

    private func pruneRecentLaunches() {
        let cutoff = Date().addingTimeInterval(-Self.recentLaunchWindow)
        recentLaunches = recentLaunches.filter { $0.value >= cutoff }
    }

    // The receipt is logged so delivery is visible; only genuinely new bundles
    // are remembered. A bundle already classified at the last collapse keeps
    // its zone (visible, hidden or always-hidden) — helpers and agents restart
    // all the time, and tracking them would union them into every allow-list
    // for 120s, popping always-hidden icons back visible. While collapsed the
    // restriction is additionally re-activated at once so a fast starter's icon
    // shows without waiting for the next collapse.
    private func handleAppLaunch(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundle = app.bundleIdentifier, !bundle.isEmpty else { return }
        pruneRecentLaunches()
        AppLog.info("NativeVisibility: launched (\(bundle))")
        guard !lastCollapseBundles.contains(bundle),
              !baseAllowedBundles.contains(bundle),
              bundle != ownBundleIdentifier else { return }
        let alreadyTracked = recentLaunches[bundle] != nil
        recentLaunches[bundle] = Date()
        guard !alreadyTracked,
              state == .collapsed, assertion != nil else { return }
        AppLog.info("NativeVisibility: launched while collapsed (\(bundle)) — re-allowing")
        activate(allowing: baseAllowedBundles) { [weak self] succeeded in
            guard let self = self else { return }
            if succeeded {
                // The icon may still register later (slow starter / agent app):
                // the continuous watch catches it within a few seconds.
                self.startNewcomerWatch()
            } else {
                // Fail open like a failed collapse: never leave icons stuck hidden.
                AppLog.info("NativeVisibility: re-allow after launch failed — expanding")
                self.releaseAssertion()
                self.state = .expanded
            }
        }
    }

    // Newcomer watch. Catches what didLaunch cannot: agent apps (LSUIElement)
    // never post a launch notification, and icons also register long after their
    // launch. A positional test is useless here — hidden items report stale
    // frames while the restriction is active — so the signal is the bundle set:
    // anything absent from the last collapse census and not already allowed is a
    // newcomer and is re-allowed. The next collapse re-reads everything from an
    // unrestricted bar, so a wrongly shown icon self-heals. Runs continuously
    // while collapsed so a new icon shows within a few seconds, not on the next
    // manual collapse.
    private func startNewcomerWatch() {
        stopNewcomerWatch()
        AppLog.info("NativeVisibility: newcomer watch started")
        // Immediate first pass catches an icon that registered in the brief gap
        // between the collapse census and now; then poll every 3s while collapsed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.newcomerCheck()
        }
        watchTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.newcomerCheck()
        }
    }

    private func stopNewcomerWatch() {
        watchTimer?.invalidate()
        watchTimer = nil
    }

    private func newcomerCheck() {
        guard state == .collapsed, assertion != nil else {
            stopNewcomerWatch()
            return
        }
        inventory.snapshot { [weak self] items in
            guard let self = self, self.state == .collapsed, self.assertion != nil else {
                self?.stopNewcomerWatch()
                return
            }
            self.pruneRecentLaunches()
            var found: [String] = []
            for item in items {
                guard let bundle = item.bundleIdentifier, !bundle.isEmpty,
                      bundle != self.ownBundleIdentifier,
                      !self.lastCollapseBundles.contains(bundle),
                      !self.baseAllowedBundles.contains(bundle),
                      self.recentLaunches[bundle] == nil else { continue }
                self.recentLaunches[bundle] = Date()
                found.append(bundle)
            }
            guard !found.isEmpty else { return }
            AppLog.info("NativeVisibility: newcomer bundles (\(found.joined(separator: " "))) — re-allowing")
            self.activate(allowing: self.baseAllowedBundles) { [weak self] succeeded in
                guard let self = self else { return }
                if succeeded {
                    self.startNewcomerWatch()
                } else {
                    AppLog.info("NativeVisibility: re-allow after watch failed — expanding")
                    self.releaseAssertion()
                    self.state = .expanded
                }
            }
        }
    }

    // Fire-and-forget post-collapse census: which items macOS still reports
    // once the restriction is active. Never blocks the completion; purely
    // diagnostic. Two samples: immediate (mid-transition tree) and +15s
    // (settled). Counts per bundle catch partial vanishes (e.g. MenuBarAgent
    // 7→5) that bundle-set subtraction misses.
    private func logPostCollapse(pre preBundles: Set<String>, preCounts: [String: Int], generation: Int) {
        snapshotPostCollapse(pre: preBundles, preCounts: preCounts, generation: generation, tag: "")
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            self?.snapshotPostCollapse(pre: preBundles, preCounts: preCounts, generation: generation, tag: "+15s")
        }
    }

    private func snapshotPostCollapse(pre preBundles: Set<String>, preCounts: [String: Int], generation: Int, tag: String) {
        inventory.snapshot { [weak self] post in
            guard let self = self else { return }
            let stale = generation == self.generation ? "" : " superseded"
            let ordered = post.sorted { $0.frame.midX < $1.frame.midX }
            let present = ordered.enumerated().map { (i, item) in
                "[\(i)]\(item.bundleIdentifier ?? "?")@\(Int(item.frame.midX)):visible:true"
            }.joined(separator: " ")
            let postBundles = Set(post.compactMap { $0.bundleIdentifier })
            let missing = preBundles.subtracting(postBundles).sorted().joined(separator: " ")
            let postCounts = Dictionary(grouping: post.compactMap { $0.bundleIdentifier }, by: { $0 }).mapValues { $0.count }
            let reduced = preCounts.compactMap { (bundle, before) -> String? in
                guard let after = postCounts[bundle], after < before else { return nil }
                return "\(bundle):\(before)→\(after)"
            }.sorted().joined(separator: " ")
            AppLog.info("NativeVisibility: post-collapse\(tag)\(stale) present [\(present)] missing [\(missing)] reduced [\(reduced)]")
        }
    }

    // The regular separator shows while expanded so it can be ⌘-dragged; the
    // always-hidden one only in arrange mode (see below). While collapsed they
    // hide (the regular one via isVisible, the always-hidden one via zero
    // width — isVisible = false would make macOS forget where the user placed
    // it, and its position defines the always-hidden zone).
    private func setSeparatorsVisible(_ visible: Bool) {
        // Stamp only on an actual flip: the parked-while-hidden slot differs
        // from the shown one, so frames read within the settle window after a
        // flip are transients, not drags.
        if items?.separatorItem.isVisible != visible {
            lastBarDisturbance = Date()
        }
        items?.separatorItem.isVisible = visible
        // The always-hidden marker shows only in arrange mode (separators
        // shown) — day-to-day bars stay clean, including while expanded.
        // Length and visibility move together; the slot and the cached frame
        // survive either way (collapse cycles prove it).
        let showAHMarker = visible && alwaysHiddenEnabled && !alwaysHiddenSeparatorHidden
        if let ahVisible = items?.alwaysHiddenItem?.isVisible, ahVisible != showAHMarker {
            lastBarDisturbance = Date()
        }
        items?.alwaysHiddenItem?.length = showAHMarker ? expandedLength : 0
        items?.alwaysHiddenItem?.isVisible = showAHMarker
        AppLog.info("NativeVisibility: markers regular visible=\(items?.separatorItem.isVisible ?? false), AH visible=\(items?.alwaysHiddenItem?.isVisible ?? false) length=\(Int(items?.alwaysHiddenItem?.length ?? -1))")
    }

    // Any arrangement works: whatever sits left of the separator is the hidden section.
    var isArrangementValid: Bool {
        return true
    }

    var isAlwaysHiddenSeparatorPlaced: Bool {
        return MenuBarOrder.isItem(items?.alwaysHiddenItem, onHiddenSideOf: items?.toggleItem)
    }

    private func releaseAssertion() {
        stopNewcomerWatch()
        // Dropping a restriction reflows the bar too (see activate success).
        lastBarDisturbance = Date()
        generation += 1
        assertion?.invalidate()
        assertion = nil
    }

    deinit {
        // Releasing the assertion restores the bar if this engine is discarded
        // (for example when the user switches engines) without an explicit expand.
        watchTimer?.invalidate()
        if let launchObserver = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(launchObserver)
        }
        assertion?.invalidate()
    }

    // Logged when the reason changes, so a retried collapse does not spam.
    private func logUnavailableOnce(_ reason: String) {
        guard reason != lastUnavailableReason else { return }
        lastUnavailableReason = reason
        AppLog.info("NativeVisibility: hiding unavailable: \(reason)")
    }
}
