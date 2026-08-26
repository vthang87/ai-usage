#if canImport(AIUsageCore)
import AIUsageCore
#endif
import XCTest

final class UnusedQuotaAlertPolicyTests: XCTestCase {
    private let settings = AppSettings.default

    func testNotifiesWeeklyWhenUnusedAndWithinTwelveHours() {
        let window = UsageWindow(
            label: "Weekly",
            usedPercent: 20,
            resetsAt: Date().addingTimeInterval(11 * 3600)
        )
        XCTAssertTrue(UnusedQuotaAlertPolicy.shouldNotify(window: window, settings: settings))
    }

    func testSkipsWeeklyWhenResetIsFartherThanLead() {
        let window = UsageWindow(
            label: "Weekly",
            usedPercent: 20,
            resetsAt: Date().addingTimeInterval(13 * 3600)
        )
        XCTAssertFalse(UnusedQuotaAlertPolicy.shouldNotify(window: window, settings: settings))
    }

    func testNotifiesFiveHourWindowWithTwoHourLead() {
        let soon = UsageWindow(
            label: "5 Hour",
            usedPercent: 10,
            quotaDescription: "300 min window",
            resetsAt: Date().addingTimeInterval(90 * 60)
        )
        let later = UsageWindow(
            label: "5 Hour",
            usedPercent: 10,
            quotaDescription: "300 min window",
            resetsAt: Date().addingTimeInterval(3 * 3600)
        )
        XCTAssertTrue(UnusedQuotaAlertPolicy.shouldNotify(window: soon, settings: settings))
        XCTAssertFalse(UnusedQuotaAlertPolicy.shouldNotify(window: later, settings: settings))
    }

    func testSkipsWhenUnusedQuotaIsBelowThreshold() {
        let window = UsageWindow(
            label: "Weekly",
            usedPercent: 40,
            resetsAt: Date().addingTimeInterval(2 * 3600)
        )
        XCTAssertFalse(UnusedQuotaAlertPolicy.shouldNotify(window: window, settings: settings))
    }

    func testDetectsWindowResetWhenResetsAtMovesForward() {
        let previous = UsageWindow(label: "Weekly", usedPercent: 80, resetsAt: Date().addingTimeInterval(-60))
        let current = UsageWindow(label: "Weekly", usedPercent: 2, resetsAt: Date().addingTimeInterval(7 * 24 * 3600))
        XCTAssertTrue(UnusedQuotaAlertPolicy.didReset(previous: previous, current: current))
        XCTAssertFalse(UnusedQuotaAlertPolicy.didReset(previous: current, current: current))
    }

    func testIgnoresMidCycleResetsAtJitter() {
        let previous = UsageWindow(
            label: "5 Hour",
            usedPercent: 0,
            quotaDescription: "300 min window",
            resetsAt: Date().addingTimeInterval(4 * 3600)
        )
        let drifted = UsageWindow(
            label: "5 Hour",
            usedPercent: 0,
            quotaDescription: "300 min window",
            resetsAt: Date().addingTimeInterval(4 * 3600 + 600)
        )
        XCTAssertFalse(UnusedQuotaAlertPolicy.didReset(previous: previous, current: drifted))
    }

    func testDetectsFiveHourResetNearExpiry() {
        let previous = UsageWindow(
            label: "5 Hour",
            usedPercent: 90,
            quotaDescription: "300 min window",
            resetsAt: Date().addingTimeInterval(2 * 60)
        )
        let current = UsageWindow(
            label: "5 Hour",
            usedPercent: 0,
            quotaDescription: "300 min window",
            resetsAt: Date().addingTimeInterval(5 * 3600)
        )
        XCTAssertTrue(UnusedQuotaAlertPolicy.didReset(previous: previous, current: current))
    }

    func testResetCandidatesSkipEmptyPreviousSnapshot() {
        let current = UsageSnapshot.placeholder
        let found = UnusedQuotaAlertPolicy.resetCandidates(
            previous: .empty,
            current: current,
            settings: settings
        )
        XCTAssertTrue(found.isEmpty)
    }

    func testResetCandidatesFindsNewCycle() {
        let oldReset = Date().addingTimeInterval(-60)
        let newReset = Date().addingTimeInterval(7 * 24 * 3600)
        let previous = UsageSnapshot(
            codex: ProviderUsage(
                name: "Codex",
                isAvailable: true,
                isOnline: true,
                windows: [UsageWindow(label: "Weekly", usedPercent: 80, resetsAt: oldReset)],
                lastError: nil
            ),
            cursor: nil,
            updatedAt: Date().addingTimeInterval(-300)
        )
        let current = UsageSnapshot(
            codex: ProviderUsage(
                name: "Codex",
                isAvailable: true,
                isOnline: true,
                windows: [UsageWindow(label: "Weekly", usedPercent: 2, resetsAt: newReset)],
                lastError: nil
            ),
            cursor: nil,
            updatedAt: Date()
        )
        let found = UnusedQuotaAlertPolicy.resetCandidates(previous: previous, current: current, settings: settings)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.provider, "Codex")
        XCTAssertEqual(found.first?.window, "Weekly")
        XCTAssertEqual(found.first?.usedPercent, 2)
        XCTAssertTrue(found.first?.key.hasPrefix("reset|Codex|Weekly|") == true)
    }
}
