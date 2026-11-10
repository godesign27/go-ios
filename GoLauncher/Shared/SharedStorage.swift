import Foundation
import UIKit

/// Where Go keeps your layout: an App Group folder shared by the app and its Home Screen
/// widgets. (Compiled into both the app and the widget extension.)
enum SharedPaths {
    static let appGroupID = "group.com.godesign.golauncher"

    /// The shared App Group folder, or nil if the entitlement is missing.
    static var groupContainer: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// The app's private folder, used before widgets existed (and as a fallback).
    static var legacyBaseURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GoLauncher", isDirectory: true)
    }

    static var baseURL: URL {
        let url = groupContainer?.appendingPathComponent("GoLauncher", isDirectory: true) ?? legacyBaseURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var stateURL: URL { baseURL.appendingPathComponent("state.json") }

    static var imagesURL: URL {
        let url = baseURL.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Launches made straight from a widget, waiting for the app to count them.
    static var launchLogURL: URL { baseURL.appendingPathComponent("widget-launches.json") }

    /// Something a widget or control asked the app to do when it opens.
    static var requestURL: URL { baseURL.appendingPathComponent("open-request.json") }

    /// One-time move of the layout and icons from the app's private folder into the shared
    /// folder, so updating to the widget version keeps everything. Safe to call every launch.
    static func migrateIfNeeded() {
        guard groupContainer != nil else { return }
        let fileManager = FileManager.default
        let oldState = legacyBaseURL.appendingPathComponent("state.json")
        guard fileManager.fileExists(atPath: oldState.path),
              !fileManager.fileExists(atPath: stateURL.path)
        else { return }

        let oldImages = legacyBaseURL.appendingPathComponent("Images", isDirectory: true)
        for file in (try? fileManager.contentsOfDirectory(atPath: oldImages.path)) ?? [] {
            let destination = imagesURL.appendingPathComponent(file)
            if !fileManager.fileExists(atPath: destination.path) {
                try? fileManager.copyItem(at: oldImages.appendingPathComponent(file), to: destination)
            }
        }
        // The layout last, so a half-finished copy is retried next launch.
        try? fileManager.copyItem(at: oldState, to: stateURL)
    }
}

/// Read-only access to the saved layout, for the widget extension.
enum SharedStore {
    static func loadState() -> LauncherState? {
        guard let data = try? Data(contentsOf: SharedPaths.stateURL) else { return nil }
        return try? JSONDecoder().decode(LauncherState.self, from: data)
    }

    /// The layout with launches made from widgets already counted.
    static func currentState() -> LauncherState? {
        loadState()?.applyingWidgetLaunches(WidgetLaunchLog.read())
    }

    /// An icon or photo saved by the app, downscaled for widgets (they have a small memory budget).
    static func image(named name: String, maxPixels: CGFloat = 180) -> UIImage? {
        let path = SharedPaths.imagesURL.appendingPathComponent(name).path
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        let longest = max(image.size.width, image.size.height) * image.scale
        guard longest > maxPixels else { return image }
        let scale = maxPixels / longest
        let size = CGSize(width: image.size.width * image.scale * scale, height: image.size.height * image.scale * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

/// Launches made directly from a widget. The widget can't safely rewrite the layout file while
/// the app may be saving it, so it logs launches here and the app merges them in.
struct WidgetLaunch: Codable {
    let appID: UUID
    let date: Date
}

enum WidgetLaunchLog {
    static func append(_ appID: UUID) {
        var launches = read()
        launches.append(WidgetLaunch(appID: appID, date: Date()))
        if let data = try? JSONEncoder().encode(Array(launches.suffix(200))) {
            try? data.write(to: SharedPaths.launchLogURL, options: .atomic)
        }
    }

    static func read() -> [WidgetLaunch] {
        guard let data = try? Data(contentsOf: SharedPaths.launchLogURL) else { return [] }
        return (try? JSONDecoder().decode([WidgetLaunch].self, from: data)) ?? []
    }

    static func clear() {
        try? FileManager.default.removeItem(at: SharedPaths.launchLogURL)
    }
}

/// A request from a widget or control for the app to act on when it opens:
/// open an app through Go, or jump straight into search.
struct GoRequest: Codable {
    enum Kind: String, Codable { case openApp, search }

    let kind: Kind
    var appID: UUID?
    let date: Date

    static func save(_ request: GoRequest) {
        if let data = try? JSONEncoder().encode(request) {
            try? data.write(to: SharedPaths.requestURL, options: .atomic)
        }
    }

    /// The pending request, if it's fresh, removed so it runs once.
    static func take() -> GoRequest? {
        guard let data = try? Data(contentsOf: SharedPaths.requestURL) else { return nil }
        try? FileManager.default.removeItem(at: SharedPaths.requestURL)
        guard let request = try? JSONDecoder().decode(GoRequest.self, from: data),
              Date().timeIntervalSince(request.date) < 30
        else { return nil }
        return request
    }
}
