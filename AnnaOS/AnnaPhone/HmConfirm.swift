#if os(iOS)
import Foundation

/// hm deadman — face alone is spoofable; hm alone is noise. Both at once = Jim.
/// Public cover: "hmmm" reads as thinking. Subway-safe confirm without saying yes.
/// v0: face-only fallback when strict off. Bone/hm detection lands in Phase 2.
final class HmConfirm {
    static let shared = HmConfirm()

    /// hm pulse must land within this window while face presence is valid.
    private let pulseWindow: TimeInterval = 8
    private var lastPulse = Date.distantPast

    private enum Key {
        static let strictDeadman = "anna_hm_strict_deadman"
    }

    /// When true, sh gates require face + recent hm. Default off — regression-safe for deploy.
    var strictDeadman: Bool {
        get { UserDefaults.standard.bool(forKey: Key.strictDeadman) }
        set { UserDefaults.standard.set(newValue, forKey: Key.strictDeadman) }
    }

    var isPulseFresh: Bool {
        Date().timeIntervalSince(lastPulse) <= pulseWindow
    }

    /// Deadman armed: passive face window and hm in the same beat.
    var isArmed: Bool {
        FacePresence.shared.isValid && isPulseFresh
    }

    private init() {}

    /// Register hm from bone mic, wrist sensor, or explicit UI tap (v0 dev path).
    func registerPulse() {
        lastPulse = Date()
        FacePresence.shared.noteLooking()
    }

    /// Gate for sh and other Jim-only confirms. Strict mode adds hm on top of face.
    func guarded(reason: String, completion: @escaping (Bool) -> Void) {
        FacePresence.shared.guarded(reason: reason) { [weak self] faceOk in
            guard let self, faceOk else {
                completion(false)
                return
            }
            if self.strictDeadman && !self.isPulseFresh {
                completion(false)
                return
            }
            completion(true)
        }
    }
}
#endif