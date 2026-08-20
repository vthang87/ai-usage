import AppKit
import Foundation
import Observation

enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case available(version: String, url: URL)
    case failed(String)
}

@MainActor
@Observable
final class UpdateChecker {
    private(set) var status: UpdateStatus = .idle

    private let endpoint: URL
    private let defaults: UserDefaults
    private let current: SemanticVersion
    private let minimumInterval: TimeInterval

    init(
        endpoint: URL = URL(string: "https://api.github.com/repos/vthang87/ai-usage/releases/latest")!,
        defaults: UserDefaults = .standard,
        current: SemanticVersion = AppVersion.semantic,
        minimumInterval: TimeInterval = 6 * 60 * 60
    ) {
        self.endpoint = endpoint
        self.defaults = defaults
        self.current = current
        self.minimumInterval = minimumInterval
        restoreCachedStatus()
    }

    func checkIfNeeded() async {
        if case .available = status { return }
        if let last = defaults.object(forKey: Keys.lastCheckedAt) as? Date,
           Date().timeIntervalSince(last) < minimumInterval {
            return
        }
        await check(force: false)
    }

    func check(force: Bool) async {
        if case .checking = status { return }
        status = .checking
        do {
            let release = try await fetchLatest()
            defaults.set(Date(), forKey: Keys.lastCheckedAt)
            apply(release)
        } catch {
            if force {
                status = .failed("Could not check for updates")
            } else {
                restoreCachedStatus()
            }
        }
    }

    func openAvailableRelease() {
        guard case let .available(_, url) = status else { return }
        NSWorkspace.shared.open(url)
    }

    private func fetchLatest() async throws -> GitHubRelease {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("AIUsage/\(current.string)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw CollectorError.unexpectedResponse("GitHub releases returned HTTP \(http.statusCode)")
        }
        return try GitHubReleaseParser.latest(from: data)
    }

    private func apply(_ release: GitHubRelease) {
        defaults.set(release.tagName, forKey: Keys.latestTag)
        defaults.set(release.htmlURL.absoluteString, forKey: Keys.latestURL)
        if let latest = release.version, latest > current {
            status = .available(version: latest.string, url: release.htmlURL)
        } else {
            status = .upToDate
        }
    }

    private func restoreCachedStatus() {
        guard let tag = defaults.string(forKey: Keys.latestTag),
              let urlString = defaults.string(forKey: Keys.latestURL),
              let url = URL(string: urlString),
              let latest = SemanticVersion(tag),
              latest > current
        else {
            if status == .checking { status = .idle }
            return
        }
        status = .available(version: latest.string, url: url)
    }

    private enum Keys {
        static let lastCheckedAt = "update.lastCheckedAt"
        static let latestTag = "update.latestTag"
        static let latestURL = "update.latestURL"
    }
}
