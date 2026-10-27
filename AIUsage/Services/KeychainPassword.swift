import Foundation
import Security

enum KeychainPassword {
    static func read(service: String, account: String) -> String? {
        secret(service: service, account: account)?.secret
    }

    static func item(service: String) -> (account: String, secret: String)? {
        secret(service: service, account: nil)
    }

    static func update(service: String, account: String, secret: String) -> Bool {
        guard let data = secret.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]
        return SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecSuccess
    }

    private static func secret(service: String, account: String?) -> (account: String, secret: String)? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if let account {
            query[kSecAttrAccount as String] = account
        }
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let result = item as? [String: Any],
              let data = result[kSecValueData as String] as? Data,
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let foundAccount = result[kSecAttrAccount as String] as? String ?? account ?? ""
        return (foundAccount, trimmed)
    }
}
