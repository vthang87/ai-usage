import Foundation

public enum UnusedQuotaAlertPolicy {
    public static func isFiveHourWindow(_ window: UsageWindow) -> Bool {
        if window.label == "5 Hour" { return true }
        if let quota = window.quotaDescription, quota.contains("300 min") { return true }
        return false
    }

    public static func leadSeconds(for window: UsageWindow, settings: AppSettings) -> TimeInterval {
        let hours = isFiveHourWindow(window) ? settings.fiveHourResetLeadHours : settings.defaultResetLeadHours
        return max(hours, 0) * 3600
    }

    public static func remainingPercent(used: Double) -> Double {
        min(max(100 - used, 0), 100)
    }

    public static func shouldNotify(window: UsageWindow, now: Date = Date(), settings: AppSettings) -> Bool {
        guard settings.unusedQuotaAlertsEnabled,
              let used = window.usedPercent,
              let reset = window.resetsAt
        else { return false }
        let remaining = remainingPercent(used: used)
        guard remaining >= settings.unusedRemainingThreshold else { return false }
        let untilReset = reset.timeIntervalSince(now)
        guard untilReset > 0 else { return false }
        return untilReset <= leadSeconds(for: window, settings: settings)
    }

    public static func notificationKey(provider: String, window: UsageWindow, prefix: String = "") -> String? {
        guard let reset = window.resetsAt else { return nil }
        let stamp = Int(reset.timeIntervalSince1970)
        if prefix.isEmpty {
            return "\(provider)|\(window.label)|\(stamp)"
        }
        return "\(prefix)|\(provider)|\(window.label)|\(stamp)"
    }

    public static func didReset(previous: UsageWindow, current: UsageWindow) -> Bool {
        guard let previousReset = previous.resetsAt, let currentReset = current.resetsAt else { return false }
        return currentReset.timeIntervalSince(previousReset) >= 60
    }

    public static func resetCandidates(
        previous: UsageSnapshot,
        current: UsageSnapshot,
        settings: AppSettings
    ) -> [ResetCandidate] {
        guard settings.resetOccurredAlertsEnabled, previous.updatedAt != .distantPast else { return [] }
        var items: [ResetCandidate] = []
        for (name, previousUsage, currentUsage) in [
            ("Codex", previous.codex, current.codex),
            ("Cursor", previous.cursor, current.cursor),
        ] {
            guard let previousUsage, let currentUsage else { continue }
            let previousWindows = Dictionary(uniqueKeysWithValues: previousUsage.windows.map { ($0.label, $0) })
            for window in currentUsage.windows {
                guard let last = previousWindows[window.label],
                      didReset(previous: last, current: window),
                      let key = notificationKey(provider: name, window: window, prefix: "reset")
                else { continue }
                items.append(
                    ResetCandidate(
                        key: key,
                        provider: name,
                        window: window.label,
                        usedPercent: window.usedPercent
                    )
                )
            }
        }
        return items
    }

    public struct ResetCandidate: Equatable, Sendable {
        public let key: String
        public let provider: String
        public let window: String
        public let usedPercent: Double?
    }

    public static func candidates(in snapshot: UsageSnapshot, now: Date = Date(), settings: AppSettings) -> [AlertCandidate] {
        var items: [AlertCandidate] = []
        for (name, usage) in [("Codex", snapshot.codex), ("Cursor", snapshot.cursor)] {
            guard let usage else { continue }
            for window in usage.windows {
                guard shouldNotify(window: window, now: now, settings: settings),
                      let key = notificationKey(provider: name, window: window),
                      let used = window.usedPercent,
                      let reset = window.resetsAt
                else { continue }
                items.append(
                    AlertCandidate(
                        key: key,
                        provider: name,
                        window: window.label,
                        remainingPercent: remainingPercent(used: used),
                        resetsAt: reset
                    )
                )
            }
        }
        return items
    }

    public struct AlertCandidate: Equatable, Sendable {
        public let key: String
        public let provider: String
        public let window: String
        public let remainingPercent: Double
        public let resetsAt: Date
    }
}
