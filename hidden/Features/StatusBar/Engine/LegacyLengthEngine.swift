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
    private let spacers: [NSStatusItem]
    // macOS 27 only: spacer block for the always-hidden section (mirrors the main
    // spacers so a single inflated unit can't span wide displays).
    private var alwaysHiddenSpacers: [NSStatusItem]

    private var collapsedLength: CGFloat = 2000
    private var alwaysHiddenCollapsedLength: CGFloat = 0

    init(items: MenuBarItemProvider) {
        self.items = items
        self.spacers = LegacyLengthEngine.makeSpacers()
        self.alwaysHiddenSpacers = LegacyLengthEngine.makeAlwaysHiddenSpacers()
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
            // Sized under the NARROWEST attached screen: the only half-width cliff
            // every bar's copy of the item can clear. A wider unit would be dropped
            // on the narrow display, leaving icons unhidden there.
            let narrowest = NSScreen.screens.map { $0.frame.width }.min() ?? 1728
            bounded = max(200, (narrowest / 2 - 64).rounded(.down))
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

    private static func makeSpacers() -> [NSStatusItem] {
        guard #available(macOS 27.0, *) else { return [] }
        return (0..<10).map { index in
            let item = NSStatusBar.system.statusItem(withLength: 0)
            item.button?.isEnabled = false
            // Keep the slot registered: a hidden (isVisible = false) item loses its
            // position when re-shown on macOS 27, so hide by zero length instead.
            item.isVisible = true
            item.autosaveName = "hiddenbar_spacer\(index)" + Self.autosaveSuffix
            return item
        }
    }

    private static func makeAlwaysHiddenSpacers() -> [NSStatusItem] {
        guard #available(macOS 27.0, *) else { return [] }
        return (0..<10).map { index in
            let item = NSStatusBar.system.statusItem(withLength: 0)
            item.button?.isEnabled = false
            item.isVisible = true
            item.autosaveName = "hiddenbar_ahspacer\(index)" + Self.autosaveSuffix
            return item
        }
    }

    private static let autosaveSuffix: String = {
        if #available(macOS 27.0, *) { return "_v27" }
        return ""
    }()

    private func setSpacersInflated(_ inflated: Bool) {
        for spacer in spacers {
            spacer.length = inflated ? collapsedLength : 0
        }
    }

    private func setAlwaysHiddenSpacersInflated(_ inflated: Bool) {
        for spacer in alwaysHiddenSpacers {
            spacer.length = inflated ? alwaysHiddenCollapsedLength : 0
        }
    }
}
