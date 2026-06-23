import CryptoKit
import Foundation
import Security

/// sh — encrypted security tier for financial/private visual memory.
/// Anything `info.sh` requires Face Presence (passive window or one biometric).
/// Never syncs to watch. Never egress. Separate AES key from general Anna storage.
enum ShRecordKind: String, Codable {
    case screenshot
    case companionScreen
    case cameraWithJim
    case financialContext
}

struct ShRecord: Codable, Identifiable, Equatable {
    let id: UUID
    var kind: ShRecordKind
    var appLabel: String
    var contextHint: String
    var learnedSummary: String
    var tags: [String]
    var imageFilename: String
    var createdAt: Date
    var thrownToVault: Bool

    init(
        id: UUID = UUID(),
        kind: ShRecordKind,
        appLabel: String,
        contextHint: String = "",
        learnedSummary: String = "",
        tags: [String] = [],
        imageFilename: String,
        createdAt: Date = Date(),
        thrownToVault: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.appLabel = appLabel.lowercased()
        self.contextHint = contextHint
        self.learnedSummary = learnedSummary
        self.tags = tags
        self.imageFilename = imageFilename
        self.createdAt = createdAt
        self.thrownToVault = thrownToVault
    }

    /// Convention: sensitive blobs live as `*.sh` under Application Support.
    var shFilename: String { "\(id.uuidString).sh" }
}

final class ShLayer: ObservableObject {
    static let shared = ShLayer()

    @Published private(set) var recordCount: Int = 0
    @Published private(set) var companionActive: Bool = false

    private var records: [ShRecord] = []
    private let indexURL: URL
    private let mediaDir: URL
    private let maxRecords = 500

    static let claudeInstructions = """
    SH LAYER (financial/private — face-gated, never on watch):
    Jim's encrypted visual memory — Venmo, banking, receipts, screens WITH him.
    Anna captures silently when companion mode + Face Presence valid (he's looking at phone).
    Query sh only when he asks about money sent, balances, who he paid — never volunteer amounts unprompted.
    Throw path: sh blobs compress to M4 vault as info.sh — solution layer, not pull.
    """

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = base.appendingPathComponent("anna_sh", isDirectory: true)
        mediaDir = root.appendingPathComponent("media", isDirectory: true)
        indexURL = root.appendingPathComponent("index.sh")
        try? FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        loadIndex()
        companionActive = UserDefaults.standard.bool(forKey: Key.companionEnabled)
        recordCount = records.count
    }

    private enum Key {
        static let companionEnabled = "anna_sh_companion_enabled"
        static let cryptoAccount = "anna_sh_encryption_key"
        static let cryptoService = "com.lacobusgump.anna.sh.crypto"
    }

    // MARK: - Settings

    var companionEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Key.companionEnabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: Key.companionEnabled)
            companionActive = newValue
        }
    }

    static let financialApps: [(label: String, keywords: [String])] = [
        ("venmo", ["venmo", "paid", "payment to", "charge"]),
        ("paypal", ["paypal"]),
        ("chase", ["chase", "checking", "savings"]),
        ("bank", ["balance", "account", "routing", "deposit"]),
        ("cashapp", ["cash app", "$cashtag"]),
        ("applepay", ["apple pay", "wallet"]),
    ]

    static func inferAppLabel(from text: String) -> String {
        let lower = text.lowercased()
        for app in financialApps {
            if app.keywords.contains(where: { lower.contains($0) }) {
                return app.label
            }
        }
        return "private"
    }

    static func isFinancialContext(_ hint: String) -> Bool {
        inferAppLabel(from: hint) != "private" || hint.lowercased().contains("venmo")
    }

    // MARK: - Store (face-gated write)

    func storeImage(
        _ imageData: Data,
        kind: ShRecordKind,
        appLabel: String,
        contextHint: String = "",
        learnedSummary: String = "",
        tags: [String] = [],
        completion: @escaping (Bool, ShRecord?) -> Void
    ) {
        #if os(iOS)
        shGate(reason: "Store private memory") { [weak self] granted in
            guard granted, let self else {
                completion(false, nil)
                return
            }
            let id = UUID()
            let filename = "\(id.uuidString).sh"
            let path = self.mediaDir.appendingPathComponent(filename)
            guard ShCrypto.write(imageData, to: path) else {
                completion(false, nil)
                return
            }
            var label = appLabel.lowercased()
            if label.isEmpty || label == "private" {
                label = Self.inferAppLabel(from: contextHint + " " + learnedSummary)
            }
            let record = ShRecord(
                kind: kind,
                appLabel: label,
                contextHint: contextHint,
                learnedSummary: learnedSummary,
                tags: tags,
                imageFilename: filename
            )
            self.records.insert(record, at: 0)
            if self.records.count > self.maxRecords {
                let dropped = self.records.suffix(from: self.maxRecords)
                for old in dropped {
                    try? FileManager.default.removeItem(at: self.mediaDir.appendingPathComponent(old.imageFilename))
                }
                self.records = Array(self.records.prefix(self.maxRecords))
            }
            self.saveIndex()
            self.recordCount = self.records.count
            completion(true, record)
        }
        #else
        completion(false, nil)
        #endif
    }

    // MARK: - Read (face-gated)

    func recentSummaries(limit: Int = 8, completion: @escaping (String) -> Void) {
        #if os(iOS)
        shGate(reason: "Read private memory") { [weak self] granted in
            guard granted, let self else {
                completion("SH: face confirmation required.")
                return
            }
            completion(self.contextBlockUnlocked(limit: limit))
        }
        #else
        completion("SH: phone only.")
        #endif
    }

    func contextBlockUnlocked(limit: Int = 8) -> String {
        guard !records.isEmpty else {
            return "SH: no private visual captures yet. Companion captures Venmo/banking when you're looking at the phone."
        }
        let lines = records.prefix(limit).map { r in
            let when = r.createdAt.formatted(date: .abbreviated, time: .shortened)
            let sum = r.learnedSummary.isEmpty ? r.contextHint : r.learnedSummary
            let thrown = r.thrownToVault ? " [vaulted]" : ""
            return "- \(when) @\(r.appLabel) \(r.kind.rawValue)\(thrown): \(sum)"
        }.joined(separator: "\n")
        return """
        SH — PRIVATE VISUAL MEMORY (\(records.count) info.sh blobs, face-gated):
        Silent captures with Jim on Venmo/finance apps. Never quote to others. Never sync watch.

        \(lines)
        """
    }

    func search(query: String, completion: @escaping ([ShRecord]) -> Void) {
        #if os(iOS)
        shGate(reason: "Search private memory") { [weak self] granted in
            guard granted, let self else {
                completion([])
                return
            }
            let tokens = query.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 2 }
            let matches = self.records.filter { r in
                let hay = [r.appLabel, r.contextHint, r.learnedSummary, r.kind.rawValue]
                    .joined(separator: " ") + " " + r.tags.joined(separator: " ")
                return tokens.isEmpty || tokens.contains(where: { hay.localizedCaseInsensitiveContains($0) })
            }
            completion(Array(matches.prefix(12)))
        }
        #else
        completion([])
        #endif
    }

    static func hasShQuery(_ utterance: String) -> Bool {
        let q = utterance.lowercased()
        let triggers = [
            "venmo", "paid", "sent money", "who did i pay", "last payment",
            "balance", "bank", "transaction", "receipt", "what was on screen",
            "screenshot", "on venmo",
        ]
        return triggers.contains(where: { q.contains($0) })
    }

    func markThrown(_ id: UUID) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].thrownToVault = true
        saveIndex()
    }

    func mediaPath(for record: ShRecord) -> URL {
        mediaDir.appendingPathComponent(record.imageFilename)
    }

    // MARK: - Persistence

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        ShCrypto.write(data, to: indexURL)
    }

    private func loadIndex() {
        guard let data = ShCrypto.read(from: indexURL),
              let decoded = try? JSONDecoder().decode([ShRecord].self, from: data) else { return }
        records = decoded
    }

    #if os(iOS)
    private func shGate(reason: String, completion: @escaping (Bool) -> Void) {
        HmConfirm.shared.guarded(reason: reason, completion: completion)
    }
    #endif
}

// MARK: - sh-specific encryption (separate Keychain key)

enum ShCrypto {
    private static let account = "anna_sh_encryption_key"
    private static let service = "com.lacobusgump.anna.sh.crypto"

    static func write(_ data: Data, to url: URL) -> Bool {
        guard let sealed = seal(data) else { return false }
        do {
            try sealed.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return true
        } catch {
            return false
        }
    }

    static func read(from url: URL) -> Data? {
        guard let sealed = try? Data(contentsOf: url) else { return nil }
        return open(sealed)
    }

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
            kSecAttrAccount as String: account,
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
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return data
    }
}