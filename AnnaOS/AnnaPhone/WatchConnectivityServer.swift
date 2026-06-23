import Foundation
import WatchConnectivity

protocol WatchMessaging: AnyObject {
    var isWatchReachable: Bool { get }
    func send(_ message: AnnaMessage)
    var onMessage: ((AnnaMessage) -> Void)? { get set }
}

final class WatchConnectivityServer: NSObject, WatchMessaging, WCSessionDelegate {
    var onMessage: ((AnnaMessage) -> Void)?
    private(set) var isWatchReachable = false

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func send(_ message: AnnaMessage) {
        guard WCSession.default.activationState == .activated else { return }
        let dict = message.encoded()
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(dict)
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            if activationState == .activated {
                self.send(AnnaMessage(type: .phoneStatus, payload: "connected"))
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            self.send(AnnaMessage(type: .phoneStatus, payload: session.isReachable ? "connected" : "disconnected"))
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let annaMessage = AnnaMessage.decode(from: message) else { return }
        DispatchQueue.main.async { self.onMessage?(annaMessage) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let annaMessage = AnnaMessage.decode(from: applicationContext) else { return }
        DispatchQueue.main.async { self.onMessage?(annaMessage) }
    }
}