import SwiftUI

// Two materials:
// - Liquid Glass (iOS 26) for Go's floating control layer: the search button, menu, search
//   bars and dock. On iOS 17–25 the same spots fall back to a frosted material.
// - Atmospheric glass for content: section cards, widgets, glass icon tiles and the pill
//   buttons inside them. Lighter than Liquid Glass, the same on every iOS version.

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

    /// Cards and widgets: atmospheric glass. A light frost that lets the wallpaper's colors
    /// through, a hairline white rim, a faint highlight along the top edge and a very soft
    /// shadow. Solid (tinted with the background's hue) when Reduce Transparency is on.
    /// Cards and widgets in the theme's card material: Glass style (atmospheric) or Classic (tone).
    @ViewBuilder
    func cardSurface<S: InsettableShape>(in shape: S, theme: Theme) -> some View {
        switch theme.cardMaterial {
        case .frosted:
            modifier(AtmosphericGlass(shape: shape, tone: Color(hex: theme.toneHex), style: .card, light: theme.hasDarkText))
        case .tone:
            modifier(ToneTint(shape: shape)).toneSurface(in: shape, theme: theme)
        }
    }

    /// Classic cards: Liquid Glass tinted with the background's own hue (tone on tone), with a
    /// faint light rim so neighbors sit together as one family. Frosted tone fill on older iOS.
    @ViewBuilder
    private func toneSurface<S: InsettableShape>(in shape: S, theme: Theme) -> some View {
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

// MARK: - Atmospheric glass

enum GlassTokens {
    /// White fill over the blur.
    static let cardFill = 0.12
    static let iconFill = 0.18
    static let buttonFill = 0.12
    static let buttonPressedFill = 0.20
    /// Hairline rim.
    static let cardBorder = 0.35
    static let iconBorder = 0.30
    /// Highlight along the top edge, fading out by the middle.
    static let topHighlight = 0.25
    /// How much of the light frost shows (1 = full system ultra-thin material).
    static let frost = 0.2
    static let shadow = Color(red: 20 / 255, green: 20 / 255, blue: 60 / 255).opacity(0.08)

    // Light glass, for light backgrounds with dark text (Cloud): bright frosted panels,
    // a navy hairline instead of a white rim, and a soft navy shadow to lift them.
    static let ink = Color(red: 10 / 255, green: 22 / 255, blue: 51 / 255)
    static let lightCardFill = 0.72
    static let lightIconFill = 0.8
    static let lightButtonFill = 0.95
    static let lightButtonPressedFill = 0.7
    static let lightCardBorder = 0.10
    static let lightButtonBorder = 0.22
    static let lightFrost = 0.6
    static let lightShadow = ink.opacity(0.10)
}

struct AtmosphericGlass<S: InsettableShape>: ViewModifier {
    enum Style { case card, icon, button(pressed: Bool) }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.legibility) private var legibility
    let shape: S
    /// Background hue, used for the solid Reduce Transparency fill.
    let tone: Color
    var style: Style = .card
    /// Light glass for light backgrounds with dark text.
    var light = false

    private var fill: Double {
        switch style {
        case .card: return light ? GlassTokens.lightCardFill : GlassTokens.cardFill
        case .icon: return light ? GlassTokens.lightIconFill : GlassTokens.iconFill
        case .button(let pressed):
            if light { return pressed ? GlassTokens.lightButtonPressedFill : GlassTokens.lightButtonFill }
            return pressed ? GlassTokens.buttonPressedFill : GlassTokens.buttonFill
        }
    }

    private var rim: Color {
        if light { return GlassTokens.ink.opacity(isButton ? GlassTokens.lightButtonBorder : GlassTokens.lightCardBorder) }
        if case .icon = style { return .white.opacity(GlassTokens.iconBorder) }
        return .white.opacity(GlassTokens.cardBorder)
    }

    func body(content: Content) -> some View {
        content
            // A soft shadow keeps white text readable over the lighter wallpapers.
            .shadow(color: .black.opacity(isCard && !light && !reduceTransparency ? 0.22 : 0), radius: 2, y: 1)
            .background {
                ZStack {
                    if reduceTransparency {
                        shape.fill(tone)
                    } else if isButton {
                        // Buttons sit on a card that's already frosted; a second frost would
                        // lighten the pill past WCAG contrast for its white label.
                        EmptyView()
                    } else {
                        // Light frost regardless of dark/light mode, so the wallpaper stays bright.
                        shape.fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .light)
                            .opacity(light ? GlassTokens.lightFrost : GlassTokens.frost)
                        // Tinted glass: the wallpaper's own deep color, as strong as contrast needs.
                        if isCard {
                            shape.fill(LinearGradient(
                                colors: [legibility.tint.opacity(legibility.cardTint), legibility.tint2.opacity(legibility.cardTint)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                        }
                    }
                    shape.fill(Color.white.opacity(fill))
                }
                .shadow(color: isCard ? (light ? GlassTokens.lightShadow : GlassTokens.shadow) : .clear, radius: light ? 16 : 12, y: 8)
            }
            .overlay {
                ZStack {
                    shape.strokeBorder(rim, lineWidth: 1)
                    shape.inset(by: 1).strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(light ? 0.9 : GlassTokens.topHighlight), .clear],
                            startPoint: .top, endPoint: .center
                        ),
                        lineWidth: 1
                    )
                }
                .allowsHitTesting(false)
            }
    }

    private var isButton: Bool {
        if case .button = style { return true }
        return false
    }

    private var isCard: Bool {
        if case .card = style { return true }
        return false
    }
}

/// Frosted pill button for use on glass cards: a little more opaque than its card, a thin
/// rim, and a brighter fill while pressed. No drop shadow.
struct GlassPillButtonStyle: ButtonStyle {
    var tone: Color = .clear
    var label: Color = .white
    var light = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(label)
            .modifier(AtmosphericGlass(shape: Capsule(), tone: tone, style: .button(pressed: configuration.isPressed), light: light))
            .contentShape(Capsule())
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

/// Classic cards get the same contrast tint as Glass (the wallpaper's own deep color), placed
/// inside the tinted Liquid Glass, so light wallpapers stay readable without dimming them.
struct ToneTint<S: InsettableShape>: ViewModifier {
    @Environment(\.legibility) private var legibility
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S

    func body(content: Content) -> some View {
        content.background {
            // Classic glass is already tinted with the background hue, so it needs less extra.
            if !reduceTransparency { shape.fill(legibility.tint.opacity(legibility.cardTint * 0.5)) }
        }
    }
}
