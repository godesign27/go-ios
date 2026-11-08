import Combine
import Foundation
import UIKit

/// Holds your layout and saves it to disk automatically.
final class LauncherStore: ObservableObject {
    @Published var state: LauncherState

    private var cancellables = Set<AnyCancellable>()
    private let imageCache = NSCache<NSString, UIImage>()

    init() {
        state = Self.loadState() ?? Self.seed()
        $state
            .dropFirst()
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveNow() }
            .store(in: &cancellables)
        cleanupUnusedImages()
        syncInstalledApps()
        fetchOfficialIcons()
    }

    // MARK: - Apps on this iPhone

    static let installedGroupName = "Your Apps"

    /// iOS doesn't let apps list what's installed, so Go asks about each catalog app by its URL scheme
    /// and adds the ones it finds to "Your Apps". Each app is added once: delete it and it stays gone.
    /// Apps that aren't installed are checked again next time, so newly installed ones show up.
    func syncInstalledApps() {
        var known = Set(state.knownCatalogApps)
        let present = Set(state.apps.map(\.name))
        var found: [CatalogEntry] = []
        for entry in AppCatalog.entries where !known.contains(entry.name) {
            if present.contains(entry.name) {
                known.insert(entry.name)
            } else if Self.isInstalled(entry) {
                known.insert(entry.name)
                found.append(entry)
            }
        }
        guard known.count != state.knownCatalogApps.count else { return }

        if !found.isEmpty {
            let groupID = state.groups.first { $0.name == Self.installedGroupName }?.id
                ?? addGroup(named: Self.installedGroupName)
            state.apps += found
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                .map { $0.makeApp(groupID: groupID) }
        }
        state.knownCatalogApps = AppCatalog.entries.map(\.name).filter(known.contains)
        if !found.isEmpty { fetchOfficialIcons() }
    }

    /// Apple's built-in apps are assumed present; others are checked with canOpenURL.
    private static func isInstalled(_ entry: CatalogEntry) -> Bool {
        if entry.category == .apple { return true }
        guard let scheme = AppCatalog.scheme(of: entry), let url = URL(string: "\(scheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    // MARK: - Queries

    func apps(in groupID: UUID) -> [LauncherApp] {
        state.apps.filter { $0.groupID == groupID }
    }

    /// Apps you opened most recently, newest first.
    func recentApps(limit: Int) -> [LauncherApp] {
        let opened = state.apps.filter { $0.lastLaunched != nil }
        let sorted = opened.sorted { ($0.lastLaunched ?? .distantPast) > ($1.lastLaunched ?? .distantPast) }
        return Array(sorted.prefix(limit))
    }

    /// Apps you open most often.
    func mostUsedApps(limit: Int) -> [LauncherApp] {
        let opened = state.apps.filter { $0.launchCount > 0 }
        let sorted = opened.sorted { $0.launchCount > $1.launchCount }
        return Array(sorted.prefix(limit))
    }

    /// Apps you've flagged with "Needs Attention".
    var attentionApps: [LauncherApp] {
        state.apps.filter(\.needsAttention)
    }

    /// The Favorite Apps widget: your picks, or your most used apps until you pick.
    var favoriteApps: [LauncherApp] {
        let picked = state.favoriteAppIDs.compactMap { id in state.apps.first { $0.id == id } }
        if !picked.isEmpty { return Array(picked.prefix(4)) }
        let mostUsed = mostUsedApps(limit: 4)
        return mostUsed.count == 4 ? mostUsed : Array(state.apps.prefix(4))
    }

    /// Every favorite, in the order you added them (the Favorites section).
    var allFavoriteApps: [LauncherApp] {
        state.favoriteAppIDs.compactMap { id in state.apps.first { $0.id == id } }
    }

    func isFavorite(_ appID: UUID) -> Bool {
        state.favoriteAppIDs.contains(appID)
    }

    /// Adds or removes an app from Favorites (the section and the widget).
    func toggleFavorite(_ appID: UUID) {
        if let index = state.favoriteAppIDs.firstIndex(of: appID) {
            state.favoriteAppIDs.remove(at: index)
        } else {
            state.favoriteAppIDs.append(appID)
        }
    }

    var dockApps: [LauncherApp] {
        Array(state.apps.filter(\.isDocked).prefix(5))
    }

    // MARK: - Section order

    /// Every section in display order. New groups land before Needs Attention.
    var sections: [HomeSection] {
        orderedKeys.compactMap(section(for:))
    }

    /// Sections shown on the home screen (hidden automatic sections left out).
    var visibleSections: [HomeSection] {
        sections.filter { !state.hiddenSections.contains($0.key) }
    }

    private func section(for key: String) -> HomeSection? {
        if let smart = SmartSection(rawValue: key) { return .smart(smart) }
        if let group = state.groups.first(where: { $0.id.uuidString == key }) { return .group(group) }
        return nil
    }

    private var orderedKeys: [String] {
        let groupKeys = state.groups.map(\.id.uuidString)
        let valid = Set(groupKeys + SmartSection.allCases.map(\.rawValue))
        var keys = state.sectionOrder.filter { valid.contains($0) }
        if keys.isEmpty {
            // Default: Recently Used, Favorites, first group (Essentials), Most Used, other groups, Needs Attention.
            keys = [SmartSection.recent.rawValue, SmartSection.favorites.rawValue]
            keys += groupKeys.prefix(1)
            keys.append(SmartSection.mostUsed.rawValue)
            keys += groupKeys.dropFirst()
            keys.append(SmartSection.attention.rawValue)
        }
        // Favorites was added later: slot it in under Recently Used for existing layouts.
        if !keys.contains(SmartSection.favorites.rawValue) {
            let index = keys.firstIndex(of: SmartSection.recent.rawValue).map { $0 + 1 } ?? 0
            keys.insert(SmartSection.favorites.rawValue, at: index)
        }
        for key in groupKeys where !keys.contains(key) {
            if let attention = keys.firstIndex(of: SmartSection.attention.rawValue) {
                keys.insert(key, at: attention)
            } else {
                keys.append(key)
            }
        }
        for smart in SmartSection.allCases where !keys.contains(smart.rawValue) {
            keys.append(smart.rawValue)
        }
        return keys
    }

    func moveSections(fromOffsets source: IndexSet, toOffset destination: Int) {
        var keys = orderedKeys
        keys.move(fromOffsets: source, toOffset: destination)
        state.sectionOrder = keys
    }

    func isSectionHidden(_ key: String) -> Bool {
        state.hiddenSections.contains(key)
    }

    func setSection(_ key: String, hidden: Bool) {
        state.hiddenSections.removeAll { $0 == key }
        if hidden { state.hiddenSections.append(key) }
    }

    func renameGroup(_ groupID: UUID, to name: String) {
        guard let index = state.groups.firstIndex(where: { $0.id == groupID }) else { return }
        state.groups[index].name = name
    }

    // MARK: - Recent searches

    func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var recents = state.recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        recents.insert(trimmed, at: 0)
        state.recentSearches = Array(recents.prefix(8))
    }

    func removeRecentSearch(_ query: String) {
        state.recentSearches.removeAll { $0 == query }
    }

    func clearRecentSearches() {
        state.recentSearches = []
    }

    // MARK: - Collapsing

    func isSectionCollapsed(_ key: String) -> Bool {
        state.collapsedSections.contains(key)
    }

    func toggleSection(_ key: String) {
        if let index = state.collapsedSections.firstIndex(of: key) {
            state.collapsedSections.remove(at: index)
        } else {
            state.collapsedSections.append(key)
        }
    }

    /// Ranked search: name prefix > word prefix > contains > keywords > fuzzy letters-in-order.
    /// Ties go to the app you open most.
    func search(_ query: String) -> [LauncherApp] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        let scored: [(app: LauncherApp, score: Int)] = state.apps.compactMap { app in
            let name = app.name.lowercased()
            let score: Int
            if name.hasPrefix(q) {
                score = 400
            } else if name.split(separator: " ").contains(where: { $0.hasPrefix(q) }) {
                score = 300
            } else if name.contains(q) {
                score = 200
            } else if app.keywords.lowercased().contains(q) {
                score = 100
            } else if Self.isSubsequence(q, of: name) {
                score = 10
            } else {
                return nil
            }
            return (app, score)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.app.launchCount > rhs.app.launchCount
            }
            .map(\.app)
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var iterator = haystack.makeIterator()
        for character in needle where character != " " {
            var found = false
            while let next = iterator.next() {
                if next == character { found = true; break }
            }
            if !found { return false }
        }
        return true
    }

    // MARK: - App mutations

    func upsert(_ app: LauncherApp) {
        if let index = state.apps.firstIndex(where: { $0.id == app.id }) {
            state.apps[index] = app
        } else {
            state.apps.append(app)
            if !app.iconLookupDone { fetchOfficialIcons() }
        }
    }

    func delete(_ appID: UUID) {
        state.apps.removeAll { $0.id == appID }
    }

    func toggleDock(_ appID: UUID) {
        guard let index = state.apps.firstIndex(where: { $0.id == appID }) else { return }
        state.apps[index].isDocked.toggle()
    }

    func toggleAttention(_ appID: UUID) {
        guard let index = state.apps.firstIndex(where: { $0.id == appID }) else { return }
        state.apps[index].needsAttention.toggle()
    }

    func recordLaunch(_ appID: UUID) {
        guard let index = state.apps.firstIndex(where: { $0.id == appID }) else { return }
        var app = state.apps[index]
        app.launchCount += 1
        app.lastLaunched = Date()
        app.needsAttention = false
        state.apps[index] = app
        // Save now: Go goes to the background as the other app opens and may be closed by iOS
        // before the usual delayed save runs, which lost launches from Recently Used.
        saveNow()
    }

    /// Drag-and-drop: the dragged app takes the target's spot (and joins its group).
    func move(appID: UUID, onto targetID: UUID) {
        guard appID != targetID else { return }
        var apps = state.apps
        guard
            let from = apps.firstIndex(where: { $0.id == appID }),
            let targetGroup = apps.first(where: { $0.id == targetID })?.groupID
        else { return }

        var app = apps.remove(at: from)
        let sameGroup = app.groupID == targetGroup
        guard let target = apps.firstIndex(where: { $0.id == targetID }) else { return }
        // Moving forward within a group lands after the target, like iOS.
        let insertAfter = sameGroup && from <= target
        app.groupID = targetGroup
        apps.insert(app, at: insertAfter ? target + 1 : target)
        state.apps = apps
    }

    /// Moves an app to the end of another group.
    func move(appID: UUID, toGroup groupID: UUID) {
        var apps = state.apps
        guard let from = apps.firstIndex(where: { $0.id == appID }) else { return }
        var app = apps.remove(at: from)
        app.groupID = groupID
        apps.append(app)
        state.apps = apps
    }

    // MARK: - Groups

    @discardableResult
    func addGroup(named name: String) -> UUID {
        let group = AppGroup(name: name)
        let keys = orderedKeys
        state.groups.append(group)
        // Place the new group just before Needs Attention (or at the end).
        var newKeys = keys
        if let attention = newKeys.firstIndex(of: SmartSection.attention.rawValue) {
            newKeys.insert(group.id.uuidString, at: attention)
        } else {
            newKeys.append(group.id.uuidString)
        }
        state.sectionOrder = newKeys
        return group.id
    }

    func toggleCollapsed(_ groupID: UUID) {
        guard let index = state.groups.firstIndex(where: { $0.id == groupID }) else { return }
        state.groups[index].isCollapsed.toggle()
    }

    /// Deletes groups, moving their apps into the first group that remains.
    /// The last group can't be deleted.
    func deleteGroups(ids: Set<UUID>) {
        let doomed = ids
        guard let fallback = state.groups.first(where: { !doomed.contains($0.id) }) else { return }
        var newState = state
        for index in newState.apps.indices where doomed.contains(newState.apps[index].groupID) {
            newState.apps[index].groupID = fallback.id
        }
        newState.groups.removeAll { doomed.contains($0.id) }
        newState.sectionOrder.removeAll { key in doomed.contains { $0.uuidString == key } }
        state = newState
    }

    // MARK: - Official app icons

    private var iconFetchRunning = false

    /// Fetches the official App Store icon for every app that hasn't been checked yet.
    /// Runs on launch and after adding apps; each app is looked up once.
    func fetchOfficialIcons() {
        guard state.theme.useOfficialIcons, !iconFetchRunning else { return }
        let pending = state.apps.filter { !$0.iconLookupDone }
        guard !pending.isEmpty else { return }
        iconFetchRunning = true
        Task {
            for app in pending {
                let item = await AppStoreIcons.bestMatch(for: app)
                let data: Data? = item == nil ? nil : await AppStoreIcons.imageData(for: item!)
                await MainActor.run {
                    self.applyOfficialIcon(appID: app.id, data: data)
                }
            }
            await MainActor.run { self.iconFetchRunning = false }
        }
    }

    private func applyOfficialIcon(appID: UUID, data: Data?) {
        guard let index = state.apps.firstIndex(where: { $0.id == appID }) else { return }
        var app = state.apps[index]
        app.iconLookupDone = true
        // Only replace symbol/emoji icons; never a photo the user picked.
        if state.theme.useOfficialIcons, let data, !isPhoto(app.glyph),
           let file = saveImage(data, maxDimension: 300) {
            app.fallbackGlyph = app.glyph
            app.glyph = .image(file)
            app.usesOfficialIcon = true
        }
        state.apps[index] = app
    }

    /// Sets an icon the user picked from App Store search (from the icon editor).
    func saveOfficialIcon(_ data: Data) -> String? {
        saveImage(data, maxDimension: 300)
    }

    /// Design › Official App Icons. Off restores the symbol icons; on fetches again.
    func setOfficialIcons(_ enabled: Bool) {
        state.theme.useOfficialIcons = enabled
        var apps = state.apps
        for index in apps.indices {
            if enabled {
                if !apps[index].usesOfficialIcon && !isPhoto(apps[index].glyph) {
                    apps[index].iconLookupDone = false
                }
            } else if apps[index].usesOfficialIcon {
                apps[index].glyph = apps[index].fallbackGlyph ?? .symbol("app.fill")
                apps[index].usesOfficialIcon = false
                apps[index].iconLookupDone = false
            }
        }
        state.apps = apps
        if enabled { fetchOfficialIcons() }
    }

    private func isPhoto(_ glyph: IconGlyph) -> Bool {
        if case .image = glyph { return true }
        return false
    }

    func resetToDefault() {
        state = Self.seed()
    }

    // MARK: - Images

    /// Saves picked photo data (downscaled) and returns its file name.
    func saveImage(_ data: Data, maxDimension: CGFloat) -> String? {
        guard let jpeg = ImageProcessing.downscaledJPEG(data, maxDimension: maxDimension) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: Self.imagesURL.appendingPathComponent(name), options: .atomic)
            return name
        } catch {
            print("GoLauncher: failed to save image: \(error)")
            return nil
        }
    }

    func image(named name: String) -> UIImage? {
        if let cached = imageCache.object(forKey: name as NSString) { return cached }
        let path = Self.imagesURL.appendingPathComponent(name).path
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        imageCache.setObject(image, forKey: name as NSString)
        return image
    }

    /// Removes photos no icon or wallpaper uses any more (e.g. replaced or cancelled picks).
    private func cleanupUnusedImages() {
        var used = Set<String>()
        for app in state.apps {
            if case .image(let name) = app.glyph { used.insert(name) }
        }
        if let wallpaper = state.theme.wallpaperFilename { used.insert(wallpaper) }

        let fileManager = FileManager.default
        let files = (try? fileManager.contentsOfDirectory(atPath: Self.imagesURL.path)) ?? []
        for file in files where !used.contains(file) {
            try? fileManager.removeItem(at: Self.imagesURL.appendingPathComponent(file))
        }
    }

    // MARK: - Persistence

    func saveNow() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: Self.stateURL, options: .atomic)
        } catch {
            print("GoLauncher: failed to save layout: \(error)")
        }
    }

    private static var baseURL: URL {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GoLauncher", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var stateURL: URL { baseURL.appendingPathComponent("state.json") }

    private static var imagesURL: URL {
        let url = baseURL.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func loadState() -> LauncherState? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        do {
            return try JSONDecoder().decode(LauncherState.self, from: data)
        } catch {
            // Keep the unreadable file around rather than silently losing it.
            let backup = baseURL.appendingPathComponent("state-backup-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: stateURL, to: backup)
            print("GoLauncher: couldn't read saved layout, backed up to \(backup.lastPathComponent): \(error)")
            return nil
        }
    }

    // MARK: - Starter layout

    static func seed() -> LauncherState {
        let essentials = AppGroup(name: "Essentials")
        let everyday = AppGroup(name: "Everyday")
        let tools = AppGroup(name: "Tools")
        let ai = AppGroup(name: "AI")

        func make(_ name: String, _ group: AppGroup) -> LauncherApp? {
            AppCatalog.entry(named: name)?.makeApp(groupID: group.id)
        }

        let apps: [LauncherApp?] = [
            make("Phone", essentials),
            make("Messages", essentials),
            make("Safari", essentials),
            make("Music", essentials),
            make("Mail", essentials),
            make("Photos", essentials),
            make("Maps", essentials),
            make("Calendar", essentials),
            make("Weather", everyday),
            make("Notes", everyday),
            make("Reminders", everyday),
            make("Podcasts", everyday),
            make("Settings", tools),
            make("Shortcuts", tools),
            make("Files", tools),
            make("App Store", tools),
            make("ChatGPT", ai),
            make("Claude", ai),
            make("Gemini", ai),
            make("Perplexity", ai),
        ]

        // Starter dock apps (the dock itself is off until turned on in Groups & Dock).
        let docked: Set<String> = ["Phone", "Messages", "Safari", "Music"]
        let starterApps = apps.compactMap { $0 }.map { app -> LauncherApp in
            var app = app
            app.isDocked = docked.contains(app.name)
            return app
        }

        var state = LauncherState(groups: [essentials, everyday, tools, ai], apps: starterApps, theme: Theme())
        // Starter favorites; change them by long-pressing any app.
        let favorites = ["Messages", "Safari", "Music", "Claude"]
        state.favoriteAppIDs = favorites.compactMap { name in starterApps.first { $0.name == name }?.id }
        return state
    }
}
