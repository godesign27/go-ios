import SwiftUI

@main
struct GoLauncherApp: App {
    @StateObject private var store = LauncherStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
        }
    }
}
