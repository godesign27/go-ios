# GO Launcher: How the App Works

A briefing for strategy work. It covers what the product is, what it does today, what iOS allows and forbids, how it is built, and where it stands.

**Status as of November 10, 2026:** working beta on TestFlight (build 202611100807), internal testers only, version 1.0. Not yet submitted to the App Store. Bundle ID `com.godesign.golauncher`, publisher GO design, Inc.

---

## 1. What it is

GO Launcher (shown on the Home Screen as **Go**) is an iPhone app that works as a personal, designed home screen. You arrange your apps into your own groups and sections, style everything (wallpaper, glass cards, icon shapes, fonts), and launch apps from Go instead of from Apple's grid.

**The core constraint:** iOS does not allow any app to replace Apple's Home Screen. Go gets as close as the platform permits, in three ways:

1. **The Go app itself:** a full-screen, customizable launcher you open from the Dock, Back Tap or the Action Button.
2. **Go widgets on Apple's Home Screen:** your Go sections (Favorites, Recently Used, groups like AI or Tools) as widgets in Go's style. Tapping an app opens it.
3. **Go everywhere else:** a Control Center / Lock Screen / Action Button search control, Siri phrases, and Shortcuts actions.

Together with a matching wallpaper exported from Go, the iPhone's own Home Screen can look and behave like Go.

**Target user:** people who want a calmer, more personal, better-organized phone than Apple's icon grid allows: design-minded users, people with many apps, people who want AI apps and work apps grouped and one tap away.

---

## 2. Feature inventory (what works today)

### 2.1 The launcher (in the app)

| Area | What it does |
| --- | --- |
| **Sections** | The screen is a vertical list of sections. Automatic ones: **Recently Used** (two rows), **Favorites**, **Most Used**, **Needs Attention**. User groups: Essentials, Everyday, Tools, AI, Your Apps (rename, add, delete, reorder). Each section is one swipeable row with **View All**, or switch to **Full Grid**. Sections collapse. |
| **Launching** | Tap an icon to open the app through its URL scheme (e.g. `spotify://`). Any app without a scheme can be opened through a Shortcut ("Opens with: Shortcut"). |
| **Search** | Search button (bottom right) opens a full-screen search with recent searches and suggestions. Type a few letters, press **Go**, and the best match opens. Ranking: name prefix, then word prefix, contains, keywords, fuzzy subsequence, then launch count. Falls back to a web search. |
| **App detection** | iOS won't list installed apps. Go checks its 67-app catalog with `canOpenURL` each time it opens and adds the ones it finds to **Your Apps**. Deleted apps stay deleted. Apps outside the catalog are added by hand (**Add App › Custom**). |
| **Icons** | Each app shows its **official App Store icon** (fetched from the iTunes Search API by bundle ID), or a custom SF Symbol, emoji or photo on a solid or gradient color. Icon shape runs from square to circle. |
| **Editing** | Long-press for Edit Icon, Move to Group, Add to Favorites, Needs Attention (a manual flag, cleared when opened) and Add to Dock. **Edit Layout** mode (wiggle) with drag-and-drop between groups. |
| **Widgets inside Go** | Two cards at the top: Date & Time, Weather (Open-Meteo, location optional) or Favorite Apps. |
| **Dock** | Optional bottom dock of up to 5 apps. |
| **Deep links** | `golauncher://search`, `golauncher://open?name=Spotify`, `golauncher://launch?id=…`, `golauncher://section?key=…` |

### 2.2 Design system

| Area | What it does |
| --- | --- |
| **Styles** | **Classic** (cards tinted with the background color, Liquid Glass on iOS 26), **Glass** (frosted "atmospheric" glass cards) and **Tiles** (edge-to-edge square tiles, names inside). Plus a **Containers** switch: off means apps sit directly on the wallpaper. |
| **Presets (13)** | **Cloud** (default: cloud white with deep navy text), **Onyx** (near-black navy with white text), five AI-generated wallpapers made in Krea (Twilight, Dusk, Haze, Daybreak, Blush), and six color gradients (Midnight, Sunset, Ocean, Mint, Paper, Mono). |
| **Customization** | Gradient colors, your own wallpaper photo with dimming, fonts (Standard, Rounded, Serif, Mono), label color, columns, icon size, spacing, uniform icon colors, show or hide clock and name greeting, open straight into search. |
| **Accessibility** | Measured to WCAG AA (4.5:1 text contrast) on every preset, in Classic and Glass, and with containers on or off. A **contrast guard** measures the wallpaper (including your photos) and adds a tint in the wallpaper's own deep color behind text, only as much as needed, instead of dimming the screen with black. Reduce Transparency switches the glass to solid. Known gap: **text does not yet scale with Dynamic Type.** |
| **Liquid Glass** | iOS 26 Liquid Glass on the control layer (search button, menus, dock) and Classic cards, with a frosted fallback on iOS 17–25. |

### 2.3 Go on Apple's Home Screen (iOS 18+)

| Area | What it does |
| --- | --- |
| **Widgets** | Four widget types in small, medium and large: **Favorites**, **Recently Used** and **Most Used** (no setup), plus **Go Group** (choose any group via Edit Widget). They use Go's theme and official icons and adapt to tinted and clear Home Screen styles. Medium shows two rows when a section has more than 4 apps. |
| **Widget taps** | Medium and large: tapping an app goes through Go, which opens the app instantly, in one tap (confirmed on device). Small: a direct-open action (iOS treats small widgets as one tap target). Every widget launch counts in Recently Used and Most Used. |
| **Wallpaper export** | **Save Background as iPhone Wallpaper** renders Go's background at screen resolution and saves it to Photos, so Apple's Home Screen matches Go. |
| **Setup guide** | Design › **Set Up Go as My Home Screen**: six steps (wallpaper, clear a page, add widgets, pick sections, hide Apple's other pages, add search). |
| **Go Search control** | For Control Center, the Lock Screen and the Action Button: one tap opens Go with the keyboard ready. |

### 2.4 Siri and Shortcuts

| Action | Use |
| --- | --- |
| **Search in Go** | Siri, Spotlight, Action Button: "Search in Go" |
| **Open App with Go** | Siri: "Open Slack with Go"; counts in Recently Used |
| **Log App in Go Recents** | For a Shortcuts automation ("When Slack is opened › Log App in Go Recents"), so apps opened from Apple's Home Screen also count in Go's Recently Used and Most Used. One automation per app. |

---

## 3. What iOS does not allow (hard limits)

These shape the strategy more than anything else. Every competitor faces the same limits.

| Limit | Consequence for Go |
| --- | --- |
| No app can replace the Home Screen | Go is a launcher you open, plus widgets on Apple's Home Screen. It cannot be the default. |
| No list of installed apps | Detection works only for apps in Go's catalog (67 today, capped at about 50 third-party checks by iOS). Others are added by hand. |
| No app-usage data from other apps | Go cannot see launches made outside Go. A Shortcuts automation per app is the workaround. Screen Time data can only be shown inside a sealed Apple view and can't be read. |
| No badge counts or notifications from other apps | Go cannot show unread counts from Slack, Teams and others. The **Needs Attention** flag is the manual substitute. |
| No other apps' widgets | Go can't host Apple's or other developers' widgets; it builds its own (Date & Time, Weather, Favorites). |
| Apps open through URL schemes | Each app needs a known scheme, and schemes can change. Shortcuts are the universal fallback. |
| Small widgets are one tap target | Per-app links work only in medium and large widgets; small ones use an intent action. |
| Apple's wallpapers and app artwork are copyrighted | Go ships its own wallpapers and uses App Store icons as each app publishes them. Apple's "dark" or "tinted" icon variants aren't available to other apps. |

---

## 4. How it is built

**Platform:** native SwiftUI, iPhone only, portrait. App runs on iOS 17+; widgets and controls need iOS 18+; Liquid Glass on iOS 26. About 5,600 lines of Swift in 31 files. No third-party dependencies, no backend, no accounts.

**Targets**
- **GoLauncher** (the app)
- **GoWidgets** (WidgetKit extension: section widgets plus the Go Search control)

They share layout data through an App Group (`group.com.godesign.golauncher`).

**Code map**

| Folder | Contents |
| --- | --- |
| `GoLauncher/App` | App entry, App Shortcuts (Siri phrases), app-only intents (Open App with Go, Log App in Go Recents, Go app entity) |
| `GoLauncher/Models` | `LauncherApp`, `AppGroup`, `LauncherState`, `Theme` and presets, `AppCatalog` (67 apps: URL schemes, bundle IDs, symbols, colors) |
| `GoLauncher/Store` | `LauncherStore` (state, search, drag-and-drop, launch tracking, installed-app sync, auto-save), App Store icon fetcher, weather service |
| `GoLauncher/Shared` | Code shared with the widget extension: storage paths and migration, widget launch log, section content, intents used by widgets |
| `GoLauncher/Support` | Glass materials and tokens, contrast guard, hex colors, image downscaling, wallpaper exporter |
| `GoLauncher/Views` | Home screen, search, editors, Design (theme) screen, groups, widgets row, setup guide |
| `GoWidgets` | Widget bundle, section widgets, tile view, Go Search control |

**Data:** the whole layout is one JSON file (`state.json`) plus picked photos and downloaded icons, stored in the shared App Group folder. Saving is debounced, and every launch saves immediately. All decoding is tolerant (missing fields fall back to defaults), so updates never reset a user's layout. Widget launches are written to a small log that the app merges when it opens.

**Network use:** only the iTunes Search API (official icons) and Open-Meteo (weather, only if location is allowed). No analytics, no tracking, no account.

**Build and release:** the Xcode project is generated by XcodeGen from `project.yml`. `scripts/testflight.sh` pulls, archives with a timestamp build number, and uploads to TestFlight in one command. The TestFlight group "GO Team" (internal) has automatic distribution.

---

## 5. Product decisions so far (and why)

- **Cloud is the default** (light, high contrast) after feedback that dark, dimmed looks were "bland and dull"; the user wanted vibrance and modernity.
- **Contrast through colored tint, not black dimming.** WCAG compliance first made wallpapers muddy, so it was redesigned to tint only behind text, in the wallpaper's own hue.
- **Official app icons stay original in every style.** Glass styles the containers, not the logos.
- **Widgets were split** into Favorites, Recently Used, Most Used and Go Group, because one configurable widget was too hidden behind Edit Widget.
- **One-tap launches from widgets** route through Go (instant, logged) because direct intent buttons proved unreliable.
- **Local-first and private:** no account, no server, no tracking.

---

## 6. Open issues and unverified items

- **Dynamic Type** (text scaling) not supported yet; the biggest remaining accessibility gap.
- Untested on device: small-widget taps, the Log App in Go Recents automation, the Siri "Open … with Go" phrase.
- Some third-party URL schemes and App Store bundle IDs in the catalog may be wrong; they need checking against real installs.
- The browser preview (`preview/index.html`) is behind the current design.
- App Store submission not started: no screenshots, description, privacy labels or review notes yet. The privacy story is strong: no data collected.

---

## 7. Strategic questions worth working on

1. **Positioning.** Is Go a "designed home screen" (aesthetic and personalization) or a "focus/productivity launcher" (fewer distractions, faster launching)? The features support both; the message should pick one.
2. **Business model.** Options: paid upfront; free with a Pro tier (premium wallpapers and presets, more widget styles, more automation); or one-time unlock. There's no backend, so subscription value would need to come from content (wallpaper drops, theme packs) rather than services.
3. **Content as a moat.** The Krea wallpapers worked well. A regular stream of designed presets (wallpaper, colors, style) is easy to ship and easy to market.
4. **Onboarding.** The value lands fully only after the Home Screen setup (wallpaper, widgets, hiding pages). That's six manual steps today; the first-run experience will decide retention.
5. **Working within iOS limits.** Badges, usage data and app lists are blocked. Shortcuts automations and Siri are the sanctioned workarounds; whether to lean into "Go + Shortcuts" as a power-user story is a choice.
6. **AI angle.** An AI group exists by default, and Siri can now open apps through Go. A larger AI story (for example "ask Go what to open") would need on-device models or Apple Intelligence integration.
7. **Competition.** Other iOS launchers and widget/theme apps (icon packs, widget builders, launcher apps) all face the same limits. Go's edges are polish (Liquid Glass, accessibility), privacy, and the combination of in-app launcher, Home Screen widgets and search control.
