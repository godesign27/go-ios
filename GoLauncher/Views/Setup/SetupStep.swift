import Foundation

/// The steps of "Set Up My GO Home Screen", in order. Saved by raw value, so never rename one.
enum SetupStep: String, CaseIterable, Identifiable, Hashable {
    case theme, wallpaper, preparePage, addWidgets, chooseGroups, addSearch
    // Optional: listed separately, never needed to finish setup.
    case hidePages, logLaunches

    var id: String { rawValue }

    static let required: [SetupStep] = [.theme, .wallpaper, .preparePage, .addWidgets, .chooseGroups, .addSearch]
    static let optional: [SetupStep] = [.hidePages, .logLaunches]

    var isOptional: Bool { Self.optional.contains(self) }

    var title: String {
        switch self {
        case .theme: return "Choose your look"
        case .wallpaper: return "Save the matching wallpaper"
        case .preparePage: return "Make room on a Home Screen page"
        case .addWidgets: return "Add GO widgets"
        case .chooseGroups: return "Pick a group for each widget"
        case .addSearch: return "Add GO Search"
        case .hidePages: return "Hide other Home Screen pages"
        case .logLaunches: return "Count apps opened from Apple's Home Screen"
        }
    }

    var summary: String {
        switch self {
        case .theme: return "A style and background for GO and its widgets."
        case .wallpaper: return "Save GO's background to Photos, then set it as your wallpaper."
        case .preparePage: return "Clear space for GO's widgets. Nothing is deleted."
        case .addWidgets: return "Favorites, Recently Used, Most Used and your groups."
        case .chooseGroups: return "Show Essentials, AI, Tools or any group you made."
        case .addSearch: return "Open GO search from Control Center, the Lock Screen or the Action Button."
        case .hidePages: return "Optional. Keep only your GO page; you can show the others again anytime."
        case .logLaunches: return "Optional. A Shortcuts automation per app, so Recently Used includes them."
        }
    }

    var symbol: String {
        switch self {
        case .theme: return "paintpalette"
        case .wallpaper: return "photo.on.rectangle"
        case .preparePage: return "square.dashed"
        case .addWidgets: return "square.grid.2x2"
        case .chooseGroups: return "slider.horizontal.3"
        case .addSearch: return "magnifyingglass"
        case .hidePages: return "eye.slash"
        case .logLaunches: return "clock.arrow.circlepath"
        }
    }
}
