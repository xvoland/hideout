//
//  NativeVisibilityBridge.swift
//  Hidden Bar
//
//  Copyright © 2026 Dwarves Foundation. All rights reserved.
//  macOS 27 Golden Gate fork — xVoLAnD (https://dotoca.net)
//

import Foundation

// A held native visibility restriction. Hiding lasts until invalidate() or until
// this process exits, when macOS drops it and restores the bar by itself.
protocol NativeVisibilityAssertion: AnyObject {
    func invalidate()
}

protocol NativeVisibilityProviding: AnyObject {
    var isAvailable: Bool { get }

    // Keeps only these system items and apps visible. The completion runs on the
    // main queue.
    func activate(allowedSystemItems: [Int],
                  allowedBundleIdentifiers: [String],
                  completion: @escaping (Result<NativeVisibilityAssertion, Error>) -> Void)
}

final class NativeVisibilityBridge: NativeVisibilityProviding {
    // Sent on every activation (collapse, expanded presentation, launch,
    // newcomer watch). Build the 4096 NSNumbers once instead of on each call.
    private static let cachedSystemItems = NativeVisibilityEngine.systemItemsToKeep
    private static let cachedSystemItemNumbers: [NSNumber] = cachedSystemItems.map { NSNumber(value: $0) }

    var isAvailable: Bool {
        return HBNativeVisibilityIsAvailable()
    }

    func activate(allowedSystemItems: [Int],
                  allowedBundleIdentifiers: [String],
                  completion: @escaping (Result<NativeVisibilityAssertion, Error>) -> Void) {
        let numbers = allowedSystemItems == Self.cachedSystemItems
            ? Self.cachedSystemItemNumbers
            : allowedSystemItems.map { NSNumber(value: $0) }
        HBNativeVisibilityActivate(numbers,
                                   allowedBundleIdentifiers) { handle, error in
            if let handle = handle {
                completion(.success(Handle(raw: handle)))
            } else {
                completion(.failure(error ?? NSError(domain: "HBNativeVisibility", code: 2)))
            }
        }
    }

    private final class Handle: NativeVisibilityAssertion {
        private var raw: Any?

        init(raw: Any) {
            self.raw = raw
        }

        func invalidate() {
            guard let raw = raw else { return }
            self.raw = nil
            HBNativeVisibilityInvalidate(raw)
        }

        deinit {
            invalidate()
        }
    }
}
