#if canImport(AIUsageCore)
import AIUsageCore
#endif
import XCTest

final class CodexRateLimitsParserTests: XCTestCase {
    func testParsesFiveHourAndWeeklyWindows() throws {
        let payload = try Fixtures.jsonObject(named: "codex-rate-limits.json")
        let windows = try CodexRateLimitsParser.windows(from: payload)
        XCTAssertEqual(windows.map(\.label), ["5 Hour", "Weekly"])
        XCTAssertEqual(windows[0].usedPercent, 72)
        XCTAssertEqual(windows[1].usedPercent, 43)
        XCTAssertEqual(windows[0].resetsAt?.timeIntervalSince1970, 1_730_947_200)
        XCTAssertEqual(windows[1].quotaDescription, "10080 min window")
    }

    func testMapsWindowLabels() {
        XCTAssertEqual(CodexRateLimitsParser.label(forMinutes: 300), "5 Hour")
        XCTAssertEqual(CodexRateLimitsParser.label(forMinutes: 10080), "Weekly")
        XCTAssertEqual(CodexRateLimitsParser.label(forMinutes: 15), "15 min")
        XCTAssertEqual(CodexRateLimitsParser.label(forMinutes: 120), "2 Hour")
    }

    func testRejectsEmptyPayload() {
        XCTAssertThrowsError(try CodexRateLimitsParser.windows(from: ["rateLimits": [:]]))
    }
}
