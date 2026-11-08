import SwiftUI

// Liquid Glass (iOS 26) for Go's floating control layer: the search button, menu,
// search bars, dock and widgets. Content (section cards, icons) stays out of glass,
// per Apple's guidance. On iOS 17–25 the same spots fall back to a frosted material.

// Liquid Glass needs the iOS 26 SDK (Xcode 26, Swift 6.2). Older Xcode builds use the fallback.
#if compiler(>=6.2)
@available(iOS 26.0, *)
private func goGlass(interactive: Bool, tint: Color?) -> Glass {
    var glass = Glass.regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}
#endif

extension View {
    /// Liquid Glass in `shape` (iOS 26+), or frosted material on older iOS.
    /// `interactive` makes the glass respond to touch, for tappable controls.
    @ViewBuilder
    func glassSurface<S: Shape>(in shape: S, interactive: Bool = false, tint: Color? = nil) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(goGlass(interactive: interactive, tint: tint), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
        #else
        self.background(.ultraThinMaterial, in: shape)
        #endif
    }

    /// Cards and widgets: glass tinted with the background's own hue (tone on tone), with a
    /// faint light rim so neighbors sit together as one family. Frosted tone fill on older iOS.
    @ViewBuilder
    func cardSurface<S: InsettableShape>(in shape: S, theme: Theme) -> some View {
        let tone = Color(hex: theme.toneHex)
        let rim = Color.white.opacity(theme.isDark ? 0.10 : 0.35)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tone.opacity(theme.isDark ? 0.45 : 0.30)), in: shape)
                .overlay(shape.strokeBorder(rim, lineWidth: 0.5))
        } else {
            toneFallback(shape: shape, tone: tone, rim: rim, isDark: theme.isDark)
        }
        #else
        toneFallback(shape: shape, tone: tone, rim: rim, isDark: theme.isDark)
        #endif
    }

    private func toneFallback<S: InsettableShape>(shape: S, tone: Color, rim: Color, isDark: Bool) -> some View {
        self.background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(tone.opacity(isDark ? 0.55 : 0.35))
                // A touch lighter at the top, like light catching the glass.
                shape.fill(LinearGradient(colors: [.white.opacity(isDark ? 0.08 : 0.20), .clear], startPoint: .top, endPoint: .bottom))
            }
        }
        .overlay(shape.strokeBorder(rim, lineWidth: 0.5))
    }

    /// Glass button style (iOS 26+), or the closest bordered style on older iOS.
    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            fallbackButtonStyle(prominent: prominent)
        }
        #else
        fallbackButtonStyle(prominent: prominent)
        #endif
    }

    @ViewBuilder
    private func fallbackButtonStyle(prominent: Bool) -> some View {
        if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}

/// Groups nearby glass shapes so they render together and blend when they move close
/// (the search button and the dock). A plain container on older iOS.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
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
