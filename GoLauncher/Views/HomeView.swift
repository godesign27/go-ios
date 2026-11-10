import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: LauncherStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The theme's columns, at most 3 at accessibility text sizes so names have room.
    private var columnCount: Int {
        dynamicTypeSize.isAccessibilitySize ? min(theme.columns, 3) : theme.columns
    }
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var designDetent: PresentationDetent = .large

    @State private var isSearching = false
    @State private var viewAllKey: String?
    @State private var viewAllQuery = ""
    @FocusState private var viewAllFocused: Bool
    @State private var isEditing = false
    @State private var activeSheet: ActiveSheet?
    @State private var pendingDelete: LauncherApp?
    @State private var launchError: String?
    @State private var askingName = false
    @State private var nameDraft = ""
    @State private var failedApp: LauncherApp?
    /// Set when a widget, control, Siri or a link opened GO, so the start screen stays out of the way.
    @State private var openedForRequest = false
    @State private var backgroundedAt: Date?
    /// Back after this long in the background counts as opening GO again (start screen shows).
    private static let startScreenAfter: TimeInterval = 5 * 60
    @StateObject private var weather = WeatherService()

    private var theme: Theme { store.state.theme }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: theme.iconSpacing, alignment: .top), count: max(columnCount, 1))
    }

    private var showsDock: Bool { store.state.showDock && !store.dockApps.isEmpty }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if store.state.setup.announcementPending && !isEditing {
                        announcementCard
                    }
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

            GlassGroup(spacing: 16) {
                VStack(alignment: .trailing, spacing: 12) {
                    if !isEditing {
                        searchButton
                    }
                    if showsDock {
                        dock
                    }
                }
            }
            .padding(.horizontal, showsDock ? 12 : 20)
            .padding(.bottom, showsDock ? 4 : 16)

            if let key = viewAllKey {
                viewAllOverlay(key)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .zIndex(1)
            }

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
        .environment(\.legibility, WallpaperView.legibility(theme: theme, store: store))
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
        .alert(
            "Couldn't open \(failedApp?.name ?? "app")",
            isPresented: Binding(get: { failedApp != nil }, set: { if !$0 { failedApp = nil } })
        ) {
            Button("Fix Link") {
                if let app = failedApp { activeSheet = .edit(app) }
                failedApp = nil
            }
            Button("Cancel", role: .cancel) { failedApp = nil }
        } message: {
            Text("iOS couldn't open it. The app may not be installed, or its link changed. Tap Fix Link to change the link, or set it to run a Shortcut with Open App, which works for any app.")
        }
        .onOpenURL(perform: handleIncomingURL)
        .onAppear {
            handleWidgetRequestSoon()
            showStartScreenSoon()
            if theme.searchOnOpen && store.state.setup.startScreen == .classicLauncher { openSearch() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                store.mergeWidgetLaunches()
                handleWidgetRequestSoon()
                if let since = backgroundedAt, Date().timeIntervalSince(since) > Self.startScreenAfter {
                    showStartScreenSoon()
                }
                backgroundedAt = nil
                store.syncInstalledApps()
                if theme.searchOnOpen { openSearch() }
                if theme.showWidgets, theme.leftWidget == .weather || theme.rightWidget == .weather {
                    weather.refreshIfNeeded()
                }
            case .background:
                backgroundedAt = Date()
                store.saveNow()
            default:
                break
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            if theme.showsHeaderClock {
                TimelineView(.everyMinute) { context in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(context.date, format: .dateTime.weekday(.wide).month(.wide).day())
                            .scaledFont(size: 15, weight: .semibold, design: theme.fontStyle.design, relativeTo: .body)
                            .opacity(Theme.secondaryOpacity)
                        Text(context.date, format: .dateTime.hour().minute())
                            .scaledFont(size: 46, weight: .bold, design: theme.fontStyle.design, relativeTo: .largeTitle, maxSize: 72)
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                }
            } else {
                greeting
            }
            Spacer()
            if isEditing {
                Button("Done") {
                    withAnimation { isEditing = false }
                }
                .font(.system(.body, design: theme.fontStyle.design).weight(.semibold))
                .glassButtonStyle(prominent: true)
            } else {
                Menu {
                    Button { openGoHome() } label: { Label("Set Up GO Home Screen", systemImage: "iphone.gen3") }
                    Divider()
                    Button { activeSheet = .add(nil) } label: { Label("Add App", systemImage: "plus.app") }
                    Button { withAnimation { isEditing = true } } label: { Label("Edit Layout", systemImage: "square.grid.2x2") }
                    Button { activeSheet = .groups } label: { Label("Groups & Dock", systemImage: "rectangle.3.group") }
                    Button { activeSheet = .theme } label: { Label("Design", systemImage: "paintpalette") }
                } label: {
                    // Everything in this menu customizes the home screen.
                    Image(systemName: "slider.horizontal.3")
                        .scaledFont(size: 17, weight: .semibold, relativeTo: .body, maxSize: 24)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .glassSurface(in: Circle(), interactive: true)
                }
                .accessibilityLabel("Customize")
            }
        }
        .foregroundStyle(theme.labelColor)
        .shadow(color: .black.opacity(theme.isDark ? 0.25 : 0), radius: 3, y: 1)
        .padding(.bottom, 4)
    }

    // MARK: - Greeting

    /// Fills the top-left when the big clock is hidden. Tap to set or change your name.
    private var greeting: some View {
        Button {
            nameDraft = theme.userName
            askingName = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(theme.userName.isEmpty ? "Hello" : "Hello, \(theme.userName)")
                    .scaledFont(size: 34, weight: .bold, design: theme.fontStyle.design, relativeTo: .largeTitle, maxSize: 56)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if theme.userName.isEmpty {
                    Text("Tap to add your name")
                        .scaledFont(size: 13, weight: .medium, design: theme.fontStyle.design, relativeTo: .footnote)
                        .opacity(Theme.secondaryOpacity)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Changes the name in your greeting")
        .alert("What should Go call you?", isPresented: $askingName) {
            TextField("Your name", text: $nameDraft)
                .textInputAutocapitalization(.words)
            Button("Save") {
                store.state.theme.userName = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It's shown in your greeting and stays on this iPhone.")
        }
    }

    // MARK: - Search button

    private var searchButton: some View {
        Button(action: openSearch) {
            Image(systemName: "magnifyingglass")
                .scaledFont(size: 22, weight: .semibold, relativeTo: .title3, maxSize: 30)
                .foregroundStyle(theme.labelColor)
                .frame(width: 56, height: 56)
                .contentShape(Circle())
                .glassSurface(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search apps")
    }

    private func openSearch() {
        withAnimation(.snappy) { isSearching = true }
    }

    // MARK: - Sections

    private func sectionHeader(
        title: String,
        symbol: String?,
        count: Int?,
        collapsed: Bool,
        viewAll: (() -> Void)? = nil,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Button(action: action) {
                HStack(spacing: 6) {
                    if let symbol {
                        Image(systemName: symbol)
                            .scaledFont(size: 12, weight: .bold, relativeTo: .caption, maxSize: 24)
                            .opacity(Theme.secondaryOpacity)
                    }
                    Text(title)
                        .scaledFont(size: 15, weight: .semibold, design: theme.fontStyle.design, relativeTo: .body)
                        .lineLimit(2)
                    if let count {
                        Text("\(count)")
                            .scaledFont(size: 13, weight: .medium, design: theme.fontStyle.design, relativeTo: .footnote)
                            .opacity(Theme.secondaryOpacity)
                    }
                    Spacer(minLength: 0)
                }
                // 44pt tall tap target (Apple's minimum) without making the header taller.
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, -12)
            // VoiceOver: "Favorites, 4 apps, heading, expanded" — headings let the rotor jump between sections.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(count.map { "\(title), \($0) \($0 == 1 ? "app" : "apps")" } ?? title)
            .accessibilityValue(collapsed ? "Collapsed" : "Expanded")
            .accessibilityHint(collapsed ? "Shows this section" : "Hides this section")
            .accessibilityAddTraits([.isHeader, .isButton])

            if let viewAll, !collapsed {
                Button(action: viewAll) {
                    Text("View All")
                        .scaledFont(size: 13, weight: .semibold, design: theme.fontStyle.design, relativeTo: .footnote)
                        .opacity(Theme.secondaryOpacity)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, -12)
            }

            Button(action: action) {
                Image(systemName: "chevron.down")
                    .scaledFont(size: 12, weight: .bold, relativeTo: .caption, maxSize: 20)
                    .rotationEffect(.degrees(collapsed ? -90 : 0))
                    .opacity(Theme.secondaryOpacity)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // 44pt target without making the header taller.
            .padding(.vertical, -10)
            .padding(.trailing, -10)
            // The title already toggles the section for VoiceOver.
            .accessibilityHidden(true)
        }
        .foregroundStyle(theme.labelColor)
    }

    private func sectionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12, content: content)
            .padding(theme.showGroupCards ? 14 : (theme.iconSpacing < 1 ? 0 : 4))
            .modifier(SectionCardSurface(theme: theme))
    }

    // MARK: - Swipe rows / grid

    private var usesRows: Bool { theme.sectionLayout == .rows }

    /// Rows shown for a section before swiping (Recently Used and Favorites get two).
    private func rowCount(for key: String) -> Int {
        key == SmartSection.recent.rawValue || key == SmartSection.favorites.rawValue ? 2 : 1
    }

    /// Splits a strip into columns, page by page: each screenful fills its top row first,
    /// so a short list stays one tidy row instead of a lopsided block.
    private func stripColumns(count: Int, rows: Int) -> [[Int]] {
        guard rows > 1 else { return (0..<count).map { [$0] } }
        let cols = max(columnCount, 1)
        let pageSize = cols * rows
        var result: [[Int]] = []
        var pageStart = 0
        while pageStart < count {
            let pageCount = min(pageSize, count - pageStart)
            for column in 0..<min(cols, pageCount) {
                let indices = (0..<rows)
                    .map { pageStart + $0 * cols + column }
                    .filter { $0 < pageStart + pageCount }
                result.append(indices)
            }
            pageStart += pageSize
        }
        return result
    }

    /// How many apps fit without swiping or "View All".
    private func visibleCount(for key: String) -> Int {
        columnCount * rowCount(for: key)
    }

    /// Apps in a section: everything in Rows mode (you swipe), a fixed amount in Grid mode.
    private func smartApps(_ kind: SmartSection, all: Bool = false) -> [LauncherApp] {
        switch kind {
        case .recent: return store.recentApps(limit: all || usesRows ? 40 : columnCount * 2)
        case .favorites: return store.allFavoriteApps
        case .mostUsed: return store.mostUsedApps(limit: all || usesRows ? 40 : columnCount)
        case .attention: return store.attentionApps
        }
    }

    private func appLayout<Cell: View>(
        _ apps: [LauncherApp],
        rows: Int,
        cell: @escaping (LauncherApp) -> Cell
    ) -> some View {
        appLayout(apps, rows: rows, trailing: { EmptyView() }, cell: cell)
    }

    /// Lays apps out as a swipeable strip (Rows) or a wrapping grid (Grid).
    /// `trailing` adds an extra item at the end (the "Add" tile in Edit Layout).
    @ViewBuilder
    private func appLayout<Cell: View, Trailing: View>(
        _ apps: [LauncherApp],
        rows: Int,
        @ViewBuilder trailing: () -> Trailing,
        cell: @escaping (LauncherApp) -> Cell
    ) -> some View {
        if usesRows {
            let columnIndices = stripColumns(count: apps.count, rows: rows)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: theme.iconSpacing) {
                    ForEach(Array(columnIndices.enumerated()), id: \.offset) { _, column in
                        VStack(spacing: theme.rowSpacing) {
                            ForEach(column, id: \.self) { index in
                                cell(apps[index])
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .top)
                        // A sliver of the next column peeks in so it's clear you can swipe.
                        .containerRelativeFrame(.horizontal, count: columnCount * 10 + 3, span: 10, spacing: theme.iconSpacing)
                    }
                    trailing()
                        .containerRelativeFrame(.horizontal, count: columnCount * 10 + 3, span: 10, spacing: theme.iconSpacing)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        } else {
            LazyVGrid(columns: columns, spacing: theme.rowSpacing) {
                ForEach(apps) { app in
                    cell(app)
                }
                trailing()
            }
        }
    }

    private func smartSection(_ kind: SmartSection) -> some View {
        let apps = smartApps(kind)
        let collapsed = store.isSectionCollapsed(kind.rawValue)
        let showCount = (collapsed || kind == .attention || kind == .favorites) && !apps.isEmpty
        let overflow = apps.count > visibleCount(for: kind.rawValue)
        return sectionCard {
            sectionHeader(
                title: kind.title,
                symbol: kind.symbol,
                count: showCount ? apps.count : nil,
                collapsed: collapsed,
                viewAll: overflow && usesRows ? { openViewAll(kind.rawValue) } : nil
            ) {
                store.toggleSection(kind.rawValue)
            }
            if !collapsed {
                if apps.isEmpty {
                    Text(kind.emptyText)
                        .font(.footnote)
                        .foregroundStyle(theme.labelColor.opacity(Theme.secondaryOpacity))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    appLayout(apps, rows: rowCount(for: kind.rawValue)) { app in
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

    private func groupSection(_ group: AppGroup) -> some View {
        let apps = store.apps(in: group.id)
        let key = group.id.uuidString
        let overflow = apps.count > visibleCount(for: key)
        return sectionCard {
            sectionHeader(
                title: group.name,
                symbol: nil,
                count: group.isCollapsed || (usesRows && overflow) ? apps.count : nil,
                collapsed: group.isCollapsed,
                viewAll: overflow && usesRows ? { openViewAll(key) } : nil
            ) {
                store.toggleCollapsed(group.id)
            }
            .dropDestination(for: String.self) { items, _ in
                dropApp(items) { store.move(appID: $0, toGroup: group.id) }
            }

            if !group.isCollapsed {
                appLayout(apps, rows: 1, trailing: {
                    if isEditing {
                        addTile(groupID: group.id)
                    }
                }) { app in
                    iconCell(app)
                }
                if apps.isEmpty && !isEditing {
                    Text("Empty. Drag apps here or tap ••• › Edit Layout.")
                        .font(.footnote)
                        .foregroundStyle(theme.labelColor.opacity(Theme.secondaryOpacity))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .dropDestination(for: String.self) { items, _ in
                            dropApp(items) { store.move(appID: $0, toGroup: group.id) }
                        }
                }
            }
        }
    }

    // MARK: - View All

    private func openViewAll(_ key: String) {
        viewAllQuery = ""
        withAnimation(.snappy) { viewAllKey = key }
    }

    private func closeViewAll() {
        viewAllFocused = false
        withAnimation(.snappy) { viewAllKey = nil }
    }

    private func viewAllContent(_ key: String) -> (title: String, symbol: String?, apps: [LauncherApp])? {
        if let kind = SmartSection(rawValue: key) {
            return (kind.title, kind.symbol, smartApps(kind, all: true))
        }
        if let group = store.state.groups.first(where: { $0.id.uuidString == key }) {
            return (group.name, nil, store.apps(in: group.id))
        }
        return nil
    }

    /// Full-screen list of every app in one section. Over four rows, a search bar appears at the bottom.
    @ViewBuilder
    private func viewAllOverlay(_ key: String) -> some View {
        if let content = viewAllContent(key) {
            let needsSearch = content.apps.count > columnCount * 4
            let q = viewAllQuery.trimmingCharacters(in: .whitespaces).lowercased()
            let shown = q.isEmpty ? content.apps : content.apps.filter {
                $0.name.lowercased().contains(q) || $0.keywords.lowercased().contains(q)
            }
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    if let symbol = content.symbol {
                        Image(systemName: symbol).scaledFont(size: 16, weight: .bold, relativeTo: .body).opacity(Theme.secondaryOpacity)
                    }
                    Text(content.title)
                        .scaledFont(size: 28, weight: .bold, design: theme.fontStyle.design, relativeTo: .largeTitle, maxSize: 44)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text("\(content.apps.count)")
                        .scaledFont(size: 17, weight: .semibold, design: theme.fontStyle.design, relativeTo: .body)
                        .opacity(Theme.secondaryOpacity)
                    Spacer()
                    Button("Done", action: closeViewAll)
                        .scaledFont(size: 17, weight: .semibold, design: theme.fontStyle.design, relativeTo: .body)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: theme.rowSpacing) {
                        ForEach(shown) { app in
                            Button { launch(app) } label: { AppIconView(app: app, theme: theme) }
                                .buttonStyle(.plain)
                                .contextMenu { contextMenu(for: app) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    if shown.isEmpty {
                        Text("No apps match “\(viewAllQuery)”").opacity(Theme.secondaryOpacity).padding(.top, 20)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .foregroundStyle(theme.labelColor)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if needsSearch {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search \(content.title)", text: $viewAllQuery)
                            .focused($viewAllFocused)
                            .submitLabel(.go)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onSubmit { if let first = shown.first { launch(first) } }
                        if !viewAllQuery.isEmpty {
                            Button { viewAllQuery = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .glassSurface(in: Capsule())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .background {
                ZStack {
                    WallpaperView(theme: theme)
                    Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
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
                                .scaledFont(size: 20, relativeTo: .title3)
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
                    .overlay(Image(systemName: "plus").scaledFont(size: 20, weight: .semibold, relativeTo: .title3, maxSize: 28))
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: theme.fillCells ? .infinity : theme.iconSize)
                if theme.showLabels {
                    Text("Add")
                        .scaledFont(size: 12, weight: .medium, design: theme.fontStyle.design, relativeTo: .caption, maxSize: 18)
                }
            }
            .foregroundStyle(theme.labelColor.opacity(Theme.secondaryOpacity))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add app to group")
    }

    @ViewBuilder
    private func contextMenu(for app: LauncherApp) -> some View {
        Button { activeSheet = .edit(app) } label: { Label("Edit Icon", systemImage: "pencil") }
        Divider()
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
        Divider()
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
        .glassSurface(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    // MARK: - Sheets

    enum ActiveSheet: Identifiable {
        case add(UUID?)
        case edit(LauncherApp)
        case groups
        case theme
        /// GO Home Screen: setup steps and the start screen choice.
        case goHome
        /// First launch of a new install.
        case welcome

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let app): return "edit-\(app.id)"
            case .groups: return "groups"
            case .theme: return "theme"
            case .goHome: return "goHome"
            case .welcome: return "welcome"
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
        case .goHome:
            GoHomeView { activeSheet = nil }
        case .welcome:
            WelcomeView(
                chooseHomeScreen: {
                    store.state.setup.welcomePending = false
                    store.state.setup.startScreen = .homeScreenSetup
                    activeSheet = .goHome
                },
                chooseClassicLauncher: {
                    store.state.setup.welcomePending = false
                    store.state.setup.startScreen = .classicLauncher
                    activeSheet = nil
                }
            )
        case .theme:
            // Opens full height; drag it down to half to watch changes on the home screen.
            ThemeView(openHomeSetup: { activeSheet = .goHome })
                .presentationDetents([.medium, .large], selection: $designDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .onAppear { designDetent = .large }
        }
    }

    // MARK: - Start screen

    private func openGoHome() {
        store.state.setup.announcementPending = false
        activeSheet = .goHome
    }

    /// New installs choose how to start; people who chose GO Home Screen see it when they open
    /// GO. Waits a moment so a widget or link that opened GO is handled instead.
    private func showStartScreenSoon() {
        openedForRequest = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard !openedForRequest, activeSheet == nil, !isSearching else { return }
            if store.state.setup.welcomePending {
                activeSheet = .welcome
            } else if store.state.setup.startScreen == .homeScreenSetup {
                activeSheet = .goHome
            }
        }
    }

    /// A widget, control, Siri or link opened GO: do that, without the start screen on top.
    private func clearStartScreenForRequest() {
        openedForRequest = true
        if case .goHome = activeSheet { activeSheet = nil }
    }

    /// Existing users: what's new, without changing how GO opens for them.
    private var announcementCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("New: GO on your Home Screen", systemImage: "iphone.gen3")
                    .font(.system(.headline, design: theme.fontStyle.design))
                Spacer()
                Button {
                    withAnimation(.snappy) { store.state.setup.announcementPending = false }
                } label: {
                    Image(systemName: "xmark")
                        .scaledFont(size: 13, weight: .bold, relativeTo: .footnote, maxSize: 22)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Full 44pt tap target without pushing the text down.
                .padding(-12)
                .accessibilityLabel("Not now")
            }
            Text("Put GO's widgets, matching wallpaper and search on your iPhone's Home Screen. Classic Launcher stays just as it is.")
                .font(.system(.subheadline, design: theme.fontStyle.design))
            Button("Set Up GO Home Screen") { openGoHome() }
                .font(.system(.subheadline, design: theme.fontStyle.design).weight(.semibold))
                .glassButtonStyle(prominent: true)
        }
        .foregroundStyle(theme.labelColor)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(in: RoundedRectangle(cornerRadius: 24, style: .continuous), theme: theme)
    }

    // MARK: - Launching

    private func launch(_ app: LauncherApp) {
        guard let url = app.launch.resolvedURL else {
            launchError = "\(app.name) doesn't have a link set yet. Long-press it and choose Edit Icon."
            return
        }
        // Record before opening: once the other app opens, Go may be closed before this
        // completion runs. Undone below if iOS couldn't open the app.
        let before = store.state.apps.first { $0.id == app.id }
        store.recordLaunch(app.id)
        openURL(url) { accepted in
            if accepted {
                withAnimation(.snappy) {
                    isSearching = false
                    viewAllKey = nil
                }
            } else {
                if let before { store.recordLaunchFailure(restoring: before) }
                failedApp = store.state.apps.first { $0.id == app.id } ?? app
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
    /// A Home Screen widget or the Go Search control opened Go to do something.
    /// Checked now and again shortly after, because iOS may run the widget's action just after
    /// Go comes to the front.
    private func handleWidgetRequestSoon() {
        handleWidgetRequest()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { handleWidgetRequest() }
    }

    private func handleWidgetRequest() {
        guard let request = GoRequest.take() else { return }
        clearStartScreenForRequest()
        switch request.kind {
        case .search:
            openSearch()
        case .openApp:
            if let id = request.appID, let app = store.state.apps.first(where: { $0.id == id }) {
                launch(app)
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "golauncher" else { return }
        clearStartScreenForRequest()
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        switch url.host {
        case "launch":
            // golauncher://launch?id=<app id>, from a widget tile.
            if let id = query.first(where: { $0.name == "id" })?.value.flatMap(UUID.init(uuidString:)),
               let app = store.state.apps.first(where: { $0.id == id }) {
                launch(app)
            }
        case "section":
            // golauncher://section?key=<section>, from tapping around a widget's tiles.
            if let key = query.first(where: { $0.name == "key" })?.value { openViewAll(key) }
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columnCount: Int {
        dynamicTypeSize.isAccessibilitySize ? min(theme.columns, 3) : theme.columns
    }
    let theme: Theme
    let onLaunch: (LauncherApp, String) -> Void
    let onWebSearch: (String) -> Void
    let onClose: () -> Void

    @State private var query = ""
    @FocusState private var focused: Bool

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: theme.iconSpacing, alignment: .top), count: max(columnCount, 1))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    suggestions
                    recentSearches
                } else {
                    results
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        // Content hugs the bottom, next to the search bar and your thumb.
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            searchBar
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

    /// Sits at the bottom of the screen (just above the keyboard) to keep it within thumb reach.
    private var searchBar: some View {
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
            .glassSurface(in: Capsule())

            Button("Cancel", action: onClose)
                .font(.system(.body, design: theme.fontStyle.design).weight(.semibold))
                .glassButtonStyle()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var recentSearches: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Recent Searches").scaledFont(size: 15, weight: .semibold, design: theme.fontStyle.design, relativeTo: .body)
                Spacer()
                if !store.state.recentSearches.isEmpty {
                    Button("Clear") { store.clearRecentSearches() }
                        .scaledFont(size: 14, weight: .medium, relativeTo: .footnote)
                        .opacity(Theme.secondaryOpacity)
                }
            }
            .padding(.bottom, 4)

            if store.state.recentSearches.isEmpty {
                Text("Your searches will show up here.")
                    .font(.footnote)
                    .opacity(Theme.secondaryOpacity)
            } else {
                // Oldest at the top, newest at the bottom next to the search bar.
                ForEach(store.state.recentSearches.reversed(), id: \.self) { recent in
                    HStack(spacing: 12) {
                        Button {
                            query = recent
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath").opacity(Theme.secondaryOpacity)
                                Text(recent)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button {
                            store.removeRecentSearch(recent)
                        } label: {
                            Image(systemName: "xmark").scaledFont(size: 12, weight: .bold, relativeTo: .caption).opacity(Theme.secondaryOpacity)
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
        let recentApps = store.recentApps(limit: columnCount)
        if !recentApps.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Suggestions").scaledFont(size: 15, weight: .semibold, design: theme.fontStyle.design, relativeTo: .body)
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
        Button {
            onWebSearch(query)
        } label: {
            Label("Search the web for “\(query)”", systemImage: "safari")
                .font(.system(.subheadline, design: theme.fontStyle.design).weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .contentShape(Capsule())
                .glassSurface(in: Capsule(), interactive: true)
        }
        .buttonStyle(.plain)
        if matches.isEmpty {
            Text("No apps match “\(query)”")
                .opacity(Theme.secondaryOpacity)
                .frame(maxWidth: .infinity)
        } else {
            LazyVGrid(columns: columns, spacing: theme.rowSpacing) {
                ForEach(matches) { app in
                    Button { onLaunch(app, query) } label: { AppIconView(app: app, theme: theme) }
                        .buttonStyle(.plain)
                }
            }
            Text("Press Go to open \(matches[0].name)")
                .font(.footnote)
                .opacity(Theme.secondaryOpacity)
                .frame(maxWidth: .infinity)
        }
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
            if let image = Self.image(theme: theme, store: store) {
                Color.clear
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            // A little extra color, so the wallpaper stays lively under the glass.
                            .saturation(1.18)
                    }
                    .clipped()
                if theme.wallpaperDim > 0 { Color.black.opacity(theme.wallpaperDim) }
            }
            // A soft fade in the wallpaper's own deep color behind the greeting, only as strong
            // as WCAG contrast needs. The rest of the wallpaper keeps its full color.
            let legibility = Self.legibility(theme: theme, store: store)
            if theme.showGroupCards {
                LinearGradient(
                    stops: [
                        .init(color: legibility.tint.opacity(legibility.headerScrim), location: 0),
                        .init(color: legibility.tint.opacity(legibility.headerScrim * 0.8), location: 0.18),
                        .init(color: legibility.tint.opacity(0), location: 0.38),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            } else {
                // No containers: names and titles sit right on the wallpaper, so an even wash
                // of its own deep color keeps them readable everywhere.
                legibility.tint.opacity(legibility.openScrim)
            }
        }
        .ignoresSafeArea()
    }

    /// Your photo first, then Go's built-in wallpaper.
    static func image(theme: Theme, store: LauncherStore) -> UIImage? {
        if let name = theme.wallpaperFilename, let image = store.image(named: name) { return image }
        if let name = theme.bundledWallpaper { return UIImage(named: name) }
        return nil
    }

    /// The tints that keep text readable on this background (see ContrastGuard).
    static func legibility(theme: Theme, store: LauncherStore) -> Legibility {
        var key: String?
        if let name = theme.wallpaperFilename, store.image(named: name) != nil {
            key = "photo:\(name):\(theme.wallpaperDim)"
        } else if let name = theme.bundledWallpaper {
            key = "bundled:\(name):\(theme.wallpaperDim)"
        }
        var result = ContrastGuard.legibility(theme: theme, image: image(theme: theme, store: store), imageKey: key)
        // Your own dimming already darkens the photo; don't tint more than needed on top.
        if theme.wallpaperDim > 0, key != nil {
            result.cardTint = max(0, result.cardTint - theme.wallpaperDim)
            result.headerScrim = max(0, result.headerScrim - theme.wallpaperDim)
            result.openScrim = max(0, result.openScrim - theme.wallpaperDim)
        }
        return result
    }
}

/// The edit-mode jiggle.
private struct Wiggle: ViewModifier {
    let active: Bool
    @State private var phase = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active && !reduceMotion ? (phase ? 1.6 : -1.6) : 0))
            .onChange(of: active, initial: true) { _, isActive in
                if isActive {
                    withAnimation(.easeInOut(duration: 0.13).repeatForever(autoreverses: true)) { phase = true }
                } else {
                    withAnimation(.default) { phase = false }
                }
            }
    }
}

/// Section card background: tone-on-tone glass when cards are on, nothing when they're off.
private struct SectionCardSurface: ViewModifier {
    let theme: Theme

    func body(content: Content) -> some View {
        if theme.showGroupCards {
            content.cardSurface(in: RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous), theme: theme)
        } else {
            content
        }
    }
}
