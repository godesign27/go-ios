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
    /// The app's App Store bundle ID, used to find its official icon.
    var bundleID: String?
    /// Go already tried to fetch this app's official icon (found or not).
    var iconLookupDone = false
    /// The icon is the official App Store icon (downloaded into Go).
    var usesOfficialIcon = false
    /// The symbol/emoji icon to restore if official icons are turned off.
    var fallbackGlyph: IconGlyph?

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
    /// Your favorites, in order. The Favorites section shows them all; the widget shows the first four.
    var favoriteAppIDs: [UUID] = []
    /// Catalog apps Go has already put in your layout (or found there), so one you delete isn't added back.
    var knownCatalogApps: [String] = []
}

/// Sections Go fills in by itself.
enum SmartSection: String, CaseIterable {
    case recent, favorites, mostUsed, attention

    var title: String {
        switch self {
        case .recent: return "Recently Used"
        case .favorites: return "Favorites"
        case .mostUsed: return "Most Used"
        case .attention: return "Needs Attention"
        }
    }

    var symbol: String {
        switch self {
        case .recent: return "clock.arrow.circlepath"
        case .favorites: return "star.fill"
        case .mostUsed: return "flame.fill"
        case .attention: return "flag.fill"
        }
    }

    var emptyText: String {
        switch self {
        case .recent, .mostUsed: return "Apps you open from Go will show up here."
        case .favorites: return "Long-press an app and choose Add to Favorites."
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

// MARK: - Tolerant loading
// Saved layouts from older versions of Go are missing newer fields. These decoders fill in
// defaults instead of failing, so an update never resets someone's home screen.

extension LauncherApp {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        launch = try c.decode(LaunchTarget.self, forKey: .launch)
        glyph = try c.decode(IconGlyph.self, forKey: .glyph)
        colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#7C6AF4"
        secondaryColorHex = try c.decodeIfPresent(String.self, forKey: .secondaryColorHex)
        glyphColorHex = try c.decodeIfPresent(String.self, forKey: .glyphColorHex) ?? "#FFFFFF"
        groupID = try c.decode(UUID.self, forKey: .groupID)
        needsAttention = try c.decodeIfPresent(Bool.self, forKey: .needsAttention) ?? false
        isDocked = try c.decodeIfPresent(Bool.self, forKey: .isDocked) ?? false
        keywords = try c.decodeIfPresent(String.self, forKey: .keywords) ?? ""
        launchCount = try c.decodeIfPresent(Int.self, forKey: .launchCount) ?? 0
        lastLaunched = try c.decodeIfPresent(Date.self, forKey: .lastLaunched)
        bundleID = try c.decodeIfPresent(String.self, forKey: .bundleID)
        iconLookupDone = try c.decodeIfPresent(Bool.self, forKey: .iconLookupDone) ?? false
        usesOfficialIcon = try c.decodeIfPresent(Bool.self, forKey: .usesOfficialIcon) ?? false
        fallbackGlyph = try c.decodeIfPresent(IconGlyph.self, forKey: .fallbackGlyph)
    }
}

extension LauncherState {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        groups = try c.decode([AppGroup].self, forKey: .groups)
        apps = try c.decode([LauncherApp].self, forKey: .apps)
        theme = try c.decodeIfPresent(Theme.self, forKey: .theme) ?? Theme()
        collapsedSections = try c.decodeIfPresent([String].self, forKey: .collapsedSections) ?? []
        sectionOrder = try c.decodeIfPresent([String].self, forKey: .sectionOrder) ?? []
        hiddenSections = try c.decodeIfPresent([String].self, forKey: .hiddenSections) ?? []
        showDock = try c.decodeIfPresent(Bool.self, forKey: .showDock) ?? false
        recentSearches = try c.decodeIfPresent([String].self, forKey: .recentSearches) ?? []
        favoriteAppIDs = try c.decodeIfPresent([UUID].self, forKey: .favoriteAppIDs) ?? []
        knownCatalogApps = try c.decodeIfPresent([String].self, forKey: .knownCatalogApps) ?? []
    }
}
