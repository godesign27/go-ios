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
            if store.state.theme.wallpaperFilename != nil {
                VStack(alignment: .leading) {
                    Text("Dim wallpaper")
                    Slider(value: $store.state.theme.wallpaperDim, in: 0...0.7)
                }
                Button("Remove Wallpaper", role: .destructive) {
                    store.state.theme.wallpaperFilename = nil
                }
            }
            Toggle("Dark style", isOn: $store.state.theme.isDark)
        }
    }

    private var iconsSection: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Size")
                Slider(value: $store.state.theme.iconSize, in: 44...84)
            }
            VStack(alignment: .leading) {
                HStack {
                    Text("Shape")
                    Spacer()
                    Text(shapeName).foregroundStyle(.secondary)
                }
                Slider(value: $store.state.theme.cornerFactor, in: 0...0.5)
            }
            Stepper("Columns: \(store.state.theme.columns)", value: $store.state.theme.columns, in: 3...6)
            Toggle("Matching icon colors", isOn: $store.state.theme.uniformIconColors)
            if store.state.theme.uniformIconColors {
                ColorPicker("Icon background", selection: hexBinding(\.uniformIconHex), supportsOpacity: true)
                ColorPicker("Icon symbol", selection: hexBinding(\.uniformGlyphHex))
            }
        } header: {
            Text("Icons")
        } footer: {
            Text("Matching colors gives every icon the same look. Each icon's own colors are kept for when you turn it off.")
        }
    }

    private var textSection: some View {
        Section("Text") {
            Toggle("Show app names", isOn: $store.state.theme.showLabels)
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
            Toggle("Show clock & date", isOn: $store.state.theme.showClock)
            Toggle("Group cards", isOn: $store.state.theme.showGroupCards)
            Toggle("Open straight into search", isOn: $store.state.theme.searchOnOpen)
        } header: {
            Text("Layout & behavior")
        } footer: {
            Text("With “Open straight into search”, Go opens to the search screen every time, keyboard ready, so you can type a few letters and press Go to launch.")
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
