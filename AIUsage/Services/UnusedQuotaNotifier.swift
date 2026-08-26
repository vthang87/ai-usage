import AppKit
import Foundation
import UserNotifications

extension Notification.Name {
    static let aiUsageOpenDashboard = Notification.Name("AIUsage.openDashboard")
}

@MainActor
final class UnusedQuotaNotifier: NSObject, UNUserNotificationCenterDelegate {
    private let store: UsageStore
    private let center: UNUserNotificationCenter

    init(store: UsageStore = UsageStore(), center: UNUserNotificationCenter = .current()) {
        self.store = store
        self.center = center
        super.init()
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() async {
        let settings = store.loadSettings()
        guard settings.unusedQuotaAlertsEnabled || settings.resetOccurredAlertsEnabled else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func evaluate(previous: UsageSnapshot, current: UsageSnapshot) async {
        var settings = store.loadSettings()
        let needsAuth = settings.unusedQuotaAlertsEnabled || settings.resetOccurredAlertsEnabled
        guard needsAuth else { return }
        await requestAuthorizationIfNeeded()

        let now = Date()
        var freshKeys: [String] = []

        if settings.unusedQuotaAlertsEnabled {
            let unused = UnusedQuotaAlertPolicy.candidates(in: current, now: now, settings: settings)
                .filter { !settings.notifiedAlertKeys.contains($0.key) }
            for candidate in unused {
                await deliverUnused(candidate, exact: settings.showExactResetDateTime)
                freshKeys.append(candidate.key)
            }
        }

        if settings.resetOccurredAlertsEnabled {
            let resets = UnusedQuotaAlertPolicy.resetCandidates(previous: previous, current: current, settings: settings)
                .filter { !settings.notifiedAlertKeys.contains($0.key) }
            for candidate in resets {
                await deliverReset(candidate)
                freshKeys.append(candidate.key)
            }
        }

        guard !freshKeys.isEmpty else { return }
        settings.notifiedAlertKeys.append(contentsOf: freshKeys)
        settings.notifiedAlertKeys = prune(settings.notifiedAlertKeys, now: now)
        store.saveSettings(settings)
    }

    private func deliverUnused(_ candidate: UnusedQuotaAlertPolicy.AlertCandidate, exact: Bool) async {
        let remaining = Int(candidate.remainingPercent.rounded())
        let until = UsageFormatting.reset(candidate.resetsAt, exact: exact)
        let phrase = exact && until != "soon" ? "Resets at \(until)" : "Resets in \(until)"
        let content = UNMutableNotificationContent()
        content.title = "\(candidate.provider) \(candidate.window) resets soon"
        content.body = "\(remaining)% unused. \(phrase)."
        content.sound = .default
        try? await center.add(UNNotificationRequest(identifier: candidate.key, content: content, trigger: nil))
    }

    private func deliverReset(_ candidate: UnusedQuotaAlertPolicy.ResetCandidate) async {
        let used = candidate.usedPercent.map { "Quota is available again. Now at \(Int($0.rounded()))% used." }
            ?? "Quota is available again."
        let content = UNMutableNotificationContent()
        content.title = "\(candidate.provider) \(candidate.window) reset"
        content.body = used
        content.sound = .default
        try? await center.add(UNNotificationRequest(identifier: candidate.key, content: content, trigger: nil))
    }

    private func prune(_ keys: [String], now: Date) -> [String] {
        keys.filter { key in
            guard let stampPart = key.split(separator: "|").last, let stamp = TimeInterval(stampPart) else {
                return false
            }
            return Date(timeIntervalSince1970: stamp) > now
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .aiUsageOpenDashboard, object: nil)
        }
    }
}
