import Foundation
#if canImport(CoreLocation)
import CoreLocation
#endif

/// Geo-synced places — disambiguates work deck vs home deck, farm vs job site.
struct MemorySite: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var label: String
    var latitude: Double?
    var longitude: Double?
    var radiusMeters: Double

    init(
        id: UUID = UUID(),
        name: String,
        label: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        radiusMeters: Double = 120
    ) {
        self.id = id
        self.name = name
        self.label = label.isEmpty ? name : label
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
    }
}

final class SiteContext: ObservableObject {
    static let shared = SiteContext()

    @Published private(set) var sites: [MemorySite] = []
    @Published var manualSiteOverride: String = ""
    @Published private(set) var gpsSite: String = ""

    private let storageURL: URL

    var currentSite: String {
        let manual = manualSiteOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manual.isEmpty { return manual.lowercased() }
        if !gpsSite.isEmpty { return gpsSite }
        return "general"
    }

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storageURL = dir.appendingPathComponent("anna_sites.enc")
        SecureStorage.migratePlaintext(at: storageURL)
        load()
        if sites.isEmpty {
            sites = [
                MemorySite(name: "home", label: "Home"),
                MemorySite(name: "farm", label: "Columbus NJ farms"),
                MemorySite(name: "work", label: "Work / client jobs")
            ]
            save()
        }
    }

    func contextBlock() -> String {
        let siteList = sites.map { s in
            let coords = (s.latitude != nil && s.longitude != nil)
                ? " (\(s.latitude!), \(s.longitude!), \(Int(s.radiusMeters))m)"
                : " (coords not set)"
            return "- \(s.name): \(s.label)\(coords)"
        }.joined(separator: "\n")

        return """
        SITE CONTEXT (geo-sync — work deck ≠ home deck):
        Current site: \(currentSite)
        \(manualSiteOverride.isEmpty ? "" : "Manual override: \(manualSiteOverride)\n")
        Known sites:
        \(siteList)
        When Jim says "remember" a materials list, bind to current site unless he names another.
        """
    }

    func upsertSite(_ site: MemorySite) {
        if let idx = sites.firstIndex(where: { $0.name == site.name }) {
            sites[idx] = site
        } else {
            sites.append(site)
        }
        save()
    }

    func setManualSite(_ name: String) {
        manualSiteOverride = name
    }

    #if os(iOS)
    func startLocationUpdates() {
        #if canImport(CoreLocation)
        LocationObserver.shared.onSiteResolved = { [weak self] siteName in
            DispatchQueue.main.async { self?.gpsSite = siteName }
        }
        LocationObserver.shared.start(with: sites)
        #endif
    }
    #endif

    private func save() {
        guard let data = try? JSONEncoder().encode(sites) else { return }
        SecureStorage.write(data, to: storageURL)
    }

    private func load() {
        guard let data = SecureStorage.read(from: storageURL),
              let decoded = try? JSONDecoder().decode([MemorySite].self, from: data) else { return }
        sites = decoded
    }
}

#if os(iOS) && canImport(CoreLocation)
private final class LocationObserver: NSObject, CLLocationManagerDelegate {
    static let shared = LocationObserver()

    var onSiteResolved: ((String) -> Void)?
    private let manager = CLLocationManager()
    private var sites: [MemorySite] = []

    func start(with sites: [MemorySite]) {
        self.sites = sites
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let match = sites.compactMap { site -> (String, Double)? in
            guard let lat = site.latitude, let lon = site.longitude else { return nil }
            let siteLoc = CLLocation(latitude: lat, longitude: lon)
            let dist = loc.distance(from: siteLoc)
            guard dist <= site.radiusMeters else { return nil }
            return (site.name, dist)
        }
        .min(by: { $0.1 < $1.1 })

        if let name = match?.0 {
            onSiteResolved?(name)
        }
    }
}
#endif