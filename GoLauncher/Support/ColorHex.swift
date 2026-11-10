import SwiftUI
import UIKit

extension Color {
    /// Accepts "#RRGGBB" or "#RRGGBBAA".
    init(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if string.hasPrefix("#") { string.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: string).scanHexInt64(&value)

        let r, g, b, a: Double
        if string.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ x: CGFloat) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }
        if a < 0.999 {
            return String(format: "#%02X%02X%02X%02X", byte(r), byte(g), byte(b), byte(a))
        }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }
}

/// Swatches offered in the icon editor.
enum Palette {
    static let swatches: [String] = [
        "#EF4444", "#F97316", "#F59E0B", "#EAB308", "#84CC16", "#22C55E",
        "#10B981", "#14B8A6", "#06B6D4", "#0EA5E9", "#3B82F6", "#6366F1",
        "#7C6AF4", "#A855F7", "#D946EF", "#EC4899", "#F43F5E", "#78716C",
        "#334155", "#111827", "#FFFFFF", "#F5F0E6",
    ]
}

extension Color {
    /// Relative luminance (0 = black, 1 = white) of a hex color, per WCAG.
    static func luminance(ofHex hex: String) -> Double {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if string.hasPrefix("#") { string.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: String(string.prefix(6))).scanHexInt64(&value)
        func channel(_ v: UInt64) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((value >> 16) & 0xFF)
            + 0.7152 * channel((value >> 8) & 0xFF)
            + 0.0722 * channel(value & 0xFF)
    }

    /// Near-black or near-white, whichever reads better on the given background.
    static func readableText(onHex hex: String) -> Color {
        // Contrast vs white is (1.05)/(L+0.05); vs near-black is (L+0.05)/0.05. Pick the higher.
        let l = luminance(ofHex: hex)
        return (l + 0.05) / 0.06 > 1.05 / (l + 0.05) ? Color(hex: "#1C1C1E") : Color(hex: "#FAFAFA")
    }
}
