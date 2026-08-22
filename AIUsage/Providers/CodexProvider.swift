import Foundation

struct CodexProvider: UsageProvider {
    func collect() async -> ProviderUsage {
        guard let binary = BinaryLocator.find(names: ["codex"]) else {
            return .unavailable(name: "Codex", message: "Codex CLI not found")
        }

        do {
            let parsed = try await Task.detached {
                let result = try JSONRPCStdioClient.call(
                    executable: binary,
                    arguments: ["app-server", "--stdio"],
                    request: [
                        "method": "account/rateLimits/read",
                        "id": 1,
                    ]
                )
                let windows = try CodexRateLimitsParser.windows(from: result)
                let credits = CodexRateLimitsParser.resetCredits(from: result)
                return (windows, credits.available, credits.nextExpiresAt)
            }.value
            return ProviderUsage(
                name: "Codex",
                isAvailable: true,
                isOnline: true,
                windows: parsed.0,
                lastError: nil,
                resetCreditsAvailable: parsed.1,
                nextResetCreditExpiresAt: parsed.2
            )
        } catch {
            return .offline(name: "Codex", message: error.localizedDescription)
        }
    }
}
