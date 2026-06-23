import Foundation

/// THROW — symbiotic trust function. Jim throws; Anna says yes.
/// Not pull — the trusted layer already has it from jump (Life Notes, capture, intention).
/// Throw something *up* = provide the solution: move, compress, vault. Never fetch-first.
/// Watch = narrow brain (intent). Phone = wide brain (route). Mac = compress + vault.
/// Not Life Memory remember-consent. Throw is trust to hand off — yes, not "look it up."
enum ThrowIntention: String, Codable, CaseIterable {
    case life
    case build
    case media
    case knowledge
    case phone
    case data
}

struct ThrowRequest: Codable {
    let utterance: String
    let intention: ThrowIntention
    let site: String
    let trustMode: Bool

    func jsonPayload() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let text = String(data: data, encoding: .utf8) else {
            return utterance
        }
        return text
    }

    static func decodePayload(_ payload: String) -> ThrowRequest? {
        guard let data = payload.data(using: .utf8),
              let req = try? JSONDecoder().decode(ThrowRequest.self, from: data) else {
            return nil
        }
        return req
    }
}

enum ThrowTrust {
    /// Jim mode — act, don't gate. Others get confirmation later.
    static var jimTrustEnabled: Bool { true }

    static func hasThrowIntent(_ utterance: String) -> Bool {
        let q = utterance.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return false }
        let triggers = [
            "throw", "vault", "move this", "move it", "store this",
            "put this in", "off my phone", "phone full", "compress",
            "sfumato", "yes move",
        ]
        return triggers.contains { q.contains($0) }
    }

    static func parse(_ utterance: String, site: String = "unknown") -> ThrowRequest {
        ThrowRequest(
            utterance: utterance,
            intention: detectIntention(utterance, site: site),
            site: site,
            trustMode: jimTrustEnabled
        )
    }

    static func detectIntention(_ utterance: String, site: String) -> ThrowIntention {
        let q = utterance.lowercased()
        if q.contains("photo") || q.contains("video") || q.contains("media") || q.contains("camera") {
            return .media
        }
        if q.contains("deck") || q.contains("build") || q.contains("2x6") || q.contains("work") || site == "work" {
            return .build
        }
        if q.contains("farm") || q.contains("home") || q.contains("egg") || q.contains("life") || site == "home" {
            return .life
        }
        if q.contains("phone") || q.contains("dcim") || q.contains("camera roll") {
            return .phone
        }
        if q.contains("note") || q.contains("transcript") || q.contains("actually say")
            || q.contains("what did they") || q.contains("verbatim") {
            return .knowledge
        }
        if q.contains("remember") || q.contains("doc") || q.contains("text") {
            return .knowledge
        }
        if q.contains("venmo") || q.contains("paid") || q.contains("receipt") || q.contains("bank") {
            return .data
        }
        return .data
    }

    /// Wrist copy — short. Never "full", never "can't".
    static func wristAck(intention: ThrowIntention, macResult: String?) -> String {
        let hint = macResult?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if hint.lowercased().contains("vaulted") || hint.lowercased().contains("yes") {
            return "Yes — \(intention.rawValue)."
        }
        if !hint.isEmpty, hint.count < 40 {
            return hint
        }
        return "Yes — thrown to \(intention.rawValue)."
    }

    static func contextBlock() -> String {
        """
        THROW (symbiotic trust — solution, not retrieval):
        The trusted layer already runs from jump — Life Notes verbatim, site, voice tags. \
        Jim does not pull information up; he throws something up and that IS the solution. \
        Anna never says "full" or "can't". Route by intention; Mac compresses and vaults. \
        Query ("what did they say") reads the trusted layer. Throw hands more INTO it. \
        No wearable lens — phone bridges (DCIM, internet, world). Every layer throw-away synced to Mac. \
        sh layer: financial/private screens → info.sh encrypted, face-gated, silent on Venmo with Jim. \
        For Jim: trust mode ON — yes first. Wrist reply ≤ 6 words when pure throw.
        """
    }
}