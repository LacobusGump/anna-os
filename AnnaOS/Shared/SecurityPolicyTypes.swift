import Foundation

/// Security policy from begump.com — updated on recouple (subscription coupling).
struct SecurityPolicyDocument: Codable {
    let version: String
    let source: String?
    let anna: SecurityPolicyAnna?
    let recoupleIntervalDays: Int?
    let offlineGraceDays: Int?
    let products: SecurityPolicyProducts?

    enum CodingKeys: String, CodingKey {
        case version, source, anna, products
        case recoupleIntervalDays = "recouple_interval_days"
        case offlineGraceDays = "offline_grace_days"
    }
}

struct SecurityPolicyAnna: Codable {
    let cloudBrainDefault: Bool?
    let macToolsDefault: Bool?
    let musicCdnDefault: Bool?
    let begumpRelayDefault: Bool?
    let rememberConsentRequired: Bool?
    let anthropicModel: String?
    let anthropicMaxTokens: Int?
    let allowedEgressHosts: [String]?
    let mousetrapRules: String?

    enum CodingKeys: String, CodingKey {
        case rememberConsentRequired = "remember_consent_required"
        case cloudBrainDefault = "cloud_brain_default"
        case macToolsDefault = "mac_tools_default"
        case musicCdnDefault = "music_cdn_default"
        case begumpRelayDefault = "begump_relay_default"
        case anthropicModel = "anthropic_model"
        case anthropicMaxTokens = "anthropic_max_tokens"
        case allowedEgressHosts = "allowed_egress_hosts"
        case mousetrapRules = "mousetrap_rules"
    }
}

struct SecurityPolicyProducts: Codable {
    let anna: SecurityPolicyProduct?
}

struct SecurityPolicyProduct: Codable {
    let name: String?
    let tier: String?
    let couplingKPeak: Double?

    enum CodingKeys: String, CodingKey {
        case name, tier
        case couplingKPeak = "coupling_k_peak"
    }
}

struct RecoupleResponse: Codable {
    let status: String
    let K: Double?
    let resonance: String?
    let product: String?
    let nextRecouple: Int?
    let securityPolicy: SecurityPolicyDocument?

    enum CodingKeys: String, CodingKey {
        case status, K, resonance, product
        case nextRecouple = "next_recouple"
        case securityPolicy = "security_policy"
    }
}

enum CouplingLicenseError: LocalizedError {
    case notActivated
    case hardwareMismatch
    case offlineGrace
    case offlineExpired

    var errorDescription: String? {
        switch self {
        case .notActivated: return "No GUMP license key — local mode still works."
        case .hardwareMismatch: return "License bound to another device."
        case .offlineGrace: return "Offline — using bundled security policy."
        case .offlineExpired: return "Recouple expired — fetch policy from begump when online."
        }
    }
}