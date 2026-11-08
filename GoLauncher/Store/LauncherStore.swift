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
        }
    }

    func delete(_ appID: UUID) {
        state.apps.removeAll { $0.id == appID }
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
        state.groups.append(group)
        return group.id
    }

    func toggleCollapsed(_ groupID: UUID) {
        guard let index = state.groups.firstIndex(where: { $0.id == groupID }) else { return }
        state.groups[index].isCollapsed.toggle()
    }

    /// Deletes groups, moving their apps into the first group that remains.
    /// The last group can't be deleted.
    func deleteGroups(at offsets: IndexSet) {
        let doomed = Set(offsets.map { state.groups[$0].id })
        guard let fallback = state.groups.first(where: { !doomed.contains($0.id) }) else { return }
        var newState = state
        for index in newState.apps.indices where doomed.contains(newState.apps[index].groupID) {
            newState.apps[index].groupID = fallback.id
        }
        newState.groups.removeAll { doomed.contains($0.id) }
        state = newState
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

        return LauncherState(groups: [essentials, everyday, tools, ai], apps: apps.compactMap { $0 }, theme: Theme())
    }
}
