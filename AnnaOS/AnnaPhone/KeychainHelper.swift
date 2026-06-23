import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.lacobusgump.anna"
    private static let apiKeyAccount = "claude_api_key"
    private static let macHostAccount = "mac_tool_host"
    private static let licenseKeyAccount = "gump_license_key"

    static func saveAPIKey(_ key: String) {
        save(key, account: apiKeyAccount)
    }

    static func loadAPIKey() -> String {
        load(account: apiKeyAccount) ?? ""
    }

    static func saveMacHost(_ host: String) {
        save(host, account: macHostAccount)
    }

    static func loadMacHost() -> String {
        load(account: macHostAccount) ?? "http://192.168.1.100:8765"
    }

    static func saveLicenseKey(_ key: String) {
        save(key, account: licenseKeyAccount)
    }

    static func loadLicenseKey() -> String {
        load(account: licenseKeyAccount) ?? ""
    }

    private static func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }
}