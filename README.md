# Go — your own iPhone home screen

**Go** is a launcher app for iPhone. Design your own home screen and open any app from it:

- **Custom icons and colors.** Every icon can be an SF Symbol, an emoji, or a photo, on a solid or gradient color. Icon shape can be anything from square to circle.
- **Your own organization.** The screen opens with **Recently Used** (two rows) and **Favorites**, then Essentials, **Most Used**, your other groups (including **AI**), and **Needs Attention** for apps you've flagged. Rearrange any of them in Groups & Dock. Reorder by drag and drop, and collapse any section.
- **Quick search and launch.** Type a few letters, press **Go**, and the best match opens. Results are ranked by name, extra keywords, and fuzzy matching, then by the apps you use most.
- **Themes.** High-contrast Cloud (the default: cloud white with deep navy text) and Onyx (near-black navy with white text), five atmospheric wallpapers (Twilight, Dusk, Haze, Daybreak, Blush) and six color presets (Midnight, Sunset, Ocean, Mint, Paper, Mono), three styles (Classic tinted cards, Glass frosted cards and see-through icons, edge-to-edge Tiles) plus full control over gradient, wallpaper photo, fonts, label colors, columns, icon size, and matching "aesthetic" icon colors. Changes show live as you edit.

> **Why an app and not a "plugin"?** iOS doesn't let anything replace Apple's home screen. The closest you can get is a launcher like Go: keep it in your Dock or open it with Back Tap, and it becomes your real home screen. See [Make it feel like your home screen](#make-it-feel-like-your-home-screen).

---

## Install it on your iPhone

You need a **Mac with Xcode** (free on the Mac App Store) and an iPhone on **iOS 17 or later**. Use **Xcode 26** with an iPhone on **iOS 26** to get Apple's Liquid Glass look; older versions build fine and use a frosted look instead. A free Apple ID is enough; a paid developer account works too.

1. **Get the code**
   ```bash
   git clone https://github.com/godesign27/go-ios.git
   cd go-ios
   ```
2. **Generate the Xcode project.** The project is described in `project.yml` and built with [XcodeGen](https://github.com/yonaskolb/XcodeGen):
   ```bash
   brew install xcodegen   # one time
   xcodegen
   open GoLauncher.xcodeproj
   ```
3. **Set up signing.** In Xcode, click the **GoLauncher** project, then the **GoLauncher** target, then **Signing & Capabilities**:
   - **Team:** pick your Apple ID or your developer team (add it under Xcode › Settings › Accounts if needed).
   - **Bundle Identifier:** change it to something unique, e.g. `com.yourname.golauncher`.
4. **Run it.** Plug in your iPhone (or connect over Wi-Fi), choose it at the top of Xcode, and press **▶ Run**.
5. **First launch only.** On the iPhone, go to **Settings › General › VPN & Device Management**, tap your Apple ID, then **Trust**. If iOS asks, also turn on **Settings › Privacy & Security › Developer Mode**.

> With a **free** Apple ID, apps you install yourself expire after **7 days**. Plug in and press Run again to renew; your layout is kept. A paid Apple Developer account ($99/yr) extends this to a year.

---

### Upload to TestFlight (install on other iPhones)

With the app created in App Store Connect and your account signed in to Xcode, run:

```bash
./scripts/testflight.sh
```

It pulls the latest code, archives with a fresh build number, and uploads. The build shows up in App Store Connect › TestFlight after 5–30 minutes of processing.

---

## Using Go

| To… | Do this |
| --- | --- |
| Open an app | Tap its icon, or tap the search button (bottom right), type, and press **Go** |
| Add an app | **Customize** (sliders button) › **Add App**: pick from the list, or choose **Custom** |
| Get the apps already on your iPhone | Automatic: each time Go opens, it checks for the ~50 popular apps it knows and adds the ones you have to **Your Apps**. iOS doesn't let any app see everything installed, so add others with **Add App › Custom**. Delete one and it stays deleted. |
| Edit an icon (name, symbol, emoji, photo, colors) | Long-press › **Edit Icon** |
| Rearrange | Long-press an icon and drag it onto another icon or onto a group title |
| Move to another group | Long-press › **Move to Group** |
| Edit everything at once | **Customize** (sliders button) › **Edit Layout**. Icons wiggle: tap one to edit, **–** to remove, **+** to add |
| Add an app to Favorites | Long-press › **Add to Favorites**. The Favorites section shows them all; the Favorite Apps widget shows the first four. |
| Flag an app to come back to | Long-press › **Needs Attention**. Opening the app clears the flag. |
| Apps right on the background (no containers) | **Customize** › **Design** › Style › turn off **Containers** |
| Arrange sections, rename/add/delete groups, hide automatic sections | **Customize** (sliders button) › **Groups & Dock** |
| Bring back the bottom dock | **Customize** (sliders button) › **Groups & Dock** › **Show Dock**, then long-press apps › **Add to Dock** |
| See more apps in a section | Swipe the row left, or tap **View All** (a search bar appears at the bottom when there are more than four rows) |
| Show every app at once instead of swipe rows | **Customize** (sliders button) › **Design** › Layout & behavior › Sections › **Full Grid** |
| Use the real app logos | On by default: Go downloads each app's official icon from the App Store. Turn off in **Design › Icons › Official app icons**; pick one by hand in the icon editor › **Find App Store Icon** |
| Change the look | **Customize** (sliders button) › **Design** |
| Two widgets at the top (Date & Time, Weather, Favorite Apps) | **Customize** (sliders button) › **Design** › **Widgets** › **Show widgets**, then pick Left and Right |
| Switch between Classic, Glass and Tiles | **Customize** (sliders button) › **Design** › **Style** |
| Edge-to-edge square tiles (no spacing, bigger tap areas) | **Customize** (sliders button) › **Design** › Style › **Tiles**, or set the **Spacing** slider yourself |

### When an app won't open: use a Shortcut

Go opens apps through their links (URL schemes such as `spotify://`). Most popular apps have one and are already in the **Add App** list. Developers can change these links, and some apps (like Camera) have none.

**Any app can be opened with a Shortcut:**

1. Open the **Shortcuts** app, tap **+**, and add the **Open App** action. Choose the app.
2. Name the shortcut, e.g. `Open Camera`.
3. In Go, edit the icon, set **Opens with** to **Shortcut**, and type that exact name.

This also works for anything else Shortcuts can do, like "Text Mom" or "Start Workout Playlist".

---

## Make Go your Home Screen

iOS doesn't let any app replace Apple's Home Screen, so Go goes everywhere iOS *does* allow:

- **Go Section widgets** (iOS 18+) put your Go layout on the real Home Screen: small (4 apps), medium (4 or 8) or large (16). Each one shows the section you pick: Favorites, Recently Used, Most Used, Needs Attention or any group. They follow your Go theme (Classic, Glass or Tiles, official icons) and update when you change Go. Tap a tile to open the app; tap around the tiles to open that section in Go.
- **Matching wallpaper:** Design › Go on your Home Screen › **Save Background as iPhone Wallpaper**, then set it in Photos.
- **Go Search control** for Control Center, the Lock Screen and the Action Button: one tap and you're typing an app name. Also in Siri, Spotlight and Shortcuts as "Search in Go".

Step by step, in the app: Design › **Set Up Go as My Home Screen**. In short:

1. Save the background as your wallpaper.
2. Long-press the Home Screen, move the first page's icons to the App Library.
3. Tap **Edit › Add Widget**, search **Go**, add Go Section widgets, and long-press each › **Edit Widget** to pick its section.
4. Tap the page dots and hide Apple's other pages.
5. Add **Go Search** to Control Center (and the Lock Screen or Action Button).

If an app doesn't open from a widget tile, turn off **Design › Widgets open apps directly**; taps then go through Go, which opens any app it can.

Go's own links, for Shortcuts or Back Tap:
- `golauncher://search` opens Go with search focused
- `golauncher://open?name=Spotify` opens your best match for "Spotify" through Go
- `golauncher://section?key=favorites` opens a section's View All

---

## Project layout

```
project.yml                 XcodeGen project definition (iOS 17+, iPhone)
GoLauncher/
  App/GoLauncherApp.swift   App entry point
  Models/                   LauncherApp, AppGroup, Theme + presets, app catalog (URL schemes)
  Store/LauncherStore.swift Layout state, search, drag/drop moves, auto-save to disk, photo storage
  Views/
    HomeView.swift          The home screen: clock, search, groups grid, dock, edit mode
    IconTile.swift          Icon rendering (symbol / emoji / photo, solid or gradient)
    AppEditorView.swift     Create/edit an icon
    AddAppView.swift        Catalog of known apps + custom
    GroupsView.swift        Manage groups
    ThemeView.swift         Design settings and presets
    SymbolPickerView.swift  SF Symbol chooser
  Shared/                   Compiled into the app and the widgets: App Group storage,
                            section contents, widget/control intents
  Support/                  Colors, glass, contrast, image downscaling, wallpaper export
GoWidgets/                  Home Screen widget extension (iOS 18+): Go Section widget, tiles,
                            open-app intent, Go Search control
```

Your layout is saved automatically in an App Group folder shared by the app and its widgets (`state.json`, plus icons and photos). Layouts from earlier versions move there on first launch. No account, no tracking; the network is used only for official app icons and the optional Weather widget.
