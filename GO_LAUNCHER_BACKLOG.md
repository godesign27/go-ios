# GO Launcher Backlog

Date: November 10, 2026
Status: In progress on branch `claude/ios-home-screen-update` (updated November 10, 2026). See **Progress and evidence** below.

See [GO_LAUNCHER_UPDATE_PLAN.md](GO_LAUNCHER_UPDATE_PLAN.md) for product decisions, release gates and migration requirements. Source: uploaded GO Launcher briefing plus the user's explicit direction. Exact earlier assistant roadmap text was unavailable. All items below are open unless the current project proves otherwise.

Priority: **P0** = core update prerequisite; **P1** = required before public release; **P2** = later improvement; **Deferred** = after iOS validation. No delivery dates or estimates are committed.

## iOS update queue

| ID | Priority / phase | Work | Done when | Status |
| --- | --- | --- | --- | --- |
| IOS-01 | P0 / 0 | Preserve current source/build and capture state fixtures | Baseline is recoverable; fixture coverage includes custom assets, groups, history and deletion choices. | Done (sim + device) |
| IOS-02 | P0 / 0 | Audit existing launch paths and catalog | Device results identify valid schemes, incorrect bundle IDs, missing apps and Shortcut fallback requirements. | Partly done; device app list needed |
| IOS-03 | P0 / 1 | Make Home Screen setup the primary product path | Clear setup entry and accessible Classic Launcher entry exist; existing users keep their prior workflow until choosing otherwise. | Built; device check pending |
| IOS-04 | P0 / 1 | Improve the existing six-step setup guide | Guide is resumable, skippable and repeatable; a new tester completes it without developer help. | Built; tester run pending |
| IOS-05 | P0 / 1 | Improve wallpaper preview/export and recovery | Saved wallpaper matches the theme at device resolution; denied permission and retry paths work. | Built; save-to-Photos device check pending |
| IOS-06 | P0 / 1 | Explain page preparation and restoration | Optional hide-page instructions include how to restore pages; no automatic rearrangement claim. | Built (wording unverified) |
| IOS-07 | P0 / 2 | Validate widget families and sizes | Favorites, Recents, Most Used and Go Group work in supported sizes with empty/full/stale states and theme updates. | Open (device) |
| IOS-08 | P0 / 2 | Resolve small-widget uncertainty | Physical-device behavior is verified, reliable and explained accurately as a single tap target. | Open (device) |
| IOS-09 | P0 / 2 | Verify native search entry points | Supported Control Center, Lock Screen, Action Button and app entry paths open search with keyboard ready. | Open (device) |
| IOS-10 | P0 / 2 | Improve launch failures and Shortcut fallback | Missing/unsupported apps produce actionable recovery; successful widget launches record once. | Built (app launches); widget failures open |
| IOS-11 | P0 / 2 | Clarify usage and attention labels | UI explains GO-recorded history, optional external-launch logging and manual Needs Attention. | Built |
| IOS-12 | P0 / cross-phase | Preserve data and compatibility | Upgrade fixtures pass; app/group identifiers, assets, widget links, history and Shortcut mappings survive; interrupted migration recovers. | Done for v2 schema (sim + device upgrade) |
| IOS-13 | P1 / 3 | Add Dynamic Type | Setup, search, editing and Classic Launcher remain usable at accessibility sizes. | Open |
| IOS-14 | P1 / 3 | Audit VoiceOver, contrast and transparency | Essential flows are understandable and legible across supported settings and custom wallpapers. | Partly (accent/button contrast) |
| IOS-15 | P1 / 4 | Validate Siri and per-app logging automation | Siri open-app phrase and Log App in Go Recents work on devices; setup steps and limitations are documented. | Open (device) |
| IOS-16 | P1 / 4 | Run upgrade/fresh-install TestFlight acceptance | Supported device/OS matrix passes with no blocking data loss, launch, setup or accessibility defect. | Open |
| IOS-17 | P1 / 4 | Prepare accurate App Store materials | Screenshots, description, privacy disclosures and review notes reflect tested behavior and verified data use. | Open |
| IOS-18 | P2 / after stabilization | Refresh browser preview | Preview reflects the released design and clearly represents any simulated interactions. | Open |

## Progress and evidence

Branch `claude/ios-home-screen-update`; commits `02c64ea` (Phase 0) and `85fc776` (Phases 1–2), plus the backlog update. Nothing uploaded to TestFlight. **Tested** means observed; **unverified** means built but not yet seen working on a physical iPhone.

**Test environment:** Xcode 27.0, iOS 27 SDK. Simulators: iPhone 17 (iOS 26.5, carrying a layout from the baseline build) and iPhone 17 Pro (iOS 26.5, fresh install). Physical: iPhone 16e, iOS 27.2 (24B119). It had build 202611100650 installed, not the latest TestFlight build 202611100807. A development build 202611101016 now replaces it; reinstall from TestFlight to go back.

### IOS-01 — Baseline and fixtures (done)
- Tags `build-202611100807` (`1513f9f`, the TestFlight source) and `baseline-pre-ios-update` (`19d08f0`). Matrix, inventory and rollback steps are in [docs/BASELINE.md](docs/BASELINE.md).
- `GoLauncherTests` has 16 tests on four fixtures: baseline build, full coverage (photo/emoji icons, Shortcut target, flags, dock, history, hidden and collapsed sections, deleted catalog app, wallpaper), legacy, and newer-version. All pass: `xcodebuild test -scheme GoLauncher -destination 'platform=iOS Simulator,name=iPhone 17'`.

### IOS-02 — Launch paths and catalog (partly done)
- **Found and fixed:** Apple's `canOpenURL` docs say apps linked on iOS 27 or later may declare at most 25 query schemes. GO declared 48. It now declares the 25 highest-priority ones and no longer asks iOS about undeclared schemes. The 23 apps dropped from auto-detection still open when added by hand. They're listed in BASELINE.md.
- **Device (tested):** on the iPhone 16e the new build queried the declared schemes with no "not allowed" errors. 17 schemes returned -10814 (no app installed for that link). That's consistent with the apps installed on that phone, but it was not cross-checked against them.
- **Open:** compare **Check My Apps** with the apps actually installed, on the daily-use iPhone. Record any wrong schemes or bundle IDs here.

### IOS-03/04/05/06 — Home Screen-first setup (built)
- The **GO Home Screen** hub is reached from Customize › Set Up GO Home Screen, from Design, and from a one-time card for existing users. It has six steps (look, wallpaper, page, widgets, groups, search) plus two optional ones (hide/restore pages, launch logging). Each step can be done, skipped, undone and revisited, and progress is saved. "When GO Opens" chooses between Classic Launcher and GO Home Screen.
- **Simulator (tested):**
  - Existing layout: still opens to Classic Launcher, with the card shown.
  - Card → hub → Mark as Done moves on to step 2.
  - Progress survived a relaunch ("1 of 6", Continue went to the wallpaper step).
  - The wallpaper preview renders.
  - With Photos access revoked, the "Photos access is off" recovery and Open GO's Settings button appear.
  - Fresh install: the welcome screen shows; choosing Home Screen saved `homeScreenSetup`; a cold relaunch opened the hub.
  - A cold `golauncher://section` link skipped the hub.
- **Device (tested):** an existing user kept `startScreen=classicLauncher` with the announcement pending (from the debug startup log).
- **Unverified:**
  - Saving to Photos from the step. Simulator taps were unreliable, but it uses the same save call as Design.
  - A new tester completing the guide on an iPhone.
  - Whether the iOS wording in each step matches iOS 26/27. Apple's support pages couldn't be fetched, so the instructions are from knowledge and the earlier guide.
  - Whether the start screen reappears after more than 5 minutes in the background.

### IOS-10/11 — Failures and labels (built)
- A failed launch now offers **Fix Link**, and the app is marked in Check My Apps ("Didn't open last time"). A failed launch is no longer counted.
- Empty states for Recently Used and Most Used say they count launches through GO. Needs Attention says it's a manual flag and that GO can't see notifications. The hub's optional step explains Shortcuts logging and its per-app cost.
- **Open:** widget launches can't report failure (`OpenURLIntent` gives no result). Recovery for those goes through Check My Apps.

### IOS-12 — Data and compatibility (done for schema 2)
- **Restore points:**
  - Made once per new build, before a restore or reset, and when a file can't be fully read. The newest 8 are kept.
  - Photo cleanup keeps photos that restore points reference, and is skipped after a failed load.
  - Apps and groups decode one at a time.
  - `schemaVersion` 2 is stamped on save.
- **Simulator upgrade:** a restore point was written before any save, and all 15 images were kept.
- **Device upgrade (tested):** iPhone 16e, from build 202611100650 to the new build. The layout loaded clean: 28 apps, 5 groups, 4 favorites, 20 image icons, 4 docked, launch history kept. Restore points `update-unknown` and `update-202611101015` were created.
- **Not tested:** an interrupted upgrade on a device. It's covered by the unreadable-file path in the tests.

### IOS-14 — Contrast (partly done)
- The accent was #7C6AF4: 4.0:1 on white and 3.5:1 on dark grouped backgrounds. It's now #5B47E0 in light mode (6.1:1) and #A99BFF in dark mode (5.9:1). Filled buttons use #5B47E0 with white text (6.1:1).
- The full VoiceOver and Dynamic Type audit is still open (IOS-13).

### Device checks for the next session (need a person on the iPhone)
1. Run setup as a new tester: save the wallpaper, set it, add each widget size, pick groups, add Go Search to Control Center.
2. Small widget: tap each tile and record whether the tapped app opens (IOS-08).
3. Medium and large widgets: regression-check tile taps (destination is correct, counts once).
4. Go Search from Control Center, the Lock Screen and the Action Button: confirm the keyboard is up (IOS-09).
5. Siri "Open Slack with Go", and a Log App in Go Recents automation (IOS-15).
6. Check My Apps against the apps actually installed (IOS-02).

## Later product decisions

| ID | Priority | Item | Exit criterion |
| --- | --- | --- | --- |
| PROD-01 | P2 | Refine positioning and test setup comprehension | User feedback supports a clear designed-Home-Screen promise; speed/focus benefits remain grounded in real workflows. |
| PROD-02 | P2 | Consider additional designed theme/wallpaper packs | Core usability is stable; content rights, accessibility and maintenance effort are assessed. |
| PROD-03 | P2 | Choose a business model | Pricing/unlock options have a separate approved proposal; no billing change is implied by this plan. |
| PROD-04 | P2 | Evaluate a larger AI experience | A concrete user need and feasible private implementation are established before adding complexity. |
| PROD-05 | P2 | Evaluate catalog expansion | Real launch reliability and documented platform detection limits determine scope. |

## Android — deferred until iOS is validated

Android work starts after the iOS Home Screen-first update passes its release gates and the user chooses to begin Android. Do not delay the iOS update for shared architecture.

| ID | Order | Work | Acceptance / dependency |
| --- | --- | --- | --- |
| AND-01 | 1 | Define Android product scope | Decide whether GO should be a true default Home launcher, a companion/widget experience, or both; document current platform and distribution requirements. |
| AND-02 | 2 | Research native capabilities and privacy constraints | Verify installed-app access, launch intents, widgets, wallpaper, shortcuts, notification access and usage permissions against current official Android guidance; avoid blanket access assumptions. |
| AND-03 | 3 | Design Android-native interaction | Specify Home navigation, search, grouping, favorites, app drawer and customization for Android conventions; include accessibility. |
| AND-04 | 4 | Prototype core launcher behavior | On test devices, validate default-launcher selection and a clear route back to the prior launcher, app launching, widget hosting if in scope, and permission-denied behavior. |
| AND-05 | 5 | Define portable data and migration | Assess which GO themes/groups can transfer; keep platform-specific launch identifiers separate; protect both platforms' data. |
| AND-06 | 6 | Plan device testing and release | Cover representative Android versions/OEMs, lifecycle, accessibility, privacy and store requirements before committing a build/release schedule. |

## Excluded from this update

- A second iOS app or replacement iOS operating system.
- Removing Classic Launcher or resetting existing users' layouts.
- Claims of global iOS app usage, third-party unread badges or automatic Home Screen setup.
- New backend, account, analytics or monetization infrastructure without a separate decision.

## Execution notes

The briefing reports many features as already implemented. Each item should begin with inspection and reproduction, then the smallest necessary change. Retain the distinction between Classic Launcher (workflow) and Classic (visual style). Verify Apple/Android API details using current official documentation during implementation; this backlog is not an API specification.

For each completed item, record the implementing revision, physical-device evidence where applicable, migration result and any known limitations. Documentation-only changes do not require app builds or deployments.
