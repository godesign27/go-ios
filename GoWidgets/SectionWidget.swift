import AppIntents
import SwiftUI
import WidgetKit

// A Home Screen widget that shows one Go section (Favorites, Recently Used, a group…),
// styled with your Go theme. Long-press › Edit Widget to choose the section.

// MARK: - Configuration

/// The sections you can pick, as plain keys ("favorites", or a group's ID) with their names.
/// A plain string survives Edit Widget reliably; a custom entity was saved but never read back,
/// so every widget fell back to the default section.
struct GoSectionOptions: DynamicOptionsProvider {
    func results() async throws -> ItemCollection<String> {
        ItemCollection {
            ItemSection(items: Self.choices().map { IntentItem($0.key, title: "\($0.title)") })
        }
    }

    /// Starts on your first group (Favorites, Recently Used and Most Used have their own widgets).
    func defaultResult() async -> String? {
        Self.firstGroupKey
    }

    /// Your sections, read from the layout the app saved.
    static func choices() -> [(key: String, title: String)] {
        SharedStore.loadState()?.widgetSectionChoices
            ?? SmartSection.allCases.map { (key: $0.rawValue, title: $0.title) }
    }

    static var firstGroupKey: String {
        choices().first { SmartSection(rawValue: $0.key) == nil }?.key ?? SmartSection.favorites.rawValue
    }
}

struct GoSectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Go Section"
    static var description = IntentDescription("Shows one of your Go sections on the Home Screen.")

    @Parameter(title: "Section", optionsProvider: GoSectionOptions())
    var section: String?

    init() {}
}

// MARK: - Timeline

extension GoSectionEntry {
    func sized(_ size: CGSize) -> GoSectionEntry {
        var copy = self
        if size.width > 0, size.height > 0 { copy.displaySize = size }
        return copy
    }
}

struct GoSectionEntry: TimelineEntry {
    let date: Date
    let content: SectionContent
    let theme: Theme
    let opensDirectly: Bool
    /// The widget's size on screen, so tiles can be laid out without a GeometryReader
    /// (links inside a GeometryReader weren't registered as tap targets).
    var displaySize: CGSize = CGSize(width: 338, height: 158)
}

struct GoSectionProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> GoSectionEntry {
        Self.sample()
    }

    func snapshot(for configuration: GoSectionIntent, in context: Context) async -> GoSectionEntry {
        entry(for: configuration, family: context.family)?.sized(context.displaySize) ?? Self.sample().sized(context.displaySize)
    }

    func timeline(for configuration: GoSectionIntent, in context: Context) async -> Timeline<GoSectionEntry> {
        let entry = entry(for: configuration, family: context.family)?.sized(context.displaySize) ?? Self.sample().sized(context.displaySize)
        return Self.timeline(with: entry)
    }

    /// The app refreshes widgets whenever your layout changes. This later refresh picks up
    /// launches made from other widgets in the meantime.
    static func timeline(with entry: GoSectionEntry) -> Timeline<GoSectionEntry> {
        Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60)))
    }

    private func entry(for configuration: GoSectionIntent, family: WidgetFamily) -> GoSectionEntry? {
        let key = configuration.section ?? GoSectionOptions.firstGroupKey
        return Self.entry(key: key, family: family)
    }

    static func entry(key: String, family: WidgetFamily) -> GoSectionEntry? {
        guard let state = SharedStore.currentState() else { return nil }
        let grid = Self.grid(family: family, theme: state.theme)
        let limit = grid.columns * grid.rows
        let content = state.sectionContent(for: key, limit: limit)
            // A group that was deleted falls back to Favorites.
            ?? state.sectionContent(for: SmartSection.favorites.rawValue, limit: limit)
            ?? SectionContent(key: key, title: "Go", symbol: nil, apps: [], totalCount: 0)
        return GoSectionEntry(date: Date(), content: content, theme: state.theme,
                              opensDirectly: state.theme.widgetOpensDirectly)
    }

    /// Tiles across and down for each widget size. Names under icons need room, so medium
    /// widgets show one row with names, two rows without.
    static func grid(family: WidgetFamily, theme: Theme) -> (columns: Int, rows: Int) {
        let namesUnder = theme.showLabels && !theme.labelsInside
        switch family {
        case .systemSmall: return (2, 2)
        // Two rows in medium too: a compact header and smaller names make room for them.
        case .systemMedium: return (4, 2)
        case .systemLarge: return (4, 4)
        default: return (4, 1)
        }
    }

    /// Shown in the widget gallery before Go has saved a layout.
    static func sample(key: String = SmartSection.favorites.rawValue) -> GoSectionEntry {
        let names = ["Messages", "Safari", "Music", "Maps", "Mail", "Photos", "Calendar", "Weather",
                     "Notes", "Spotify", "YouTube", "ChatGPT", "Claude", "Podcasts", "Files", "Settings"]
        let group = UUID()
        let apps = names.compactMap { AppCatalog.entry(named: $0)?.makeApp(groupID: group) }
        let smart = SmartSection(rawValue: key) ?? .favorites
        let content = SectionContent(key: smart.rawValue, title: smart.title,
                                     symbol: smart.symbol, apps: apps, totalCount: apps.count)
        return GoSectionEntry(date: Date(), content: content, theme: Theme(), opensDirectly: true)
    }
}

// MARK: - Widgets

/// A widget that always shows one automatic section, so it appears in the widget gallery
/// under its own name with nothing to set up.
struct FixedSectionProvider: TimelineProvider {
    let section: SmartSection

    func placeholder(in context: Context) -> GoSectionEntry {
        GoSectionProvider.sample(key: section.rawValue)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoSectionEntry) -> Void) {
        let entry = GoSectionProvider.entry(key: section.rawValue, family: context.family)?.sized(context.displaySize)
        // In the widget gallery, an empty Recently Used or Most Used would show nothing worth
        // adding, so preview it with example apps. On the Home Screen it shows your real apps.
        if context.isPreview, entry?.content.apps.isEmpty ?? true {
            completion(GoSectionProvider.sample(key: section.rawValue).sized(context.displaySize))
        } else {
            completion(entry ?? GoSectionProvider.sample(key: section.rawValue).sized(context.displaySize))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoSectionEntry>) -> Void) {
        let entry = GoSectionProvider.entry(key: section.rawValue, family: context.family)?.sized(context.displaySize)
            ?? GoSectionProvider.sample(key: section.rawValue).sized(context.displaySize)
        completion(GoSectionProvider.timeline(with: entry))
    }
}

private func fixedSectionWidget(_ section: SmartSection, kind: String, description: String) -> some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: FixedSectionProvider(section: section)) { entry in
        GoSectionWidgetView(entry: entry)
    }
    .configurationDisplayName(section.title)
    .description(description)
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    .contentMarginsDisabled()
}

struct FavoritesWidget: Widget {
    var body: some WidgetConfiguration {
        fixedSectionWidget(.favorites, kind: "GoFavorites", description: "The apps you've added to Favorites in Go.")
    }
}

struct RecentlyUsedWidget: Widget {
    var body: some WidgetConfiguration {
        fixedSectionWidget(.recent, kind: "GoRecentlyUsed", description: "The apps you opened most recently from Go.")
    }
}

struct MostUsedWidget: Widget {
    var body: some WidgetConfiguration {
        fixedSectionWidget(.mostUsed, kind: "GoMostUsed", description: "The apps you open most from Go.")
    }
}

/// Your groups (Essentials, AI, Tools…) or any section. Long-press › Edit Widget to choose.
/// The kind stays "GoSection" so widgets already on your Home Screen keep working.
struct GoSectionWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "GoSection", intent: GoSectionIntent.self, provider: GoSectionProvider()) { entry in
            GoSectionWidgetView(entry: entry)
        }
        .configurationDisplayName("Go Group")
        .description("One of your groups: Essentials, AI, Tools and more. Long-press › Edit Widget to choose.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // Go draws its own margins, so Tiles style can run edge to edge.
        .contentMarginsDisabled()
    }
}

struct GoSectionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: GoSectionEntry

    private var theme: Theme { entry.theme }

    /// Tiles style: tiles fill the whole widget with no gaps and no title.
    private var isTiles: Bool { theme.iconSpacing < 1 && renderingMode == .fullColor }

    private var textColor: Color {
        renderingMode == .fullColor ? WidgetPalette.textColor(for: theme) : .primary
    }

    var body: some View {
        let fullGrid = GoSectionProvider.grid(family: family, theme: theme)
        // Medium: a second row only when there are more apps than fit in one, so a short
        // section gets one row of bigger icons instead of an empty band.
        let grid = (family == .systemMedium && entry.content.apps.count <= fullGrid.columns)
            ? (columns: fullGrid.columns, rows: 1) : fullGrid
        VStack(alignment: .leading, spacing: Self.headerGap(family)) {
            if !isTiles && family != .systemSmall {
                header
            }
            if entry.content.apps.isEmpty {
                emptyState
            } else {
                tiles(in: tileArea, grid: grid)
                    // One row in a medium widget: center it so leftover space splits evenly.
                    .frame(maxHeight: .infinity, alignment: grid.rows == 1 && family == .systemMedium ? .center : .top)
            }
        }
        .padding(isTiles ? 0 : Self.padding(family))
        .containerBackground(for: .widget) {
            WidgetBackground(theme: theme)
        }
        // Tapping around the tiles opens the whole section in Go.
        .widgetURL(URL(string: "golauncher://section?key=\(entry.content.key)"))
    }

    // Medium widgets fit two rows of apps with names, so they use tighter spacing.
    static func padding(_ family: WidgetFamily) -> CGFloat { family == .systemMedium ? 12 : 14 }
    static func headerGap(_ family: WidgetFamily) -> CGFloat { family == .systemMedium ? 4 : 8 }
    static func nameHeight(_ family: WidgetFamily) -> CGFloat { family == .systemMedium ? 13 : 16 }

    /// Room left for tiles: the widget minus its padding and the header line.
    private var tileArea: CGSize {
        let padding: CGFloat = isTiles ? 0 : Self.padding(family)
        let headerHeight: CGFloat = (!isTiles && family != .systemSmall) ? 16 + Self.headerGap(family) : 0
        return CGSize(width: max(0, entry.displaySize.width - padding * 2),
                      height: max(0, entry.displaySize.height - padding * 2 - headerHeight))
    }

    private var header: some View {
        HStack(spacing: 5) {
            if let symbol = entry.content.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(entry.content.title)
                .font(.system(size: 13, weight: .semibold, design: theme.fontStyle.design))
                .lineLimit(1)
            Spacer(minLength: 4)
            if entry.content.totalCount > entry.content.apps.count {
                Text("\(entry.content.totalCount)")
                    .font(.system(size: 12, weight: .medium, design: theme.fontStyle.design))
                    .opacity(Theme.secondaryOpacity)
            }
        }
        .foregroundStyle(textColor)
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.content.totalCount > entry.content.apps.count
            ? "\(entry.content.title), \(entry.content.totalCount) apps"
            : entry.content.title)
        .accessibilityAddTraits(.isHeader)
    }

    private var emptyState: some View {
        let message = SmartSection(rawValue: entry.content.key)?.emptyText ?? "No apps in this group yet."
        return Text(message)
            .font(.system(size: 13, weight: .medium, design: theme.fontStyle.design))
            .foregroundStyle(textColor)
            .opacity(Theme.secondaryOpacity)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(isTiles ? 14 : 0)
    }

    private func tiles(in size: CGSize, grid: (columns: Int, rows: Int)) -> some View {
        let gap: CGFloat = isTiles ? 0 : max(CGFloat(theme.iconSpacing), 6)
        let namesUnder = theme.showLabels && !theme.labelsInside && !isTiles && family != .systemSmall
        let cell = CGSize(
            width: (size.width - gap * CGFloat(grid.columns - 1)) / CGFloat(grid.columns),
            height: (size.height - gap * CGFloat(grid.rows - 1)) / CGFloat(grid.rows)
        )
        let side = max(0, min(cell.width, cell.height - (namesUnder ? Self.nameHeight(family) : 0)))
        let apps = Array(entry.content.apps.prefix(grid.columns * grid.rows))
        let namesInside = theme.showLabels && (theme.labelsInside || isTiles)

        return VStack(alignment: .leading, spacing: gap) {
            ForEach(0..<grid.rows, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<grid.columns, id: \.self) { column in
                        let index = row * grid.columns + column
                        if index < apps.count {
                            tile(apps[index], cell: cell, side: side, namesUnder: namesUnder, namesInside: namesInside)
                        } else {
                            Color.clear.frame(width: cell.width, height: cell.height)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ app: LauncherApp, cell: CGSize, side: CGFloat, namesUnder: Bool, namesInside: Bool) -> some View {
        let label = VStack(spacing: family == .systemMedium ? 1 : 3) {
            WidgetTileView(
                app: app,
                theme: theme,
                size: isTiles ? cell : CGSize(width: side, height: side),
                nameInside: namesInside
            )
            if namesUnder {
                Text(app.name)
                    .font(.system(size: family == .systemMedium ? 10 : 11, weight: .medium, design: theme.fontStyle.design))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .frame(width: cell.width)
            }
        }
        .frame(width: cell.width, height: cell.height, alignment: .top)
        // One VoiceOver element per app ("Slack, button"), not the icon and name separately.
        // Names stay a fixed size: a widget's grid has no room to grow, and VoiceOver and
        // Large Content reading still give the full name.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(app.name)
        .accessibilityHint("Opens the app")

        if family == .systemSmall {
            // iOS treats a small widget as one tap target and ignores links inside it, so a
            // button that runs an intent is the only way to open one app from it.
            Button(intent: OpenAppDirectlyIntent(appID: app.id.uuidString)) { label }
                .buttonStyle(.plain)
        } else {
            // Medium and large: each tile links into Go, which opens the app at once and logs
            // the launch. One tap, with Go showing for a moment.
            Link(destination: URL(string: "golauncher://launch?id=\(app.id.uuidString)")!) { label }
        }
    }
}
