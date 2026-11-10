import AppIntents
import SwiftUI
import WidgetKit

/// "Go Search" for Control Center, the Lock Screen and the Action Button: one tap and you're
/// typing an app name.
struct GoSearchControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.godesign.golauncher.search") {
            ControlWidgetButton(action: OpenGoSearchIntent()) {
                Label("Go Search", systemImage: "magnifyingglass")
            }
        }
        .displayName("Go Search")
        .description("Opens Go with the search keyboard ready.")
    }
}
