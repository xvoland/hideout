//
//  Bundle+Extension.swift
//  Hideout
//
//  Created by phucld on 12/19/19.
//  Changed by Vitalii Tereshchuk / xVoLAnD, 2026
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import Foundation

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}
