//
//  AccessibilityMenuBarInventory.swift
//  Hidden Bar
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//  macOS 27 Golden Gate fork — xVoLAnD (https://dotoca.net)
//

import AppKit
import ApplicationServices

// Lists other apps' status items through public Accessibility API: every running
// app's AXExtrasMenuBar children, with the owning bundle from the process.
// Needs the Accessibility permission, and does not work inside the App Sandbox
// (the sandbox denies the mach-lookup to com.apple.axserver even when the
// permission is granted), so only the non-sandboxed direct build uses it.
final class AccessibilityMenuBarInventory: MenuBarInventoryProviding {
    private static let messagingTimeout: Float = 0.1

    // The census is requested from several places (collapse, expanded
    // presentation, the newcomer poll, post-collapse diagnostics). One AX walk
    // takes ~1s, so concurrent requests share the in-flight result instead of
    // each paying for a full walk. Callers arriving during a walk join it;
    // the next request after delivery starts a fresh one.
    private let coordination = DispatchQueue(label: "hideout.ax.snapshot")
    private var pending: [([MenuBarInventoryItem]) -> Void] = []
    private var isWalking = false

    private var hasRequestedAuthorization = false

    var isAuthorized: Bool {
        return AXIsProcessTrusted()
    }

    // Shows the system prompt once per launch; asking on every collapse would
    // nag while the user is still in System Settings.
    func requestAuthorization() {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // Accessibility round-trips to every app take about a second in total, so the
    // walk runs off the main thread.
    func snapshot(completion: @escaping ([MenuBarInventoryItem]) -> Void) {
        var startsWalk = false
        coordination.sync {
            pending.append(completion)
            if !isWalking {
                isWalking = true
                startsWalk = true
            }
        }
        guard startsWalk else { return }

        // Only app bundles own status items. Skipping the rest (dozens of WebKit
        // and XPC helpers, each of which would sit out the timeout) cuts the walk
        // from ~2.8s to ~1s.
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.processIdentifier != ownPID && $0.bundleURL?.pathExtension == "app" }
            .map { (pid: $0.processIdentifier, bundleIdentifier: $0.bundleIdentifier) }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let items = Self.statusItems(of: apps)
            DispatchQueue.main.async {
                guard let self = self else { return }
                var callbacks: [([MenuBarInventoryItem]) -> Void] = []
                self.coordination.sync {
                    callbacks = self.pending
                    self.pending.removeAll()
                    self.isWalking = false
                }
                for callback in callbacks { callback(items) }
            }
        }
    }

    private static func statusItems(of apps: [(pid: pid_t, bundleIdentifier: String?)]) -> [MenuBarInventoryItem] {
        var items: [MenuBarInventoryItem] = []
        for app in apps {
            let element = AXUIElementCreateApplication(app.pid)
            // The default timeout is several seconds per app, and one busy or hung
            // app then stalls the collapse (measured: ~18s on a normal session).
            AXUIElementSetMessagingTimeout(element, messagingTimeout)
            var barValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, "AXExtrasMenuBar" as CFString, &barValue) == .success,
                  let barValue = barValue,
                  CFGetTypeID(barValue) == AXUIElementGetTypeID() else { continue }
            // CFGetTypeID above guarantees this cast; `as?` is rejected by the
            // compiler because a downcast to a CoreFoundation type always succeeds.
            let bar = barValue as! AXUIElement
            var childrenValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(bar, kAXChildrenAttribute as CFString, &childrenValue) == .success,
                  let children = childrenValue as? [AXUIElement] else { continue }
            for child in children {
                guard let frame = frame(of: child) else { continue }
                items.append(MenuBarInventoryItem(bundleIdentifier: app.bundleIdentifier, frame: frame))
            }
        }
        return items
    }

    // Accessibility frames use a top-left origin, AppKit's bottom-left. Only the
    // horizontal position matters for sections, and x is the same in both.
    private static func frame(of element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue = positionValue,
              let sizeValue = sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        // CFGetTypeID checks above guarantee both casts; `as?` is rejected by
        // the compiler because a downcast to a CoreFoundation type always succeeds.
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: position, size: size)
    }
}
