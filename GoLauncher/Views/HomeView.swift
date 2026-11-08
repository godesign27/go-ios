import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: LauncherStore
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var isSearching = false
    @State private var isEditing = false
    @State private var activeSheet: ActiveSheet?
    @State private var pendingDelete: LauncherApp?
    @State private var launchError: String?
    @StateObject private var weather = WeatherService()

    private var theme: Theme { store.state.theme }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: theme.iconSpacing, alignment: .top), count: max(theme.columns, 1))
    }

    private var showsDock: Bool { store.state.showDock && !store.dockApps.isEmpty }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if theme.showWidgets {
                        WidgetsRow(weather: weather, theme: theme) { launch($0) }
                    }
                    ForEach(store.visibleSections) { section in
                        switch section {
                        case .smart(let kind):
                            smartSection(kind)
                        case .group(let group):
                            groupSection(group)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                // Room for the search button (and dock) so the last row isn't covered.
                .padding(.bottom, showsDock ? 190 : 96)
            }

            VStack(alignment: .trailing, spacing: 12) {
                if !isEditing {
                    searchButton
                }
                if showsDock {
                    dock
                }
            }
            .padding(.horizontal, showsDock ? 12 : 20)
            .padding(.bottom, showsDock ? 4 : 16)

            if isSearching {
                SearchOverlay(
                    theme: theme,
                    onLaunch: { app, query in
                        store.addRecentSearch(query)
                        launch(app)
                    },
                    onWebSearch: { query in
                        store.addRecentSearch(query)
                        webSearch(query)
                    },
                    onClose: { withAnimation(.snappy) { isSearching = false } }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(1)
            }
        }
        .background { WallpaperView(theme: theme) }
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .animation(.snappy, value: store.state.apps)
        .animation(.snappy, value: store.state.groups)
        .animation(.snappy, value: store.state.sectionOrder)
        .sheet(item: $activeSheet) { sheet in
            sheetContent(sheet)
                .environmentObject(store)
        }
        .confirmationDialog(
            "Remove \(pendingDelete?.name ?? "app")?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove from Go", role: .destructive) {
                if let app = pendingDelete { store.delete(app.id) }
                pendingDelete = nil
            }
        } message: {
            Text("This only removes the icon from your launcher. The real app stays on your iPhone.")
        }
        .alert(
            "Couldn't open app",
            isPresented: Binding(get: { launchError != nil }, set: { if !$0 { launchError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(launchError ?? "")
        }
        .onOpenURL(perform: handleIncomingURL)
        .onAppear {
            if theme.searchOnOpen { openSearch() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if theme.searchOnOpen { openSearch() }
                if theme.showWidgets, theme.leftWidget == .weather || theme.rightWidget == .weather {
                    weather.refreshIfNeeded()
                }
            case .background:
                store.saveNow()
            default:
                break
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            if theme.showClock {
                TimelineView(.everyMinute) { context in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(context.date, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.system(size: 15, weight: .semibold, design: theme.fontStyle.design))
                            .opacity(0.8)
                        Text(context.date, format: .dateTime.hour().minute())
                            .font(.system(size: 46, weight: .bold, design: theme.fontStyle.design))
                            .monospacedDigit()
                    }
                }
            }
            Spacer()
            if isEditing {
                Button("Done") {
                    withAnimation { isEditing = false }
                }
                .font(.system(.body, design: theme.fontStyle.design).weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(theme.labelColor.opacity(0.25))
                .foregroundStyle(theme.labelColor)
            } else {
                Menu {
                    Button { activeSheet = .add(nil) } label: { Label("Add App", systemImage: "plus.app") }
                    Button { withAnimation { isEditing = true } } label: { Label("Edit Layout", systemImage: "square.grid.2x2") }
                    Button { activeSheet = .groups } label: { Label("Groups & Dock", systemImage: "rectangle.3.group") }
                    Button { activeSheet = .theme } label: { Label("Design", systemImage: "paintpalette") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Options")
            }
        }
        .foregroundStyle(theme.labelColor)
        .shadow(color: .black.opacity(theme.isDark ? 0.25 : 0), radius: 3, y: 1)
        .padding(.bottom, 4)
    }

    // MARK: - Search button

    private var searchButton: some View {
        Button(action: openSearch) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(theme.labelColor)
                .frame(width: 58, height: 58)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search apps")
    }

    private func openSearch() {
        withAnimation(.snappy) { isSearching = true }
    }

    // MARK: - Sections

    private func sectionHeader(title: String, symbol: String?, count: Int?, collapsed: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .bold))
                        .opacity(0.75)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: theme.fontStyle.design))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 13, weight: .medium, design: theme.fontStyle.design))
                        .opacity(0.6)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .rotationEffect(.degrees(collapsed ? -90 : 0))
                    .opacity(0.6)
            }
            .foregroundStyle(theme.labelColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(theme.showGroupCards ? 14 : (theme.iconSpacing < 1 ? 0 : 4))
            .background {
                if theme.showGroupCards {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
    }

    private func smartApps(_ kind: SmartSection) -> [LauncherApp] {
        switch kind {
        case .recent: return store.recentApps(limit: theme.columns * 2) // two rows
        case .favorites: return store.allFavoriteApps
        case .mostUsed: return store.mostUsedApps(limit: theme.columns)
        case .attention: return store.attentionApps
        }
    }

    private func smartSection(_ kind: SmartSection) -> some View {
        let apps = smartApps(kind)
        let collapsed = store.isSectionCollapsed(kind.rawValue)
        let showCount = (collapsed || kind == .attention || kind == .favorites) && !apps.isEmpty
        return sectionCard {
            sectionHeader(title: kind.title, symbol: kind.symbol, count: showCount ? apps.count : nil, collapsed: collapsed) {
                store.toggleSection(kind.rawValue)
            }
            if !collapsed {
                if apps.isEmpty {
                    Text(kind.emptyText)
                        .font(.footnote)
                        .foregroundStyle(theme.labelColor.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVGrid(columns: columns, spacing: theme.rowSpacing) {
                        ForEach(apps) { app in
                            Button {
                                if isEditing { activeSheet = .edit(app) } else { launch(app) }
                            } label: {
                                AppIconView(app: app, theme: theme)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { contextMenu(for: app) }
                        }
                    }
                }
            }
        }
    }

    private func groupSection(_ group: AppGroup) -> some View {
        let apps = store.apps(in: group.id)
        return sectionCard {
            sectionHeader(title: group.name, symbol: nil, count: group.isCollapsed ? apps.count : nil, collapsed: group.isCollapsed) {
                store.toggleCollapsed(group.id)
            }
            .dropDestination(for: String.self) { items, _ in
                dropApp(items) { store.move(appID: $0, toGroup: group.id) }
            }

            if !group.isCollapsed {
                LazyVGrid(columns: columns, spacing: theme.rowSpacing) {
                    ForEach(apps) { app in
                        iconCell(app)
                    }
                    if isEditing {
                        addTile(groupID: group.id)
                    }
                }
                if apps.isEmpty && !isEditing {
                    Text("Empty. Drag apps here or tap ••• › Edit Layout.")
                        .font(.footnote)
                        .foregroundStyle(theme.labelColor.opacity(0.6))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .dropDestination(for: String.self) { items, _ in
                            dropApp(items) { store.move(appID: $0, toGroup: group.id) }
                        }
                }
            }
        }
    }

    private func iconCell(_ app: LauncherApp) -> some View {
        Button {
            if isEditing {
                activeSheet = .edit(app)
            } else {
                launch(app)
            }
        } label: {
            AppIconView(app: app, theme: theme)
                .overlay(alignment: .topLeading) {
                    if isEditing {
                        Button {
                            pendingDelete = app
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .gray)
                                .font(.system(size: 20))
                        }
                        .offset(x: -4, y: -4)
                        .accessibilityLabel("Remove \(app.name)")
                    }
                }
                .modifier(Wiggle(active: isEditing))
        }
        .buttonStyle(.plain)
        .contextMenu { contextMenu(for: app) }
        .draggable(app.id.uuidString) {
            AppIconView(app: app, theme: theme, showLabel: false)
                .frame(width: theme.iconSize)
                .environmentObject(store)
        }
        .dropDestination(for: String.self) { items, _ in
            dropApp(items) { store.move(appID: $0, onto: app.id) }
        }
    }

    private func addTile(groupID: UUID) -> some View {
        Button {
            activeSheet = .add(groupID)
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: theme.iconSize * theme.cornerFactor, style: .continuous)
                    .strokeBorder(theme.labelColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .overlay(Image(systemName: "plus").font(.system(size: 20, weight: .semibold)))
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: theme.fillCells ? .infinity : theme.iconSize)
                if theme.showLabels {
                    Text("Add")
                        .font(.system(size: 12, weight: .medium, design: theme.fontStyle.design))
                }
            }
            .foregroundStyle(theme.labelColor.opacity(0.8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add app to group")
    }

    @ViewBuilder
    private func contextMenu(for app: LauncherApp) -> some View {
        Button { activeSheet = .edit(app) } label: { Label("Edit Icon", systemImage: "pencil") }
        Button { store.toggleFavorite(app.id) } label: {
            Label(store.isFavorite(app.id) ? "Remove from Favorites" : "Add to Favorites",
                  systemImage: store.isFavorite(app.id) ? "star.slash" : "star")
        }
        Button { store.toggleAttention(app.id) } label: {
            Label(app.needsAttention ? "Clear Needs Attention" : "Needs Attention",
                  systemImage: app.needsAttention ? "flag.slash" : "flag")
        }
        if store.state.showDock {
            Button { store.toggleDock(app.id) } label: {
                Label(app.isDocked ? "Remove from Dock" : "Add to Dock", systemImage: "dock.rectangle")
            }
        }
        Menu {
            ForEach(store.state.groups) { group in
                Button(group.name) { store.move(appID: app.id, toGroup: group.id) }
                    .disabled(group.id == app.groupID)
            }
        } label: {
            Label("Move to Group", systemImage: "folder")
        }
        Button { withAnimation { isEditing = true } } label: { Label("Edit Layout", systemImage: "square.grid.2x2") }
        Divider()
        Button(role: .destructive) { pendingDelete = app } label: { Label("Remove", systemImage: "trash") }
    }

    private func dropApp(_ items: [String], perform: (UUID) -> Void) -> Bool {
        guard let first = items.first, let id = UUID(uuidString: first) else { return false }
        withAnimation(.snappy) { perform(id) }
        return true
    }

    // MARK: - Dock (optional, ••• › Groups & Dock)

    private var dock: some View {
        HStack(spacing: 0) {
            ForEach(store.dockApps) { app in
                Button { launch(app) } label: {
                    AppIconView(app: app, theme: theme, showLabel: false)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .contextMenu { contextMenu(for: app) }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    // MARK: - Sheets

    enum ActiveSheet: Identifiable {
        case add(UUID?)
        case edit(LauncherApp)
        case groups
        case theme

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let app): return "edit-\(app.id)"
            case .groups: return "groups"
            case .theme: return "theme"
            }
        }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .add(let groupID):
            AddAppView(preselectedGroup: groupID)
        case .edit(let app):
            NavigationStack {
                AppEditorView(app: app, isNew: false) { activeSheet = nil }
            }
        case .groups:
            GroupsView()
        case .theme:
            ThemeView()
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
    }

    // MARK: - Launching

    private func launch(_ app: LauncherApp) {
        guard let url = app.launch.resolvedURL else {
            launchError = "\(app.name) doesn't have a link set yet. Long-press it and choose Edit Icon."
            return
        }
        openURL(url) { accepted in
            if accepted {
                store.recordLaunch(app.id)
                withAnimation(.snappy) { isSearching = false }
            } else {
                launchError = "iOS couldn't open \(app.name). The app may not be installed, or its link changed. Edit the icon and try the Shortcut option instead."
            }
        }
    }

    private func webSearch(_ query: String) {
        var components = URLComponents()
        components.scheme = "x-web-search"
        components.host = ""
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        if let url = components.url { openURL(url) }
    }

    /// golauncher://search        → opens straight into search
    /// golauncher://open?name=X   → opens the best match for X
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "golauncher" else { return }
        switch url.host {
        case "search":
            openSearch()
        case "open":
            let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "name" })?.value ?? ""
            if let app = store.search(name).first { launch(app) }
        default:
            break
        }
    }
}

/// Full-screen search that opens from the search button: recent searches, suggestions, live results.
struct SearchOverlay: View {
    @EnvironmentObject private var store: LauncherStore
    let theme: Theme
    let onLaunch: (LauncherApp, String) -> Void
    let onWebSearch: (String) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @FocusState private var focused: Bool

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: theme.iconSpacing, alignment: .top), count: max(theme.columns, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search apps", text: $query)
                        .focused($focused)
                        .submitLabel(.go)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit(launchTopResult)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Cancel", action: onClose)
                    .foregroundStyle(theme.labelColor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        recentSearches
                        suggestions
                    } else {
                        results
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .font(.system(.body, design: theme.fontStyle.design))
        .foregroundStyle(theme.labelColor)
        .background {
            ZStack {
                WallpaperView(theme: theme)
                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { focused = true }
        }
    }

    @ViewBuilder
    private var recentSearches: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Recent Searches").font(.system(size: 15, weight: .semibold, design: theme.fontStyle.design))
                Spacer()
                if !store.state.recentSearches.isEmpty {
                    Button("Clear") { store.clearRecentSearches() }
                        .font(.system(size: 14, weight: .medium))
                        .opacity(0.75)
                }
            }
            .padding(.bottom, 4)

            if store.state.recentSearches.isEmpty {
                Text("Your searches will show up here.")
                    .font(.footnote)
                    .opacity(0.6)
            } else {
                ForEach(store.state.recentSearches, id: \.self) { recent in
                    HStack(spacing: 12) {
                        Button {
                            query = recent
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath").opacity(0.6)
                                Text(recent)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button {
                            store.removeRecentSearch(recent)
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).opacity(0.5)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(recent) from recent searches")
                    }
                    .padding(.vertical, 10)
                    Divider().opacity(0.4)
                }
            }
        }
    }

    @ViewBuilder
    private var suggestions: some View {
        let recentApps = store.recentApps(limit: theme.columns)
        if !recentApps.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Suggestions").font(.system(size: 15, weight: .semibold, design: theme.fontStyle.design))
                LazyVGrid(columns: columns, spacing: theme.rowSpacing) {
                    ForEach(recentApps) { app in
                        Button { onLaunch(app, "") } label: { AppIconView(app: app, theme: theme) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        let matches = store.search(query)
        if matches.isEmpty {
            Text("No apps match “\(query)”")
                .opacity(0.7)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        } else {
            LazyVGrid(columns: columns, spacing: theme.rowSpacing) {
                ForEach(matches) { app in
                    Button { onLaunch(app, query) } label: { AppIconView(app: app, theme: theme) }
                        .buttonStyle(.plain)
                }
            }
            Text("Press Go to open \(matches[0].name)")
                .font(.footnote)
                .opacity(0.6)
                .frame(maxWidth: .infinity)
        }
        Button {
            onWebSearch(query)
        } label: {
            Label("Search the web for “\(query)”", systemImage: "safari")
                .font(.system(.subheadline, design: theme.fontStyle.design).weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func launchTopResult() {
        if let first = store.search(query).first { onLaunch(first, query) }
    }
}

/// The background: gradient, optionally with a photo wallpaper on top.
struct WallpaperView: View {
    @EnvironmentObject private var store: LauncherStore
    let theme: Theme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: theme.backgroundTopHex), Color(hex: theme.backgroundBottomHex)],
                startPoint: .top,
                endPoint: .bottom
            )
            if let name = theme.wallpaperFilename, let image = store.image(named: name) {
                Color.clear
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                Color.black.opacity(theme.wallpaperDim)
            }
        }
        .ignoresSafeArea()
    }
}

/// The edit-mode jiggle.
private struct Wiggle: ViewModifier {
    let active: Bool
    @State private var phase = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active ? (phase ? 1.6 : -1.6) : 0))
            .onChange(of: active, initial: true) { _, isActive in
                if isActive {
                    withAnimation(.easeInOut(duration: 0.13).repeatForever(autoreverses: true)) { phase = true }
                } else {
                    withAnimation(.default) { phase = false }
                }
            }
    }
}
