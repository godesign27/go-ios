import AppIntents
import Foundation
import WidgetKit

/// A widget tile tap: opens the app straight from the Home Screen, without showing Go first.
/// The launch is logged so Recently Used and Most Used stay accurate.
/// (If an app won't open this way, Design › Home Screen Widgets › "Open apps directly" off
/// routes taps through Go instead.)
struct OpenAppDirectlyIntent: AppIntent {
    static var title: LocalizedStringResource = "Open App"
    static var isDiscoverable: Bool = false

    @Parameter(title: "App ID")
    var appID: String

    init() {}

    init(appID: String) {
        self.appID = appID
    }

    func perform() async throws -> some IntentResult & OpensIntent {
        guard let id = UUID(uuidString: appID),
              let app = SharedStore.loadState()?.apps.first(where: { $0.id == id }),
              let url = app.launch.resolvedURL
        else {
            // Unknown app (deleted since the widget refreshed): open Go instead.
            return .result(opensIntent: OpenURLIntent(URL(string: "golauncher://")!))
        }
        WidgetLaunchLog.append(id)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(opensIntent: OpenURLIntent(url))
    }
}
