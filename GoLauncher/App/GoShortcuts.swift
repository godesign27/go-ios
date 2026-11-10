import AppIntents

/// Makes "Search in Go" available to Siri, Spotlight, the Shortcuts app and the Action Button.
struct GoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenGoSearchIntent(),
            phrases: [
                "Search in \(.applicationName)",
                "Find an app with \(.applicationName)",
            ],
            shortTitle: "Search",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: OpenAppWithGoIntent(),
            phrases: [
                "Open \(\.$app) with \(.applicationName)",
                "Open an app with \(.applicationName)",
            ],
            shortTitle: "Open App",
            systemImageName: "arrow.up.forward.app"
        )
    }
}
