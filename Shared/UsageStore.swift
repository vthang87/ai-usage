import Foundation

public struct UsageStore: @unchecked Sendable {
    public static let defaultRefreshInterval: TimeInterval = 300

    public init() {}

    public func loadSnapshot() -> UsageSnapshot? {
        for url in snapshotURLs() {
            guard let data = try? Data(contentsOf: url),
                  let snapshot = try? JSONDecoder().decode(UsageSnapshot.self, from: data)
            else { continue }
            return snapshot
        }
        return nil
    }

    public func saveSnapshot(_ snapshot: UsageSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        for directory in snapshotDirectories() {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? data.write(
                to: directory.appendingPathComponent("snapshot.json"),
                options: .atomic
            )
        }
    }

    public func refreshInterval() -> TimeInterval {
        guard let data = try? Data(contentsOf: UsagePaths.settingsFile),
              let settings = try? JSONDecoder().decode(Settings.self, from: data)
        else {
            return Self.defaultRefreshInterval
        }
        return settings.refreshIntervalSeconds >= 60 ? settings.refreshIntervalSeconds : Self.defaultRefreshInterval
    }

    public func setRefreshInterval(_ value: TimeInterval) {
        let directory = UsagePaths.processSupportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let settings = Settings(refreshIntervalSeconds: max(60, value))
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: UsagePaths.settingsFile, options: .atomic)
    }

    private func snapshotDirectories() -> [URL] {
        uniqueURLs([
            UsagePaths.processSupportDirectory,
            UsagePaths.widgetContainerSupportDirectory,
        ])
    }

    private func snapshotURLs() -> [URL] {
        uniqueURLs([
            UsagePaths.snapshotFile,
            UsagePaths.widgetContainerSnapshotFile,
        ])
    }

    private func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }
}

private struct Settings: Codable {
    var refreshIntervalSeconds: TimeInterval
}
