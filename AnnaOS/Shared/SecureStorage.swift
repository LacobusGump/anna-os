import CryptoKit
import Foundation
import Security

/// Encrypts Anna data at rest — memories, health, call context. Key in Secure Enclave-backed Keychain.
enum SecureStorage {
    private static let keyAccount = "anna_data_encryption_key"
    private static let service = "com.lacobusgump.anna.crypto"

    static func write(_ data: Data, to url: URL) {
        guard let sealed = seal(data) else { return }
        try? sealed.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    static func read(from url: URL) -> Data? {
        guard let sealed = try? Data(contentsOf: url) else { return nil }
        return open(sealed)
    }

    /// Migrate legacy plaintext JSON → encrypted blob.
    static func migratePlaintext(at url: URL) {
        let plainPath = url.deletingPathExtension().appendingPathExtension("json")
        guard !FileManager.default.fileExists(atPath: url.path),
              let plain = try? Data(contentsOf: plainPath) else { return }
        write(plain, to: url)
        try? FileManager.default.removeItem(at: plainPath)
    }

    // MARK: - Crypto

    private static func seal(_ data: Data) -> Data? {
        guard let key = symmetricKey() else { return nil }
        guard let sealed = try? AES.GCM.seal(data, using: key),
              let combined = sealed.combined else { return nil }
        return combined
    }

    private static func open(_ combined: Data) -> Data? {
        guard let key = symmetricKey(),
              let box = try? AES.GCM.SealedBox(combined: combined),
              let data = try? AES.GCM.open(box, using: key) else { return nil }
        return data
    }

    private static func symmetricKey() -> SymmetricKey? {
        if let existing = loadKeyData() {
            return SymmetricKey(data: existing)
        }
        let newKey = SymmetricKey(size: .bits256)
        saveKeyData(newKey.withUnsafeBytes { Data($0) })
        return newKey
    }

    private static func saveKeyData(_ data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyAccount
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func loadKeyData() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return data
    }
}