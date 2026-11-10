# GO Launcher baseline and data safety (Phase 0)

Recorded November 10, 2026 for the Home Screen-first iOS update ([plan](../GO_LAUNCHER_UPDATE_PLAN.md), [backlog](../GO_LAUNCHER_BACKLOG.md)).

## Recoverable source baseline

| What | Where |
| --- | --- |
| Source of TestFlight build **202611100807** (archived 08:07:49 MST, Nov 10) | tag `build-202611100807` → commit `1513f9f` |
| Last commit before the update (adds docs only) | tag `baseline-pre-ios-update` → commit `19d08f0` |
| Update work | branch `claude/ios-home-screen-update` |

To roll the source back, build either tag with `./scripts/testflight.sh` after checking it out (the script pulls first, so run it from a branch made at the tag). See **Data compatibility** before shipping a rollback.

## Identity (unchanged by the update)

- App bundle ID `com.godesign.golauncher`, widget extension `com.godesign.golauncher.widgets`, team `TTM6RL99QG`.
- App Group `group.com.godesign.golauncher`; URL scheme `golauncher://` (`launch?id=`, `section?key=`, `search`, `open?name=`).
- Widget kinds `GoFavorites`, `GoRecentlyUsed`, `GoMostUsed`, `GoSection`; control `GoSearchControl`. App and group IDs are UUIDs saved in the layout and never regenerated, so widget links and Shortcuts keep resolving.

## Supported OS and device matrix

| Part | Minimum | Source |
| --- | --- | --- |
| App (Classic Launcher, setup, search) | iOS 17.0 | `project.yml` deploymentTarget |
| Widgets, Go Search control, one-tap widget launches | iOS 18.0 | GoWidgets deploymentTarget; `ControlWidget` and `OpenURLIntent` are iOS 18.0 in Apple's docs |
| Siri/Shortcuts actions (Search, Open App with Go, Log App in Go Recents) | iOS 17 for the app actions; `OpenAppDirectlyIntent` is iOS 18 | code annotations |
| Devices | iPhone only (`TARGETED_DEVICE_FAMILY 1`), portrait | `project.yml` |

Build toolchain: Xcode 27.0 (27A266a), iOS 27 SDK. Test devices available: iPhone 16e on iOS 27.2 (24B119), iPhone 17 Pro (paired), simulators for iOS 18.6, 26.5 and 27.0.

## Feature and launch-path inventory

| Path | How it opens an app | Records the launch | Status |
| --- | --- | --- | --- |
| Classic Launcher tile, dock, search result | `openURL(app URL)` from GO | Yes, before opening; undone if iOS refuses | Works (device, earlier builds) |
| Medium/large widget tile | `Link(golauncher://launch?id=)` → GO → app | Yes (in GO) | **Device-confirmed** Nov 10 (build 202611100750) |
| Small widget tile | `Button(intent: OpenAppDirectlyIntent)` → `OpenURLIntent` | Logged to `widget-launches.json`, merged by GO | **Unverified on device** |
| Tap outside tiles | `.widgetURL(golauncher://section?key=)` → GO's View All | n/a | Simulator only |
| Go Search control | `OpenGoSearchIntent` → GO search | n/a | Unverified on device |
| Siri "Open X with Go" | `OpenAppWithGoIntent` → GO → app | Yes | **Unverified on device** |
| Log App in Go Recents (Shortcuts automation) | none (logs only) | Logged, merged by GO | **Unverified on device** |

Apple's WidgetKit docs list small widgets among the sizes that can include buttons, so per-tile intent buttons in small widgets are a supported pattern; Links in small widgets aren't used (simulator testing showed only `widgetURL` firing). Simulator widget taps never reach tiles, so all widget launch checks need a physical iPhone.

## Catalog and URL scheme audit

**Finding (fixed in this update):** Apple's `canOpenURL(_:)` documentation says apps linked on or after iOS 15 may declare at most 50 `LSApplicationQueriesSchemes`, and apps linked on or after **iOS 27 at most 25**. GO builds with the iOS 27 SDK and declared 48, so on iOS 27 detection of catalog apps beyond the limit wasn't reliable (behavior past the limit isn't documented). The list is now the 25 highest-priority schemes; GO no longer asks iOS about undeclared schemes, so an undeclared app is "not checked", never "not installed". Opening an app by its scheme doesn't need the declaration, so every catalog app still launches when added by hand.

- Detected automatically (25): Gmail, Outlook, Slack, Teams, Zoom, Notion, Google Drive, Chrome, WhatsApp, Instagram, Facebook, LinkedIn, X, Discord, Spotify, YouTube, Netflix, Google Maps, Uber, Venmo, ChatGPT, Claude, Gemini, Perplexity, Copilot.
- Not detected, still addable: Messenger, Threads, TikTok, Snapchat, Telegram, Reddit, Pinterest, Prime Video, Disney+, Hulu, Twitch, Shazam, Google Photos, Duolingo, Strava, Lyft, Waze, Amazon, Airbnb, DoorDash, PayPal, Cash App, Signal.
- Apple apps (19) are assumed present and aren't checked.
- Unit tests (`CatalogTests`) enforce ≤ 25 schemes, no duplicates, every scheme belongs to a catalog app, and bundle IDs map to catalog names.
- **Still needs the iPhone:** which schemes actually open each installed app, and which bundle IDs return the right App Store icon. Use **Customize › Set Up GO Home Screen › Check My Apps** on the device; its statuses distinguish *added to GO*, *detected on this iPhone*, *not checked*, *opened from GO* and *opens via Shortcut*. Record failures in the backlog under IOS-02. The fallback for any app whose scheme fails is a Shortcut with Open App, set in the icon's editor.

## Saved data and fixtures

Files in the App Group folder `GoLauncher/`: `state.json` (layout), `Images/` (photos, official icons, wallpaper), `widget-launches.json`, `open-request.json`, and new `Backups/`.

Fixtures in `GoLauncherTests/Fixtures/`:

| Fixture | Covers |
| --- | --- |
| `baseline-1513f9f-simulator.json` | A layout written by the build-202611100807 code (5 groups incl. Your Apps, 23 apps, official icons, favorites, dock, order, detected catalog apps) |
| `full-coverage.json` | Baseline plus a custom group (collapsed), photo icon with gradient, emoji icon, Shortcut target, Needs Attention flag, launch history, dock, hidden and collapsed sections, recent searches, photo + bundled wallpaper, a deleted catalog app (Slack) |
| `legacy-early.json` | Oldest shape: most fields missing, one app without an ID |
| `future-unknown-fields.json` | A newer GO's file: unknown keys, an unknown icon kind, a malformed group, schemaVersion 9 |

`LayoutCompatibilityTests` and `StateBackupsTests` (16 tests) run with:

```bash
xcodebuild test -project GoLauncher.xcodeproj -scheme GoLauncher -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Migration and recovery policy

1. **Additive only.** New saved fields use `decodeIfPresent` with defaults. `schemaVersion` is now 2 (absent = 1). Version 2 adds `schemaVersion` and `setup` only; nothing is renamed or removed.
2. **Restore point per build.** Before a new build loads or saves anything, GO copies `state.json` to `Backups/state-<time>-update-<previous build>.json` (once per build; the newest 8 copies are kept).
3. **No silent loss.** Apps and groups decode one at a time; one GO can't read is skipped rather than failing the whole layout, and the original file is copied (`-unreadable-`) before anything is saved over it. A completely unreadable file is copied the same way and GO starts from the starter layout.
4. **Photos stay with restore points.** Cleanup of unused photos keeps every photo a restore point references, and is skipped entirely after a failed load.
5. **Restore and reset make a copy first** (`-restore-`, `-manual-`). Restoring keeps the current setup progress and start screen.
6. **Widget launch log:** GO saves the merged layout before clearing the log, so a launch is never lost; if GO is killed between those two steps the launch can count twice (accepted; low impact).

## Data compatibility for rollbacks

- An older build reading a version-2 layout ignores `schemaVersion` and `setup` and drops them on its next save. The layout itself is unaffected; setup progress resets.
- An older build can't read the `Backups/` folder; copies stay on disk until a newer build is installed again.
- A source rollback doesn't reverse data. If a rollback build must start from an earlier layout, restore a restore point with the newer build first (Design › Restore Points), then install the rollback.
