import Foundation

enum ClaudeAccessToken {
    private static let cacheKey = "oauth:tokenCacheV2"
    private static let safeStorageService = "Claude Safe Storage"
    private static let safeStorageAccount = "Claude Key"
    private static let credentialsService = "Claude Code-credentials"
    private static let tokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!
    private static let usageClientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"

    struct Credential {
        var accessToken: String
        var refreshToken: String?
        var expiresAt: Date?
        var clientID: String
        var scopes: String
        var source: Source
    }

    enum Source {
        case desktop(cacheKey: String, password: String)
        case keychain(account: String)
    }

    enum Lookup {
        case credential(Credential)
        case needsKeychainUnlock
        case missing
    }

    static func lookup() -> Lookup {
        switch desktopCredential() {
        case .credential(let credential):
            return .credential(credential)
        case .needsKeychainUnlock:
            return .needsKeychainUnlock
        case .missing:
            break
        }
        if let credential = keychainCredential() {
            return .credential(credential)
        }
        return .missing
    }

    static func validAccessToken(from credential: Credential) async -> String? {
        if let expiresAt = credential.expiresAt, expiresAt.timeIntervalSinceNow > 60 {
            return credential.accessToken
        }
        return await refresh(credential)?.accessToken
    }

    static func refresh(_ credential: Credential) async -> Credential? {
        guard let refreshToken = credential.refreshToken, !refreshToken.isEmpty else { return nil }
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": credential.clientID,
            "scope": credential.scopes,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = object["access_token"] as? String,
              !accessToken.isEmpty
        else { return nil }

        var next = credential
        next.accessToken = accessToken
        if let rotated = object["refresh_token"] as? String, !rotated.isEmpty {
            next.refreshToken = rotated
        }
        if let expiresIn = FlexibleJSONNumber.double(from: object["expires_in"]) {
            next.expiresAt = Date().addingTimeInterval(expiresIn)
        }
        persist(next)
        return next
    }

    private static func desktopCredential() -> Lookup {
        let url = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Claude/config.json")
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let encrypted = config[cacheKey] as? String,
              !encrypted.isEmpty
        else { return .missing }
        guard let password = KeychainPassword.read(service: safeStorageService, account: safeStorageAccount) else {
            return .needsKeychainUnlock
        }
        guard let plain = SafeStorageCryptor.decrypt(base64: encrypted, password: password),
              let cacheData = plain.data(using: .utf8),
              let cache = try? JSONSerialization.jsonObject(with: cacheData) as? [String: Any]
        else { return .needsKeychainUnlock }

        let ranked = cache.compactMap { key, value -> (Int, Date, String, [String: Any])? in
            guard let entry = value as? [String: Any],
                  let token = entry["token"] as? String,
                  !token.isEmpty,
                  key.contains("user:inference")
            else { return nil }
            let score = key.contains("user:sessions:claude_code") ? 2 : 1
            let expires = date(fromMilliseconds: entry["expiresAt"]) ?? .distantPast
            return (score, expires, key, entry)
        }.sorted { lhs, rhs in
            if lhs.0 != rhs.0 { return lhs.0 > rhs.0 }
            return lhs.1 > rhs.1
        }
        guard let best = ranked.first else { return .missing }
        guard let identity = identity(fromCacheKey: best.2) else { return .missing }
        let entry = best.3
        return .credential(
            Credential(
                accessToken: entry["token"] as? String ?? "",
                refreshToken: entry["refreshToken"] as? String,
                expiresAt: best.1 == .distantPast ? nil : best.1,
                clientID: identity.clientID,
                scopes: identity.scopes,
                source: .desktop(cacheKey: best.2, password: password)
            )
        )
    }

    private static func keychainCredential() -> Credential? {
        guard let item = KeychainPassword.item(service: credentialsService),
              let data = item.secret.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = object["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              !token.isEmpty
        else { return nil }
        let scopes = (oauth["scopes"] as? [String])?.joined(separator: " ")
            ?? "user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload"
        return Credential(
            accessToken: token,
            refreshToken: oauth["refreshToken"] as? String,
            expiresAt: date(fromMilliseconds: oauth["expiresAt"]),
            clientID: usageClientID,
            scopes: scopes,
            source: .keychain(account: item.account)
        )
    }

    private static func persist(_ credential: Credential) {
        switch credential.source {
        case let .desktop(cacheKey, password):
            persistDesktop(credential, cacheKey: cacheKey, password: password)
        case let .keychain(account):
            persistKeychain(credential, account: account)
        }
    }

    private static func persistDesktop(_ credential: Credential, cacheKey entryKey: String, password: String) {
        let url = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/Claude/config.json")
        guard let data = try? Data(contentsOf: url),
              var config = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let encrypted = config[cacheKey] as? String,
              let plain = SafeStorageCryptor.decrypt(base64: encrypted, password: password),
              let cacheData = plain.data(using: .utf8),
              var cache = try? JSONSerialization.jsonObject(with: cacheData) as? [String: Any],
              var entry = cache[entryKey] as? [String: Any]
        else { return }
        entry["token"] = credential.accessToken
        if let refreshToken = credential.refreshToken {
            entry["refreshToken"] = refreshToken
        }
        if let expiresAt = credential.expiresAt {
            entry["expiresAt"] = expiresAt.timeIntervalSince1970 * 1000
        }
        cache[entryKey] = entry
        guard let updatedCache = try? JSONSerialization.data(withJSONObject: cache),
              let updatedText = String(data: updatedCache, encoding: .utf8),
              let sealed = SafeStorageCryptor.encrypt(updatedText, password: password)
        else { return }
        config[Self.cacheKey] = sealed
        guard let output = try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted]) else { return }
        try? output.write(to: url, options: .atomic)
    }

    private static func persistKeychain(_ credential: Credential, account: String) {
        guard let item = KeychainPassword.item(service: credentialsService),
              item.account == account || account.isEmpty,
              let data = item.secret.data(using: .utf8),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var oauth = object["claudeAiOauth"] as? [String: Any]
        else { return }
        oauth["accessToken"] = credential.accessToken
        if let refreshToken = credential.refreshToken {
            oauth["refreshToken"] = refreshToken
        }
        if let expiresAt = credential.expiresAt {
            oauth["expiresAt"] = expiresAt.timeIntervalSince1970 * 1000
        }
        object["claudeAiOauth"] = oauth
        guard let output = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: output, encoding: .utf8)
        else { return }
        _ = KeychainPassword.update(service: credentialsService, account: item.account, secret: text)
    }

    private static func identity(fromCacheKey key: String) -> (clientID: String, scopes: String)? {
        guard let pipe = key.firstIndex(of: "|") else { return nil }
        let rest = key[key.index(after: pipe)...]
        guard let colon = rest.firstIndex(of: ":") else { return nil }
        let clientID = String(rest[..<colon])
        let marker = "https://api.anthropic.com:"
        guard let range = rest.range(of: marker) else { return nil }
        let scopes = String(rest[range.upperBound...])
        guard !clientID.isEmpty, !scopes.isEmpty else { return nil }
        return (clientID, scopes)
    }

    private static func date(fromMilliseconds value: Any?) -> Date? {
        guard let milliseconds = FlexibleJSONNumber.double(from: value), milliseconds > 0 else { return nil }
        return Date(timeIntervalSince1970: milliseconds / 1000)
    }
}
