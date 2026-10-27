import Foundation
import SQLite3

enum CursorAccessToken {
    static func fromAgentStatusJSON(_ data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let auth = object["auth"] as? [String: Any], let token = auth["accessToken"] as? String, !token.isEmpty {
            return token
        }
        if let token = object["accessToken"] as? String, !token.isEmpty {
            return token
        }
        return nil
    }

    enum Lookup {
        case token(String)
        case needsKeychainUnlock
        case missing
    }

    /// Prefer the IDE session. Cursor now stores it as `cursor-safe-storage:v1:` ciphertext.
    static func session() -> Lookup {
        if let binary = BinaryLocator.find(names: ["agent", "cursor-agent"]),
           let status = try? ProcessCapture.run(executable: binary, arguments: ["status", "--format", "json"]),
           let token = fromAgentStatusJSON(Data(status.utf8)) {
            return .token(token)
        }
        switch stateDatabaseToken() {
        case .token(let token):
            return .token(token)
        case .needsKeychainUnlock:
            return .needsKeychainUnlock
        case .missing:
            break
        }
        if let token = fromAuthFile() ?? fromCLIKeychain() {
            return .token(token)
        }
        return .missing
    }

    static func fromStateDatabase() -> String? {
        if case let .token(token) = stateDatabaseToken() {
            return token
        }
        return nil
    }

    private static func stateDatabaseToken() -> Lookup {
        let path = NSHomeDirectory()
            + "/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
        guard FileManager.default.isReadableFile(atPath: path) else { return .missing }

        var database: OpaquePointer?
        let uri = "file:\(path)?mode=ro"
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI
        guard sqlite3_open_v2(uri, &database, flags, nil) == SQLITE_OK else {
            sqlite3_close(database)
            return .missing
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let sql = "SELECT value FROM ItemTable WHERE key = ? LIMIT 1"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return .missing
        }
        defer { sqlite3_finalize(statement) }

        let key = "cursorAuth/accessToken"
        let bindResult = key.withCString { pointer in
            sqlite3_bind_text(statement, 1, pointer, -1, nil)
        }
        guard bindResult == SQLITE_OK, sqlite3_step(statement) == SQLITE_ROW else { return .missing }
        guard let cString = sqlite3_column_text(statement, 0) else { return .missing }
        let stored = String(cString: cString)
        guard !stored.isEmpty else { return .missing }

        let prefix = "cursor-safe-storage:v1:"
        guard stored.hasPrefix(prefix) else { return .token(stored) }
        guard let password = KeychainPassword.read(service: "Cursor Safe Storage", account: "Cursor Key") else {
            return .needsKeychainUnlock
        }
        guard let token = SafeStorageCryptor.decrypt(base64: String(stored.dropFirst(prefix.count)), password: password),
              !token.isEmpty
        else {
            return .needsKeychainUnlock
        }
        return .token(token)
    }

    private static func fromAuthFile() -> String? {
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".cursor/auth.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = object["accessToken"] as? String,
              !token.isEmpty
        else { return nil }
        return token
    }

    private static func fromCLIKeychain() -> String? {
        KeychainPassword.read(service: "cursor-access-token", account: "cursor-user")
    }
}
