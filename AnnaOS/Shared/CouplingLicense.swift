import CryptoKit
import Foundation

/// Coupling license — protection through physics, not walls.
/// Port of gump.coupling_license. Recouple weekly → security policy + K from begump.
struct CouplingLicenseState: Codable {
    var keyHash: String?
    var machineId: String
    var activationMachine: String?
    var K: Double
    var lastCoupled: Date?
    var activated: Bool
    var product: String
}

final class CouplingLicense: ObservableObject {
    static let shared = CouplingLicense()

    static let kPeak = 1.868
    static let kMin = 0.002
    static let kDecayPerHour = 0.003
    static let recoupleInterval: TimeInterval = 7 * 24 * 3600
    static let offlineGrace: TimeInterval = 14 * 24 * 3600

    @Published private(set) var K: Double = kMin
    @Published private(set) var activated = false
    @Published private(set) var phase: String = "decoupled"
    @Published private(set) var lastCoupled: Date?
    @Published private(set) var product: String = ""

    private let machineId: String
    private var key: String = ""
    private var activationMachine: String?
    private let storageURL: URL

    private init() {
        machineId = CouplingLicense.machineFingerprint()
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("coupling_license.enc")
        SecureStorage.migratePlaintext(at: storageURL)
        load()
        applyDecay()
        updatePhase()
    }

    var coupled: Bool { K > 0.5 }

    func activate(_ licenseKey: String) -> Bool {
        guard Self.validateKeyFormat(licenseKey) else { return false }
        key = licenseKey
        activationMachine = machineId
        K = Self.kPeak
        lastCoupled = Date()
        activated = true
        KeychainHelper.saveLicenseKey(licenseKey)
        save()
        updatePhase()
        return true
    }

    func recouple(completion: @escaping (Result<SecurityPolicyDocument, Error>) -> Void) {
        guard activated, !key.isEmpty else {
            completion(.failure(CouplingLicenseError.notActivated))
            return
        }

        guard machineId == activationMachine else {
            completion(.failure(CouplingLicenseError.hardwareMismatch))
            return
        }

        SecurityPolicySync.shared.recouple(key: key, machineId: machineId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let doc):
                self.K = Self.kPeak
                self.lastCoupled = Date()
                self.product = doc.products?.anna?.name ?? "anna"
                self.save()
                self.updatePhase()
                AnnaSecurity.shared.applyRemotePolicy(doc)
                completion(.success(doc))
            case .failure:
                if let last = self.lastCoupled,
                   Date().timeIntervalSince(last) < Self.offlineGrace {
                    completion(.failure(CouplingLicenseError.offlineGrace))
                } else {
                    self.applyDecay()
                    self.updatePhase()
                    completion(.failure(CouplingLicenseError.offlineExpired))
                }
            }
        }
    }

    // MARK: - Machine fingerprint

    static func machineFingerprint() -> String {
        let parts = [
            DeviceIdentity.identifier(),
            Bundle.main.bundleIdentifier ?? "anna"
        ]
        let raw = parts.joined(separator: "|")
        return spectralHash(raw, salt: "anna_machine_v1")
    }

    static func validateKeyFormat(_ key: String) -> Bool {
        let parts = key.split(separator: "-")
        guard parts.count == 4, parts[0] == "GUMP" else { return false }
        return parts.dropFirst().allSatisfy { $0.count == 4 }
    }

    static func spectralHash(_ data: String, salt: String) -> String {
        let phi = (1.0 + sqrt(5.0)) / 2.0
        let golden = 1.0 / phi
        var input = Data((data + salt).utf8)
        let base = SHA256.hash(data: input)
        var state = 0.0
        for (i, byte) in base.enumerated() {
            let angle = Double(i) * golden * 2.0 * Double.pi
            let mod = angle.truncatingRemainder(dividingBy: 2.0 * Double.pi)
            state += Double(byte) * (1.0 / (1.0 + abs(mod - Double.pi)))
        }
        var combined = Data(base)
        combined.append(contentsOf: withUnsafeBytes(of: state) { Data($0) })
        return SHA256.hash(data: combined).compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Persistence

    private func save() {
        let state = CouplingLicenseState(
            keyHash: key.isEmpty ? nil : Self.spectralHash(key, salt: "state"),
            machineId: machineId,
            activationMachine: activationMachine,
            K: K,
            lastCoupled: lastCoupled,
            activated: activated,
            product: product
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        SecureStorage.write(data, to: storageURL)
    }

    private func load() {
        key = KeychainHelper.loadLicenseKey()
        guard let data = SecureStorage.read(from: storageURL),
              let state = try? JSONDecoder().decode(CouplingLicenseState.self, from: data),
              state.machineId == machineId else { return }
        activationMachine = state.activationMachine
        K = state.K
        lastCoupled = state.lastCoupled
        activated = state.activated && !key.isEmpty
        product = state.product
    }

    private func applyDecay() {
        guard activated, let last = lastCoupled else { return }
        let elapsed = Date().timeIntervalSince(last)
        if elapsed <= Self.recoupleInterval { return }
        let decayHours = (elapsed - Self.recoupleInterval) / 3600
        K = max(Self.kMin, K - Self.kDecayPerHour * decayHours)
    }

    private func updatePhase() {
        if K >= Self.kPeak * 0.9 { phase = "peak" }
        else if K >= 1.0 { phase = "coupled" }
        else if K >= 0.5 { phase = "drifting" }
        else if K >= 0.1 { phase = "degraded" }
        else { phase = "decoupled" }
    }
}

