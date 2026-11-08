import Foundation

/// What is drawn inside an icon tile.
enum IconGlyph: Codable, Hashable {
    /// An SF Symbol name, e.g. "music.note".
    case symbol(String)
    /// A single emoji.
    case emoji(String)
    /// A photo from your library, stored as a file name in the app's Images folder.
    case image(String)
}

/// How tapping an icon opens the real app.
enum LaunchTarget: Codable, Hashable {
    /// Any URL: an app's URL scheme ("spotify://"), a website ("https://…"), "tel:", etc.
    case url(String)
    /// The name of a Shortcut to run. Works for *any* app: make a Shortcut
    /// with the "Open App" action and put its name here.
    case shortcut(String)

    var resolvedURL: URL? {
        switch self {
        case .url(let string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return URL(string: trimmed)
        case .shortcut(let name):
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            var components = URLComponents()
            components.scheme = "shortcuts"
            components.host = "run-shortcut"
            components.queryItems = [URLQueryItem(name: "name", value: trimmed)]
            return components.url
        }
    }
}

struct LauncherApp: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var launch: LaunchTarget
    var glyph: IconGlyph
    var colorHex: String
    /// When set, the tile background is a gradient from `colorHex` to this color.
    var secondaryColorHex: String?
    var glyphColorHex: String = "#FFFFFF"
    var groupID: UUID
    /// Flagged by you to show in the "Needs Attention" section. Cleared when you open the app.
    var needsAttention = false
    /// Shown in the bottom dock when the dock is turned on.
    var isDocked = false
    /// Extra words that should match in search (e.g. "chat" for Messages).
    var keywords: String = ""
    var launchCount = 0
    var lastLaunched: Date?

    static func blank(groupID: UUID) -> LauncherApp {
        LauncherApp(
            name: "",
            launch: .url(""),
            glyph: .symbol("app.fill"),
            colorHex: "#7C6AF4",
            groupID: groupID
        )
    }
}

struct AppGroup: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var isCollapsed = false
}

/// Everything that gets saved to disk.
struct LauncherState: Codable {
    var groups: [AppGroup]
    /// Order in this array is the display order within each group.
    var apps: [LauncherApp]
    var theme: Theme
    /// Keys of collapsed automatic sections ("recent", "mostUsed", "attention").
    var collapsedSections: [String] = []
    /// Display order of every section: automatic section keys and group IDs.
    var sectionOrder: [String] = []
    /// Automatic sections the user turned off.
    var hiddenSections: [String] = []
    var showDock = false
    /// Newest first.
    var recentSearches: [String] = []
    /// Up to 4 apps shown in the Favorite Apps widget.
    var favoriteAppIDs: [UUID] = []
}

/// Sections Go fills in by itself.
enum SmartSection: String, CaseIterable {
    case recent, mostUsed, attention

    var title: String {
        switch self {
        case .recent: return "Recently Used"
        case .mostUsed: return "Most Used"
        case .attention: return "Needs Attention"
        }
    }

    var symbol: String {
        switch self {
        case .recent: return "clock.arrow.circlepath"
        case .mostUsed: return "flame.fill"
        case .attention: return "flag.fill"
        }
    }

    var emptyText: String {
        switch self {
        case .recent, .mostUsed: return "Apps you open from Go will show up here."
        case .attention: return "Long-press an app and choose Needs Attention to flag it here."
        }
    }
}

/// One entry in the home screen's section list.
enum HomeSection: Identifiable {
    case smart(SmartSection)
    case group(AppGroup)

    var key: String {
        switch self {
        case .smart(let kind): return kind.rawValue
        case .group(let group): return group.id.uuidString
        }
    }

    var id: String { key }
}
