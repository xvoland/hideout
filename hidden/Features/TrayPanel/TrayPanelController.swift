//
//  TrayPanelController.swift
//  Hideout
//
//  Created by Vitalii Tereshchuk (xVoLAnD), 2026
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import AppKit

/// Owns the transient popover that replaced the Preferences window.
///
/// It follows the tray-panel pattern: a compact panel anchored to the arrow
/// status item, dismissed by Escape or a click outside, with a height the user
/// can drag and that is remembered across launches.
final class TrayPanelController: NSObject, NSPopoverDelegate {

    static let shared = TrayPanelController()

    /// The panel's fixed width. Its height changes with the grip.
    static let width: CGFloat = 340

    private static let minimumHeight: CGFloat = 380
    private static let defaultHeight: CGFloat = 600
    private static let maximumScreenShare: CGFloat = 0.8

    private let popover = NSPopover()
    private let panel = TrayPanelViewController()

    private(set) var isVisible = false

    /// The tallest the panel may grow on the screen it is shown on.
    private var heightLimit: CGFloat = 0

    /// When the popover last closed. A transient popover closes on the
    /// mouse-down that precedes the right-click's mouse-up on the arrow, so
    /// the toggle would otherwise reopen what the click just dismissed.
    private var lastCloseDate: Date?

    private override init() {
        super.init()
        panel.onRequestClose = { [weak self] in self?.close() }
        panel.onResize = { [weak self] height, commit in
            self?.resize(to: height, commit: commit)
        }
        panel.onSetAnimates = { [weak self] animates in
            self?.setAnimates(animates)
        }
        popover.contentViewController = panel
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    /// Opens the panel below the arrow, or closes it when already open, so a
    /// second right-click behaves like a toggle.
    func toggle(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            close()
        } else if let lastClose = lastCloseDate, Date().timeIntervalSince(lastClose) < 0.3 {
            // The click that dismissed the transient popover; stay closed.
            AppLog.info("TrayPanel: toggle ignored — just closed")
        } else {
            show(relativeTo: button)
        }
    }

    func show(relativeTo button: NSStatusBarButton) {
        guard !popover.isShown else { return }

        let screen = button.window?.screen ?? NSScreen.main
        let screenHeight = screen?.visibleFrame.height ?? 900
        heightLimit = max(Self.minimumHeight, screenHeight * Self.maximumScreenShare)

        let saved = CGFloat(Preferences.panelHeight)
        let height = clampHeight(saved > 0 ? saved : Self.defaultHeight)

        panel.heightLimit = heightLimit
        panel.setCurrentHeight(height)
        panel.prepareForPresentation()

        popover.contentSize = NSSize(width: Self.width, height: height)

        // An accessory app must become active for the popover to take key
        // focus (needed by the shortcut recorder) and for clicks outside to
        // dismiss it.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        isVisible = true
        AppLog.info("TrayPanel: shown at height \(Int(height))")
    }

    func close() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    /// Turns the popover's open/close animation off while the grip is dragged:
    /// an animated resize would trail the pointer.
    func setAnimates(_ animates: Bool) {
        popover.animates = animates
    }

    private func resize(to height: CGFloat, commit: Bool) {
        let clamped = clampHeight(height)
        popover.contentSize = NSSize(width: Self.width, height: clamped)
        if commit {
            Preferences.panelHeight = Double(clamped)
            AppLog.info("TrayPanel: height saved \(Int(clamped))")
        }
    }

    private func clampHeight(_ height: CGFloat) -> CGFloat {
        let limit = heightLimit > 0 ? heightLimit : Self.defaultHeight
        return min(max(height, Self.minimumHeight), limit)
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        isVisible = false
        lastCloseDate = Date()
        panel.panelDidClose()
        AppLog.info("TrayPanel: closed")
    }
}
