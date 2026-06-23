import Foundation

/// Fetches security policy from begump.com — iPhone only (recouple + public manifest).
final class SecurityPolicySync {
    static let shared = SecurityPolicySync()

    static let policyURL = URL(string: "https://begump.com/anna/security-policy.json")!
    static let validateURL = URL(string: "https://license.begump.com/validate")!

    private let storageURL: URL
    private(set) var current: SecurityPolicyDocument

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageURL = dir.appendingPathComponent("anna_security_policy.enc")
        current = Self.loadBundled()
        if let cached = Self.loadCached(from: storageURL) {
            current = cached
        }
    }

    func refreshIfNeeded() {
        fetchPublicPolicy { [weak self] doc in
            guard let self, let doc else { return }
            self.apply(doc, source: "begump.com")
        }
    }

    func recouple(key: String, machineId: String, completion: @escaping (Result<SecurityPolicyDocument, Error>) -> Void) {
        if tryValidate(key: key, machineId: machineId, completion: completion) { return }
        fetchPublicPolicy { doc in
            if let doc {
                self.apply(doc, source: "begump.com")
                completion(.success(doc))
            } else {
                completion(.failure(CouplingLicenseError.offlineExpired))
            }
        }
    }

    private func tryValidate(
        key: String,
        machineId: String,
        completion: @escaping (Result<SecurityPolicyDocument, Error>) -> Void
    ) -> Bool {
        guard NetworkGuard.isAllowed(Self.validateURL) else {
            return false
        }
        NetworkGuard.logEgress(url: Self.validateURL, kind: .securityPolicy)

        var request = URLRequest(url: Self.validateURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        let body: [String: String] = ["key": key, "machine_id": machineId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data,
                  let resp = try? JSONDecoder().decode(RecoupleResponse.self, from: data),
                  resp.status == "valid" else {
                completion(.failure(CouplingLicenseError.offlineExpired))
                return
            }
            let doc = resp.securityPolicy ?? self.current
            self.apply(doc, source: "license.begump.com")
            completion(.success(doc))
        }.resume()
        return true
    }

    func fetchPublicPolicy(completion: @escaping (SecurityPolicyDocument?) -> Void) {
        guard NetworkGuard.isAllowed(Self.policyURL) else {
            completion(current)
            return
        }
        NetworkGuard.logEgress(url: Self.policyURL, kind: .securityPolicy)

        URLSession.shared.dataTask(with: Self.policyURL) { data, _, _ in
            guard let data,
                  let doc = try? JSONDecoder().decode(SecurityPolicyDocument.self, from: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async {
                self.apply(doc, source: "begump.com")
                completion(doc)
            }
        }.resume()
    }

    func apply(_ doc: SecurityPolicyDocument, source: String) {
        var merged = doc
        if merged.source == nil {
            merged = SecurityPolicyDocument(
                version: doc.version,
                source: source,
                anna: doc.anna,
                recoupleIntervalDays: doc.recoupleIntervalDays,
                offlineGraceDays: doc.offlineGraceDays,
                products: doc.products
            )
        }
        current = merged
        if let data = try? JSONEncoder().encode(merged) {
            SecureStorage.write(data, to: storageURL)
        }
        AnnaSecurity.shared.applyRemotePolicy(merged)
    }

    private static func loadBundled() -> SecurityPolicyDocument {
        guard let url = Bundle.main.url(forResource: "security-policy.default", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let doc = try? JSONDecoder().decode(SecurityPolicyDocument.self, from: data) else {
            return SecurityPolicyDocument(
                version: "0",
                source: "inline",
                anna: nil,
                recoupleIntervalDays: 7,
                offlineGraceDays: 14,
                products: nil
            )
        }
        return doc
    }

    private static func loadCached(from url: URL) -> SecurityPolicyDocument? {
        guard let data = SecureStorage.read(from: url) else { return nil }
        return try? JSONDecoder().decode(SecurityPolicyDocument.self, from: data)
    }
}