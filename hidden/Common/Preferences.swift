//
//  Preferences.swift
//  Hidden Bar
//
//  Created by phucld on 12/18/19.
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import Foundation

enum Preferences {

    // One-time migration after the Hideout rebrand (bundle id
    // com.dwarvesv.minimalbar → net.dotoca.hideout): copy every stored key so
    // settings survive the identity change. The old domain is never modified,
    // so downgrading keeps the old settings. TCC Accessibility and the menu-bar
    // arrangement cannot migrate (system-owned): macOS re-prompts, icons need
    // a one-time ⌘-drag into place.
    static func migrateFromLegacyDomainIfNeeded() {
        let doneKey = "hideoutRebrandMigratedV1"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        if let legacy = UserDefaults(suiteName: "com.dwarvesv.minimalbar") {
            let source = legacy.dictionaryRepresentation()
            if !source.isEmpty {
                for (key, value) in source where key != doneKey {
                    defaults.set(value, forKey: key)
                }
            }
        }
        defaults.set(true, forKey: doneKey)
    }

    static var globalKey: GlobalKeybindPreferences? {
        get {
            guard let data = UserDefaults.standard.value(forKey: UserDefaults.Key.globalKey) as? Data else { return nil }
            return try? JSONDecoder().decode(GlobalKeybindPreferences.self, from: data)
        }
        
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: UserDefaults.Key.globalKey)
            } else if newValue == nil {
                // encode(nil) comes back empty; without this the key survives in
                // defaults and the "cleared" shortcut is back after relaunch.
                UserDefaults.standard.removeObject(forKey: UserDefaults.Key.globalKey)
            }
            
            NotificationCenter.default.post(Notification(name: .prefsChanged))
        }
    }
    
    static var isAutoStart: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserDefaults.Key.isAutoStart)
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaults.Key.isAutoStart)
            
            Util.setUpAutoStart(isAutoStart: newValue)
            
            NotificationCenter.default.post(Notification(name: .prefsChanged))
        }
    }
    
    static var numberOfSecondForAutoHide: Double {
        get {
            UserDefaults.standard.double(forKey: UserDefaults.Key.numberOfSecondForAutoHide)
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaults.Key.numberOfSecondForAutoHide)
            
            NotificationCenter.default.post(Notification(name: .prefsChanged))
        }
    }
    
    static var isAutoHide: Bool {
        get {
            UserDefaults.standard.bool(forKey: UserDefaults.Key.isAutoHide)
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaults.Key.isAutoHide)
            
            NotificationCenter.default.post(Notification(name: .prefsChanged))
        }
    }
    
    static var isShowPreference: Bool {
        get {
            UserDefaults.standard.bool(forKey: UserDefaults.Key.isShowPreference)
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaults.Key.isShowPreference)
            
            NotificationCenter.default.post(Notification(name: .prefsChanged))
        }
    }
    
    static var areSeparatorsHidden: Bool {
        get {
            UserDefaults.standard.bool(forKey: UserDefaults.Key.areSeparatorsHidden)
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaults.Key.areSeparatorsHidden)
        }
    }
    
    static var alwaysHiddenSectionEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: UserDefaults.Key.alwaysHiddenSectionEnabled)
        }

        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaults.Key.alwaysHiddenSectionEnabled)
            NotificationCenter.default.post(Notification(name: .alwayHideToggle))
        }
    }

    // One-time marker: enabling the always-hidden section hides the separators
    // once, otherwise the zone never holds while expanded (expand releases the
    // restriction when separators are shown). Later Option-clicks are untouched.
    static var didEnforceSeparatorsForAlwaysHidden: Bool {
        get {
            UserDefaults.standard.bool(forKey: UserDefaults.Key.didEnforceSeparatorsForAlwaysHidden)
        }

        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaults.Key.didEnforceSeparatorsForAlwaysHidden)
        }
    }
    
    static var hoverToExpand: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserDefaults.Key.hoverToExpand)
        }

        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaults.Key.hoverToExpand)
        }
    }

    // Whether system-owned menu-bar items (Now Playing/Player, MenuBarAgent,
    // Passwords and other com.apple.* extras) are always kept visible on
    // collapse, regardless of which section the user dragged them into. Off by
    // default: system items follow the normal section rules, so a system extra
    // left of the separator hides with the rest. On because some system extras
    // (Now Playing) are not exposed to Accessibility and cannot be re-allowed by
    // bundle, so they vanish when collapsed — flip this on to force-keep them.
    static var keepSystemItemsVisible: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserDefaults.Key.keepSystemItemsVisible)
        }

        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaults.Key.keepSystemItemsVisible)
            NotificationCenter.default.post(Notification(name: .prefsChanged))
        }
    }

    static var lastCollapsedState: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "lastCollapsedState")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastCollapsedState")
        }
    }

    static var useFullStatusBarOnExpandEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: UserDefaults.Key.useFullStatusBarOnExpandEnabled)
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaults.Key.useFullStatusBarOnExpandEnabled)
        }
    }

    static var lastUpdateCheck: Date? {
        get {
            UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastUpdateCheck")
        }
    }


}
