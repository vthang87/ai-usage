import Foundation

struct CodexProvider: UsageProvider {
    func collect() async -> ProviderUsage {
        guard let binary = BinaryLocator.find(names: ["codex"]) else {
            return .unavailable(name: "Codex", message: "Codex CLI not found")
        }

        do {
            let windows = try await Task.detached {
                let result = try JSONRPCStdioClient.call(
                    executable: binary,
                    arguments: ["app-server", "--stdio"],
                    request: [
                        "method": "account/rateLimits/read",
                        "id": 1,
                    ]
                )
                return try CodexRateLimitsParser.windows(from: result)
            }.value
            return ProviderUsage(
                name: "Codex",
                isAvailable: true,
                isOnline: true,
                windows: windows,
                lastError: nil
            )
        } catch {
            return .offline(name: "Codex", message: error.localizedDescription)
        }
    }
}
