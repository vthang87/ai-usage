#if canImport(AIUsageCore)
import AIUsageCore
#endif
import XCTest

final class WidgetRingLayoutTests: XCTestCase {
    func testMediumShowsEachCodexWindowNotResetCredits() {
        let items = WidgetRingLayout.items(from: snapshot, capacity: 4)
        XCTAssertEqual(items.map(\.id), [
            "Codex|5 Hour",
            "Codex|Weekly",
            "Cursor|Cursor Models",
            "Cursor|Other Models",
        ])
        XCTAssertEqual(items[0].percent, 5)
        XCTAssertEqual(items[0].resetsAt, fiveHourReset)
        XCTAssertEqual(items[1].percent, 1)
    }

    func testSmallPrefersCodexFiveHourWindow() {
        let items = WidgetRingLayout.items(from: snapshot, capacity: 2)
        XCTAssertEqual(items.map(\.id), ["Codex|5 Hour", "Cursor|Cursor Models"])
        XCTAssertEqual(items[0].resetsAt, fiveHourReset)
    }

    private let fiveHourReset = Date().addingTimeInterval(5 * 3600)

    private var snapshot: UsageSnapshot {
        UsageSnapshot(
            codex: ProviderUsage(
                name: "Codex",
                isAvailable: true,
                isOnline: true,
                windows: [
                    UsageWindow(label: "5 Hour", usedPercent: 5, resetsAt: fiveHourReset),
                    UsageWindow(label: "Weekly", usedPercent: 1, resetsAt: Date().addingTimeInterval(7 * 24 * 3600)),
                ],
                lastError: nil,
                resetCreditsAvailable: 1,
                nextResetCreditExpiresAt: Date().addingTimeInterval(26 * 24 * 3600)
            ),
            cursor: ProviderUsage(
                name: "Cursor",
                isAvailable: true,
                isOnline: true,
                windows: [
                    UsageWindow(label: "Cursor Models", usedPercent: 13, resetsAt: Date().addingTimeInterval(26 * 24 * 3600)),
                    UsageWindow(label: "Other Models", usedPercent: 0, resetsAt: Date().addingTimeInterval(26 * 24 * 3600)),
                ],
                lastError: nil
            ),
            updatedAt: Date()
        )
    }
}
