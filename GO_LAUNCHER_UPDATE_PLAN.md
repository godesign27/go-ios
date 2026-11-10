# GO Launcher Update Plan

Date: November 10, 2026
Status: Planning handoff; no implementation authorized by this document.

## Basis and scope

Based on the uploaded “GO Launcher: How the App Works” briefing (TestFlight build 202611100807) and the user's stated direction in “Improve iOS App Usability.” The prior assistant roadmap was returned as reference placeholders, so its exact wording could not be recovered. Phase details and acceptance criteria below are proposed execution guidance, not claims of additional prior approval. Confirm the current code and device behavior before implementation.

## Product direction

Keep one iOS app, retaining bundle ID `com.godesign.golauncher`. Update the existing product rather than publishing a second app. Preserve the current full-screen experience as **Classic Launcher**. This product label is distinct from the existing **Classic** visual style; retain Classic, Glass and Tiles styling.

Make the primary experience a GO-themed iPhone Home Screen: matching wallpaper, GO widgets, search controls and optional Shortcuts. The app becomes the place to configure that experience and use Classic Launcher. Users can choose either workflow and switch without losing their layout.

Do not promise a replacement for iOS or Apple's default Home Screen. Setup requires user actions in iOS. Retain local-first storage, no accounts, no backend and no tracking.

## Existing baseline

The briefing already reports Favorites, Recently Used, Most Used and Go Group widgets; wallpaper export; a six-step setup guide; search controls; Siri/Shortcuts actions; themes; and shared App Group storage. Improve and validate these features rather than recreate them.

Treat reported medium/large widget launching as an existing behavior to regression-test. Small-widget taps, external-launch logging automation and the Siri open-app phrase remain unverified according to the briefing.

## Phase 0 — Preserve and verify (P0)

- Record the current revision, build and supported OS/device matrix; retain a recoverable source baseline before implementation.
- Inventory current features and reproduce the critical launch paths on physical devices.
- Capture representative existing layouts, custom photos/icons, groups, favorites, dock, themes, deleted-app choices and usage history as migration fixtures.
- Review the catalog's URL schemes and bundle IDs against actual installs; document failures and Shortcut fallback.
- Distinguish a configured app, a detected app and an app that can actually launch. Do not imply complete installed-app detection.

Acceptance: baseline can be restored; known failures have reproducible steps; representative state fixtures exist; existing Classic Launcher and medium/large widget launches work before changes begin.

## Phase 1 — Home Screen-first setup and navigation (P0)

- Introduce a clear primary entry to **Set Up My GO Home Screen**, with **Open Classic Launcher** readily available.
- For existing users, explain the update and offer Home Screen setup without forcing a workflow change or moving their saved layout.
- Rework the existing guide into resumable steps: choose a theme, save wallpaper, prepare a page, add widgets, choose groups, and add search.
- Explain how to hide and restore other Home Screen pages; make this optional.
- Show concrete previews and honest instructions for actions users must perform in iOS. Allow skipping, revisiting and recovering from denied Photos permission.
- Keep Shortcut setup optional and outside the minimum first-use path.

Acceptance: a new tester can follow the guide on a physical iPhone without developer help; progress survives closing/reopening; all steps can be revisited; skipping a step does not block Classic Launcher; wallpaper export matches the selected background; existing users retain their previous entry behavior until choosing a change.

## Phase 2 — Reliable everyday launching (P0)

- Validate every supported widget family and size, empty states, large groups, theme changes and stale/deleted app entries.
- Preserve medium/large per-app launch behavior; communicate the single-target behavior of small widgets accurately.
- Verify search entry from the app and supported native controls, including keyboard readiness.
- Make failed URL-scheme launches understandable and provide a usable Shortcut setup/recovery path.
- Clarify that Recently Used and Most Used reflect launches recorded by GO, plus optional per-app Shortcuts automations. Needs Attention remains a manual flag.

Acceptance: physical-device checks cover widget taps, destination accuracy, launch recording without duplicates, group edits and widget refresh; small-widget behavior is documented from testing; unsupported or missing apps have a recovery path; no global usage tracking or unread-count claims appear in the UI.

## Phase 3 — Accessibility and polish (P1; before public release)

- Add Dynamic Type support to app text and usable layouts at accessibility sizes.
- Check VoiceOver labels, reading order, focus, controls and launch destinations.
- Recheck contrast for presets and custom wallpapers; retain colored contrast protection and Reduce Transparency behavior.
- Check constrained widget layouts with supported accessibility settings and legible fallbacks.
- Preserve official app icons and the current light Cloud default unless later product testing justifies a change.

Acceptance: key setup, search, editing and Classic Launcher flows remain usable at accessibility text sizes; controls are announced meaningfully; text is legible with custom photos and supported appearance settings; Reduce Transparency does not remove essential information.

## Phase 4 — TestFlight validation and release readiness (P1)

- Run an end-to-end upgrade from the current beta with real saved data, then a fresh-install setup.
- Test the app on iOS 17 and widgets/controls on their supported OS versions; confirm exact availability in the project and current Apple documentation before shipping.
- Validate Siri “Open … with Go” and Log App in Go Recents on devices. Explain the per-app automation setup cost.
- Prepare App Store screenshots, description, privacy disclosures and review notes that match observed behavior and actual network/data use.
- Refresh the browser preview only after the shipped direction is stable.

Acceptance: no blocking loss-of-data, launch, setup or accessibility defects; all claimed entry points work on supported devices; release materials explain iOS limits; privacy statements are verified rather than copied from assumptions; user approves the release separately.

## Migration and rollback

1. Keep existing app identity and App Group `group.com.godesign.golauncher`.
2. Before introducing schema changes, define a versioned, non-destructive migration and recovery policy for `state.json`, photos, icons and widget launch logs.
3. Preserve identifiers used by widgets, deep links and Shortcuts, or supply explicit compatibility handling. Do not silently regenerate app/group IDs.
4. Retain existing groups, order, favorites, themes, dock, custom apps, Shortcut mappings, manual flags, deletion choices and launch history.
5. Use safe defaults for new fields. Do not auto-enroll existing users into a redesigned layout or reset their current one.
6. Verify upgrade and interrupted-migration cases with fixtures. Protect original data from partial writes and avoid double-merging widget logs.
7. Record a source rollback procedure and data compatibility constraints. A source rollback alone may not reverse a migrated schema; restore only from a verified compatible backup.

Migration acceptance: before/after state comparisons show no unintended loss; existing widgets/deep links still resolve; restarting mid-upgrade is recoverable; switching between setup/configuration and Classic Launcher keeps the same saved configuration.

## Boundaries and dependencies

No second iOS app, custom iOS replacement, automatic Home Screen rearrangement, third-party notification badges, global usage monitoring or hosting other developers' widgets. Do not expand catalog detection promises without verifying platform constraints. Native controls, App Intents and widget behavior must be checked against the supported OS matrix during implementation.

Android is deferred until the iOS Home Screen-first update is validated. Track discovery and a native Android launcher separately in [GO_LAUNCHER_BACKLOG.md](GO_LAUNCHER_BACKLOG.md).

## Handoff order

Work through Phase 0, then setup and launching, then accessibility and release validation. Track individual work in the backlog. This document adds planning only; it does not request code changes, builds, uploads or a release.
