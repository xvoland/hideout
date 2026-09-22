//
//  MenuBarEngineFactory.swift
//  Hidden Bar
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//  macOS 27 Golden Gate fork — xVoLAnD (https://dotoca.net)
//

import Foundation
import os

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

// The single place that picks a hiding mechanism for the running OS.
enum MenuBarEngineFactory {
    // Whether the running build can offer the native visibility engine at all
    // (direct, non-sandboxed build linked with HIDDENBAR_NATIVE_VISIBILITY on 27).
    static var nativeVisibilityAvailable: Bool {
        #if HIDDENBAR_NATIVE_VISIBILITY
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
        #else
        return false
        #endif
    }

    // Resolves the user's preference against what the build can actually do.
    // "auto" → native on 27 direct build, else legacy. "native" forced but
    // rejected when unavailable (falls back to legacy). "legacy" always honored.
    static func resolvedPreference(_ preference: Preferences.MenuBarEnginePreference) -> Preferences.MenuBarEnginePreference {
        switch preference {
        case .auto:
            return nativeVisibilityAvailable ? .native : .legacy
        case .native:
            return nativeVisibilityAvailable ? .native : .legacy
        case .legacy:
            return .legacy
        }
    }

    static func make(items: MenuBarItemProvider) -> MenuBarEngine {
        // macOS 27 ejects an inflated separator from the menu bar (#360). When the
        // native visibility API is available (direct, non-sandboxed build on 27) we
        // hide natively instead — independent of display width, notch and the
        // frontmost app's menus. Otherwise we fall back to the legacy length engine
        // with its macOS 27 spacer block.
        let resolved = resolvedPreference(Preferences.menuBarEnginePreference)
        // The resolved engine is the one that actually runs: on builds without
        // the native visibility API (plain Debug/Release, App Store) both .auto
        // and .native fall back to .legacy. Logged so a "hides nothing" report
        // can be told apart from a broken engine.
        AppLog.info("MenuBarEngine: preference=\(Preferences.menuBarEnginePreference.rawValue) resolved=\(resolved.rawValue) nativeAvailable=\(nativeVisibilityAvailable)")
        if resolved == .native {
            return NativeVisibilityEngine(items: items)
        }
        return LegacyLengthEngine(items: items)
    }
}
