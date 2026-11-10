import AppIntents
import Foundation

// Intents used by the Home Screen widgets and the Go Search control. Compiled into both the
// app and the widget extension: intents that open the app are performed by the app.

/// Opens Go, which then opens the app (the fallback when a widget can't open it directly).
struct OpenAppThroughGoIntent: AppIntent {
    static var title: LocalizedStringResource = "Open App with Go"
    static var isDiscoverable: Bool = false
    static var openAppWhenRun: Bool = true

    @Parameter(title: "App ID")
    var appID: String

    init() {}

    init(appID: String) {
        self.appID = appID
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: appID) {
            GoRequest.save(GoRequest(kind: .openApp, appID: id, date: Date()))
        }
        return .result()
    }
}

/// Opens Go straight into search. Used by the Control Center / Lock Screen control,
/// the Action Button, Siri and Spotlight.
struct OpenGoSearchIntent: AppIntent {
    static var title: LocalizedStringResource = "Search in Go"
    static var description = IntentDescription("Opens Go with the search keyboard ready.")
    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult {
        GoRequest.save(GoRequest(kind: .search, appID: nil, date: Date()))
        return .result()
    }
}
