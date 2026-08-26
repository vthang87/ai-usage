#if canImport(AIUsageCore)
import AIUsageCore
#endif
import XCTest

final class CursorUsageParserTests: XCTestCase {
    func testParsesPlanPercentAndReset() throws {
        let payload = try Fixtures.jsonObject(named: "cursor-usage.json")
        let windows = try CursorUsageParser.windows(from: payload)
        XCTAssertEqual(windows.map(\.label), ["Cursor Models", "Other Models"])
        XCTAssertEqual(windows[0].usedPercent, 66.6525)
        XCTAssertEqual(windows[1].usedPercent, 33.85454545454545)
        XCTAssertEqual(windows[0].quotaDescription, "23222 / 40000")
        XCTAssertEqual(windows[0].resetsAt?.timeIntervalSince1970, 1_771_077_734)
    }

    func testFallsBackToTotalPercentWhenSplitMissing() throws {
        let payload: [String: Any] = [
            "billingCycleEnd": "1771077734000",
            "planUsage": [
                "includedSpend": 100,
                "limit": 200,
                "totalPercentUsed": 50,
            ],
        ]
        let windows = try CursorUsageParser.windows(from: payload)
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows[0].label, "Usage")
        XCTAssertEqual(windows[0].usedPercent, 50)
    }

    func testRejectsMissingPlanUsage() {
        XCTAssertThrowsError(try CursorUsageParser.windows(from: ["billingCycleEnd": "1771077734000"]))
    }
}

final class UsageFormattingTests: XCTestCase {
    func testPercentAndMissingValues() {
        XCTAssertEqual(UsageFormatting.percent(61.4), "61%")
        XCTAssertEqual(UsageFormatting.percent(nil), "—")
        XCTAssertEqual(UsageFormatting.status(nil), "Unknown")
        XCTAssertEqual(
            UsageFormatting.status(.unavailable(name: "Codex", message: "missing")),
            "Unavailable"
        )
    }

    func testResetRemainingAndSoon() {
        let now = Date()
        XCTAssertEqual(UsageFormatting.reset(nil), "—")
        XCTAssertEqual(UsageFormatting.reset(now.addingTimeInterval(-60), now: now), "soon")
        XCTAssertEqual(UsageFormatting.reset(now.addingTimeInterval(26 * 3600), now: now), "1d 2h")
        XCTAssertEqual(UsageFormatting.reset(now.addingTimeInterval(3 * 3600 + 20 * 60), now: now), "3h 20m")
        XCTAssertEqual(UsageFormatting.reset(now.addingTimeInterval(15 * 60), now: now), "15m")
    }

    func testResetExactDateTimeUsesLocale() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "UTC")!
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 26, hour: 10, minute: 0))!
        let reset = calendar.date(from: DateComponents(year: 2026, month: 8, day: 26, hour: 14, minute: 32))!
        XCTAssertEqual(
            UsageFormatting.reset(
                reset,
                exact: true,
                now: now,
                locale: Locale(identifier: "en_GB"),
                timeZone: timeZone
            ),
            "26 Aug at 14:32"
        )
        XCTAssertEqual(
            UsageFormatting.reset(reset.addingTimeInterval(-1), exact: true, now: reset),
            "soon"
        )
    }

    func testDecodesMissingShowExactResetDateTimeAsFalse() throws {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(AppSettings.default)) as! [String: Any]
        XCTAssertEqual(object["showExactResetDateTime"] as? Bool, false)
        object.removeValue(forKey: "showExactResetDateTime")
        let settings = try JSONDecoder().decode(
            AppSettings.self,
            from: try JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertFalse(settings.showExactResetDateTime)
    }
}
