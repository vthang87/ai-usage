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
        let credits = CodexRateLimitsParser.resetCredits(from: codexJSON)
        expect(credits.available == 2, "codex reset credits")
        expect(credits.nextExpiresAt?.timeIntervalSince1970 == 1_733_558_400, "codex reset credit expiry")
        expect(UsageFormatting.resetCredits(2) == "2 resets", "plural reset credits")
        expect(UsageFormatting.resetCredits(1) == "1 reset", "singular reset credit")
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

        expect(SemanticVersion("v0.0.2") == SemanticVersion("0.0.2"), "strip v prefix")
        expect(SemanticVersion("0.0.3")! > SemanticVersion("0.0.2")!, "patch bump is newer")
        expect(SemanticVersion("1.0.0")! > SemanticVersion("0.9.9")!, "major bump is newer")
        expect(SemanticVersion("0.0.2-beta")?.string == "0.0.2", "strip prerelease suffix")
        expect(SemanticVersion("not-a-version") == nil, "reject invalid version")

        let githubData = Data(#"""
        {"tag_name":"v0.0.3","html_url":"https://github.com/vthang87/ai-usage/releases/tag/v0.0.3","assets":[{"name":"AI-Usage-0.0.3.dmg","browser_download_url":"https://github.com/vthang87/ai-usage/releases/download/v0.0.3/AI-Usage-0.0.3.dmg"}]}
        """#.utf8)
        let release = try GitHubReleaseParser.latest(from: githubData)
        expect(release.tagName == "v0.0.3", "github tag_name")
        expect(release.version?.string == "0.0.3", "github semantic version")
        expect(release.htmlURL.absoluteString.hasSuffix("/v0.0.3"), "github html_url")
        expect(release.downloadURL?.lastPathComponent == "AI-Usage-0.0.3.dmg", "github dmg asset")
        expect(GitHubReleaseParser.isTrustedDownload(release.downloadURL!), "trusted github download")
        expect(
            !GitHubReleaseParser.isTrustedDownload(URL(string: "https://evil.example/AI-Usage.dmg")!),
            "reject untrusted download host"
        )

        do {
            _ = try GitHubReleaseParser.latest(from: Data("{}".utf8))
            expect(false, "empty github payload should throw")
        } catch {
            expect(true, "empty github payload throws")
        }

        if failures > 0 {
            fputs("\(failures) test(s) failed\n", stderr)
            exit(1)
        }
        print("All parser tests passed")
    }
}
