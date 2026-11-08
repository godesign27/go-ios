# Go — your own iPhone home screen

**Go** is a launcher app for iPhone. Design your own home screen and open any app from it:

- **Custom icons and colors.** Every icon can be an SF Symbol, an emoji, or a photo, on a solid or gradient color. Icon shape can be anything from square to circle.
- **Your own organization.** The screen opens with **Recently Used** (two rows) and **Favorites**, then Essentials, **Most Used**, your other groups (including **AI**), and **Needs Attention** for apps you've flagged. Rearrange any of them in Groups & Dock. Reorder by drag and drop, and collapse any section.
- **Quick search and launch.** Type a few letters, press **Go**, and the best match opens. Results are ranked by name, extra keywords, and fuzzy matching, then by the apps you use most.
- **Themes.** Six presets (Midnight, Sunset, Ocean, Mint, Paper, Mono) plus full control over gradient, wallpaper photo, fonts, label colors, columns, icon size, and matching "aesthetic" icon colors. Changes show live as you edit.

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

## Using Go

| To… | Do this |
| --- | --- |
| Open an app | Tap its icon, or tap the search button (bottom right), type, and press **Go** |
| Add an app | **•••** › **Add App**: pick from the list, or choose **Custom** |
| Edit an icon (name, symbol, emoji, photo, colors) | Long-press › **Edit Icon** |
| Rearrange | Long-press an icon and drag it onto another icon or onto a group title |
| Move to another group | Long-press › **Move to Group** |
| Edit everything at once | **•••** › **Edit Layout**. Icons wiggle: tap one to edit, **–** to remove, **+** to add |
| Add an app to Favorites | Long-press › **Add to Favorites**. The Favorites section shows them all; the Favorite Apps widget shows the first four. |
| Flag an app to come back to | Long-press › **Needs Attention**. Opening the app clears the flag. |
| Arrange sections, rename/add/delete groups, hide automatic sections | **•••** › **Groups & Dock** |
| Bring back the bottom dock | **•••** › **Groups & Dock** › **Show Dock**, then long-press apps › **Add to Dock** |
| See more apps in a section | Swipe the row left, or tap **View All** (a search bar appears at the bottom when there are more than four rows) |
| Show every app at once instead of swipe rows | **•••** › **Design** › Layout & behavior › Sections › **Full Grid** |
| Use the real app logos | On by default: Go downloads each app's official icon from the App Store. Turn off in **Design › Icons › Official app icons**; pick one by hand in the icon editor › **Find App Store Icon** |
| Change the look | **•••** › **Design** |
| Two widgets at the top (Date & Time, Weather, Favorite Apps) | **•••** › **Design** › **Widgets** › **Show widgets**, then pick Left and Right |
| Edge-to-edge square tiles (no spacing, bigger tap areas) | **•••** › **Design** › Style › **Tiles**, or set the **Spacing** slider yourself |

### When an app won't open: use a Shortcut

Go opens apps through their links (URL schemes such as `spotify://`). Most popular apps have one and are already in the **Add App** list. Developers can change these links, and some apps (like Camera) have none.

**Any app can be opened with a Shortcut:**

1. Open the **Shortcuts** app, tap **+**, and add the **Open App** action. Choose the app.
2. Name the shortcut, e.g. `Open Camera`.
3. In Go, edit the icon, set **Opens with** to **Shortcut**, and type that exact name.

This also works for anything else Shortcuts can do, like "Text Mom" or "Start Workout Playlist".

---

## Make it feel like your home screen

- **Put Go in the iPhone Dock.** Move Apple's other Dock icons onto a page, then drag Go into the Dock.
- **Hide Apple's home screen pages.** Long-press the home screen, tap the page dots, and uncheck every page except one with Go on it. Your apps stay in the App Library.
- **Open Go by tapping the back of the phone.** Settings › Accessibility › Touch › **Back Tap** › Double Tap › choose a Shortcut that opens Go.
- **Jump straight into search.** Turn on **Design › Open straight into search**. The keyboard is then ready every time you open Go.
- **Go's own links**, for Shortcuts, Back Tap, or the Action button:
  - `golauncher://search` opens Go with search focused
  - `golauncher://open?name=Spotify` opens your best match for "Spotify" through Go

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
  Support/                  Hex colors, image downscaling
```

Your layout is saved automatically to the app's Application Support folder (`state.json`, plus any photos you picked). No account, no network, no tracking.
