import PhotosUI
import SwiftUI

/// The "Design" sheet. Changes apply live behind the sheet.
struct ThemeView: View {
    @EnvironmentObject private var store: LauncherStore
    @Environment(\.dismiss) private var dismiss
    @State private var wallpaperItem: PhotosPickerItem?
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                styleSection
                widgetsSection
                presetsSection
                backgroundSection
                iconsSection
                textSection
                layoutSection
                Section {
                    Button("Reset Everything to Default", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Design")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Reset layout and design?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { store.resetToDefault() }
            } message: {
                Text("This restores the starter apps, groups and theme. Your custom icons will be removed.")
            }
            .onChange(of: wallpaperItem) { _, item in
                guard let item else { return }
                Task { @MainActor in
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let name = store.saveImage(data, maxDimension: 2000) {
                        store.state.theme.wallpaperFilename = name
                    }
                }
            }
        }
    }

    // MARK: Sections

    private var styleSection: some View {
        Section {
            HStack(spacing: 12) {
                styleCard(name: "Classic", isOn: store.state.theme.isClassic, tiles: false) {
                    store.state.theme.applyClassic()
                }
                styleCard(name: "Glass", isOn: store.state.theme.isGlass, tiles: false, glass: true) {
                    store.state.theme.applyGlass()
                }
                styleCard(name: "Tiles", isOn: store.state.theme.isTiles, tiles: true) {
                    store.state.theme.applyTiles()
                }
            }
            .padding(.vertical, 6)
        } header: {
            Text("Style")
        } footer: {
            Text("Classic: cards tinted with the background color. Glass: frosted cards that let the wallpaper show through. Tiles: no spacing, square edges, and every app fills its whole cell for a bigger tap area. Names sit inside the tiles. You can still fine-tune each setting below.")
        }
    }

    private func styleCard(name: String, isOn: Bool, tiles: Bool, glass: Bool = false, apply: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { apply() }
        } label: {
            VStack(spacing: 8) {
                // A tiny drawing of the style.
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(18), spacing: tiles ? 0 : 6), count: 3), spacing: tiles ? 0 : 6) {
                    ForEach(0..<6, id: \.self) { i in
                        RoundedRectangle(cornerRadius: tiles ? 0 : 5, style: .continuous)
                            .fill(Color(hex: ["#F472B6", "#818CF8", "#34D399", "#FBBF24", "#38BDF8", "#F97316"][i]))
                            .frame(width: 18, height: 18)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 56)
                .background {
                    if glass {
                        // A frosted panel over the wallpaper, like the Glass cards.
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(LinearGradient(colors: [Color(hex: "#3A2D9C"), Color(hex: "#C08AD8")], startPoint: .top, endPoint: .bottom))
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.18))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.45), lineWidth: 1))
                                .padding(4)
                        }
                    }
                }
                Text(name).font(.subheadline.weight(.semibold))
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.secondary.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isOn ? Color.accentColor : .clear, lineWidth: 2.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) style")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var widgetsSection: some View {
        Section {
            Toggle("Show widgets", isOn: $store.state.theme.showWidgets)
            if store.state.theme.showWidgets {
                Picker("Left", selection: $store.state.theme.leftWidget) {
                    ForEach(WidgetKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                Picker("Right", selection: $store.state.theme.rightWidget) {
                    ForEach(WidgetKind.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                NavigationLink {
                    FavoritesPickerView()
                } label: {
                    HStack {
                        Text("Favorite Apps")
                        Spacer()
                        Text(store.state.favoriteAppIDs.isEmpty ? "Most used" : "\(store.state.favoriteAppIDs.count) picked")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Widgets")
        } footer: {
            Text("Two widgets side by side at the top of your home screen. Weather uses your location and the free Open-Meteo service.")
        }
    }

    private var presetsSection: some View {
        Section("Presets") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ThemePreset.all) { preset in
                        Button {
                            withAnimation { preset.apply(&store.state.theme) }
                        } label: {
                            presetSwatch(preset)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private func presetSwatch(_ preset: ThemePreset) -> some View {
        let t = preset.preview
        return VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: t.backgroundTopHex), Color(hex: t.backgroundBottomHex)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 64, height: 88)
                .overlay {
                    if let name = t.bundledWallpaper, let image = UIImage(named: name) {
                        Image(uiImage: image).resizable().scaledToFill()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    LazyVGrid(columns: [GridItem(.fixed(16)), GridItem(.fixed(16))], spacing: 6) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 16 * t.cornerFactor, style: .continuous)
                                .fill(t.uniformIconColors
                                      ? Color(hex: t.uniformIconHex)
                                      : Color(hex: ["#F472B6", "#818CF8", "#34D399", "#FBBF24"][i]))
                                .frame(width: 16, height: 16)
                        }
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.1)))
            Text(preset.name)
                .font(.system(.caption, design: t.fontStyle.design))
        }
    }

    private var backgroundSection: some View {
        Section("Background") {
            ColorPicker("Top color", selection: hexBinding(\.backgroundTopHex))
            ColorPicker("Bottom color", selection: hexBinding(\.backgroundBottomHex))
            PhotosPicker(selection: $wallpaperItem, matching: .images) {
                Label(store.state.theme.wallpaperFilename == nil ? "Choose Wallpaper Photo" : "Change Wallpaper Photo",
                      systemImage: "photo")
            }
            if store.state.theme.wallpaperFilename != nil || store.state.theme.bundledWallpaper != nil {
                VStack(alignment: .leading) {
                    Text("Dim wallpaper")
                    Slider(value: $store.state.theme.wallpaperDim, in: 0...0.7)
                }
                Button("Remove Wallpaper (use the colors above)", role: .destructive) {
                    store.state.theme.wallpaperFilename = nil
                    store.state.theme.bundledWallpaper = nil
                }
            }
            Toggle("Dark style", isOn: $store.state.theme.isDark)
        }
    }

    private var iconsSection: some View {
        Section {
            VStack(alignment: .leading) {
                Text(store.state.theme.fillCells ? "Size (set by Fill each cell)" : "Size")
                Slider(value: $store.state.theme.iconSize, in: 44...84)
            }
            .disabled(store.state.theme.fillCells)
            VStack(alignment: .leading) {
                HStack {
                    Text("Shape")
                    Spacer()
                    Text(shapeName).foregroundStyle(.secondary)
                }
                Slider(value: $store.state.theme.cornerFactor, in: 0...0.5)
            }
            VStack(alignment: .leading) {
                HStack {
                    Text("Spacing")
                    Spacer()
                    Text(store.state.theme.iconSpacing < 1 ? "None" : "\(Int(store.state.theme.iconSpacing)) pt")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $store.state.theme.iconSpacing, in: 0...24, step: 1)
            }
            Toggle("Fill each cell", isOn: $store.state.theme.fillCells)
            Toggle("Official app icons", isOn: Binding(
                get: { store.state.theme.useOfficialIcons },
                set: { store.setOfficialIcons($0) }
            ))
            Stepper("Columns: \(store.state.theme.columns)", value: $store.state.theme.columns, in: 3...6)
            Toggle("Matching icon colors", isOn: $store.state.theme.uniformIconColors)
            if store.state.theme.uniformIconColors {
                ColorPicker("Icon background", selection: hexBinding(\.uniformIconHex), supportsOpacity: true)
                ColorPicker("Icon symbol", selection: hexBinding(\.uniformGlyphHex))
            }
        } header: {
            Text("Icons")
        } footer: {
            Text("Official app icons are downloaded once from the App Store; built-in Apple apps that aren't on the App Store keep their symbols. Matching colors gives every other icon the same look.")
        }
    }

    private var textSection: some View {
        Section("Text") {
            Toggle("Show app names", isOn: $store.state.theme.showLabels)
            if store.state.theme.showLabels {
                Toggle("Names inside icons", isOn: $store.state.theme.labelsInside)
            }
            ColorPicker("Text color", selection: hexBinding(\.labelColorHex))
            Picker("Font", selection: $store.state.theme.fontStyle) {
                ForEach(FontStyle.allCases) { style in
                    Text(style.label).font(.system(.body, design: style.design)).tag(style)
                }
            }
        }
    }

    private var layoutSection: some View {
        Section {
            Picker("Sections", selection: $store.state.theme.sectionLayout) {
                ForEach(SectionLayout.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            HStack {
                Text("Your name")
                TextField("For the greeting", text: $store.state.theme.userName)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
            }
            Toggle("Show clock & date", isOn: $store.state.theme.showClock)
                .disabled(store.state.theme.showsDateWidget)
            Toggle("Group cards", isOn: $store.state.theme.showGroupCards)
            Toggle("Open straight into search", isOn: $store.state.theme.searchOnOpen)
        } header: {
            Text("Layout & behavior")
        } footer: {
            Text("Swipe Rows shows one row per section (two for Recently Used); swipe left for more or tap View All. Full Grid shows every app. With “Open straight into search”, Go opens to the search screen every time, keyboard ready, so you can type a few letters and press Go to launch.")
        }
    }

    // MARK: Helpers

    private var shapeName: String {
        switch store.state.theme.cornerFactor {
        case ..<0.06: return "Square"
        case ..<0.33: return "Rounded"
        case ..<0.46: return "Squircle"
        default: return "Circle"
        }
    }

    private func hexBinding(_ keyPath: WritableKeyPath<Theme, String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: store.state.theme[keyPath: keyPath]) },
            set: { store.state.theme[keyPath: keyPath] = $0.hexString }
        )
    }
}
