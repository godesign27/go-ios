import SwiftUI

/// Step-by-step guide for turning the iPhone's own Home Screen into Go.
struct HomeScreenSetupView: View {
    private struct Step: Identifiable {
        let id: Int
        let title: String
        let detail: String
        let symbol: String
    }

    private let steps: [Step] = [
        Step(id: 1, title: "Match the wallpaper",
             detail: "In Design, tap “Save Background as iPhone Wallpaper”. Then in Photos, open it, tap Share › Use as Wallpaper, and pick Home Screen.",
             symbol: "photo.on.rectangle"),
        Step(id: 2, title: "Make room",
             detail: "Long-press an empty spot on your Home Screen until icons jiggle. Drag the icons on your first page into the App Library (they stay installed).",
             symbol: "square.dashed"),
        Step(id: 3, title: "Add Go widgets",
             detail: "Tap Edit › Add Widget, search for Go, and add Go Section in the size you like. Large shows 16 apps, medium 4 or 8, small 4.",
             symbol: "square.grid.2x2"),
        Step(id: 4, title: "Pick a section for each",
             detail: "Long-press a Go widget › Edit Widget › Section: Favorites, Recently Used, Most Used, Needs Attention or any of your groups.",
             symbol: "slider.horizontal.3"),
        Step(id: 5, title: "Hide Apple's other pages",
             detail: "While icons jiggle, tap the page dots and uncheck every page except your Go page. Swipe left still opens the App Library.",
             symbol: "eye.slash"),
        Step(id: 6, title: "Search from anywhere",
             detail: "Add the Go Search control: Control Center › + › Add a Control › Go Search. You can also put it on the Lock Screen or the Action Button (Settings › Action Button › Controls).",
             symbol: "magnifyingglass"),
    ]

    // Shown as a page inside Design's navigation (pushed, not a second sheet).
    var body: some View {
        List {
                Section {
                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: step.symbol)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(step.id). \(step.title)").font(.headline)
                                Text(step.detail).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } footer: {
                    Text("iOS doesn't let any app replace Apple's Home Screen, but with Go's widgets, wallpaper and search control in place, your phone runs on your Go layout. Widgets update when you change Go.")
                }
            }
            .navigationTitle("Go as Your Home Screen")
            .navigationBarTitleDisplayMode(.inline)
    }
}
