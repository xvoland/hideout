//
//  UpdateManager.swift
//  Hideout
//
//  Sparkle-backed update flow. Checks and downloads happen in the background;
//  the tray panel shows what is happening and offers a one-click install.
//
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//  Changed by Vitalii Tereshchuk / xVoLAnD, 2026.
//

import AppKit
import Sparkle

enum UpdateStatus {
    case idle
    case checking
    case available
    case downloading
    case ready
    case failed

    var message: String {
        switch self {
        case .idle: return "Up to date".localized
        case .checking: return "Checking for updates…".localized
        case .available: return "Update available".localized
        case .downloading: return "Downloading update…".localized
        case .ready: return "Update ready to install".localized
        case .failed: return "Update check failed".localized
        }
    }
}

/// Owns the Sparkle updater and exposes a tiny, observable state machine to
/// the tray panel. `SUAutomaticallyUpdate` makes Sparkle download updates in
/// the background and install them on quit; we keep the installation handler
/// so the panel can offer "Install now" while the app is still running.
final class UpdateManager: NSObject, SPUUpdaterDelegate {

    static let shared = UpdateManager()

    private var controller: SPUStandardUpdaterController!
    private var started = false
    private var pendingInstall: (() -> Void)?
    private var currentStatus: UpdateStatus = .idle

    private override init() {
        super.init()
    }

    var status: UpdateStatus { currentStatus }

    private var updater: SPUUpdater { controller.updater }

    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyInstallsUpdates: Bool {
        get { updater.automaticallyDownloadsUpdates }
        set { updater.automaticallyDownloadsUpdates = newValue }
    }

    func start() {
        guard !started else { return }
        started = true
        controller = SPUStandardUpdaterController(startingUpdater: false,
                                                  updaterDelegate: self,
                                                  userDriverDelegate: nil)
        installMainMenuItem()
        controller.startUpdater()
    }

    // MARK: - Actions

    func checkNow() {
        pendingInstall = nil
        setStatus(.checking)
        controller.checkForUpdates(nil)
    }

    /// Installs a downloaded update immediately, or runs a normal check when
    /// Sparkle has not handed us a pending installation yet.
    func installNow() {
        if let install = pendingInstall {
            pendingInstall = nil
            install()
        } else {
            checkNow()
        }
    }

    @objc func checkUpdates(_ sender: Any?) {
        checkNow()
    }

    // MARK: - Main menu

    private func installMainMenuItem() {
        guard let menu = NSApp.mainMenu?.items.first?.submenu else { return }
        let selector = #selector(checkUpdates(_:))
        guard !menu.items.contains(where: { $0.action == selector }) else { return }

        let item = NSMenuItem(title: "Check for Updates…".localized,
                              action: selector,
                              keyEquivalent: "")
        item.target = self
        menu.insertItem(item, at: min(2, menu.items.count))
    }

    // MARK: - Status

    private func setStatus(_ status: UpdateStatus) {
        if Thread.isMainThread {
            apply(status)
        } else {
            DispatchQueue.main.async { [weak self] in self?.apply(status) }
        }
    }

    private func apply(_ status: UpdateStatus) {
        currentStatus = status
        NotificationCenter.default.post(name: .updateStatusChanged, object: self)
    }

    // MARK: - SPUUpdaterDelegate

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        setStatus(.available)
    }

    func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        setStatus(.ready)
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: any Error) {
        setStatus(.failed)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
        if currentStatus == .checking { setStatus(.idle) }
    }

    /// Returning YES lets us show "Install now" in the panel instead of
    /// installing silently behind the user's back. Sparkle still installs on
    /// quit if we never invoke the handler.
    func updater(_ updater: SPUUpdater,
                 willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.pendingInstall = immediateInstallHandler
            self?.setStatus(.ready)
        }
        return true
    }
}
