import SwiftUI
import UIKit

/// Keeps light (white) text readable on any wallpaper, to WCAG AA.
///
/// Go measures the brightest parts of the background (a built-in wallpaper, your photo, or
/// the gradient) and works out the least black dimming that brings them down to
/// `targetLuminance`. At that level, white text at the secondary opacity (85%) on the frosted
/// Glass cards measures at least 4.5:1. The value was tuned by measuring rendered screenshots
/// of every preset. Your own "Dim wallpaper" setting still applies when it's stronger.
enum ContrastGuard {
    /// Highest relative luminance the brightest 10% of the background may keep.
    static let targetLuminance = 0.055

    private static var cache: [String: Double] = [:]

    /// Dimming needed under light text for this theme and background image.
    static func requiredDim(theme: Theme, image: UIImage?, imageKey: String?) -> Double {
        // Dark text on a light background needs the opposite; those themes are already light.
        guard Color.luminance(ofHex: theme.labelColorHex) > 0.5 else { return 0 }
        if let image, let imageKey {
            if let cached = cache[imageKey] { return cached }
            let dim = dimFor(brightest: brightestColor(in: image))
            cache[imageKey] = dim
            return dim
        }
        let colors = [theme.backgroundTopHex, theme.backgroundBottomHex].map(rgb(ofHex:))
        let brightest = colors.max { luminance($0) < luminance($1) } ?? (0, 0, 0)
        return dimFor(brightest: brightest)
    }

    // MARK: - Math

    typealias RGB = (Double, Double, Double)

    /// Smallest black overlay (0...0.8) that brings `color` down to the target luminance.
    static func dimFor(brightest color: RGB) -> Double {
        var dim = 0.0
        while dim < 0.8 {
            let c = (color.0 * (1 - dim), color.1 * (1 - dim), color.2 * (1 - dim))
            if luminance(c) <= targetLuminance { return dim }
            dim += 0.01
        }
        return 0.8
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

    /// Average color of the brightest 10% of a small downsampled copy of the image.
    private static func brightestColor(in image: UIImage) -> RGB {
        let width = 24, height = 48
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard
            let cgImage = image.cgImage,
            let context = CGContext(
                data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return (1, 1, 1) }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var colors: [RGB] = []
        colors.reserveCapacity(width * height)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            colors.append((Double(pixels[i]) / 255, Double(pixels[i + 1]) / 255, Double(pixels[i + 2]) / 255))
        }
        let top = colors.sorted { luminance($0) > luminance($1) }.prefix(max(1, colors.count / 10))
        let n = Double(top.count)
        return (top.reduce(0) { $0 + $1.0 } / n, top.reduce(0) { $0 + $1.1 } / n, top.reduce(0) { $0 + $1.2 } / n)
    }
}
