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
