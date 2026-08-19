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

    static func isAuthenticated(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        if let authenticated = object["isAuthenticated"] as? Bool {
            return authenticated
        }
        if let status = object["status"] as? String {
            return status == "authenticated"
        }
        return false
    }

    static func fromStateDatabase() -> String? {
        let path = NSHomeDirectory()
            + "/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
        guard FileManager.default.isReadableFile(atPath: path) else { return nil }

        var database: OpaquePointer?
        let uri = "file:\(path)?mode=ro"
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI
        guard sqlite3_open_v2(uri, &database, flags, nil) == SQLITE_OK else {
            sqlite3_close(database)
            return nil
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let sql = "SELECT value FROM ItemTable WHERE key = ? LIMIT 1"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        let key = "cursorAuth/accessToken"
        let bindResult = key.withCString { pointer in
            sqlite3_bind_text(statement, 1, pointer, -1, nil)
        }
        guard bindResult == SQLITE_OK, sqlite3_step(statement) == SQLITE_ROW else { return nil }
        guard let cString = sqlite3_column_text(statement, 0) else { return nil }
        let token = String(cString: cString)
        return token.isEmpty ? nil : token
    }
}
