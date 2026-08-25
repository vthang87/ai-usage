import AppKit
import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class UsageCollector {
    private(set) var snapshot: UsageSnapshot
    private(set) var isRefreshing = false
    private(set) var refreshInterval: TimeInterval
    private(set) var settings: AppSettings

    private let store: UsageStore
    private let notifier: UnusedQuotaNotifier
    private let codex: CodexProvider
    private let cursor: CursorProvider
    private var timer: Timer?
    private var activity: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var started = false

    init(
        store: UsageStore = UsageStore(),
        codex: CodexProvider = CodexProvider(),
        cursor: CursorProvider = CursorProvider()
    ) {
        self.store = store
        self.notifier = UnusedQuotaNotifier(store: store)
        self.codex = codex
        self.cursor = cursor
        self.snapshot = store.loadSnapshot() ?? .empty
        let settings = store.loadSettings()
        self.settings = settings
        self.refreshInterval = settings.refreshIntervalSeconds
    }

    func start() {
        guard !started else { return }
        started = true
        activity = ProcessInfo.processInfo.beginActivity(
            options: [
                .automaticTerminationDisabled,
                .suddenTerminationDisabled,
                .userInitiatedAllowingIdleSystemSleep,
            ],
            reason: "Polling Codex and Cursor usage"
        )
        observeWake()
        Task {
            await notifier.requestAuthorizationIfNeeded()
            await refresh()
        }
        restartLoop()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let codexUsage = collectCodex()
        async let cursorUsage = collectCursor()
        let previous = snapshot
        let next = UsageSnapshot(
            codex: await codexUsage,
            cursor: await cursorUsage,
            updatedAt: Date()
        )
        snapshot = next
        store.saveSnapshot(next)
        WidgetCenter.shared.reloadAllTimelines()
        await notifier.evaluate(previous: previous, current: next)
    }

    func setRefreshInterval(_ interval: TimeInterval) {
        var next = settings
        next.refreshIntervalSeconds = max(60, interval)
        applySettings(next)
    }

    func updateSettings(_ next: AppSettings) {
        applySettings(next)
        if next.unusedQuotaAlertsEnabled || next.resetOccurredAlertsEnabled {
            Task { await notifier.requestAuthorizationIfNeeded() }
        }
    }

    private func applySettings(_ next: AppSettings) {
        settings = next
        refreshInterval = max(60, next.refreshIntervalSeconds)
        store.saveSettings(next)
        restartLoop()
    }

    private func restartLoop() {
        timer?.invalidate()
        let timer = Timer(timeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        timer.tolerance = min(20, refreshInterval / 5)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func observeWake() {
        guard wakeObserver == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    private func collectCodex() async -> ProviderUsage {
        await Task.detached { [codex] in
            await codex.collect()
        }.value
    }

    private func collectCursor() async -> ProviderUsage {
        await Task.detached { [cursor] in
            await cursor.collect()
        }.value
    }
}
