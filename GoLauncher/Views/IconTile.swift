import SwiftUI

/// The rounded icon square. Scales its glyph to whatever size it's given (up to `maxSize`).
struct IconTile: View {
    @EnvironmentObject private var store: LauncherStore

    let glyph: IconGlyph
    let backgroundHex: String
    var secondaryHex: String? = nil
    var glyphHex: String = "#FFFFFF"
    var maxSize: CGFloat = 62
    var cornerFactor: CGFloat = 0.24

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let shape = RoundedRectangle(cornerRadius: side * cornerFactor, style: .continuous)

            ZStack {
                background
                glyphView(side: side)
            }
            .frame(width: side, height: side)
            .clipShape(shape)
            .overlay(shape.strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: side * 0.06, y: side * 0.03)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: maxSize)
    }

    @ViewBuilder
    private var background: some View {
        if let secondaryHex {
            LinearGradient(
                colors: [Color(hex: backgroundHex), Color(hex: secondaryHex)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color(hex: backgroundHex)
        }
    }

    @ViewBuilder
    private func glyphView(side: CGFloat) -> some View {
        switch glyph {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: side * 0.46, weight: .semibold))
                .foregroundStyle(Color(hex: glyphHex))
        case .emoji(let emoji):
            Text(emoji)
                .font(.system(size: side * 0.56))
        case .image(let name):
            if let uiImage = store.image(named: name) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: side, height: side)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: side * 0.4))
                    .foregroundStyle(Color(hex: glyphHex))
            }
        }
    }
}

/// An app's icon + label, styled by the current theme.
struct AppIconView: View {
    let app: LauncherApp
    let theme: Theme
    var showLabel = true

    var body: some View {
        VStack(spacing: 6) {
            IconTile(
                glyph: app.glyph,
                backgroundHex: theme.uniformIconColors ? theme.uniformIconHex : app.colorHex,
                secondaryHex: theme.uniformIconColors ? nil : app.secondaryColorHex,
                glyphHex: theme.uniformIconColors ? theme.uniformGlyphHex : app.glyphColorHex,
                maxSize: theme.iconSize,
                cornerFactor: theme.cornerFactor
            )
            if showLabel && theme.showLabels {
                Text(app.name)
                    .font(.system(size: 12, weight: .medium, design: theme.fontStyle.design))
                    .foregroundStyle(theme.labelColor)
                    .shadow(color: .black.opacity(theme.isDark ? 0.35 : 0), radius: 2, y: 1)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(app.name)
        .accessibilityAddTraits(.isButton)
    }
}
