import SwiftUI

@main
struct AnnaApp: App {
    @StateObject private var anna = AnnaCore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(anna)
        }
    }
}
