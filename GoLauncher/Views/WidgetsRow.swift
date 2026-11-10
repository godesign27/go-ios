import SwiftUI
import UIKit

/// Two square widgets side by side at the top of the home screen (Design › Widgets).
struct WidgetsRow: View {
    @EnvironmentObject private var store: LauncherStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var weather: WeatherService
    let theme: Theme
    let onLaunch: (LauncherApp) -> Void

    var body: some View {
        // Side by side normally; stacked at accessibility text sizes so nothing is cut off.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: max(theme.iconSpacing, 8)))
            : AnyLayout(HStackLayout(spacing: theme.iconSpacing))
        layout {
            widget(theme.leftWidget)
            widget(theme.rightWidget)
        }
        .onAppear(perform: refreshWeatherIfShown)
        .onChange(of: theme.leftWidget) { _, _ in refreshWeatherIfShown() }
        .onChange(of: theme.rightWidget) { _, _ in refreshWeatherIfShown() }
    }

    private func refreshWeatherIfShown() {
        if theme.leftWidget == .weather || theme.rightWidget == .weather {
            weather.refreshIfNeeded()
        }
    }

    @ViewBuilder
    private func widget(_ kind: WidgetKind) -> some View {
        switch kind {
        case .dateTime:
            WidgetCard(theme: theme) { DateTimeWidget(theme: theme) }
        case .weather:
            WidgetCard(theme: theme) { WeatherWidget(weather: weather, theme: theme) }
        case .favorites:
            WidgetCard(theme: theme, padded: theme.iconSpacing >= 1) {
                FavoritesWidget(apps: store.favoriteApps, theme: theme, onLaunch: onLaunch)
            }
        }
    }
}

/// Square glass card. Its corners follow the icon shape (square in Tiles style).
struct WidgetCard<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let theme: Theme
    var padded = true
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous)
        sized(content.padding(padded ? 14 : 0))
            .clipShape(shape)
            .cardSurface(in: shape, theme: theme)
            .foregroundStyle(theme.labelColor)
    }

    /// Square normally; at accessibility text sizes full width and as tall as the text needs.
    @ViewBuilder
    private func sized<V: View>(_ view: V) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            view
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            view
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .aspectRatio(1, contentMode: .fit)
        }
    }
}

struct DateTimeWidget: View {
    let theme: Theme

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 0) {
                Text(context.date, format: .dateTime.weekday(.wide))
                    .scaledFont(size: 13, weight: .bold, design: theme.fontStyle.design, relativeTo: .footnote)
                    .textCase(.uppercase)
                    .opacity(Theme.secondaryOpacity)
                Text(context.date, format: .dateTime.day())
                    .scaledFont(size: 46, weight: .bold, design: theme.fontStyle.design, relativeTo: .largeTitle, maxSize: 60)
                    .monospacedDigit()
                Spacer(minLength: 0)
                Text(context.date, format: .dateTime.hour().minute())
                    .scaledFont(size: 26, weight: .semibold, design: theme.fontStyle.design, relativeTo: .title3, maxSize: 40)
                    .monospacedDigit()
                Text(context.date, format: .dateTime.month(.wide).year())
                    .scaledFont(size: 12, weight: .medium, design: theme.fontStyle.design, relativeTo: .caption)
                    .opacity(Theme.secondaryOpacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

struct WeatherWidget: View {
    @ObservedObject var weather: WeatherService
    let theme: Theme
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if let current = weather.current {
                VStack(alignment: .leading, spacing: 2) {
                    Text(current.place ?? "Your location")
                        .scaledFont(size: 13, weight: .bold, design: theme.fontStyle.design, relativeTo: .footnote)
                        .lineLimit(1)
                    Text("\(Int(current.temperature.rounded()))°")
                        .scaledFont(size: 44, weight: .semibold, design: theme.fontStyle.design, relativeTo: .largeTitle, maxSize: 60)
                    Spacer(minLength: 0)
                    Image(systemName: WeatherService.symbol(for: current.code))
                        .weatherSymbolStyle(theme)
                        .scaledFont(size: 20, relativeTo: .title3)
                    Text(WeatherService.description(for: current.code))
                        .scaledFont(size: 13, weight: .semibold, design: theme.fontStyle.design, relativeTo: .footnote)
                        .lineLimit(1)
                    Text("H:\(Int(current.high.rounded()))°  L:\(Int(current.low.rounded()))°")
                        .scaledFont(size: 12, weight: .medium, design: theme.fontStyle.design, relativeTo: .caption)
                        .opacity(Theme.secondaryOpacity)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Weather, \(current.place ?? "your location")")
                .accessibilityValue("\(Int(current.temperature.rounded())) degrees, \(WeatherService.description(for: current.code)), high \(Int(current.high.rounded())), low \(Int(current.low.rounded()))")
            } else {
                message
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var message: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "cloud.sun.fill")
                .weatherSymbolStyle(theme)
                .accessibilityHidden(true)
                .scaledFont(size: 26, relativeTo: .title3)
            Spacer(minLength: 0)
            switch weather.status {
            case .loading, .idle:
                ProgressView()
            case .needsPermission:
                Text("Show your local weather")
                    .scaledFont(size: 13, weight: .semibold, design: theme.fontStyle.design, relativeTo: .footnote)
                Button("Allow Location") { weather.requestPermission() }
                    .scaledFont(size: 13, weight: .bold, relativeTo: .footnote)
                    .buttonStyle(GlassPillButtonStyle(tone: Color(hex: theme.toneHex), label: theme.labelColor, light: theme.hasDarkText))
            case .denied:
                Text("Location is off for Go")
                    .scaledFont(size: 13, weight: .semibold, design: theme.fontStyle.design, relativeTo: .footnote)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .scaledFont(size: 13, weight: .bold, relativeTo: .footnote)
                .buttonStyle(GlassPillButtonStyle(tone: Color(hex: theme.toneHex), label: theme.labelColor, light: theme.hasDarkText))
            case .failed, .ready:
                Text("Couldn't load weather")
                    .scaledFont(size: 13, weight: .semibold, design: theme.fontStyle.design, relativeTo: .footnote)
                Button("Try Again") { weather.retry() }
                    .scaledFont(size: 13, weight: .bold, relativeTo: .footnote)
                    .buttonStyle(GlassPillButtonStyle(tone: Color(hex: theme.toneHex), label: theme.labelColor, light: theme.hasDarkText))
            }
        }
    }
}

/// A 2×2 block of four apps you pick in Design › Widgets › Favorite Apps.
struct FavoritesWidget: View {
    let apps: [LauncherApp]
    let theme: Theme
    let onLaunch: (LauncherApp) -> Void

    var body: some View {
        let gap: CGFloat = theme.iconSpacing >= 1 ? 10 : 0
        LazyVGrid(columns: [GridItem(.flexible(), spacing: gap), GridItem(.flexible(), spacing: gap)], spacing: gap) {
            ForEach(apps.prefix(4)) { app in
                Button { onLaunch(app) } label: {
                    IconTile(
                        glyph: app.glyph,
                        backgroundHex: theme.uniformIconColors ? theme.uniformIconHex : app.colorHex,
                        secondaryHex: theme.uniformIconColors ? nil : app.secondaryColorHex,
                        glyphHex: theme.uniformIconColors ? theme.uniformGlyphHex : app.glyphColorHex,
                        maxSize: .infinity,
                        cornerFactor: theme.cornerFactor,
                        showsShadow: false
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(app.name)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Design › Widgets › Favorite Apps: choose your favorites (also editable by long-pressing an app).
struct FavoritesPickerView: View {
    @EnvironmentObject private var store: LauncherStore

    var body: some View {
        List {
            Section {
                ForEach(store.state.apps) { app in
                    let selected = store.isFavorite(app.id)
                    Button {
                        store.toggleFavorite(app.id)
                    } label: {
                        HStack(spacing: 12) {
                            IconTile(
                                glyph: app.glyph,
                                backgroundHex: app.colorHex,
                                secondaryHex: app.secondaryColorHex,
                                glyphHex: app.glyphColorHex,
                                maxSize: 30,
                                cornerFactor: store.state.theme.cornerFactor
                            )
                            .frame(width: 30, height: 30)
                            Text(app.name).foregroundStyle(.primary)
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark").foregroundStyle(.tint).fontWeight(.semibold)
                            }
                        }
                    }
                }
            } footer: {
                Text("These are your Favorites. The Favorites section shows them all; the widget shows the first four. Until you pick any, the widget shows your most used apps.")
            }
        }
        .navigationTitle("Favorite Apps")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension View {
    /// Apple's colored weather symbols draw clouds white, which vanish on light themes.
    /// There, clouds take the text color (meets the 3:1 contrast for graphics) and the sun
    /// and rain keep a color accent.
    @ViewBuilder
    func weatherSymbolStyle(_ theme: Theme) -> some View {
        if theme.hasDarkText {
            self.symbolRenderingMode(.palette)
                .foregroundStyle(theme.labelColor, Color(hex: "#F59E0B"), Color(hex: "#2563EB"))
        } else {
            self.symbolRenderingMode(.multicolor)
        }
    }
}
