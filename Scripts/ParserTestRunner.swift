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

        let alertSettings = AppSettings.default
        let weeklySoon = UsageWindow(label: "Weekly", usedPercent: 20, resetsAt: Date().addingTimeInterval(11 * 3600))
        let weeklyFar = UsageWindow(label: "Weekly", usedPercent: 20, resetsAt: Date().addingTimeInterval(13 * 3600))
        let fiveSoon = UsageWindow(label: "5 Hour", usedPercent: 10, quotaDescription: "300 min window", resetsAt: Date().addingTimeInterval(90 * 60))
        let fiveFar = UsageWindow(label: "5 Hour", usedPercent: 10, quotaDescription: "300 min window", resetsAt: Date().addingTimeInterval(3 * 3600))
        let mostlyUsed = UsageWindow(label: "Weekly", usedPercent: 40, resetsAt: Date().addingTimeInterval(2 * 3600))
        expect(UnusedQuotaAlertPolicy.shouldNotify(window: weeklySoon, settings: alertSettings), "weekly unused near reset")
        expect(!UnusedQuotaAlertPolicy.shouldNotify(window: weeklyFar, settings: alertSettings), "weekly reset still far")
        expect(UnusedQuotaAlertPolicy.shouldNotify(window: fiveSoon, settings: alertSettings), "5 hour unused in last 2h")
        expect(!UnusedQuotaAlertPolicy.shouldNotify(window: fiveFar, settings: alertSettings), "5 hour reset farther than 2h")
        expect(!UnusedQuotaAlertPolicy.shouldNotify(window: mostlyUsed, settings: alertSettings), "skip when unused below 70%")

        let previousWeekly = UsageWindow(label: "Weekly", usedPercent: 80, resetsAt: Date().addingTimeInterval(-60))
        let currentWeekly = UsageWindow(label: "Weekly", usedPercent: 2, resetsAt: Date().addingTimeInterval(7 * 24 * 3600))
        expect(UnusedQuotaAlertPolicy.didReset(previous: previousWeekly, current: currentWeekly), "detect window reset")
        expect(!UnusedQuotaAlertPolicy.didReset(previous: currentWeekly, current: currentWeekly), "same window is not a reset")
        let jitterPrevious = UsageWindow(
            label: "5 Hour",
            usedPercent: 0,
            quotaDescription: "300 min window",
            resetsAt: Date().addingTimeInterval(4 * 3600)
        )
        let jitterCurrent = UsageWindow(
            label: "5 Hour",
            usedPercent: 0,
            quotaDescription: "300 min window",
            resetsAt: Date().addingTimeInterval(4 * 3600 + 600)
        )
        expect(!UnusedQuotaAlertPolicy.didReset(previous: jitterPrevious, current: jitterCurrent), "ignore mid-cycle resetsAt jitter")
        expect(
            UnusedQuotaAlertPolicy.didReset(
                previous: UsageWindow(
                    label: "5 Hour",
                    usedPercent: 90,
                    quotaDescription: "300 min window",
                    resetsAt: Date().addingTimeInterval(2 * 60)
                ),
                current: UsageWindow(
                    label: "5 Hour",
                    usedPercent: 0,
                    quotaDescription: "300 min window",
                    resetsAt: Date().addingTimeInterval(5 * 3600)
                )
            ),
            "detect 5 hour reset near expiry"
        )
        expect(
            UnusedQuotaAlertPolicy.resetCandidates(
                previous: .empty,
                current: .placeholder,
                settings: alertSettings
            ).isEmpty,
            "skip reset alerts on first snapshot"
        )
        let previousSnap = UsageSnapshot(
            codex: ProviderUsage(
                name: "Codex",
                isAvailable: true,
                isOnline: true,
                windows: [previousWeekly],
                lastError: nil
            ),
            cursor: nil,
            updatedAt: Date().addingTimeInterval(-300)
        )
        let currentSnap = UsageSnapshot(
            codex: ProviderUsage(
                name: "Codex",
                isAvailable: true,
                isOnline: true,
                windows: [currentWeekly],
                lastError: nil
            ),
            cursor: nil,
            updatedAt: Date()
        )
        let resetFound = UnusedQuotaAlertPolicy.resetCandidates(
            previous: previousSnap,
            current: currentSnap,
            settings: alertSettings
        )
        expect(resetFound.count == 1 && resetFound.first?.window == "Weekly", "reset candidate for new cycle")

        let fiveHourReset = Date().addingTimeInterval(5 * 3600)
        let widgetSnap = UsageSnapshot(
            codex: ProviderUsage(
                name: "Codex",
                isAvailable: true,
                isOnline: true,
                windows: [
                    UsageWindow(label: "5 Hour", usedPercent: 5, resetsAt: fiveHourReset),
                    UsageWindow(label: "Weekly", usedPercent: 1, resetsAt: Date().addingTimeInterval(7 * 24 * 3600)),
                ],
                lastError: nil,
                resetCreditsAvailable: 1
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
        expect(
            WidgetRingLayout.items(from: widgetSnap, capacity: 4).map(\.id) == [
                "Codex|5 Hour",
                "Codex|Weekly",
                "Cursor|Cursor Models",
                "Cursor|Other Models",
            ],
            "medium widget shows each Codex window"
        )
        expect(
            WidgetRingLayout.items(from: widgetSnap, capacity: 2).map(\.id) == [
                "Codex|5 Hour",
                "Cursor|Cursor Models",
            ],
            "small widget prefers Codex 5 Hour"
        )
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
        let now = Date()
        expect(UsageFormatting.reset(nil) == "—", "missing reset")
        expect(UsageFormatting.reset(now.addingTimeInterval(-60), now: now) == "soon", "reset soon")
        expect(UsageFormatting.reset(now.addingTimeInterval(26 * 3600), now: now) == "1d 2h", "reset remaining days")
        var calendar = Calendar(identifier: .gregorian)
        let utc = TimeZone(identifier: "UTC")!
        calendar.timeZone = utc
        let morning = calendar.date(from: DateComponents(year: 2026, month: 8, day: 26, hour: 10, minute: 0))!
        let afternoon = calendar.date(from: DateComponents(year: 2026, month: 8, day: 26, hour: 14, minute: 32))!
        expect(
            UsageFormatting.reset(
                afternoon,
                exact: true,
                now: morning,
                locale: Locale(identifier: "en_GB"),
                timeZone: utc
            ) == "26 Aug at 14:32",
            "exact reset datetime"
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
