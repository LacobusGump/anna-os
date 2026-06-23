import SwiftUI

@main
struct AnnaPhoneApp: App {
    @StateObject private var brain = PhoneBrain()
    @StateObject private var security = AnnaSecurity.shared
    @StateObject private var coupling = CouplingLicense.shared

    var body: some Scene {
        WindowGroup {
            PhoneContentView()
                .environmentObject(brain)
                .environmentObject(security)
                .environmentObject(coupling)
                .onAppear {
                    if ShLayer.shared.companionEnabled {
                        ShCompanion.shared.start()
                    }
                }
        }
    }
}