import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: LauncherStore
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var isEditing = false
    @State private var activeSheet: ActiveSheet?
    @State private var pendingDelete: LauncherApp?
    @State private var launchError: String?

    private var theme: Theme { store.state.theme }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: max(theme.columns, 1))
    }

    private var results: [LauncherApp] { store.search(query) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                searchBar
                if query.isEmpty {
                    groupsContent
                } else {
                    searchContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .background { WallpaperView(theme: theme) }
        .preferredColorScheme(theme.isDark ? .dark : .light)
        .animation(.snappy, value: store.state.apps)
        .animation(.snappy, value: store.state.groups)
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
            if theme.searchOnOpen { focusSearchSoon() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                if theme.searchOnOpen {
                    query = ""
                    focusSearchSoon()
                }
            case .background:
                store.saveNow()
            default:
                break
            }
        }
    }

    // MARK: - Header & search

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
                    Button { activeSheet = .groups } label: { Label("Groups", systemImage: "folder") }
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
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search apps", text: $query)
                    .focused($searchFocused)
                    .submitLabel(.go)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit(launchTopResult)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if searchFocused {
                Button("Cancel") {
                    query = ""
                    searchFocused = false
                }
                .foregroundStyle(theme.labelColor)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: searchFocused)
    }

    // MARK: - Grouped grid

    /// Recently Used and Most Used first, then your groups, then Needs Attention.
    @ViewBuilder
    private var groupsContent: some View {
        smartSection(.recent, apps: store.recentApps(limit: theme.columns))
        smartSection(.mostUsed, apps: store.mostUsedApps(limit: theme.columns))
        ForEach(store.state.groups) { group in
            groupSection(group)
        }
        smartSection(.attention, apps: store.attentionApps)
    }

    // MARK: - Automatic sections

    enum SmartSection: String {
        case recent, mostUsed, attention

        var title: String {
            switch self {
            case .recent: return "Recently Used"
            case .mostUsed: return "Most Used"
            case .attention: return "Needs Attention"
            }
        }

        var symbol: String {
            switch self {
            case .recent: return "clock.arrow.circlepath"
            case .mostUsed: return "flame.fill"
            case .attention: return "flag.fill"
            }
        }

        var emptyText: String {
            switch self {
            case .recent, .mostUsed: return "Apps you open from Go will show up here."
            case .attention: return "Long-press an app and choose Needs Attention to flag it here."
            }
        }
    }

    private func smartSection(_ kind: SmartSection, apps: [LauncherApp]) -> some View {
        let collapsed = store.isSectionCollapsed(kind.rawValue)
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                store.toggleSection(kind.rawValue)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: kind.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .opacity(0.75)
                    Text(kind.title)
                        .font(.system(size: 15, weight: .semibold, design: theme.fontStyle.design))
                    if (collapsed || kind == .attention) && !apps.isEmpty {
                        Text("\(apps.count)")
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

            if !collapsed {
                if apps.isEmpty {
                    Text(kind.emptyText)
                        .font(.footnote)
                        .foregroundStyle(theme.labelColor.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
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
        .padding(theme.showGroupCards ? 14 : 4)
        .background {
            if theme.showGroupCards {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
    }

    private func groupSection(_ group: AppGroup) -> some View {
        let apps = store.apps(in: group.id)
        return VStack(alignment: .leading, spacing: 12) {
            Button {
                store.toggleCollapsed(group.id)
            } label: {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.system(size: 15, weight: .semibold, design: theme.fontStyle.design))
                    if group.isCollapsed {
                        Text("\(apps.count)")
                            .font(.system(size: 13, weight: .medium, design: theme.fontStyle.design))
                            .opacity(0.6)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .rotationEffect(.degrees(group.isCollapsed ? -90 : 0))
                        .opacity(0.6)
                }
                .foregroundStyle(theme.labelColor)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .dropDestination(for: String.self) { items, _ in
                dropApp(items) { store.move(appID: $0, toGroup: group.id) }
            }

            if !group.isCollapsed {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(apps) { app in
                        iconCell(app)
                    }
                    if isEditing {
                        addTile(groupID: group.id)
                    }
                }
                if apps.isEmpty && !isEditing {
                    Text("Empty — drag apps here or tap ••• › Edit Layout")
                        .font(.footnote)
                        .foregroundStyle(theme.labelColor.opacity(0.6))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .dropDestination(for: String.self) { items, _ in
                            dropApp(items) { store.move(appID: $0, toGroup: group.id) }
                        }
                }
            }
        }
        .padding(theme.showGroupCards ? 14 : 4)
        .background {
            if theme.showGroupCards {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
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
                    .frame(maxWidth: theme.iconSize)
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
        Button { store.toggleAttention(app.id) } label: {
            Label(app.needsAttention ? "Clear Needs Attention" : "Needs Attention",
                  systemImage: app.needsAttention ? "flag.slash" : "flag")
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

    // MARK: - Search results

    @ViewBuilder
    private var searchContent: some View {
        let matches = results
        if matches.isEmpty {
            Text("No apps match “\(query)”")
                .font(.system(.subheadline, design: theme.fontStyle.design))
                .foregroundStyle(theme.labelColor.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(matches) { app in
                    Button { launch(app) } label: { AppIconView(app: app, theme: theme) }
                        .buttonStyle(.plain)
                        .contextMenu { contextMenu(for: app) }
                }
            }
            .padding(theme.showGroupCards ? 14 : 4)
            .background {
                if theme.showGroupCards {
                    RoundedRectangle(cornerRadius: 24, style: .continuous).fill(.ultraThinMaterial)
                }
            }
            Text("Press Go to open \(matches[0].name)")
                .font(.footnote)
                .foregroundStyle(theme.labelColor.opacity(0.6))
                .frame(maxWidth: .infinity)
        }

        Button {
            var components = URLComponents()
            components.scheme = "x-web-search"
            components.host = ""
            components.queryItems = [URLQueryItem(name: "q", value: query)]
            if let url = components.url { openURL(url) }
        } label: {
            Label("Search the web for “\(query)”", systemImage: "safari")
                .font(.system(.subheadline, design: theme.fontStyle.design).weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.labelColor)
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
                query = ""
                searchFocused = false
            } else {
                launchError = "iOS couldn't open \(app.name). The app may not be installed, or its link changed. Edit the icon and try the Shortcut option instead."
            }
        }
    }

    private func launchTopResult() {
        if let first = results.first { launch(first) }
    }

    private func focusSearchSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { searchFocused = true }
    }

    /// golauncher://search        → opens straight into search
    /// golauncher://open?name=X   → opens the best match for X
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "golauncher" else { return }
        switch url.host {
        case "search":
            query = ""
            focusSearchSoon()
        case "open":
            let name = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "name" })?.value ?? ""
            if let app = store.search(name).first { launch(app) }
        default:
            break
        }
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
