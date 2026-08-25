import Foundation

public struct UsageStore: @unchecked Sendable {
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

    public func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: UsagePaths.settingsFile),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return .default
        }
        var next = settings
        if next.refreshIntervalSeconds < 60 {
            next.refreshIntervalSeconds = AppSettings.default.refreshIntervalSeconds
        }
        return next
    }

    public func saveSettings(_ settings: AppSettings) {
        let directory = UsagePaths.processSupportDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var next = settings
        next.refreshIntervalSeconds = max(60, next.refreshIntervalSeconds)
        guard let data = try? JSONEncoder().encode(next) else { return }
        try? data.write(to: UsagePaths.settingsFile, options: .atomic)
    }

    public func refreshInterval() -> TimeInterval {
        loadSettings().refreshIntervalSeconds
    }

    public func setRefreshInterval(_ value: TimeInterval) {
        var settings = loadSettings()
        settings.refreshIntervalSeconds = max(60, value)
        saveSettings(settings)
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
