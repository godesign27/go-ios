import XCTest
@testable import GoLauncher

/// Saved layouts from earlier builds must load without losing anything (plan: IOS-01, IOS-12).
/// Fixtures: baseline = a layout saved by the build-202611100807 code (commit 1513f9f) in the
/// simulator; full-coverage = baseline plus every kind of user data; legacy-early = the oldest
/// shape (most fields missing); future-unknown-fields = a layout written by a newer GO.
final class LayoutCompatibilityTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func decode(_ name: String) throws -> LauncherState {
        try JSONDecoder().decode(LauncherState.self, from: fixture(name))
    }

    private func rawObject(_ name: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: fixture(name)) as? [String: Any])
    }

    func testBaselineLoadsEverything() throws {
        let raw = try rawObject("baseline-1513f9f-simulator")
        let state = try decode("baseline-1513f9f-simulator")
        XCTAssertEqual(state.apps.count, (raw["apps"] as? [Any])?.count)
        XCTAssertEqual(state.groups.map(\.name), ["Essentials", "Everyday", "Tools", "AI", "Your Apps"])
        XCTAssertEqual(state.favoriteAppIDs.map(\.uuidString), raw["favoriteAppIDs"] as? [String])
        XCTAssertEqual(state.sectionOrder, raw["sectionOrder"] as? [String])
        XCTAssertEqual(state.knownCatalogApps, raw["knownCatalogApps"] as? [String])
        // Saved before versioning: an existing user. Their start screen stays the launcher.
        XCTAssertEqual(state.schemaVersion, 1)
        XCTAssertEqual(state.setup.startScreen, .classicLauncher)
        XCTAssertTrue(state.setup.announcementPending)
        XCTAssertFalse(state.setup.welcomePending)
        XCTAssertFalse(LauncherStore.skippedItems(in: try fixture("baseline-1513f9f-simulator"), decoded: state))
    }

    func testFullCoverageSurvivesSaveAndReload() throws {
        let original = try decode("full-coverage")
        let reloaded = try JSONDecoder().decode(LauncherState.self, from: JSONEncoder().encode(original))

        XCTAssertEqual(reloaded.apps, original.apps)
        XCTAssertEqual(reloaded.groups, original.groups)
        XCTAssertEqual(reloaded.favoriteAppIDs, original.favoriteAppIDs)
        XCTAssertEqual(reloaded.sectionOrder, original.sectionOrder)
        XCTAssertEqual(reloaded.hiddenSections, ["mostUsed"])
        XCTAssertEqual(reloaded.collapsedSections, ["attention"])
        XCTAssertTrue(reloaded.showDock)
        XCTAssertEqual(reloaded.recentSearches, ["slack", "weather"])
        XCTAssertEqual(reloaded.knownCatalogApps, original.knownCatalogApps)
        XCTAssertEqual(reloaded.setup, original.setup)

        let photo = try XCTUnwrap(reloaded.apps.first { $0.name == "My Photo App" })
        XCTAssertEqual(photo.glyph, .image("11111111-2222-4333-8444-555555555555.jpg"))
        XCTAssertTrue(photo.needsAttention)
        XCTAssertEqual(photo.launchCount, 7)
        XCTAssertEqual(photo.secondaryColorHex, "#654321")
        let shortcut = try XCTUnwrap(reloaded.apps.first { $0.name == "Run My Shortcut" })
        XCTAssertEqual(shortcut.launch, .shortcut("Open Banking"))
        XCTAssertEqual(shortcut.glyph, .emoji("🏦"))
        XCTAssertTrue(shortcut.isDocked)

        XCTAssertEqual(reloaded.theme.wallpaperFilename, "99999999-8888-4777-8666-555555555555.jpg")
        XCTAssertEqual(reloaded.theme.bundledWallpaper, "WallpaperTwilight")
        XCTAssertEqual(reloaded.theme.userName, "Fixture")
    }

    func testThemeSurvivesReloadUnchanged() throws {
        let original = try decode("full-coverage")
        let once = try JSONEncoder().encode(original.theme)
        let twice = try JSONEncoder().encode(JSONDecoder().decode(Theme.self, from: once))
        XCTAssertEqual(
            try JSONSerialization.jsonObject(with: once) as? NSDictionary,
            try JSONSerialization.jsonObject(with: twice) as? NSDictionary
        )
    }

    func testDeletedCatalogAppStaysDeleted() throws {
        let state = try decode("full-coverage")
        XCTAssertTrue(state.knownCatalogApps.contains("Slack"))
        XCTAssertFalse(state.apps.contains { $0.name == "Slack" })
    }

    func testLegacyLayoutGetsDefaults() throws {
        let state = try decode("legacy-early")
        XCTAssertEqual(state.apps.map(\.name), ["Phone", "Notes"])
        XCTAssertEqual(state.apps[0].id.uuidString, "D6BC7809-FBBD-429A-8A3F-6846BAA3E7A1")
        XCTAssertEqual(state.theme.columns, 5)
        XCTAssertTrue(state.theme.isDark)
        XCTAssertEqual(state.favoriteAppIDs, [])
        XCTAssertEqual(state.setup.startScreen, .classicLauncher)
        XCTAssertTrue(state.setup.announcementPending)
    }

    func testNewerLayoutKeepsWhatThisBuildCanRead() throws {
        let data = try fixture("future-unknown-fields")
        let raw = try rawObject("future-unknown-fields")
        let state = try JSONDecoder().decode(LauncherState.self, from: data)
        // One app has an icon kind this build doesn't know, one group is malformed: only those drop.
        XCTAssertEqual(state.apps.count, ((raw["apps"] as? [Any])?.count ?? 0) - 1)
        XCTAssertEqual(state.groups.count, ((raw["groups"] as? [Any])?.count ?? 0) - 1)
        XCTAssertEqual(state.schemaVersion, 9)
        // The loader sees the loss and keeps the original file as a restore point.
        XCTAssertTrue(LauncherStore.skippedItems(in: data, decoded: state))
    }

    func testWidgetLaunchesCountOnce() throws {
        let state = try decode("full-coverage")
        let app = try XCTUnwrap(state.apps.first { $0.name == "My Photo App" })
        let later = Date(timeIntervalSinceReferenceDate: 790_000_000)
        let merged = state.applyingWidgetLaunches([WidgetLaunch(appID: app.id, date: later)])
        let updated = try XCTUnwrap(merged.apps.first { $0.id == app.id })
        XCTAssertEqual(updated.launchCount, app.launchCount + 1)
        XCTAssertEqual(updated.lastLaunched, later)
        XCTAssertFalse(updated.needsAttention)
        // A launch for an app that no longer exists is ignored, not crashed on.
        let ignored = state.applyingWidgetLaunches([WidgetLaunch(appID: UUID(), date: later)])
        XCTAssertEqual(ignored.apps, state.apps)
    }

    func testFreshInstallAsksHowToStart() {
        let fresh = LauncherStore.seed(newUser: true)
        XCTAssertTrue(fresh.setup.welcomePending)
        XCTAssertFalse(fresh.setup.announcementPending)
        XCTAssertEqual(fresh.schemaVersion, LauncherState.currentSchemaVersion)
        let reset = LauncherStore.seed()
        XCTAssertFalse(reset.setup.welcomePending)
    }
}

final class StateBackupsTests: XCTestCase {
    private var root: URL!
    private var backups: StateBackups!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        backups = StateBackups(directory: root.appendingPathComponent("Backups"), stateURL: root.appendingPathComponent("state.json"), keep: 3)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func writeState(_ name: String) throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        try? FileManager.default.removeItem(at: backups.stateURL)
        try FileManager.default.copyItem(at: url, to: backups.stateURL)
    }

    func testBacksUpOncePerNewBuild() throws {
        try writeState("full-coverage")
        backups.backupIfNewBuild(currentBuild: "100")
        backups.backupIfNewBuild(currentBuild: "100")
        XCTAssertEqual(backups.list().count, 1)
        XCTAssertEqual(backups.list().first?.reason, "update")
        XCTAssertEqual(backups.list().first?.build, "unknown")
        backups.backupIfNewBuild(currentBuild: "101")
        XCTAssertEqual(backups.list().count, 2)
        XCTAssertEqual(backups.list().first?.build, "100")
    }

    func testNoLayoutMeansNoBackup() {
        backups.backupIfNewBuild(currentBuild: "100")
        XCTAssertTrue(backups.list().isEmpty)
    }

    func testBackupRestoresTheSameLayout() throws {
        try writeState("full-coverage")
        let copy = try XCTUnwrap(backups.backup(reason: "manual"))
        try writeState("legacy-early")
        let backup = try XCTUnwrap(backups.list().first { $0.url == copy })
        let restored = try XCTUnwrap(backups.load(backup))
        XCTAssertEqual(restored.apps.count, 25)
    }

    func testKeepsOnlyNewest() throws {
        try writeState("legacy-early")
        for _ in 0..<5 {
            backups.backup(reason: "manual")
            Thread.sleep(forTimeInterval: 0.002)
        }
        XCTAssertEqual(backups.list().count, 3)
    }

    func testPhotosUsedByBackupsAreFound() throws {
        try writeState("full-coverage")
        backups.backup(reason: "manual")
        let names = backups.referencedImages()
        XCTAssertTrue(names.contains("11111111-2222-4333-8444-555555555555.jpg"))
        XCTAssertTrue(names.contains("99999999-8888-4777-8666-555555555555.jpg"))
    }
}

final class CatalogTests: XCTestCase {
    /// Apple's canOpenURL docs: apps linked on or after iOS 27 may list at most 25 schemes.
    func testQuerySchemesWithinLimit() throws {
        let schemes = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes") as? [String])
        XCTAssertLessThanOrEqual(schemes.count, 25)
        XCTAssertEqual(Set(schemes).count, schemes.count, "duplicate scheme")
    }

    func testEveryQuerySchemeBelongsToACatalogApp() throws {
        let catalogSchemes = Set(AppCatalog.entries.compactMap(AppCatalog.scheme(of:)))
        for scheme in AppCatalog.detectableSchemes {
            XCTAssertTrue(catalogSchemes.contains(scheme), "\(scheme) isn't used by any catalog app")
        }
    }

    func testCatalogNamesAndBundleIDsAreConsistent() {
        let names = AppCatalog.entries.map(\.name)
        XCTAssertEqual(Set(names).count, names.count, "duplicate catalog name")
        for name in AppCatalog.bundleIDs.keys {
            XCTAssertTrue(names.contains(name), "bundle ID for unknown app \(name)")
        }
        for entry in AppCatalog.entries {
            XCTAssertNotNil(URL(string: entry.url), "\(entry.name) has an invalid URL")
        }
    }
}
