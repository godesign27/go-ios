import PhotosUI
import SwiftUI

/// Create or edit one icon: name, what it opens, glyph, colors, group.
struct AppEditorView: View {
    enum IconKind: String, CaseIterable, Identifiable {
        case symbol = "Symbol", emoji = "Emoji", photo = "Photo"
        var id: String { rawValue }
    }

    enum LaunchKind: String, CaseIterable, Identifiable {
        case url = "Link / URL", shortcut = "Shortcut"
        var id: String { rawValue }
    }

    @EnvironmentObject private var store: LauncherStore
    @Environment(\.openURL) private var openURL

    let isNew: Bool
    let onFinish: () -> Void

    @State private var draft: LauncherApp
    @State private var iconKind: IconKind
    @State private var symbolName: String
    @State private var emoji: String
    @State private var imageName: String?
    @State private var launchKind: LaunchKind
    @State private var launchText: String
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var confirmDelete = false
    /// The user changed the icon themselves, so Go won't swap in the App Store icon.
    @State private var iconTouched = false
    @State private var pickedOfficialIcon: Bool

    init(app: LauncherApp, isNew: Bool, onFinish: @escaping () -> Void) {
        self.isNew = isNew
        self.onFinish = onFinish
        _draft = State(initialValue: app)
        _pickedOfficialIcon = State(initialValue: app.usesOfficialIcon)

        var kind = IconKind.symbol
        var symbol = "app.fill"
        var emoji = "⭐️"
        var image: String?
        switch app.glyph {
        case .symbol(let name): kind = .symbol; symbol = name
        case .emoji(let value): kind = .emoji; emoji = value
        case .image(let name): kind = .photo; image = name
        }
        _iconKind = State(initialValue: kind)
        _symbolName = State(initialValue: symbol)
        _emoji = State(initialValue: emoji)
        _imageName = State(initialValue: image)

        switch app.launch {
        case .url(let value):
            _launchKind = State(initialValue: .url)
            _launchText = State(initialValue: value)
        case .shortcut(let value):
            _launchKind = State(initialValue: .shortcut)
            _launchText = State(initialValue: value)
        }
    }

    private var composedGlyph: IconGlyph {
        switch iconKind {
        case .symbol: return .symbol(symbolName.isEmpty ? "app.fill" : symbolName)
        case .emoji: return .emoji(emoji.isEmpty ? "⭐️" : emoji)
        case .photo:
            if let imageName { return .image(imageName) }
            return .symbol(symbolName.isEmpty ? "photo" : symbolName)
        }
    }

    private var composedLaunch: LaunchTarget {
        switch launchKind {
        case .url: return .url(launchText)
        case .shortcut: return .shortcut(launchText)
        }
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !launchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            previewSection
            basicsSection
            launchSection
            iconSection
            colorSection
            organizeSection
            if !isNew {
                Section {
                    Button("Remove from Go", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .navigationTitle(isNew ? "New Icon" : "Edit Icon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onFinish)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isNew ? "Add" : "Save", action: save)
                    .disabled(!canSave)
            }
        }
        .confirmationDialog("Remove \(draft.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                store.delete(draft.id)
                onFinish()
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            isLoadingPhoto = true
            Task { @MainActor in
                defer { isLoadingPhoto = false }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let name = store.saveImage(data, maxDimension: 300) {
                    imageName = name
                    pickedOfficialIcon = false
                    iconTouched = true
                }
            }
        }
    }

    // MARK: Sections

    private var previewSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    IconTile(
                        glyph: composedGlyph,
                        backgroundHex: draft.colorHex,
                        secondaryHex: draft.secondaryColorHex,
                        glyphHex: draft.glyphColorHex,
                        maxSize: 96,
                        cornerFactor: store.state.theme.cornerFactor
                    )
                    .frame(width: 96, height: 96)
                    Text(draft.name.isEmpty ? "Name" : draft.name)
                        .font(.system(.footnote, design: store.state.theme.fontStyle.design).weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .listRowBackground(Color.clear)
        } footer: {
            if store.state.theme.uniformIconColors {
                Text("Your design uses matching icon colors, so your colors below show only when that's off (Design › Icons).")
            }
        }
    }

    private var basicsSection: some View {
        Section("Name") {
            TextField("App name", text: $draft.name)
            TextField("Extra search words (optional)", text: $draft.keywords)
                .textInputAutocapitalization(.never)
        }
    }

    private var launchSection: some View {
        Section {
            Picker("Opens with", selection: $launchKind) {
                ForEach(LaunchKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if launchKind == .url {
                TextField("e.g. spotify:// or https://…", text: $launchText)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Menu("Pick a known app…") {
                    ForEach(CatalogEntry.Category.allCases, id: \.self) { category in
                        Section(category.rawValue) {
                            ForEach(AppCatalog.entries.filter { $0.category == category }) { entry in
                                Button(entry.name) { applyCatalog(entry) }
                            }
                        }
                    }
                }
            } else {
                TextField("Shortcut name, e.g. Open Camera", text: $launchText)
                    .autocorrectionDisabled()
            }

            Button {
                if let url = composedLaunch.resolvedURL { openURL(url) }
            } label: {
                Label("Test", systemImage: "play.fill")
            }
            .disabled(composedLaunch.resolvedURL == nil)
        } header: {
            Text("What it opens")
        } footer: {
            if launchKind == .url {
                Text("Most apps have a link like name:// that opens them. If an app doesn't, use Shortcut instead.")
            } else {
                Text("Works for ANY app: in the Shortcuts app, make a shortcut with the “Open App” action, then type its exact name here.")
            }
        }
    }

    private var iconSection: some View {
        Section("Icon") {
            Picker("Style", selection: Binding(get: { iconKind }, set: { iconKind = $0; iconTouched = true })) {
                ForEach(IconKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            switch iconKind {
            case .symbol:
                NavigationLink {
                    SymbolPickerView(selection: Binding(get: { symbolName }, set: { symbolName = $0; iconTouched = true }))
                } label: {
                    HStack {
                        Text("Symbol")
                        Spacer()
                        Image(systemName: symbolName)
                        Text(symbolName).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            case .emoji:
                TextField("Type one emoji", text: $emoji)
                    .font(.largeTitle)
                    .onChange(of: emoji) { _, value in
                        // Keep only the last character typed (one emoji, including combined ones).
                        if value.count > 1, let last = value.last { emoji = String(last) }
                    }
            case .photo:
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack {
                        Label(imageName == nil ? "Choose Photo" : "Change Photo", systemImage: "photo.on.rectangle")
                        if isLoadingPhoto {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
            }
            NavigationLink {
                AppStoreIconSearchView(initialTerm: draft.name) { data in
                    if let name = store.saveOfficialIcon(data) {
                        imageName = name
                        iconKind = .photo
                        pickedOfficialIcon = true
                        iconTouched = true
                    }
                }
            } label: {
                Label("Find App Store Icon", systemImage: "app.badge.checkmark")
            }
        }
    }

    private var colorSection: some View {
        Section("Colors") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Palette.swatches, id: \.self) { hex in
                        Button {
                            draft.colorHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().strokeBorder(.primary.opacity(0.15)))
                                .overlay {
                                    if draft.colorHex.uppercased() == hex {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(hex == "#FFFFFF" || hex == "#F5F0E6" ? Color.black : Color.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Color \(hex)")
                    }
                }
                .padding(.vertical, 4)
            }
            ColorPicker("Background", selection: hexBinding(\.colorHex))
            Toggle("Gradient", isOn: Binding(
                get: { draft.secondaryColorHex != nil },
                set: { draft.secondaryColorHex = $0 ? "#111827" : nil }
            ))
            if draft.secondaryColorHex != nil {
                ColorPicker("Gradient end", selection: Binding(
                    get: { Color(hex: draft.secondaryColorHex ?? "#111827") },
                    set: { draft.secondaryColorHex = $0.hexString }
                ))
            }
            if iconKind == .symbol {
                ColorPicker("Symbol", selection: hexBinding(\.glyphColorHex))
            }
        }
    }

    private var organizeSection: some View {
        Section("Organize") {
            Picker("Group", selection: $draft.groupID) {
                ForEach(store.state.groups) { Text($0.name).tag($0.id) }
            }
            Toggle("Needs attention", isOn: $draft.needsAttention)
            if store.state.showDock {
                Toggle("Show in Dock", isOn: $draft.isDocked)
            }
        }
    }

    // MARK: Helpers

    private func hexBinding(_ keyPath: WritableKeyPath<LauncherApp, String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: draft[keyPath: keyPath]) },
            set: { draft[keyPath: keyPath] = $0.hexString }
        )
    }

    private func applyCatalog(_ entry: CatalogEntry) {
        launchText = entry.url
        if draft.name.isEmpty { draft.name = entry.name }
        if draft.keywords.isEmpty { draft.keywords = entry.keywords }
        if iconKind == .symbol {
            symbolName = entry.symbol
            draft.colorHex = entry.colorHex
        }
    }

    private func save() {
        var app = draft
        app.name = app.name.trimmingCharacters(in: .whitespaces)
        app.glyph = composedGlyph
        app.launch = composedLaunch
        if iconKind == .photo && imageName != nil {
            app.usesOfficialIcon = pickedOfficialIcon
            if pickedOfficialIcon { app.fallbackGlyph = .symbol(symbolName) }
        } else {
            app.usesOfficialIcon = false
        }
        // A hand-picked icon wins over the automatic App Store icon.
        if iconTouched { app.iconLookupDone = true }
        store.upsert(app)
        onFinish()
    }
}

/// Search the App Store and pick an app's official icon.
struct AppStoreIconSearchView: View {
    let initialTerm: String
    let onPick: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var term = ""
    @State private var results: [AppStoreIcons.Item] = []
    @State private var isSearching = false
    @State private var downloadingID: Int?
    @State private var didSearch = false

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("App name", text: $term)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await runSearch() } }
                    Button("Search") { Task { await runSearch() } }
                        .disabled(term.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } footer: {
                Text("Icons come from the App Store. Pick the one that matches the app on your phone.")
            }

            Section {
                if isSearching {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if didSearch && results.isEmpty {
                    Text("No apps found for “\(term)”. Try the name as it appears in the App Store.")
                        .foregroundStyle(.secondary)
                }
                ForEach(results) { item in
                    Button {
                        Task { await pick(item) }
                    } label: {
                        HStack(spacing: 12) {
                            AsyncImage(url: item.thumbnailURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.secondary.opacity(0.15)
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.trackName).foregroundStyle(.primary).lineLimit(1)
                                if let seller = item.sellerName {
                                    Text(seller).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                            if downloadingID == item.id { ProgressView() }
                        }
                    }
                    .disabled(downloadingID != nil)
                }
            }
        }
        .navigationTitle("App Store Icon")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if term.isEmpty {
                term = initialTerm
                if !term.isEmpty { await runSearch() }
            }
        }
    }

    @MainActor
    private func runSearch() async {
        let query = term.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isSearching = true
        results = await AppStoreIcons.search(query)
        isSearching = false
        didSearch = true
    }

    @MainActor
    private func pick(_ item: AppStoreIcons.Item) async {
        downloadingID = item.id
        if let data = await AppStoreIcons.imageData(for: item) {
            onPick(data)
            dismiss()
        }
        downloadingID = nil
    }
}
