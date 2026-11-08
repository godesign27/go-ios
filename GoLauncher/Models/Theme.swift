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
    var showLabels = true
    var labelColorHex = "#FFFFFF"
    var fontStyle: FontStyle = .rounded
    /// When on, every icon uses the same colors below (great for minimal/aesthetic looks).
    var uniformIconColors = false
    var uniformIconHex = "#FFFFFF33"
    var uniformGlyphHex = "#FFFFFF"

    // Layout & behavior
    var showGroupCards = true
    var showClock = true
    var searchOnOpen = false

    var labelColor: Color { Color(hex: labelColorHex) }
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
