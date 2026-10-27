import Foundation

struct CursorProvider: UsageProvider {
    private static let usageURL = URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage")!

    func collect() async -> ProviderUsage {
        let session = await Task.detached {
            CursorAccessToken.session()
        }.value

        let token: String
        switch session {
        case let .token(value):
            token = value
        case .needsKeychainUnlock:
            return .offline(
                name: "Cursor",
                message: "Allow AI Usage to read Cursor Safe Storage in Keychain"
            )
        case .missing:
            return .offline(name: "Cursor", message: "Not signed in")
        }

        do {

            let windows = try await fetchUsage(token: token)
            return ProviderUsage(
                name: "Cursor",
                isAvailable: true,
                isOnline: true,
                windows: windows,
                lastError: nil
            )
        } catch {
            return .offline(name: "Cursor", message: sanitized(error))
        }
    }

    private func fetchUsage(token: String) async throws -> [UsageWindow] {
        var request = URLRequest(url: Self.usageURL)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue("AIUsage/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw CollectorError.notAuthenticated
            }
            if http.statusCode >= 400 {
                throw CollectorError.unexpectedResponse("Cursor usage API returned HTTP \(http.statusCode)")
            }
        }
        let object = try JSONSerialization.jsonObject(with: data)
        return try CursorUsageParser.windows(from: object)
    }

    private func sanitized(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.lowercased().contains("bearer") || text.lowercased().contains("token") {
            return "Cursor usage request failed"
        }
        return text
    }
}
