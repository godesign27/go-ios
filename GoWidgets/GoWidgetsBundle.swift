import SwiftUI
import WidgetKit

/// Go on the Home Screen, Lock Screen and in Control Center.
@main
struct GoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        GoSectionWidget()
        GoSearchControl()
    }
}
