import CommonCrypto
import Foundation

/// Chromium/Electron safeStorage on macOS: `v10` + AES-128-CBC.
/// Key is PBKDF2-HMAC-SHA1 of the Keychain safe-storage password (`saltysalt`, 1003 rounds).
public enum SafeStorageCryptor {
    public static func decrypt(base64: String, password: String) -> String? {
        guard let blob = Data(base64Encoded: base64), blob.count > 3 else { return nil }
        guard blob.prefix(3) == Data("v10".utf8) else { return nil }
        guard let key = deriveKey(password) else { return nil }
        let ciphertext = Data(blob.dropFirst(3))
        guard let plain = crypt(ciphertext, key: key, operation: CCOperation(kCCDecrypt)) else { return nil }
        return String(data: plain, encoding: .utf8)
    }

    public static func encrypt(_ plaintext: String, password: String) -> String? {
        guard let key = deriveKey(password), let data = plaintext.data(using: .utf8) else { return nil }
        guard let cipher = crypt(data, key: key, operation: CCOperation(kCCEncrypt)) else { return nil }
        var blob = Data("v10".utf8)
        blob.append(cipher)
        return blob.base64EncodedString()
    }

    private static func deriveKey(_ password: String) -> Data? {
        let passwordData = Array(password.utf8)
        let salt = Array("saltysalt".utf8)
        var key = [UInt8](repeating: 0, count: kCCKeySizeAES128)
        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            passwordData,
            passwordData.count,
            salt,
            salt.count,
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
            1003,
            &key,
            key.count
        )
        guard status == kCCSuccess else { return nil }
        return Data(key)
    }

    private static func crypt(_ input: Data, key: Data, operation: CCOperation) -> Data? {
        var iv = [UInt8](repeating: 0x20, count: kCCBlockSizeAES128)
        var output = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
        var outputLength = 0
        let status = input.withUnsafeBytes { inputBytes in
            key.withUnsafeBytes { keyBytes in
                CCCrypt(
                    operation,
                    CCAlgorithm(kCCAlgorithmAES),
                    CCOptions(kCCOptionPKCS7Padding),
                    keyBytes.baseAddress,
                    kCCKeySizeAES128,
                    &iv,
                    inputBytes.baseAddress,
                    input.count,
                    &output,
                    output.count,
                    &outputLength
                )
            }
        }
        guard status == kCCSuccess else { return nil }
        return Data(output.prefix(outputLength))
    }
}
