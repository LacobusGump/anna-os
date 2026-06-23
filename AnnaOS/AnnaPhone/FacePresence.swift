#if os(iOS)
import Foundation
import LocalAuthentication
import UIKit

/// Passive Face Presence — Jim is looking at the phone.
/// Extends trust window after device unlock / app foreground without spamming confirms.
/// One explicit Face ID only when the window expired.
final class FacePresence {
    static let shared = FacePresence()

    private let windowDuration: TimeInterval = 300
    private var windowUntil = Date.distantPast
    private var lastExplicitPrompt = Date.distantPast
    private let minPromptGap: TimeInterval = 120

    var isValid: Bool { Date() < windowUntil }

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(protectedDataAvailable),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        noteLooking()
    }

    @objc private func protectedDataAvailable() {
        // Device unlocked — Face ID or passcode already satisfied at lock screen.
        extendWindow()
    }

    func noteLooking() {
        extendWindow()
    }

    func extendWindow() {
        windowUntil = Date().addingTimeInterval(windowDuration)
    }

    /// Gate sh read/write. Uses passive window first; one biometric if expired.
    func guarded(reason: String, completion: @escaping (Bool) -> Void) {
        if isValid {
            completion(true)
            return
        }
        let now = Date()
        guard now.timeIntervalSince(lastExplicitPrompt) >= minPromptGap else {
            completion(false)
            return
        }
        lastExplicitPrompt = now
        let context = LAContext()
        context.localizedReason = reason
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
                DispatchQueue.main.async {
                    if ok { self.extendWindow() }
                    completion(ok)
                }
            }
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { ok, _ in
            DispatchQueue.main.async {
                if ok { self.extendWindow() }
                completion(ok)
            }
        }
    }
}
#endif