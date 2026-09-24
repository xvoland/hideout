//
//  MenuBarEngine.swift
//  Hidden Bar
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//  macOS 27 Golden Gate fork — xVoLAnD (https://dotoca.net)
//

import AppKit
import os

// StatusBarController decides WHAT the user wants (collapsed or expanded, which
// sections exist); an engine decides HOW the menu bar is made to do it. Keeping
// the mechanics here lets an OS release that changes menu-bar layout (#360) get
// its own engine without version checks spreading through the controller.
protocol MenuBarEngine: AnyObject {
    var state: MenuBarEngineState { get }

    func collapse(completion: @escaping (CollapseResult) -> Void)
    func expand()

    func updateAlwaysHiddenSection(enabled: Bool, separatorHidden: Bool)

    // Whether the user's ⌘-drag arrangement lets the engine hide anything: its
    // hiding boundary must sit on the hidden side of the arrow. The controller
    // does not collapse otherwise.
    var isArrangementValid: Bool { get }

    // Whether the always-hidden separator sits beyond the regular hidden section.
    var isAlwaysHiddenSeparatorPlaced: Bool { get }

    // Display geometry changed. Re-applies the collapse to the live items when
    // collapsed, so a hot-plug does not leave a stale length behind (PR #354).
    func invalidateLayout()
}

enum MenuBarEngineState: Equatable {
    case expanded
    case calibrating
    case collapsed
    case unavailable
}

enum CollapseResult {
    case collapsed
    case unavailable
}

enum MenuBarOrder {
    // True when `item` sits on the hidden side of `boundary`: to its left in a
    // left-to-right layout, to its right otherwise. False when either is not on
    // screen, since nothing can be judged then.
    static func isItem(_ item: NSStatusItem?, onHiddenSideOf boundary: NSStatusItem?) -> Bool {
        guard let itemX = item?.button?.getOrigin?.x,
              let boundaryX = boundary?.button?.getOrigin?.x else { return false }
        return Constant.isUsingLTRLanguage ? boundaryX >= itemX : boundaryX <= itemX
    }
}

// The controller owns and recreates the status items; engines only borrow them.
protocol MenuBarItemProvider: AnyObject {
    var toggleItem: NSStatusItem { get }
    var separatorItem: NSStatusItem { get }
    var alwaysHiddenItem: NSStatusItem? { get }
}

// Unified-logging diagnostics. NSLog routes through os_log as *private*, so
// `log stream` renders every message as `<private>` — useless for debugging.
// This helper logs everything as public; the strings carry no user data, only
// bundle ids, coordinates and engine state.
enum AppLog {
    private static let logger = Logger(subsystem: "hideout", category: "menubar")
    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }
}

// Identifies the exact code behind a log line: MARKETING_VERSION only moves
// on tags, so this is bumped on every diagnostics-visibility change.
enum BuildInfo {
    static let diagnosticsRevision = 9
}
