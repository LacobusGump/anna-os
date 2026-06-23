import SwiftUI

@main
struct AnnaPhoneApp: App {
    @StateObject private var brain = PhoneBrain()

    var body: some Scene {
        WindowGroup {
            PhoneContentView()
                .environmentObject(brain)
        }
    }
}