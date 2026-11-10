import Foundation

/// Restore points for your saved layout (state.json).
///
/// GO copies the layout before the first launch of each new build, before restoring an older
/// copy, and whenever a saved file can't be fully read. Copies live next to the layout in the
/// App Group folder (Backups/), the newest few are kept, and photos they use are never
/// cleaned up, so a restore brings back custom icons and wallpaper too.
struct StateBackups {
    struct Backup: Identifiable, Equatable {
        let url: URL
        let date: Date
        /// Why it was made: "update", "restore", "unreadable" or "manual".
        let reason: String
        /// The GO build that wrote the layout ("unknown" before backups existed).
        let build: String
        var id: URL { url }
    }

    let directory: URL
    let stateURL: URL
    var keep = 8

    static let live = StateBackups(
        directory: SharedPaths.baseURL.appendingPathComponent("Backups", isDirectory: true),
        stateURL: SharedPaths.stateURL
    )

    static var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    private var lastBuildURL: URL { directory.appendingPathComponent("last-build.txt") }

    /// Call before loading. On the first launch of a new build, copies the layout the previous
    /// build left, so an update can always be undone.
    func backupIfNewBuild(currentBuild: String = Self.currentBuild) {
        let previous = (try? String(contentsOf: lastBuildURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard previous != currentBuild else { return }
        if FileManager.default.fileExists(atPath: stateURL.path) {
            backup(reason: "update", build: previous ?? "unknown")
        }
        ensureDirectory()
        try? currentBuild.write(to: lastBuildURL, atomically: true, encoding: .utf8)
    }

    /// Copies the current layout file. Returns the copy, or nil if there's nothing to copy.
    @discardableResult
    func backup(reason: String, build: String = Self.currentBuild) -> URL? {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return nil }
        ensureDirectory()
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        let safeBuild = build.filter { $0.isLetter || $0.isNumber }
        let url = directory.appendingPathComponent("state-\(stamp)-\(reason)-\(safeBuild.isEmpty ? "unknown" : safeBuild).json")
        do {
            try FileManager.default.copyItem(at: stateURL, to: url)
        } catch {
            return nil
        }
        prune()
        return url
    }

    /// Newest first.
    func list() -> [Backup] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.compactMap(Self.parse).sorted { $0.date > $1.date }
    }

    /// Reads a copy and checks it decodes. Nil if it can't be used.
    func load(_ backup: Backup) -> LauncherState? {
        guard let data = try? Data(contentsOf: backup.url) else { return nil }
        return try? JSONDecoder().decode(LauncherState.self, from: data)
    }

    /// Photo file names any restore point uses, so cleanup keeps them.
    func referencedImages() -> Set<String> {
        var names = Set<String>()
        for backup in list() {
            guard let text = try? String(contentsOf: backup.url, encoding: .utf8) else { continue }
            names.formUnion(Self.imageNames(in: text))
        }
        return names
    }

    static func imageNames(in json: String) -> Set<String> {
        let pattern = #"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\.(jpg|png)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(json.startIndex..., in: json)
        return Set(regex.matches(in: json, range: range).compactMap { match in
            Range(match.range, in: json).map { String(json[$0]) }
        })
    }

    private func prune() {
        for old in list().dropFirst(keep) {
            try? FileManager.default.removeItem(at: old.url)
        }
    }

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private static func parse(_ url: URL) -> Backup? {
        let name = url.deletingPathExtension().lastPathComponent
        let parts = name.split(separator: "-", maxSplits: 3).map(String.init)
        guard url.pathExtension == "json", parts.count == 4, parts[0] == "state",
              let millis = Double(parts[1])
        else { return nil }
        return Backup(url: url, date: Date(timeIntervalSince1970: millis / 1000), reason: parts[2], build: parts[3])
    }
}
