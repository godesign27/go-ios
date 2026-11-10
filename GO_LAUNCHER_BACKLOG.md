# GO Launcher Backlog

Date: November 10, 2026
Status: Proposed work queue; no code changes included.

See [GO_LAUNCHER_UPDATE_PLAN.md](GO_LAUNCHER_UPDATE_PLAN.md) for product decisions, release gates and migration requirements. Source: uploaded GO Launcher briefing plus the user's explicit direction. Exact earlier assistant roadmap text was unavailable. All items below are open unless the current project proves otherwise.

Priority: **P0** = core update prerequisite; **P1** = required before public release; **P2** = later improvement; **Deferred** = after iOS validation. No delivery dates or estimates are committed.

## iOS update queue

| ID | Priority / phase | Work | Done when |
| --- | --- | --- | --- |
| IOS-01 | P0 / 0 | Preserve current source/build and capture state fixtures | Baseline is recoverable; fixture coverage includes custom assets, groups, history and deletion choices. |
| IOS-02 | P0 / 0 | Audit existing launch paths and catalog | Device results identify valid schemes, incorrect bundle IDs, missing apps and Shortcut fallback requirements. |
| IOS-03 | P0 / 1 | Make Home Screen setup the primary product path | Clear setup entry and accessible Classic Launcher entry exist; existing users keep their prior workflow until choosing otherwise. |
| IOS-04 | P0 / 1 | Improve the existing six-step setup guide | Guide is resumable, skippable and repeatable; a new tester completes it without developer help. |
| IOS-05 | P0 / 1 | Improve wallpaper preview/export and recovery | Saved wallpaper matches the theme at device resolution; denied permission and retry paths work. |
| IOS-06 | P0 / 1 | Explain page preparation and restoration | Optional hide-page instructions include how to restore pages; no automatic rearrangement claim. |
| IOS-07 | P0 / 2 | Validate widget families and sizes | Favorites, Recents, Most Used and Go Group work in supported sizes with empty/full/stale states and theme updates. |
| IOS-08 | P0 / 2 | Resolve small-widget uncertainty | Physical-device behavior is verified, reliable and explained accurately as a single tap target. |
| IOS-09 | P0 / 2 | Verify native search entry points | Supported Control Center, Lock Screen, Action Button and app entry paths open search with keyboard ready. |
| IOS-10 | P0 / 2 | Improve launch failures and Shortcut fallback | Missing/unsupported apps produce actionable recovery; successful widget launches record once. |
| IOS-11 | P0 / 2 | Clarify usage and attention labels | UI explains GO-recorded history, optional external-launch logging and manual Needs Attention. |
| IOS-12 | P0 / cross-phase | Preserve data and compatibility | Upgrade fixtures pass; app/group identifiers, assets, widget links, history and Shortcut mappings survive; interrupted migration recovers. |
| IOS-13 | P1 / 3 | Add Dynamic Type | Setup, search, editing and Classic Launcher remain usable at accessibility sizes. |
| IOS-14 | P1 / 3 | Audit VoiceOver, contrast and transparency | Essential flows are understandable and legible across supported settings and custom wallpapers. |
| IOS-15 | P1 / 4 | Validate Siri and per-app logging automation | Siri open-app phrase and Log App in Go Recents work on devices; setup steps and limitations are documented. |
| IOS-16 | P1 / 4 | Run upgrade/fresh-install TestFlight acceptance | Supported device/OS matrix passes with no blocking data loss, launch, setup or accessibility defect. |
| IOS-17 | P1 / 4 | Prepare accurate App Store materials | Screenshots, description, privacy disclosures and review notes reflect tested behavior and verified data use. |
| IOS-18 | P2 / after stabilization | Refresh browser preview | Preview reflects the released design and clearly represents any simulated interactions. |

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
