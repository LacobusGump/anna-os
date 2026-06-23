import SwiftUI

@main
struct AnnaPhoneApp: App {
    @StateObject private var brain = PhoneBrain()
    @StateObject private var security = AnnaSecurity.shared

    var body: some Scene {
        WindowGroup {
            PhoneContentView()
                .environmentObject(brain)
                .environmentObject(security)
        }
    }
}