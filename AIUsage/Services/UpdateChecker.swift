import AppKit
import Foundation
import Observation

enum UpdateStatus: Equatable {
    case idle
    case checking
    case upToDate
    case available(version: String, pageURL: URL, downloadURL: URL?)
    case downloading(version: String)
    case installing(version: String)
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .checking, .downloading, .installing:
            true
        default:
            false
        }
    }
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

    var actionTitle: String {
        switch status {
        case .checking:
            "Checking…"
        case let .downloading(version):
            "Downloading \(version)…"
        case let .installing(version):
            "Installing \(version)…"
        case let .available(version, _, _):
            "Install \(version)"
        default:
            "Check Update"
        }
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
        if status.isBusy { return }
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

    func performAction() {
        switch status {
        case .available:
            Task { await installAvailableUpdate() }
        case .checking, .downloading, .installing:
            break
        default:
            Task { await check(force: true) }
        }
    }

    func openAvailableRelease() {
        switch status {
        case let .available(_, pageURL, _):
            NSWorkspace.shared.open(pageURL)
        default:
            break
        }
    }

    func installAvailableUpdate() async {
        if status.isBusy { return }
        let version: String
        if case let .available(current, _, _) = status {
            version = current
        } else {
            return
        }

        status = .downloading(version: version)
        do {
            let release = try await fetchLatest()
            guard let latest = release.version, latest > current else {
                apply(release)
                return
            }
            guard let download = release.downloadURL else {
                apply(release)
                status = .failed("No downloadable build on this release")
                openPage(release.htmlURL)
                return
            }
            guard GitHubReleaseParser.isTrustedDownload(download) else {
                status = .failed("Update download URL was not trusted")
                return
            }

            let package = try await downloadPackage(from: download)
            status = .installing(version: latest.string)
            let app = try await Task.detached {
                try AppInstaller.prepareApp(from: package)
            }.value
            try AppInstaller.scheduleReplaceAndRelaunch(newApp: app)
            NSApp.terminate(nil)
        } catch {
            status = .failed(error.localizedDescription)
        }
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

    private func downloadPackage(from url: URL) async throws -> URL {
        var request = URLRequest(url: url)
        request.timeoutInterval = 120
        request.setValue("AIUsage/\(current.string)", forHTTPHeaderField: "User-Agent")
        let (temp, response) = try await URLSession.shared.download(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw CollectorError.unexpectedResponse("Download failed (HTTP \(http.statusCode))")
        }
        let ext = url.pathExtension.isEmpty ? "dmg" : url.pathExtension
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("AI-Usage-update.\(ext)")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: temp, to: dest)
        return dest
    }

    private func apply(_ release: GitHubRelease) {
        defaults.set(release.tagName, forKey: Keys.latestTag)
        defaults.set(release.htmlURL.absoluteString, forKey: Keys.latestURL)
        if let download = release.downloadURL {
            defaults.set(download.absoluteString, forKey: Keys.latestDownload)
        } else {
            defaults.removeObject(forKey: Keys.latestDownload)
        }
        if let latest = release.version, latest > current {
            status = .available(
                version: latest.string,
                pageURL: release.htmlURL,
                downloadURL: release.downloadURL
            )
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
            if case .checking = status { status = .idle }
            return
        }
        let download = defaults.string(forKey: Keys.latestDownload).flatMap(URL.init(string:))
        status = .available(version: latest.string, pageURL: url, downloadURL: download)
    }

    private func openPage(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private enum Keys {
        static let lastCheckedAt = "update.lastCheckedAt"
        static let latestTag = "update.latestTag"
        static let latestURL = "update.latestURL"
        static let latestDownload = "update.latestDownload"
    }
}
