//
//  LegacyLengthEngine.swift
//  Hidden Bar
//
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//  macOS 27 Golden Gate fork — xVoLAnD (https://dotoca.net)
//

import AppKit

// Hides icons by inflating a status item until everything on the hidden side
// leaves the visible bar. macOS <= 26 reflows around any length, so the length
// only has to be large enough to cover the widest attached display.
//
// On macOS 27 the menu bar is re-architected: a status item whose length reaches
// half the display width is DROPPED rather than clamped, and a single item cannot
// span a wide or mixed-width setup. To keep hiding on 27 (when the native
// visibility engine is unavailable — e.g. the App Store build), this engine uses
// the fork's spacer block: zero-length items beside the separator that inflate
// with it, sized under the narrowest attached screen so no single item is dropped.
final class LegacyLengthEngine: MenuBarEngine {
    // The collapse length to use for the spacer blocks. Kept here so the
    // controller can re-apply it when geometry changes (display hot-plug).
    static var spacerCollapseLength: CGFloat = 2000

    private weak var items: MenuBarItemProvider?

    private let expandedLength: CGFloat = 20

    // macOS 27 only: zero-length spacers between the arrow and the separator that
    // inflate with it so the total span covers wide/mixed displays without any
    // single item crossing the half-width cliff. Empty on <= 26.
    private var spacers: [NSStatusItem] = []
    // macOS 27 only: spacer block for the always-hidden section (mirrors the main
    // spacers so a single inflated unit can't span wide displays).
    private var alwaysHiddenSpacers: [NSStatusItem] = []

    private var collapsedLength: CGFloat = 2000
    private var alwaysHiddenCollapsedLength: CGFloat = 0

    init(items: MenuBarItemProvider) {
        self.items = items
        // Fixed 10+10 blocks: the computed small blocks proved too weak to
        // displace anything on 27.0, while the full block hides (rogue-gating
        // below keeps the arrow safe). Deinit removes them so rebuilds do not
        // accumulate leaked invisible items.
        self.spacers = (0..<10).map { Self.makeSpacer(index: $0, prefix: "hideout_spacer") }
        self.alwaysHiddenSpacers = (0..<10).map { Self.makeSpacer(index: $0, prefix: "hideout_ahspacer") }
        updateCollapsedLengths()
    }

    // Derived from the live length rather than stored, and compared with > rather
    // than ==, so the state survives the collapse length being recomputed while
    // collapsed (PR #354).
    var state: MenuBarEngineState {
        guard let separator = items?.separatorItem else { return .expanded }
        return separator.length > expandedLength ? .collapsed : .expanded
    }

    // The separator is what widens, so it must sit between the hidden icons and
    // the arrow, and the always-hidden separator further out still.
    var isArrangementValid: Bool {
        return MenuBarOrder.isItem(items?.separatorItem, onHiddenSideOf: items?.toggleItem)
    }

    var isAlwaysHiddenSeparatorPlaced: Bool {
        return MenuBarOrder.isItem(items?.alwaysHiddenItem, onHiddenSideOf: items?.separatorItem)
    }

    func collapse(completion: @escaping (CollapseResult) -> Void) {
        AppLog.info("LegacyLength: collapse — separator=\(collapsedLength), spacers=\(spacers.count)×\(collapsedLength), alwaysHidden=\(alwaysHiddenCollapsedLength), screens=\(NSScreen.screens.map { Int($0.frame.width) })")
        // Order check: the spacer block must sit left of the arrow (LTR), else
        // inflation shoves the arrow itself into the « overflow and it vanishes.
        if let sepX = items?.separatorItem.button?.getOrigin?.x,
           let arrowX = items?.toggleItem.button?.getOrigin?.x {
            let spacerXs = spacers.compactMap { $0.button?.getOrigin?.x }.map { Int($0) }.sorted()
            AppLog.info("LegacyLength: order sepX=\(Int(sepX)) spacers=\(spacerXs) arrowX=\(Int(arrowX))")
        }
        items?.separatorItem.length = collapsedLength
        setSpacersInflated(true)
        items?.alwaysHiddenItem?.length = alwaysHiddenCollapsedLength
        setAlwaysHiddenSpacersInflated(alwaysHiddenCollapsedLength > 0)
        completion(.collapsed)
    }

    func expand() {
        items?.separatorItem.length = expandedLength
        setSpacersInflated(false)
        items?.alwaysHiddenItem?.length = alwaysHiddenEnabled ? expandedLength : 0
        setAlwaysHiddenSpacersInflated(false)
    }

    func updateAlwaysHiddenSection(enabled: Bool, separatorHidden: Bool) {
        alwaysHiddenEnabled = enabled
        let length: CGFloat
        if separatorHidden {
            length = enabled ? collapsedLength : 0
        } else {
            length = enabled ? expandedLength : 0
        }
        alwaysHiddenCollapsedLength = enabled ? collapsedLength : 0
        items?.alwaysHiddenItem?.length = length
        setAlwaysHiddenSpacersInflated(separatorHidden && enabled)
    }

    func invalidateLayout() {
        guard state == .collapsed else { return }
        updateCollapsedLengths()
        items?.separatorItem.length = collapsedLength
        setSpacersInflated(true)
    }

    // MARK: - macOS 27 spacer fallback

    private var alwaysHiddenEnabled = false

    private func updateCollapsedLengths() {
        let bounded: CGFloat
        if #available(macOS 27.0, *) {
            // Sized under a QUARTER of the narrowest attached screen. macOS 27
            // drops items at half the *usable* bar width, and the notch eats a
            // big chunk of that on internal displays: a 692 unit renders on a
            // notchless wide bar but vanishes on the 14" built-in bar. Quarter
            // width clears any realistic notch with margin, and 11 such units
            // still span every attached display.
            let narrowest = NSScreen.screens.map { $0.frame.width }.min() ?? 1728
            bounded = max(200, (narrowest / 4).rounded(.down))
        } else {
            // The menubar replicates across every attached display, so the collapse
            // length must cover the WIDEST screen, not NSScreen.main (the focused
            // one); sizing from a narrower screen leaks hidden icons on wider displays.
            // frame.width, not visibleFrame: the menubar spans the full frame width.
            let screenWidth = NSScreen.screens.map { $0.frame.width }.max() ?? 1728
            // macOS enforces a hard 10,000pt maximum on NSStatusItem.length (PR #354).
            bounded = max(500, min(screenWidth * 2, 10_000))
        }
        collapsedLength = bounded
        alwaysHiddenCollapsedLength = alwaysHiddenEnabled ? bounded : 0
        LegacyLengthEngine.spacerCollapseLength = bounded
    }

    private static func makeSpacer(index: Int, prefix: String) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: 0)
        item.button?.isEnabled = false
        // Keep the slot registered: a hidden (isVisible = false) item loses its
        // position when re-shown on macOS 27, so hide by zero length instead.
        item.isVisible = true
        item.autosaveName = "\(prefix)\(index)" + Self.autosaveSuffix
        return item
    }

    // NOTE: a fixed 10+10 burst is intentional. A computed small block (2+sep)
    // proved too weak to displace anything on 27.0; the full block hides, and
    // rogue-gating in setSpacersInflated keeps a misplaced spacer from shoving
    // the arrow into «. Deinit removes the blocks so rebuilds do not leak.
    // Pre-27 both blocks stay empty (Legacy uses one wide separator there).

    private static let autosaveSuffix: String = {
        if #available(macOS 27.0, *) { return "_v27" }
        return ""
    }()

    // Hidden side of a boundary (LTR: left of it, RTL: right of it).
    private func isOnHiddenSide(x: CGFloat, boundary: CGFloat) -> Bool {
        Constant.isUsingLTRLanguage ? x < boundary : x > boundary
    }

    private func setSpacersInflated(_ inflated: Bool) {
        guard inflated else {
            for spacer in spacers { spacer.length = 0 }
            return
        }
        // Inflate only spacers verified on the hidden side of the arrow. A
        // misplaced spacer at/after the arrow would shove the arrow itself
        // into the « overflow on inflation and it would vanish (seen live:
        // spacers=[906×9, 997] with arrowX=972). Skipped rogues stay at zero.
        let boundary = items?.toggleItem.button?.getOrigin?.x
        for spacer in spacers {
            if let spacerX = spacer.button?.getOrigin?.x, let boundary = boundary,
               !isOnHiddenSide(x: spacerX, boundary: boundary) {
                AppLog.info("LegacyLength: skipping rogue spacer at x=\(Int(spacerX)) (arrow at \(Int(boundary))) — inflating it would shove the arrow into «. Reset slots with `defaults delete net.dotoca.hideout` (reconfigure prefs after) and restart.")
                spacer.length = 0
                continue
            }
            spacer.length = collapsedLength
        }
    }

    private func setAlwaysHiddenSpacersInflated(_ inflated: Bool) {
        guard inflated else {
            for spacer in alwaysHiddenSpacers { spacer.length = 0 }
            return
        }
        let boundary = items?.alwaysHiddenItem?.button?.getOrigin?.x
        for spacer in alwaysHiddenSpacers {
            if let spacerX = spacer.button?.getOrigin?.x, let boundary = boundary,
               !isOnHiddenSide(x: spacerX, boundary: boundary) {
                AppLog.info("LegacyLength: skipping rogue always-hidden spacer at x=\(Int(spacerX))")
                spacer.length = 0
                continue
            }
            spacer.length = alwaysHiddenCollapsedLength
        }
    }

    deinit {
        // Spacers are ours alone: remove them so engine rebuilds (preference
        // switches) do not accumulate leaked invisible items that fragment
        // the bar order further.
        for spacer in spacers + alwaysHiddenSpacers {
            NSStatusBar.system.removeStatusItem(spacer)
        }
    }
}
