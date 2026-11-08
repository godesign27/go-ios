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

/// What cards and widgets are made of.
enum CardMaterial: String, Codable {
    /// Classic: Liquid Glass tinted with the background's hue.
    case tone
    /// Glass: light atmospheric frost that lets the wallpaper show through.
    case frosted
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
    // Background (default: Cloud, near-white with deep navy text). With a wallpaper, these
    // colors match it; they tint cards when Reduce Transparency is on.
    var backgroundTopHex = "#FBFCFE"
    var backgroundBottomHex = "#E4EAF4"
    /// Your own photo. Shown instead of `bundledWallpaper` when set.
    var wallpaperFilename: String? = nil
    /// One of Go's built-in wallpapers (an asset catalog image name).
    var bundledWallpaper: String? = nil
    var wallpaperDim: Double = 0
    var isDark = false

    // Icons
    var iconSize: Double = 62
    /// 0 = square, 0.5 = circle.
    var cornerFactor: Double = 0.24
    var columns = 4
    /// Gap between icons in points. 0 = tiles touch.
    var iconSpacing: Double = 6
    /// Icons stretch to fill their whole grid cell (bigger tap targets).
    var fillCells = false
    /// App names drawn inside the icon instead of underneath.
    var labelsInside = false
    var showLabels = true
    var labelColorHex = "#0A1633"
    var fontStyle: FontStyle = .rounded
    /// When on, every icon uses the same colors below (great for minimal/aesthetic looks).
    /// A see-through color (#RRGGBBAA) makes frosted glass tiles.
    var uniformIconColors = false
    var uniformIconHex = "#FFFFFF33"
    var uniformGlyphHex = "#FFFFFF"

    // Widgets (two side by side above everything else)
    var showWidgets = true
    var leftWidget: WidgetKind = .dateTime
    var rightWidget: WidgetKind = .weather

    // Layout & behavior
    var sectionLayout: SectionLayout = .rows
    var showGroupCards = true
    var cardMaterial: CardMaterial = .frosted
    var showClock = true
    var searchOnOpen = false
    /// Use each app's official App Store icon where one exists.
    var useOfficialIcons = true
    /// Shown in the greeting ("Hello, Tim"). iOS doesn't share the owner's name with apps.
    var userName = ""

    var labelColor: Color { Color(hex: labelColorHex) }

    /// Dark text on a light background (Cloud, Mint, Paper): cards use light glass.
    var hasDarkText: Bool { Color.luminance(ofHex: labelColorHex) < 0.5 }

    /// Secondary text and small controls (counts, dates, hints, chevrons): 85% of the label
    /// color, the top of the 75-85% range, so it keeps WCAG AA contrast (4.5:1) on cards.
    static let secondaryOpacity = 0.85

    /// Uniform icons in a see-through color render as frosted glass tiles.
    var usesGlassIcons: Bool {
        guard uniformIconColors else { return false }
        let hex = uniformIconHex.hasPrefix("#") ? String(uniformIconHex.dropFirst()) : uniformIconHex
        return hex.count == 8 && !hex.uppercased().hasSuffix("FF")
    }

    /// The background's own hue (midpoint of the gradient), used to tint cards and widgets
    /// so they read as a lighter layer of the same color: tone on tone.
    var toneHex: String {
        func rgb(_ hex: String) -> (Double, Double, Double) {
            var s = hex.trimmingCharacters(in: .whitespaces).uppercased()
            if s.hasPrefix("#") { s.removeFirst() }
            var v: UInt64 = 0
            Scanner(string: String(s.prefix(6))).scanHexInt64(&v)
            return (Double((v >> 16) & 0xFF), Double((v >> 8) & 0xFF), Double(v & 0xFF))
        }
        let a = rgb(backgroundTopHex), b = rgb(backgroundBottomHex)
        return String(format: "#%02X%02X%02X", Int((a.0 + b.0) / 2), Int((a.1 + b.1) / 2), Int((a.2 + b.2) / 2))
    }

    /// One corner radius for cards and widgets so they harmonize (square in Tiles style).
    var cardCornerRadius: CGFloat {
        24 * min(cornerFactor, 0.24) / 0.24
    }

    /// A Date & Time widget is on screen, so the header clock would repeat it.
    var showsDateWidget: Bool {
        showWidgets && (leftWidget == .dateTime || rightWidget == .dateTime)
    }

    /// The big clock in the top-left corner.
    var showsHeaderClock: Bool {
        showClock && !showsDateWidget
    }

    /// Space between rows: a little extra when names sit under the icons.
    var rowSpacing: Double {
        showLabels && !labelsInside ? iconSpacing + 6 : iconSpacing
    }

    var isTiles: Bool {
        iconSpacing == 0 && cornerFactor == 0 && fillCells && labelsInside && !showGroupCards
    }

    /// Standard spacing and rounded icons with names underneath, on cards.
    private var hasCardLayout: Bool {
        iconSpacing == 6 && cornerFactor == 0.24 && !fillCells && !labelsInside && showGroupCards
    }

    var isClassic: Bool {
        hasCardLayout && cardMaterial == .tone
    }

    var isGlass: Bool {
        hasCardLayout && cardMaterial == .frosted
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

    private mutating func applyCardLayout() {
        iconSpacing = 6
        cornerFactor = 0.24
        fillCells = false
        labelsInside = false
        showGroupCards = true
    }

    /// The standard iOS-like look: icons on cards tinted with the background's hue.
    mutating func applyClassic() {
        applyCardLayout()
        cardMaterial = .tone
    }

    /// Frosted glass cards over the wallpaper. Icons keep their own logos and colors.
    mutating func applyGlass() {
        applyCardLayout()
        cardMaterial = .frosted
        uniformIconColors = false
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

    /// A built-in wallpaper with frosted glass icons and white text.
    /// `dim` darkens the lighter wallpapers a little so white text stays readable.
    private static func wallpaper(_ name: String, top: String, bottom: String, dim: Double) -> ThemePreset {
        ThemePreset(name: name) { t in
            t.bundledWallpaper = "Wallpaper\(name)"; t.wallpaperFilename = nil; t.wallpaperDim = dim
            t.backgroundTopHex = top; t.backgroundBottomHex = bottom
            t.isDark = true; t.labelColorHex = "#FFFFFF"
            t.fontStyle = .rounded
            t.applyGlass()
        }
    }

    static let all: [ThemePreset] = [
        wallpaper("Twilight", top: "#0B1652", bottom: "#3A2D9C", dim: 0),
        wallpaper("Dusk", top: "#8E7FE0", bottom: "#3F63D6", dim: 0),
        wallpaper("Haze", top: "#9AA6EE", bottom: "#4C6BC4", dim: 0),
        wallpaper("Daybreak", top: "#D6BFE6", bottom: "#5B78D8", dim: 0),
        wallpaper("Blush", top: "#E3A9C0", bottom: "#A27DBF", dim: 0),
        // High contrast: near-black navy with crisp white text.
        ThemePreset(name: "Onyx") { t in
            t.bundledWallpaper = nil; t.wallpaperFilename = nil; t.wallpaperDim = 0
            t.backgroundTopHex = "#0A1022"; t.backgroundBottomHex = "#03050B"
            t.isDark = true; t.labelColorHex = "#FFFFFF"
            t.fontStyle = .rounded
            t.applyGlass()
        },
        // High contrast: cloud white with deep navy text.
        ThemePreset(name: "Cloud") { t in
            t.bundledWallpaper = nil; t.wallpaperFilename = nil; t.wallpaperDim = 0
            t.backgroundTopHex = "#FBFCFE"; t.backgroundBottomHex = "#E4EAF4"
            t.isDark = false; t.labelColorHex = "#0A1633"
            t.fontStyle = .rounded
            t.applyGlass()
        },
        ThemePreset(name: "Midnight") { t in
            t.bundledWallpaper = nil
            t.backgroundTopHex = "#312E81"; t.backgroundBottomHex = "#0F172A"
            t.isDark = true; t.labelColorHex = "#FFFFFF"
            t.uniformIconColors = false; t.fontStyle = .rounded; t.cornerFactor = 0.24
        },
        ThemePreset(name: "Sunset") { t in
            t.bundledWallpaper = nil
            t.backgroundTopHex = "#F97316"; t.backgroundBottomHex = "#BE185D"
            t.isDark = true; t.labelColorHex = "#FFFFFF"
            t.uniformIconColors = true; t.uniformIconHex = "#FFFFFF40"; t.uniformGlyphHex = "#FFFFFF"
            t.fontStyle = .rounded; t.cornerFactor = 0.5
        },
        ThemePreset(name: "Ocean") { t in
            t.bundledWallpaper = nil
            t.backgroundTopHex = "#0EA5E9"; t.backgroundBottomHex = "#1E3A8A"
            t.isDark = true; t.labelColorHex = "#FFFFFF"
            t.uniformIconColors = false; t.fontStyle = .standard; t.cornerFactor = 0.24
        },
        ThemePreset(name: "Mint") { t in
            t.bundledWallpaper = nil
            t.backgroundTopHex = "#ECFDF5"; t.backgroundBottomHex = "#A7F3D0"
            t.isDark = false; t.labelColorHex = "#064E3B"
            t.uniformIconColors = true; t.uniformIconHex = "#FFFFFF"; t.uniformGlyphHex = "#047857"
            t.fontStyle = .rounded; t.cornerFactor = 0.3
        },
        ThemePreset(name: "Paper") { t in
            t.bundledWallpaper = nil
            t.backgroundTopHex = "#F5F0E6"; t.backgroundBottomHex = "#E7DCC8"
            t.isDark = false; t.labelColorHex = "#3B3024"
            t.uniformIconColors = true; t.uniformIconHex = "#FFFDF8"; t.uniformGlyphHex = "#3B3024"
            t.fontStyle = .serif; t.cornerFactor = 0.18
        },
        ThemePreset(name: "Mono") { t in
            t.bundledWallpaper = nil
            t.backgroundTopHex = "#111111"; t.backgroundBottomHex = "#000000"
            t.isDark = true; t.labelColorHex = "#E5E5E5"
            t.uniformIconColors = true; t.uniformIconHex = "#1F1F1F"; t.uniformGlyphHex = "#FFFFFF"
            t.fontStyle = .mono; t.cornerFactor = 0.12
        },
    ]
}

// MARK: - Tolerant loading (missing settings fall back to their defaults)

extension Theme {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Theme()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        backgroundTopHex = value(.backgroundTopHex, d.backgroundTopHex)
        backgroundBottomHex = value(.backgroundBottomHex, d.backgroundBottomHex)
        wallpaperFilename = (try? c.decodeIfPresent(String.self, forKey: .wallpaperFilename)) ?? nil
        // Layouts saved before built-in wallpapers keep their gradient (no Twilight default).
        bundledWallpaper = (try? c.decodeIfPresent(String.self, forKey: .bundledWallpaper)) ?? nil
        wallpaperDim = value(.wallpaperDim, d.wallpaperDim)
        isDark = value(.isDark, d.isDark)
        iconSize = value(.iconSize, d.iconSize)
        cornerFactor = value(.cornerFactor, d.cornerFactor)
        columns = value(.columns, d.columns)
        iconSpacing = value(.iconSpacing, d.iconSpacing)
        fillCells = value(.fillCells, d.fillCells)
        labelsInside = value(.labelsInside, d.labelsInside)
        showLabels = value(.showLabels, d.showLabels)
        labelColorHex = value(.labelColorHex, d.labelColorHex)
        fontStyle = value(.fontStyle, d.fontStyle)
        uniformIconColors = value(.uniformIconColors, d.uniformIconColors)
        uniformIconHex = value(.uniformIconHex, d.uniformIconHex)
        uniformGlyphHex = value(.uniformGlyphHex, d.uniformGlyphHex)
        showWidgets = value(.showWidgets, d.showWidgets)
        leftWidget = value(.leftWidget, d.leftWidget)
        rightWidget = value(.rightWidget, d.rightWidget)
        sectionLayout = value(.sectionLayout, d.sectionLayout)
        showGroupCards = value(.showGroupCards, d.showGroupCards)
        // Layouts saved before the Glass style keep the Classic cards they had.
        cardMaterial = value(.cardMaterial, CardMaterial.tone)
        showClock = value(.showClock, d.showClock)
        searchOnOpen = value(.searchOnOpen, d.searchOnOpen)
        useOfficialIcons = value(.useOfficialIcons, d.useOfficialIcons)
        userName = value(.userName, d.userName)
    }
}
