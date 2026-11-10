import SwiftUI
import UIKit
import WidgetKit

/// One app tile in a widget: Go's icon style (color, glyph or official App Store icon).
/// In tinted or clear Home Screen styles it becomes a soft tile with an accent-colored glyph.
struct WidgetTileView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let app: LauncherApp
    let theme: Theme
    let size: CGSize
    var nameInside = false

    private var side: CGFloat { min(size.width, size.height) }
    private var backgroundHex: String { theme.uniformIconColors ? theme.uniformIconHex : app.colorHex }
    private var glyphHex: String { theme.uniformIconColors ? theme.uniformGlyphHex : app.glyphColorHex }

    private var picture: UIImage? {
        if case .image(let name) = app.glyph { return SharedStore.image(named: name) }
        return nil
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: side * theme.cornerFactor, style: .continuous)
        let image = picture
        ZStack(alignment: .bottomLeading) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.accentedDesaturated)
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                background
                glyph
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, nameInside ? side * 0.16 : 0)
            }
            if nameInside {
                Text(app.name)
                    .font(.system(size: 10, weight: .semibold, design: theme.fontStyle.design))
                    .foregroundStyle(nameColor(onPicture: image != nil))
                    .shadow(color: .black.opacity(image != nil ? 0.5 : 0), radius: 2, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 5)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(renderingMode == .fullColor ? 0.10 : 0.25), lineWidth: 0.5))
    }

    @ViewBuilder
    private var background: some View {
        if renderingMode != .fullColor {
            Color.white.opacity(0.14)
        } else if !theme.uniformIconColors, let secondary = app.secondaryColorHex {
            LinearGradient(colors: [Color(hex: app.colorHex), Color(hex: secondary)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Color(hex: backgroundHex)
        }
    }

    @ViewBuilder
    private var glyph: some View {
        switch app.glyph {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: side * (nameInside ? 0.36 : 0.44), weight: .semibold))
                .foregroundStyle(renderingMode == .fullColor ? Color(hex: glyphHex) : .primary)
                .widgetAccentable()
        case .emoji(let emoji):
            Text(emoji)
                .font(.system(size: side * (nameInside ? 0.44 : 0.54)))
        case .image:
            // The picture file is missing; show a neutral placeholder.
            Image(systemName: "app.fill")
                .font(.system(size: side * 0.4))
                .foregroundStyle(Color(hex: glyphHex))
        }
    }

    private func nameColor(onPicture: Bool) -> Color {
        if renderingMode != .fullColor { return .primary }
        if onPicture { return .white }
        if theme.usesGlassIcons { return WidgetPalette.textColor(for: theme) }
        return Color.readableText(onHex: backgroundHex)
    }
}

/// The widget's own background. Home Screen widgets must be opaque, so instead of see-through
/// glass Go uses the theme's colors: a deep jewel tone of your background for light text, or a
/// bright frosted white for themes with dark text (like Cloud). iOS removes it in tinted and
/// clear Home Screen styles.
struct WidgetBackground: View {
    let theme: Theme

    var body: some View {
        ZStack {
            if theme.hasDarkText {
                LinearGradient(
                    colors: [Color(hex: "#FFFFFF"), Color(hex: theme.backgroundBottomHex)],
                    startPoint: .top, endPoint: .bottom
                )
                Color(hex: theme.toneHex).opacity(0.10)
            } else {
                LinearGradient(
                    colors: [WidgetPalette.deep(theme.backgroundTopHex), WidgetPalette.deep(theme.backgroundBottomHex, hueShift: 0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
            // Light catching the top edge, like Go's glass cards.
            LinearGradient(colors: [.white.opacity(theme.hasDarkText ? 0.5 : 0.12), .clear],
                           startPoint: .top, endPoint: .center)
        }
    }
}

enum WidgetPalette {
    /// The theme's text color, adjusted for the widget background.
    static func textColor(for theme: Theme) -> Color {
        theme.hasDarkText ? theme.labelColor : .white
    }

    /// A rich, deep version of a color (same hue, saturated, dark), so white text reads well.
    static func deep(_ hex: String, hueShift: CGFloat = 0) -> Color {
        let ui = UIColor(Color(hex: hex))
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let hue = (h + hueShift).truncatingRemainder(dividingBy: 1)
        // Near-neutral colors (black, gray) stay neutral instead of turning red.
        let saturation = s < 0.08 ? s : min(0.9, max(0.6, s * 1.5))
        return Color(UIColor(hue: hue, saturation: saturation, brightness: min(b, 0.38), alpha: 1))
    }
}
