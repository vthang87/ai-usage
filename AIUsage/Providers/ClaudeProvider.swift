import Foundation

struct ClaudeProvider: UsageProvider {
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    func collect() async -> ProviderUsage {
        let lookup = await Task.detached {
            ClaudeAccessToken.lookup()
        }.value

        let credential: ClaudeAccessToken.Credential
        switch lookup {
        case let .credential(value):
            credential = value
        case .needsKeychainUnlock:
            return .offline(
                name: "Claude",
                message: "Allow AI Usage to read Claude Safe Storage in Keychain"
            )
        case .missing:
            return .offline(name: "Claude", message: "Not signed in")
        }

        do {
            let windows = try await fetchUsage(credential: credential)
            return ProviderUsage(
                name: "Claude",
                isAvailable: true,
                isOnline: true,
                windows: windows,
                lastError: nil
            )
        } catch {
            return .offline(name: "Claude", message: sanitized(error))
        }
    }

    private func fetchUsage(credential: ClaudeAccessToken.Credential) async throws -> [UsageWindow] {
        let token = await ClaudeAccessToken.validAccessToken(from: credential) ?? credential.accessToken
        do {
            return try await requestUsage(token: token)
        } catch CollectorError.notAuthenticated {
            guard let refreshed = await ClaudeAccessToken.refresh(credential) else {
                throw CollectorError.notAuthenticated
            }
            return try await requestUsage(token: refreshed.accessToken)
        }
    }

    private func requestUsage(token: String) async throws -> [UsageWindow] {
        var request = URLRequest(url: Self.usageURL)
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AIUsage/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw CollectorError.notAuthenticated
            }
            if http.statusCode >= 400 {
                throw CollectorError.unexpectedResponse("Claude usage API returned HTTP \(http.statusCode)")
            }
        }
        let object = try JSONSerialization.jsonObject(with: data)
        return try ClaudeUsageParser.windows(from: object)
    }

    private func sanitized(_ error: Error) -> String {
        if let collector = error as? CollectorError, case .notAuthenticated = collector {
            return "Claude session expired. Open Claude and sign in again."
        }
        let text = error.localizedDescription
        if text.lowercased().contains("bearer") || text.lowercased().contains("token") {
            return "Claude usage request failed"
        }
        return text
    }
}
