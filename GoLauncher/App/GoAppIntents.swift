import AppIntents
import Foundation
import WidgetKit

// Go's apps as something Siri and the Shortcuts app can name ("Slack", "Gmail"), plus two
// actions that use them. Lives in the app only: these run from Siri, Spotlight and Shortcuts.

/// One app in your Go layout.
struct GoAppEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Go App"
    static var defaultQuery = GoAppQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct GoAppQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [GoAppEntity] {
        Self.all().filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [GoAppEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return Self.all().filter { $0.name.lowercased().contains(needle) }
    }

    func suggestedEntities() async throws -> [GoAppEntity] {
        Self.all()
    }

    static func all() -> [GoAppEntity] {
        (SharedStore.loadState()?.apps ?? [])
            .map { GoAppEntity(id: $0.id.uuidString, name: $0.name) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

/// Adds an app to Go's Recently Used and Most Used without opening Go.
///
/// iOS doesn't tell other apps when you open something from Apple's Home Screen. This action
/// is for a Shortcuts automation ("When Slack is opened › Log App in Go Recents › Slack"), so
/// launches from anywhere still count in Go and its widgets.
struct LogAppOpenedIntent: AppIntent {
    static var title: LocalizedStringResource = "Log App in Go Recents"
    static var description = IntentDescription(
        "Adds an app to Go's Recently Used and Most Used. Use it in a Shortcuts automation that runs when that app is opened."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "App")
    var app: GoAppEntity

    init() {}

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: app.id) {
            // Same log the widgets use: Go merges it when it opens, widgets read it right away.
            WidgetLaunchLog.append(id)
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}

/// "Open Slack with Go": opens the app through Go so the launch counts in Recently Used.
struct OpenAppWithGoIntent: AppIntent {
    static var title: LocalizedStringResource = "Open App with Go"
    static var description = IntentDescription("Opens one of your Go apps and counts it in Recently Used.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "App")
    var app: GoAppEntity

    init() {}

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: app.id) {
            GoRequest.save(GoRequest(kind: .openApp, appID: id, date: Date()))
        }
        return .result()
    }
}
