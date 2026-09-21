//
//  Preferences.swift
//  Hidden Bar
//
//  Created by phucld on 12/18/19.
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import Foundation

enum Preferences {
    
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
    
    static var hoverToExpand: Bool {
        get {
            return UserDefaults.standard.bool(forKey: UserDefaults.Key.hoverToExpand)
        }

        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaults.Key.hoverToExpand)
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

    // Which hiding engine the user wants. "auto" lets MenuBarEngineFactory pick
    // (native on macOS 27 direct build, legacy otherwise). "native" forces the
    // native visibility engine; "legacy" forces the spacer-length engine. Forcing
    // a build-incompatible choice falls back to auto at engine construction.
    enum MenuBarEnginePreference: String {
        case auto
        case native
        case legacy
    }

    static var menuBarEnginePreference: MenuBarEnginePreference {
        get {
            let raw = UserDefaults.standard.string(forKey: UserDefaults.Key.menuBarEnginePreference)
            return MenuBarEnginePreference(rawValue: raw ?? "") ?? .auto
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: UserDefaults.Key.menuBarEnginePreference)
            NotificationCenter.default.post(Notification(name: .enginePreferenceChanged))
        }
    }

    
}
