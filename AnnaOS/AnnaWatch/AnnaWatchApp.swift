import SwiftUI

@main
struct AnnaWatchApp: App {
    @StateObject private var anna = AnnaCore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(anna)
        }
    }
}