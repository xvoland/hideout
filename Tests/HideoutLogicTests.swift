//
//  HideoutLogicTests.swift
//  Hideout
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//  macOS 27 Golden Gate fork — xVoLAnD (https://dotoca.net)
//
//  Pure-logic tests for the parts that do not need the real menu bar. The
//  engine's hide/reflow behaviour is still verified manually against the live
//  bar (docs/RUNBOOK.md); these tests pin down the classification and parsing
//  rules that used to have no safety net at all.
//

import XCTest
@testable import Hideout

final class HideoutLogicTests: XCTestCase {

    // MARK: - Section classification

    private let separator = CGRect(x: 100, y: 0, width: 8, height: 20) // midX 104
    private let alwaysHidden = CGRect(x: 40, y: 0, width: 8, height: 20) // midX 44

    private func section(x: CGFloat, isLTR: Bool) -> MenuBarSection {
        MenuBarLayoutResolver.section(of: CGRect(x: x, y: 0, width: 16, height: 16),
                                      separatorFrame: separator,
                                      alwaysHiddenSeparatorFrame: alwaysHidden,
                                      isLTR: isLTR)
    }

    func testSectionsLTR() {
        XCTAssertEqual(section(x: 120, isLTR: true), .visible)
        XCTAssertEqual(section(x: 70, isLTR: true), .hidden)
        XCTAssertEqual(section(x: 20, isLTR: true), .alwaysHidden)
    }

    func testSectionsRTLMirror() {
        XCTAssertEqual(section(x: 80, isLTR: false), .visible)
        XCTAssertEqual(section(x: 130, isLTR: false), .hidden)
        XCTAssertEqual(section(x: 200, isLTR: false), .alwaysHidden)
    }

    func testNoAlwaysHiddenSeparatorMeansTwoZones() {
        let section = MenuBarLayoutResolver.section(of: CGRect(x: 20, y: 0, width: 16, height: 16),
                                                    separatorFrame: separator,
                                                    alwaysHiddenSeparatorFrame: nil,
                                                    isLTR: true)
        XCTAssertEqual(section, .hidden)
    }

    // MARK: - Layout resolution

    func testMostVisibleItemWinsForBundle() {
        let inventory = [
            MenuBarInventoryItem(bundleIdentifier: "app.example", frame: CGRect(x: 130, y: 0, width: 16, height: 16)),
            MenuBarInventoryItem(bundleIdentifier: "app.example", frame: CGRect(x: 70, y: 0, width: 16, height: 16)),
        ]
        let layout = MenuBarLayoutResolver.resolve(inventory: inventory,
                                                   separatorFrame: separator,
                                                   alwaysHiddenSeparatorFrame: alwaysHidden,
                                                   isLTR: true,
                                                   excludingBundle: nil)
        XCTAssertEqual(layout.sections["app.example"], .visible)
        XCTAssertEqual(layout.bundles(in: [.hidden]), [])
        XCTAssertEqual(layout.bundles(in: [.visible]), ["app.example"])
    }

    func testOwnAndSystemBundlesAreExcluded() {
        let inventory = [
            MenuBarInventoryItem(bundleIdentifier: "net.dotoca.hideout", frame: CGRect(x: 130, y: 0, width: 16, height: 16)),
            MenuBarInventoryItem(bundleIdentifier: "com.apple.MenuBarAgent", frame: CGRect(x: 130, y: 0, width: 16, height: 16)),
            MenuBarInventoryItem(bundleIdentifier: "app.example", frame: CGRect(x: 70, y: 0, width: 16, height: 16)),
            MenuBarInventoryItem(bundleIdentifier: nil, frame: CGRect(x: 70, y: 0, width: 16, height: 16)),
        ]
        let layout = MenuBarLayoutResolver.resolve(inventory: inventory,
                                                   separatorFrame: separator,
                                                   alwaysHiddenSeparatorFrame: alwaysHidden,
                                                   isLTR: true,
                                                   excludingBundle: "net.dotoca.hideout")
        XCTAssertEqual(Set(layout.sections.keys), ["app.example"])
        XCTAssertEqual(layout.bundles(in: [.hidden, .visible]), ["app.example"])
    }

    // MARK: - Version comparison

    func testVersionComparison() {
        XCTAssertTrue(UpdateChecker.isNewer(tag: "v1.26.0", than: "1.25.0"))
        XCTAssertTrue(UpdateChecker.isNewer(tag: "v1.25.1", than: "1.25.0"))
        XCTAssertFalse(UpdateChecker.isNewer(tag: "v1.25.0", than: "1.25.0"))
        XCTAssertFalse(UpdateChecker.isNewer(tag: "v1.24.9", than: "1.25.0"))
        XCTAssertFalse(UpdateChecker.isNewer(tag: "v1.25.0-rc1", than: "1.25.0"))
        XCTAssertTrue(UpdateChecker.isNewer(tag: "v2.0", than: "1.25.9"))
    }

    // MARK: - Shortcut rendering

    func testShortcutDescription() {
        let bind = GlobalKeybindPreferences(function: false, control: true, command: false,
                                            shift: false, option: false, capsLock: false,
                                            carbonFlags: 0, characters: "a", keyCode: 0)
        XCTAssertEqual(bind.description, "⌃A")

        let fKey = GlobalKeybindPreferences(function: true, control: false, command: false,
                                            shift: false, option: false, capsLock: false,
                                            carbonFlags: 0, characters: nil, keyCode: 122)
        XCTAssertEqual(fKey.description, "F1")
    }

    // MARK: - Delay mapping

    func testSelectedSecondMapping() {
        for value in SelectedSecond.allCases {
            XCTAssertEqual(SelectedSecond.secondToPosition(seconds: value.toSeconds()), value.rawValue)
        }
        XCTAssertEqual(SelectedSecond.secondToPosition(seconds: 999), SelectedSecond.fiveSeconds.rawValue)
    }

    // MARK: - Preference edge cases (regressions fixed in v1.26.0)

    func testClearingShortcutRemovesTheKey() {
        let bind = GlobalKeybindPreferences(function: false, control: false, command: true,
                                            shift: false, option: false, capsLock: false,
                                            carbonFlags: 0, characters: "p", keyCode: 35)
        Preferences.globalKey = bind
        XCTAssertNotNil(UserDefaults.standard.data(forKey: UserDefaults.Key.globalKey))
        Preferences.globalKey = nil
        XCTAssertNil(UserDefaults.standard.data(forKey: UserDefaults.Key.globalKey))
    }

    func testAutoHideDelayHasAMinimum() {
        let key = UserDefaults.Key.numberOfSecondForAutoHide
        let original = UserDefaults.standard.object(forKey: key)
        defer {
            if let original = original { UserDefaults.standard.set(original, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        UserDefaults.standard.set(0.0, forKey: key)
        XCTAssertEqual(Preferences.numberOfSecondForAutoHide, 1.0)
    }
}
