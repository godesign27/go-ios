import Foundation

/// Finds official app icons with Apple's public iTunes Search API (no key needed).
/// iOS doesn't let one app read another app's icon from the device, so Go downloads
/// the App Store artwork once and keeps a copy.
enum AppStoreIcons {
    struct Item: Decodable, Identifiable, Hashable {
        let trackId: Int
        let trackName: String
        let bundleId: String
        let sellerName: String?
        let artworkUrl100: String
        let artworkUrl512: String?

        var id: Int { trackId }
        var artworkURL: URL? { URL(string: artworkUrl512 ?? artworkUrl100) }
        var thumbnailURL: URL? { URL(string: artworkUrl100) }
    }

    private struct Response: Decodable {
        let results: [Item]
    }

    private static var country: String {
        (Locale.current.region?.identifier ?? "US").lowercased()
    }

    static func lookup(bundleID: String) async -> Item? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: country),
        ]
        return await fetch(components?.url).first
    }

    static func search(_ term: String, limit: Int = 12) async -> [Item] {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        return await fetch(components?.url)
    }

    /// The official listing for an app in your layout, or nil if there isn't a confident match.
    /// Name searches only accept titles like "Spotify" or "Spotify: Music…", never "Spotify Tools".
    static func bestMatch(for app: LauncherApp) async -> Item? {
        if app.bundleID == nil, AppCatalog.noStoreIcon.contains(app.name) { return nil }
        if let bundleID = app.bundleID ?? AppCatalog.bundleIDs[app.name],
           let item = await lookup(bundleID: bundleID) {
            return item
        }
        let name = app.name.trimmingCharacters(in: .whitespaces).lowercased()
        guard name.count >= 2 else { return nil }
        let separators = [":", " -", " –", " —", " |"]
        return await search(app.name, limit: 8).first { item in
            let title = item.trackName.lowercased()
            return title == name || separators.contains { title.hasPrefix(name + $0) }
        }
    }

    static func imageData(for item: Item) async -> Data? {
        guard let url = item.artworkURL else { return nil }
        return try? await URLSession.shared.data(from: url).0
    }

    private static func fetch(_ url: URL?) async -> [Item] {
        guard let url, let (data, _) = try? await URLSession.shared.data(from: url) else { return [] }
        return (try? JSONDecoder().decode(Response.self, from: data))?.results ?? []
    }
}
