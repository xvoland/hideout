//
//  StatusBarController.swift
//  vanillaClone
//
//  Created by Thanh Nguyen on 1/30/19.
//  Changed by Vitalii Tereshchuk / xVoLAnD, 2026
//  macOS 27 Golden Gate fork — xVoLAnD (https://dotoca.net)
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import AppKit

class StatusBarController: MenuBarItemProvider {

    //MARK: - Variables
    private var timer:Timer? = nil

    //MARK: - BarItems

    // Created and named in declaration order on purpose: a status item registers
    // with the menu bar under its autosave name, and on macOS 27 every new name
    // lands left of the previous one, so the bar reads separator, spacers, arrow.
    let btnExpandCollapse = StatusBarController.makeItem("hideout_expandcollapse", length: NSStatusItem.variableLength)
    let btnSeparate = StatusBarController.makeItem("hideout_separate", length: 1)
    var btnAlwaysHidden:NSStatusItem? = nil

    //MARK: - MenuBarItemProvider conformance
    var toggleItem: NSStatusItem { return btnExpandCollapse }
    var separatorItem: NSStatusItem { return btnSeparate }
    var alwaysHiddenItem: NSStatusItem? { return btnAlwaysHidden }

    private let imgIconLine = NSImage(named:NSImage.Name("ic_line"))

    // The engine owns the hiding mechanics; the controller decides WHAT the user
    // wants and reflects the result in the UI. On macOS 27 the direct build uses
    // NativeVisibilityEngine (native hiding); otherwise LegacyLengthEngine
    // with its spacer block (spacers are owned by the engine, not here).
    // Rebuilt when the user changes the engine preference.
    private var menuBarEngine: MenuBarEngine!

    private var isCollapsed: Bool {
        return menuBarEngine.state == .collapsed
    }

    private var isBtnAlwaysHiddenValidPosition: Bool {
        if !Preferences.alwaysHiddenSectionEnabled { return true }
        return menuBarEngine.isAlwaysHiddenSeparatorPlaced
    }

    private var isToggle = false

    private static let autosaveSuffix: String = {
        if #available(macOS 27.0, *) { return "_v27" }
        return ""
    }()

    static func makeItem(_ name: String, length: CGFloat) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: length)
        item.autosaveName = name + autosaveSuffix
        return item
    }

    private var hoverMonitor: Any?
    private var hoverDwellTimer: Timer?

    private var isMouseInMenuBar: Bool {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.contains { screen in
            mouse.x >= screen.frame.minX && mouse.x <= screen.frame.maxX
                && mouse.y >= screen.visibleFrame.maxY && mouse.y <= screen.frame.maxY
        }
    }

    private var isPreferencesWindowVisible: Bool {
        let wc = PreferencesWindowController.shared
        return wc.isWindowLoaded && (wc.window?.isVisible ?? false)
    }

    //MARK: - Methods
    init() {
        // Identity migration first: everything below reads Preferences.
        Preferences.migrateFromLegacyDomainIfNeeded()
        menuBarEngine = MenuBarEngineFactory.make(items: self)
        setupUI()
        setupAlwayHideStatusBar()
        setupHoverToExpandIfEnabled()
        updateHoverMonitoring()
        NotificationCenter.default.addObserver(self, selector: #selector(handleScreenParametersChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateHoverMonitoring), name: .prefsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(rebuildEngineIfNeeded), name: .enginePreferenceChanged, object: nil)

        // Create the engine now so one that does not use the separator (macOS 27
        // native hiding) takes it back out before it is ever drawn.
        _ = menuBarEngine
        if Preferences.areSeparatorsHidden {
            applySeparatorsHidden(true)
        }
        if Preferences.alwaysHiddenSectionEnabled {
            menuBarEngine.updateAlwaysHiddenSection(enabled: true, separatorHidden: Preferences.areSeparatorsHidden)
        }

        let isLikelyLoginLaunch = Self.isLikelyLoginLaunch()
        let initialDelay: TimeInterval = 15.0
        DispatchQueue.main.asyncAfter(deadline: .now() + initialDelay) { [weak self] in
            self?.restoreCollapsedState(isLoginLaunch: isLikelyLoginLaunch)
        }

        Self.saveLaunchTimestamp()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        hoverDwellTimer?.invalidate()
        if let monitor = hoverMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupHoverToExpandIfEnabled() {
        installHoverMonitor()
    }

    @objc private func updateHoverMonitoring() {
        removeHoverMonitor()
        installHoverMonitor()
    }

    private func installHoverMonitor() {
        guard hoverMonitor == nil else { return }
        guard Preferences.hoverToExpand else { return }
        AppLog.info("HoverToExpand: enabled, installing global mouse monitor")
        hoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            guard let self = self else { return }
            guard self.isCollapsed && self.isMouseInMenuBar else {
                self.hoverDwellTimer?.invalidate()
                self.hoverDwellTimer = nil
                return
            }
            guard self.hoverDwellTimer == nil else { return }
            self.hoverDwellTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                self.hoverDwellTimer = nil
                if self.isCollapsed && self.isMouseInMenuBar {
                    self.expandMenubar()
                }
            }
        }
    }

    private func removeHoverMonitor() {
        if let monitor = hoverMonitor {
            NSEvent.removeMonitor(monitor)
            hoverMonitor = nil
        }
        hoverDwellTimer?.invalidate()
        hoverDwellTimer = nil
    }

    @objc private func handleScreenParametersChanged() {
        menuBarEngine.invalidateLayout()
    }

    // Rebuild the hiding engine when the user changes the engine preference. The
    // previous engine is discarded; if it held a native assertion that is released
    // by deinit. The new engine restores the current collapsed/expanded state.
    @objc private func rebuildEngineIfNeeded() {
        let previousCollapsed = isCollapsed
        let previousAreSeparatorsHidden = Preferences.areSeparatorsHidden
        let previousAlwaysHidden = Preferences.alwaysHiddenSectionEnabled
        // Drop any active native assertion on the old engine before discarding it,
        // so a forced switch does not leave icons hidden by the previous engine.
        menuBarEngine.expand()
        menuBarEngine = MenuBarEngineFactory.make(items: self)
        if previousAreSeparatorsHidden {
            applySeparatorsHidden(true)
        }
        if previousAlwaysHidden {
            menuBarEngine.updateAlwaysHiddenSection(enabled: true, separatorHidden: previousAreSeparatorsHidden)
        }
        if previousCollapsed {
            collapseMenuBar()
        } else {
            expandMenubar(isInitialRestore: true)
        }
    }

    private func setupUI() {
        if let button = btnSeparate.button {
            button.image = self.imgIconLine
        }
        let menu = self.getContextMenu()
        btnSeparate.menu = menu

        updateAutoCollapseMenuTitle()

        if let button = btnExpandCollapse.button {
            button.image = Assets.collapseImage
            button.target = self

            button.action = #selector(self.btnExpandCollapsePressed(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc func btnExpandCollapsePressed(sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent {

            let isOptionKeyPressed = event.modifierFlags.contains(NSEvent.ModifierFlags.option)

            if event.type == NSEvent.EventType.leftMouseUp && !isOptionKeyPressed{
                self.expandCollapseIfNeeded()
            } else if event.type == NSEvent.EventType.rightMouseUp && !isOptionKeyPressed {
                showContextMenu(from: sender)
            } else {
                self.showHideSeparatorsAndAlwayHideArea()
            }
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        guard let menu = btnSeparate.menu else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY + 5), in: button)
    }

    func showHideSeparatorsAndAlwayHideArea() {
        Preferences.areSeparatorsHidden ? self.showSeparators() : self.hideSeparators()

        if self.isCollapsed {self.expandMenubar()}
    }

    private func showSeparators() {
        applySeparatorsHidden(false)
    }

    private func hideSeparators() {
        guard self.isBtnAlwaysHiddenValidPosition else {return}
        applySeparatorsHidden(true)
    }

    private func applySeparatorsHidden(_ hidden: Bool) {
        Preferences.areSeparatorsHidden = hidden
        menuBarEngine.updateAlwaysHiddenSection(
            enabled: Preferences.alwaysHiddenSectionEnabled,
            separatorHidden: hidden)
    }

    func expandCollapseIfNeeded() {
        // While the native engine calibrates (async Accessibility read plus
        // activation), presses are ignored: the bar is neither collapsed nor
        // expanded, and treating the press as a new collapse would pile
        // superseded activations behind the in-flight one.
        if menuBarEngine.state == .calibrating {
            AppLog.info("StatusBar: press ignored — engine calibrating")
            return
        }
        if isToggle {return}
        isToggle = true

        // Collapse can be asynchronous on macOS 27 (the native engine calibrates
        // against Accessibility before hiding). A second click during that window
        // must not be treated as a separate toggle, so keep the gate held until
        // the engine leaves .calibrating (with a hard ceiling so it can never
        // wedge the arrow). Expand is synchronous, so it releases immediately.
        let collapseStarted = !self.isCollapsed
        let action: () -> Void = collapseStarted ? { [weak self] in self?.collapseMenuBar() } : { [weak self] in self?.expandMenubar() }
        let release: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.isToggle = false
        }
        if collapseStarted {
            let pollInterval: TimeInterval = 0.03
            let timeout: TimeInterval = 3.0
            var elapsed: TimeInterval = 0
            Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                elapsed += pollInterval
                if self.menuBarEngine.state != .calibrating || elapsed >= timeout {
                    timer.invalidate()
                    release()
                }
            }
        }
        action()
        if !collapseStarted {
            release()
        }
    }

    private func restoreCollapsedState(isLoginLaunch: Bool = false) {
        if !menuBarEngine.isArrangementValid {
            expandMenubar(isInitialRestore: true)
            autoCollapseIfNeeded()
            return
        }

        if Preferences.isAutoHide && Preferences.lastCollapsedState {
            collapseMenuBar()
        } else {
            expandMenubar(isInitialRestore: true)
        }
        autoCollapseIfNeeded()
    }

    private static func isLikelyLoginLaunch() -> Bool {
        let lastLaunch = UserDefaults.standard.double(forKey: "lastLaunchTimestamp")
        let now = Date().timeIntervalSince1970
        return now - lastLaunch < 60 && lastLaunch > 0
    }

    private static func saveLaunchTimestamp() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastLaunchTimestamp")
    }

    private func collapseMenuBar() {
        guard menuBarEngine.isArrangementValid && !self.isCollapsed else {
            if !menuBarEngine.isArrangementValid {
                AppLog.info("StatusBar: collapse skipped — arrow is not on the visible side of the separator; ⌘-drag it past the separator")
            } else {
                AppLog.info("StatusBar: collapse ignored — already collapsed (engine state=\(menuBarEngine.state))")
            }
            Preferences.lastCollapsedState = false
            autoCollapseIfNeeded()
            return
        }
        AppLog.info("StatusBar: collapse requested")
        // The arrow flips only in didCollapseMenuBar once the engine confirms.
        // Flipping it here would show collapsed while nothing is hidden yet:
        // the native engine calibrates asynchronously (Accessibility snapshot
        // alone takes up to ~10s), and every screenshot taken in that window
        // "proved" hiding was broken when it had not even started.
        if Preferences.useFullStatusBarOnExpandEnabled {
            NSApp.setActivationPolicy(.accessory)
            NSApp.deactivate()
        }
        menuBarEngine.collapse { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .collapsed:
                self.didCollapseMenuBar()
            case .unavailable:
                self.didFailToCollapseMenuBar()
            }
        }
    }

    private func expandMenubar(isInitialRestore: Bool = false) {
        AppLog.info("StatusBar: expand requested (isCollapsed=\(self.isCollapsed))")
        guard self.isCollapsed else {return}
        if let button = btnExpandCollapse.button {
            button.image = Assets.collapseImage
        }
        if Preferences.useFullStatusBarOnExpandEnabled {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        Preferences.lastCollapsedState = false
        menuBarEngine.expand()
        if !isInitialRestore {
            autoCollapseIfNeeded()
        }
    }

    private func didFailToCollapseMenuBar() {
        AppLog.info("StatusBar: collapse failed (.unavailable) — arrow reverted to <")
        if let button = btnExpandCollapse.button {
            button.image = Assets.collapseImage
        }
        if Preferences.useFullStatusBarOnExpandEnabled {
            NSApp.setActivationPolicy(.regular)
        }
        Preferences.lastCollapsedState = false
    }

    private func didCollapseMenuBar() {
        AppLog.info("StatusBar: collapse completed (.collapsed)")
        if let button = btnExpandCollapse.button {
            button.image = Assets.expandImage
        }
        Preferences.lastCollapsedState = true
    }

    private func autoCollapseIfNeeded() {
        guard Preferences.isAutoHide else {return}
        guard !isCollapsed else { return }

        startTimerToAutoHide()
    }

    private func startTimerToAutoHide() {
        timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: Preferences.numberOfSecondForAutoHide, repeats: false) { [weak self] _ in
            guard let self = self, Preferences.isAutoHide else { return }
            if self.isMouseInMenuBar || self.isPreferencesWindowVisible {
                // Silent by design until now: this re-arm loop is why auto-hide
                // "stops working" whenever the pointer parks in the menu bar or
                // Preferences stays open (e.g. while switching engines to test).
                AppLog.info("StatusBar: auto-collapse deferred (pointerInBar=\(self.isMouseInMenuBar) prefsVisible=\(self.isPreferencesWindowVisible)) — re-arming")
                self.startTimerToAutoHide()
            } else {
                self.collapseMenuBar()
            }
        }
    }

    private func getContextMenu() -> NSMenu {
        let menu = NSMenu()

        let prefItem = NSMenuItem(title: "Preferences...".localized, action: #selector(openPreferenceViewControllerIfNeeded), keyEquivalent: "P")
        prefItem.target = self
        menu.addItem(prefItem)

        let toggleAutoHideItem = NSMenuItem(title: "Toggle Auto Collapse".localized, action: #selector(toggleAutoHide), keyEquivalent: "t")
        toggleAutoHideItem.target = self
        toggleAutoHideItem.tag = 1
        NotificationCenter.default.addObserver(self, selector: #selector(updateAutoHide), name: .prefsChanged, object: nil)
        menu.addItem(toggleAutoHideItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    private func updateAutoCollapseMenuTitle() {
        guard let toggleAutoHideItem = btnSeparate.menu?.item(withTag: 1) else { return }
        if Preferences.isAutoHide {
            toggleAutoHideItem.title = "Disable Auto Collapse".localized
        } else {
            toggleAutoHideItem.title = "Enable Auto Collapse".localized
        }
    }

    @objc func updateAutoHide() {
        updateAutoCollapseMenuTitle()
        autoCollapseIfNeeded()
    }

    @objc func openPreferenceViewControllerIfNeeded() {
        Util.showPrefWindow()
    }

    @objc func toggleAutoHide() {
        Preferences.isAutoHide.toggle()
    }
}


//MARK: - Alway hide feature
extension StatusBarController {
    private func setupAlwayHideStatusBar() {
        NotificationCenter.default.addObserver(self, selector: #selector(toggleStatusBarIfNeeded), name: .alwayHideToggle, object: nil)
        toggleStatusBarIfNeeded()
    }
    @objc private func toggleStatusBarIfNeeded() {
        if Preferences.alwaysHiddenSectionEnabled {
            if let existing = self.btnAlwaysHidden {
                NSStatusBar.system.removeStatusItem(existing)
            }
            self.btnAlwaysHidden = NSStatusBar.system.statusItem(withLength: 20)
            if let button = btnAlwaysHidden?.button {
                button.image = self.imgIconLine
                button.appearsDisabled = true
            }
            self.btnAlwaysHidden?.autosaveName = "hideout_terminate" + StatusBarController.autosaveSuffix
            self.btnAlwaysHidden?.isVisible = true
        } else {
            if let existing = self.btnAlwaysHidden {
                NSStatusBar.system.removeStatusItem(existing)
            }
            self.btnAlwaysHidden = nil
        }
        menuBarEngine.updateAlwaysHiddenSection(
            enabled: Preferences.alwaysHiddenSectionEnabled,
            separatorHidden: Preferences.areSeparatorsHidden)
    }
}
