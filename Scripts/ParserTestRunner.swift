import Foundation

@main
struct ParserTestRunner {
    static func main() throws {
        var failures = 0
        func expect(_ condition: Bool, _ message: String) {
            if !condition {
                fputs("FAIL: \(message)\n", stderr)
                failures += 1
            } else {
                print("PASS: \(message)")
            }
        }

        let fixtures = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AIUsageTests/Fixtures")

        let codexData = try Data(contentsOf: fixtures.appendingPathComponent("codex-rate-limits.json"))
        let codexJSON = try JSONSerialization.jsonObject(with: codexData)
        let windows = try CodexRateLimitsParser.windows(from: codexJSON)
        expect(windows.map(\.label) == ["5 Hour", "Weekly"], "codex window labels")
        expect(windows[0].usedPercent == 72, "codex 5 hour percent")
        expect(windows[1].usedPercent == 43, "codex weekly percent")
        expect(windows[0].resetsAt?.timeIntervalSince1970 == 1_730_947_200, "codex reset timestamp")
        expect(CodexRateLimitsParser.label(forMinutes: 300) == "5 Hour", "label 5 hour")
        expect(CodexRateLimitsParser.label(forMinutes: 10080) == "Weekly", "label weekly")
        expect(CodexRateLimitsParser.label(forMinutes: 15) == "15 min", "label 15 min")

        do {
            _ = try CodexRateLimitsParser.windows(from: ["rateLimits": [:]])
            expect(false, "empty codex payload should throw")
        } catch {
            expect(true, "empty codex payload throws")
        }

        let cursorData = try Data(contentsOf: fixtures.appendingPathComponent("cursor-usage.json"))
        let cursorJSON = try JSONSerialization.jsonObject(with: cursorData)
        let usageWindows = try CursorUsageParser.windows(from: cursorJSON)
        expect(usageWindows.map(\.label) == ["Cursor Models", "Other Models"], "cursor labels")
        expect(abs((usageWindows[0].usedPercent ?? -1) - 66.6525) < 0.001, "cursor models percent")
        expect(abs((usageWindows[1].usedPercent ?? -1) - 33.85454545454545) < 0.001, "other models percent")
        expect(usageWindows[0].quotaDescription == "23222 / 40000", "cursor quota")
        expect(usageWindows[0].resetsAt?.timeIntervalSince1970 == 1_771_077_734, "cursor reset")

        do {
            _ = try CursorUsageParser.windows(from: ["billingCycleEnd": "1771077734000"])
            expect(false, "missing planUsage should throw")
        } catch {
            expect(true, "missing planUsage throws")
        }

        expect(UsageFormatting.percent(61.4) == "61%", "percent formatting")
        expect(UsageFormatting.percent(nil) == "—", "missing percent")
        expect(UsageFormatting.status(nil) == "Unknown", "unknown status")
        expect(
            UsageFormatting.status(.unavailable(name: "Codex", message: "missing")) == "Unavailable",
            "unavailable status"
        )

        if failures > 0 {
            fputs("\(failures) test(s) failed\n", stderr)
            exit(1)
        }
        print("All parser tests passed")
    }
}
