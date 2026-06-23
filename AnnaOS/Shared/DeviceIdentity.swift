import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Stable per-device identifier for coupling license (not transmitted except on recouple).
enum DeviceIdentity {
    private static let defaultsKey = "anna_device_uuid"

    static func identifier() -> String {
        if let existing = UserDefaults.standard.string(forKey: defaultsKey) {
            return existing
        }
        let id: String
        #if canImport(UIKit)
        id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        id = UUID().uuidString
        #endif
        UserDefaults.standard.set(id, forKey: defaultsKey)
        return id
    }
}