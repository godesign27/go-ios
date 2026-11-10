import SwiftUI
import UIKit

/// How Go keeps white text readable (WCAG AA, 4.5:1) without dulling the wallpaper.
///
/// Instead of dimming the whole screen with black, Go tints only what sits behind text, in a
/// deep, saturated version of the wallpaper's own color: the glass cards, and a soft fade at
/// the top of the screen behind the greeting. The wallpaper itself stays at full color.
struct Legibility: Equatable {
    /// Rich, deep version of the wallpaper's hue (indigo on Twilight, plum on Blush).
    var tint: Color = .clear
    /// The same depth one step along the color wheel, so cards shift gently from `tint` to this.
    var tint2: Color = .clear
    /// Opacity of `tint` inside cards.
    var cardTint: Double = 0
    /// Opacity of `tint` at the top edge of the screen, fading out by a third of the way down.
    var headerScrim: Double = 0
    /// Opacity of `tint` over the whole wallpaper when containers are off and text sits
    /// right on the background.
    var openScrim: Double = 0

    static let none = Legibility()
}

private struct LegibilityKey: EnvironmentKey {
    static let defaultValue = Legibility.none
}

extension EnvironmentValues {
    var legibility: Legibility {
        get { self[LegibilityKey.self] }
        set { self[LegibilityKey.self] = newValue }
    }
}

/// Measures the background and works out the `Legibility` tints.
/// Targets were tuned by measuring rendered screenshots of every preset.
enum ContrastGuard {
    /// Highest luminance the brightest 10% of a card's background may keep under its tint
    /// (the card's own white frost adds a little on top).
    static let cardTarget = 0.06
    /// Same, for the greeting area at the top of the screen (no frost there).
    static let headerTarget = 0.08

    typealias RGB = (Double, Double, Double)

    private static var cache: [String: Legibility] = [:]

    static func legibility(theme: Theme, image: UIImage?, imageKey: String?) -> Legibility {
        // Dark text on a light background is a different case; those themes are already light.
        guard Color.luminance(ofHex: theme.labelColorHex) > 0.5 else { return .none }
        let key = imageKey ?? "gradient:\(theme.backgroundTopHex)\(theme.backgroundBottomHex)"
        if let cached = cache[key] { return cached }

        let stats: (average: RGB, brightest: RGB, brightestTop: RGB)
        if let image {
            stats = measure(image)
        } else {
            let top = rgb(ofHex: theme.backgroundTopHex), bottom = rgb(ofHex: theme.backgroundBottomHex)
            let brightest = luminance(top) > luminance(bottom) ? top : bottom
            stats = (((top.0 + bottom.0) / 2, (top.1 + bottom.1) / 2, (top.2 + bottom.2) / 2), brightest, top)
        }

        let deep = deepTone(of: stats.average)
        let deep2 = deepTone(of: stats.average, hueShift: 0.07)
        // Enough of the brighter of the two tints to reach the target everywhere on the card.
        let card = max(tintNeeded(over: stats.brightest, tint: deep, target: cardTarget),
                       tintNeeded(over: stats.brightest, tint: deep2, target: cardTarget))
        let result = Legibility(
            tint: Color(.sRGB, red: deep.0, green: deep.1, blue: deep.2),
            tint2: Color(.sRGB, red: deep2.0, green: deep2.1, blue: deep2.2),
            cardTint: card,
            headerScrim: tintNeeded(over: stats.brightestTop, tint: deep, target: headerTarget),
            openScrim: tintNeeded(over: stats.brightest, tint: deep, target: headerTarget)
        )
        cache[key] = result
        return result
    }

    // MARK: - Math

    /// A rich, jewel-toned version of a color: same hue (optionally shifted), strongly
    /// saturated, fairly dark. Saturated rather than gray keeps the glass lively.
    static func deepTone(of c: RGB, hueShift: CGFloat = 0) -> RGB {
        let ui = UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let hue = (h + hueShift).truncatingRemainder(dividingBy: 1)
        let deep = UIColor(hue: hue, saturation: min(0.95, max(0.8, s * 1.8)), brightness: 0.34, alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0
        deep.getRed(&r, green: &g, blue: &bl, alpha: &a)
        return (Double(r), Double(g), Double(bl))
    }

    /// Least opacity of `tint` over `color` that brings it down to `target` luminance.
    static func tintNeeded(over color: RGB, tint: RGB, target: Double) -> Double {
        var a = 0.0
        while a < 0.95 {
            let mixed = (color.0 + (tint.0 - color.0) * a, color.1 + (tint.1 - color.1) * a, color.2 + (tint.2 - color.2) * a)
            if luminance(mixed) <= target { return a }
            a += 0.01
        }
        return 0.95
    }

    /// WCAG relative luminance of an sRGB color with 0...1 channels.
    static func luminance(_ c: RGB) -> Double {
        func linear(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(c.0) + 0.7152 * linear(c.1) + 0.0722 * linear(c.2)
    }

    private static func rgb(ofHex hex: String) -> RGB {
        var s = hex.trimmingCharacters(in: .whitespaces).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: String(s.prefix(6))).scanHexInt64(&v)
        return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    /// Average color, brightest 10% overall, and brightest 10% of the top third, from a small copy.
    private static func measure(_ image: UIImage) -> (average: RGB, brightest: RGB, brightestTop: RGB) {
        let width = 24, height = 48
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard
            let cgImage = image.cgImage,
            let context = CGContext(
                data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return ((0.5, 0.5, 0.5), (1, 1, 1), (1, 1, 1)) }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // The buffer's first row is the top of the image.
        var all: [RGB] = [], top: [RGB] = []
        for row in 0..<height {
            for col in 0..<width {
                let i = (row * width + col) * 4
                let c: RGB = (Double(pixels[i]) / 255, Double(pixels[i + 1]) / 255, Double(pixels[i + 2]) / 255)
                all.append(c)
                if row < height / 3 { top.append(c) }
            }
        }
        func mean(_ cs: ArraySlice<RGB>) -> RGB {
            let n = Double(max(cs.count, 1))
            return (cs.reduce(0) { $0 + $1.0 } / n, cs.reduce(0) { $0 + $1.1 } / n, cs.reduce(0) { $0 + $1.2 } / n)
        }
        func brightest(_ cs: [RGB]) -> RGB {
            mean(cs.sorted { luminance($0) > luminance($1) }.prefix(max(1, cs.count / 10)))
        }
        return (mean(all[...]), brightest(all), brightest(top))
    }
}
