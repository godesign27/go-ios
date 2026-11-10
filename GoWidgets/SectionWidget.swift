import AppIntents
import SwiftUI
import WidgetKit

// A Home Screen widget that shows one Go section (Favorites, Recently Used, a group…),
// styled with your Go theme. Long-press › Edit Widget to choose the section.

// MARK: - Configuration

struct GoSectionEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Go Section"
    static var defaultQuery = GoSectionQuery()

    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    static let favorites = GoSectionEntity(id: SmartSection.favorites.rawValue, title: SmartSection.favorites.title)
}

struct GoSectionQuery: EntityQuery {
    func entities(for identifiers: [GoSectionEntity.ID]) async throws -> [GoSectionEntity] {
        Self.all().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [GoSectionEntity] {
        Self.all()
    }

    func defaultResult() async -> GoSectionEntity? {
        .favorites
    }

    /// Your sections, read from the layout the app saved.
    static func all() -> [GoSectionEntity] {
        let choices = SharedStore.loadState()?.widgetSectionChoices
            ?? SmartSection.allCases.map { (key: $0.rawValue, title: $0.title) }
        return choices.map { GoSectionEntity(id: $0.key, title: $0.title) }
    }
}

struct GoSectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Go Section"
    static var description = IntentDescription("Shows one of your Go sections on the Home Screen.")

    @Parameter(title: "Section")
    var section: GoSectionEntity?

    init() {}

    init(section: GoSectionEntity) {
        self.section = section
    }
}

// MARK: - Timeline

struct GoSectionEntry: TimelineEntry {
    let date: Date
    let content: SectionContent
    let theme: Theme
    let opensDirectly: Bool
}

struct GoSectionProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> GoSectionEntry {
        Self.sample()
    }

    func snapshot(for configuration: GoSectionIntent, in context: Context) async -> GoSectionEntry {
        entry(for: configuration, family: context.family) ?? Self.sample()
    }

    func timeline(for configuration: GoSectionIntent, in context: Context) async -> Timeline<GoSectionEntry> {
        let entry = entry(for: configuration, family: context.family) ?? Self.sample()
        // The app refreshes widgets whenever your layout changes. This later refresh picks up
        // launches made from other widgets in the meantime.
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60)))
    }

    private func entry(for configuration: GoSectionIntent, family: WidgetFamily) -> GoSectionEntry? {
        guard let state = SharedStore.currentState() else { return nil }
        let grid = Self.grid(family: family, theme: state.theme)
        let limit = grid.columns * grid.rows
        let key = configuration.section?.id ?? SmartSection.favorites.rawValue
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
        case .systemMedium: return (4, namesUnder ? 1 : 2)
        case .systemLarge: return (4, 4)
        default: return (4, 1)
        }
    }

    /// Shown in the widget gallery before Go has saved a layout.
    static func sample() -> GoSectionEntry {
        let names = ["Messages", "Safari", "Music", "Maps", "Mail", "Photos", "Calendar", "Weather",
                     "Notes", "Spotify", "YouTube", "ChatGPT", "Claude", "Podcasts", "Files", "Settings"]
        let group = UUID()
        let apps = names.compactMap { AppCatalog.entry(named: $0)?.makeApp(groupID: group) }
        let content = SectionContent(key: SmartSection.favorites.rawValue, title: SmartSection.favorites.title,
                                     symbol: SmartSection.favorites.symbol, apps: apps, totalCount: apps.count)
        return GoSectionEntry(date: Date(), content: content, theme: Theme(), opensDirectly: true)
    }
}

// MARK: - Widget

struct GoSectionWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "GoSection", intent: GoSectionIntent.self, provider: GoSectionProvider()) { entry in
            GoSectionWidgetView(entry: entry)
        }
        .configurationDisplayName("Go Section")
        .description("Your Go apps, styled like Go. Long-press › Edit Widget to pick the section.")
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
        let grid = GoSectionProvider.grid(family: family, theme: theme)
        VStack(alignment: .leading, spacing: 8) {
            if !isTiles && family != .systemSmall {
                header
            }
            if entry.content.apps.isEmpty {
                emptyState
            } else {
                GeometryReader { geo in
                    tiles(in: geo.size, grid: grid)
                }
            }
        }
        .padding(isTiles ? 0 : 14)
        .containerBackground(for: .widget) {
            WidgetBackground(theme: theme)
        }
        // Tapping around the tiles opens the whole section in Go.
        .widgetURL(URL(string: "golauncher://section?key=\(entry.content.key)"))
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
        let side = max(0, min(cell.width, cell.height - (namesUnder ? 16 : 0)))
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
        let label = VStack(spacing: 3) {
            WidgetTileView(
                app: app,
                theme: theme,
                size: isTiles ? cell : CGSize(width: side, height: side),
                nameInside: namesInside
            )
            if namesUnder {
                Text(app.name)
                    .font(.system(size: 11, weight: .medium, design: theme.fontStyle.design))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .frame(width: cell.width)
            }
        }
        .frame(width: cell.width, height: cell.height, alignment: .top)
        .accessibilityLabel(app.name)

        if entry.opensDirectly {
            Button(intent: OpenAppDirectlyIntent(appID: app.id.uuidString)) { label }
                .buttonStyle(.plain)
        } else {
            Button(intent: OpenAppThroughGoIntent(appID: app.id.uuidString)) { label }
                .buttonStyle(.plain)
        }
    }
}
