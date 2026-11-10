import AppIntents
import Foundation
import WidgetKit

/// A widget tile tap: opens the app straight from the Home Screen, without showing Go first.
/// The launch is logged so Recently Used and Most Used stay accurate.
///
/// Compiled into both the app and the widget extension. iOS looks up a widget button's intent
/// through the app too; when this lived only in the extension, that lookup failed, the app's ID
/// was dropped from the tap, and every tap opened Go instead of the app.
/// (If an app won't open this way, Design › Home Screen Widgets › "Open apps directly" off
/// routes taps through Go instead.)
@available(iOS 18.0, *)
struct OpenAppDirectlyIntent: AppIntent {
    static var title: LocalizedStringResource = "Open App"
    static var isDiscoverable: Bool = false

    // A default value keeps the parameter encodable when the widget packages the button.
    @Parameter(title: "App ID", default: "")
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
