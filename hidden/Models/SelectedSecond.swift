//
//  SelectedSecond.swift
//  Hidden Bar
//
//  Created by phucld on 12/18/19.
//  Changed by Vitalii Tereshchuk / xVoLAnD, 2026
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import Foundation

enum SelectedSecond: Int, CaseIterable {
    case fiveSeconds = 0
    case tenSeconds = 1
    case fifteenSeconds = 2
    case thirtySeconds = 3
    case oneMinute = 4

    func toSeconds() -> Double {
        switch self {
        case .fiveSeconds:  return 5.0
        case .tenSeconds:   return 10.0
        case .fifteenSeconds: return 15.0
        case .thirtySeconds: return 30.0
        case .oneMinute:    return 60.0
        }
    }

    /// Index into the panel's delay popup. Derived from the raw values so the
    /// enum order and the popup item order cannot drift apart.
    static func secondToPosition(seconds: Double) -> Int {
        if let match = allCases.first(where: { $0.toSeconds() == seconds }) {
            return match.rawValue
        }
        return Self.fiveSeconds.rawValue
    }
}
