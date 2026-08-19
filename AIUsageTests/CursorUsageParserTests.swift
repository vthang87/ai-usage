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
}
