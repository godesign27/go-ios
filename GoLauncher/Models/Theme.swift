import SwiftUI

enum FontStyle: String, Codable, CaseIterable, Identifiable {
    case standard, rounded, serif, mono

    var id: String { rawValue }

    var design: Font.Design {
        switch self {
        case .standard: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .mono: return .monospaced
        }
    }

    var label: String {
        switch self {
        case .standard: return "Standard"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .mono: return "Mono"
        }
    }
}

/// Go's built-in widgets for the top row. (iOS doesn't let apps show other apps' widgets.)
enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case dateTime, weather, favorites

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateTime: return "Date & Time"
        case .weather: return "Weather"
        case .favorites: return "Favorite Apps"
        }
    }

    var symbol: String {
        switch self {
        case .dateTime: return "calendar.badge.clock"
        case .weather: return "cloud.sun.fill"
        case .favorites: return "square.grid.2x2.fill"
        }
    }
}

/// How each section shows its apps.
enum SectionLayout: String, Codable, CaseIterable, Identifiable {
    /// One row (two for Recently Used) you swipe left for more, plus View All.
    case rows
    /// Every app visible in a wrapping grid.
    case grid

    var id: String { rawValue }
    var title: String { self == .rows ? "Swipe Rows" : "Full Grid" }
}

struct Theme: Codable, Hashable {
    // Background
    var backgroundTopHex = "#312E81"
    var backgroundBottomHex = "#0F172A"
    var wallpaperFilename: String? = nil
    var wallpaperDim: Double = 0.2
    var isDark = true

    // Icons
    var iconSize: Double = 62
    /// 0 = square, 0.5 = circle.
    var cornerFactor: Double = 0.24
    var columns = 4
    /// Gap between icons in points. 0 = tiles touch.
    var iconSpacing: Double = 10
    /// Icons stretch to fill their whole grid cell (bigger tap targets).
    var fillCells = false
    /// App names drawn inside the icon instead of underneath.
    var labelsInside = false
    var showLabels = true
    var labelColorHex = "#FFFFFF"
    var fontStyle: FontStyle = .rounded
    /// When on, every icon uses the same colors below (great for minimal/aesthetic looks).
    var uniformIconColors = false
    var uniformIconHex = "#FFFFFF33"
    var uniformGlyphHex = "#FFFFFF"

    // Widgets (two side by side above everything else)
    var showWidgets = false
    var leftWidget: WidgetKind = .dateTime
    var rightWidget: WidgetKind = .weather

    // Layout & behavior
    var sectionLayout: SectionLayout = .rows
    var showGroupCards = true
    var showClock = true
    var searchOnOpen = false

    var labelColor: Color { Color(hex: labelColorHex) }

    /// Space between rows: a little extra when names sit under the icons.
    var rowSpacing: Double {
        showLabels && !labelsInside ? iconSpacing + 6 : iconSpacing
    }

    var isTiles: Bool {
        iconSpacing == 0 && cornerFactor == 0 && fillCells && labelsInside && !showGroupCards
    }

    var isClassic: Bool {
        iconSpacing == 10 && cornerFactor == 0.24 && !fillCells && !labelsInside && showGroupCards
    }

    /// Edge-to-edge square tiles: no gaps, square corners, each icon fills its cell, names inside.
    mutating func applyTiles() {
        iconSpacing = 0
        cornerFactor = 0
        fillCells = true
        labelsInside = true
        showLabels = true
        showGroupCards = false
    }

    /// The standard iOS-like look.
    mutating func applyClassic() {
        iconSpacing = 10
        cornerFactor = 0.24
        fillCells = false
        labelsInside = false
        showGroupCards = true
    }
}

struct ThemePreset: Identifiable {
    let name: String
    let apply: (inout Theme) -> Void

    var id: String { name }

    var preview: Theme {
        var theme = Theme()
        apply(&theme)
        return theme
    }

    static let all: [ThemePreset] = [
        ThemePreset(name: "Midnight") { t in
            t.backgroundTopHex = "#312E81"; t.backgroundBottomHex = "#0F172A"
            t.isDark = true; t.labelColorHex = "#FFFFFF"
            t.uniformIconColors = false; t.fontStyle = .rounded; t.cornerFactor = 0.24
        },
        ThemePreset(name: "Sunset") { t in
            t.backgroundTopHex = "#F97316"; t.backgroundBottomHex = "#BE185D"
            t.isDark = true; t.labelColorHex = "#FFFFFF"
            t.uniformIconColors = true; t.uniformIconHex = "#FFFFFF40"; t.uniformGlyphHex = "#FFFFFF"
            t.fontStyle = .rounded; t.cornerFactor = 0.5
        },
        ThemePreset(name: "Ocean") { t in
            t.backgroundTopHex = "#0EA5E9"; t.backgroundBottomHex = "#1E3A8A"
            t.isDark = true; t.labelColorHex = "#FFFFFF"
            t.uniformIconColors = false; t.fontStyle = .standard; t.cornerFactor = 0.24
        },
        ThemePreset(name: "Mint") { t in
            t.backgroundTopHex = "#ECFDF5"; t.backgroundBottomHex = "#A7F3D0"
            t.isDark = false; t.labelColorHex = "#064E3B"
            t.uniformIconColors = true; t.uniformIconHex = "#FFFFFF"; t.uniformGlyphHex = "#047857"
            t.fontStyle = .rounded; t.cornerFactor = 0.3
        },
        ThemePreset(name: "Paper") { t in
            t.backgroundTopHex = "#F5F0E6"; t.backgroundBottomHex = "#E7DCC8"
            t.isDark = false; t.labelColorHex = "#3B3024"
            t.uniformIconColors = true; t.uniformIconHex = "#FFFDF8"; t.uniformGlyphHex = "#3B3024"
            t.fontStyle = .serif; t.cornerFactor = 0.18
        },
        ThemePreset(name: "Mono") { t in
            t.backgroundTopHex = "#111111"; t.backgroundBottomHex = "#000000"
            t.isDark = true; t.labelColorHex = "#E5E5E5"
            t.uniformIconColors = true; t.uniformIconHex = "#1F1F1F"; t.uniformGlyphHex = "#FFFFFF"
            t.fontStyle = .mono; t.cornerFactor = 0.12
        },
    ]
}
