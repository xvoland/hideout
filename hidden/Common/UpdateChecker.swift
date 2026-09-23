//
//  UpdateChecker.swift
//  Hideout
//
//  Created by Vitalii Tereshchuk, 2026
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import AppKit

/// Lightweight update check against the GitHub Releases API. No dependencies,
/// no auto-install: when a newer stable release exists it shows a dialog with
/// a Download button that opens the releases page in the browser.
///
/// Schedule: checked at launch, throttled to once per 7 days (persisted in
/// `Preferences.lastUpdateCheck`). The manual menu entry bypasses the
/// throttle and also confirms the "up to date" state.
///
/// Stable-only is enforced by the endpoint choice: `/releases/latest`
/// resolves to the newest non-prerelease, non-draft release, so
/// `-goldengate-test` tags are never offered. All failures (offline,
/// rate-limited, sandboxed without network) are silent by design — the check
/// must never nag.
final class UpdateChecker: NSObject {

    static let shared = UpdateChecker()
    private override init() { super.init() }

    private static let latestAPI = URL(string: "https://api.github.com/repos/xvoland/hideout/releases/latest")!
    private static let releasesPage = URL(string: "https://github.com/xvoland/hideout/releases/latest")!
    private static let checkInterval: TimeInterval = 7 * 24 * 3600

    private struct Release: Decodable {
        let tagName: String
        let htmlUrl: String
        private enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
        }
    }

    /// Auto-check entry point (called at launch). No-ops until the throttle expires.
    func checkIfDue() {
        let last = Preferences.lastUpdateCheck ?? .distantPast
        guard Date().timeIntervalSince(last) >= Self.checkInterval else { return }
        check(manual: false)
    }

    /// Manual entry point from the status menu. Always runs; reports "up to date".
    @objc func checkNow() {
        check(manual: true)
    }

    private func check(manual: Bool) {
        var request = URLRequest(url: Self.latestAPI, timeoutInterval: 20)
        request.setValue("Hideout-update-check", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil,
                  let release = try? JSONDecoder().decode(Release.self, from: data) else {
                AppLog.info("UpdateCheck: request failed (\(error?.localizedDescription ?? "bad payload")) — silent")
                return
            }
            Preferences.lastUpdateCheck = Date()
            let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            if Self.isNewer(tag: release.tagName, than: current) {
                AppLog.info("UpdateCheck: \(release.tagName) newer than \(current) — prompting")
                DispatchQueue.main.async {
                    self.prompt(tag: release.tagName, current: current,
                                url: URL(string: release.htmlUrl) ?? Self.releasesPage)
                }
            } else if manual {
                AppLog.info("UpdateCheck: up to date (\(current)) — confirming")
                DispatchQueue.main.async { self.confirmUpToDate(version: current) }
            } else {
                AppLog.info("UpdateCheck: up to date (\(current)) — silent")
            }
        }.resume()
    }

    /// Compares dotted versions: "v1.20.0" > "1.19.0". Strips a leading "v"
    /// and any "-suffix" (defensive: the endpoint never returns prereleases,
    /// but tags are user-controlled strings).
    static func isNewer(tag: String, than current: String) -> Bool {
        func parts(_ s: String) -> [Int] {
            var v = s
            if v.hasPrefix("v") { v.removeFirst() }
            v = v.split(separator: "-").first.map(String.init) ?? v
            return v.split(separator: ".").map { Int($0) ?? 0 }
        }
        let a = parts(tag), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    private func prompt(tag: String, current: String, url: URL) {
        let alert = NSAlert()
        alert.messageText = "A new version of Hideout is available".localized
        alert.informativeText = "\(tag) is out — you have \(current).".localized
        alert.addButton(withTitle: "Download".localized)
        alert.addButton(withTitle: "Later".localized)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(url)
        }
    }

    private func confirmUpToDate(version: String) {
        let alert = NSAlert()
        alert.messageText = "Hideout is up to date".localized
        alert.informativeText = "Version \(version) is the latest stable release.".localized
        alert.addButton(withTitle: "OK".localized)
        alert.runModal()
    }
}
