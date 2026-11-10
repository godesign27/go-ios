import Photos
import SwiftUI
import UIKit

/// One setup step: what to do in iOS, any action GO can take, and Done / Skip.
struct SetupStepView: View {
    @EnvironmentObject private var store: LauncherStore
    let step: SetupStep
    @Binding var path: [SetupStep]
    let openDesign: () -> Void

    private var status: LauncherStore.StepStatus { store.status(of: step) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: step.symbol)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text(step.title).font(.title2.weight(.bold))
                    Text(step.summary).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            content

            Section {
                if status != .done {
                    Button {
                        store.setStatus(.done, for: step)
                        advance()
                    } label: {
                        Label("Mark as Done", systemImage: "checkmark.circle.fill")
                            .font(.body.weight(.semibold))
                    }
                }
                if status == .pending {
                    Button {
                        store.setStatus(.skipped, for: step)
                        advance()
                    } label: {
                        Label(step.isOptional ? "Not Now" : "Skip for Now", systemImage: "forward")
                    }
                }
                if status != .pending {
                    Button {
                        store.setStatus(.pending, for: step)
                    } label: {
                        Label(status == .done ? "Mark as Not Done" : "Unskip", systemImage: "arrow.uturn.backward")
                    }
                }
            } footer: {
                if let index = SetupStep.required.firstIndex(of: step) {
                    Text("Step \(index + 1) of \(SetupStep.required.count). Skipped steps stay in the list for later.")
                } else {
                    Text("Optional. GO works without it.")
                }
            }
        }
        .navigationTitle(step.isOptional ? "Optional" : "Step \((SetupStep.required.firstIndex(of: step) ?? 0) + 1)")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Done or skipped: on to the next unfinished step, or back to the overview.
    private func advance() {
        if !step.isOptional, let next = store.step(after: step) {
            path = [next]
        } else {
            path = []
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .theme: themeContent
        case .wallpaper: WallpaperStepContent { store.setStatus(.done, for: .wallpaper) }
        case .preparePage: preparePageContent
        case .addWidgets: addWidgetsContent
        case .chooseGroups: chooseGroupsContent
        case .addSearch: addSearchContent
        case .hidePages: hidePagesContent
        case .logLaunches: logLaunchesContent
        }
    }

    // MARK: - Steps

    private var themeContent: some View {
        Section {
            HStack {
                Text("Current style")
                Spacer()
                Text(styleName).foregroundStyle(.secondary)
            }
            Button(action: openDesign) {
                Label("Open Design", systemImage: "paintpalette")
            }
        } footer: {
            Text("Pick Classic, Glass or Tiles, then a preset, photo or gradient. GO's widgets and the wallpaper you save next use this look. You can change it later and save the wallpaper again.")
        }
    }

    private var styleName: String {
        let theme = store.state.theme
        if theme.isTiles { return "Tiles" }
        if theme.isGlass { return "Glass" }
        if theme.isClassic { return "Classic" }
        return "Custom"
    }

    private var preparePageContent: some View {
        Group {
            instructions([
                "Touch and hold an empty area of your Home Screen until the apps jiggle.",
                "Pick a page for GO, usually the first one. To clear it, touch and hold an app, tap Remove App, then tap Remove from Home Screen. The app stays installed in the App Library.",
                "Or drag apps to another page instead.",
                "Tap Done.",
            ], footer: "Nothing is deleted. GO can't move icons for you; iOS only lets you do it yourself.")
        }
    }

    private var addWidgetsContent: some View {
        Group {
            if #unavailable(iOS 18) {
                Section {
                    Label("GO's widgets need iOS 18 or later. Update in Settings › General › Software Update, or keep using Classic Launcher.", systemImage: "exclamationmark.triangle")
                }
            }
            instructions([
                "Touch and hold an empty area of your Home Screen until the apps jiggle.",
                "Tap Edit, then Add Widget, and search for GO.",
                "Swipe to the widget you want, pick a size, and tap Add Widget.",
                "Repeat for each widget, then tap Done.",
            ], footer: nil)
            Section {
                widgetRow("Favorites", "The apps you starred.", symbol: "star.fill")
                widgetRow("Recently Used", "Apps you opened through GO, newest first.", symbol: "clock.arrow.circlepath")
                widgetRow("Most Used", "Apps you open through GO most often.", symbol: "flame.fill")
                widgetRow("Go Group", "Any group: Essentials, AI, Tools or your own.", symbol: "rectangle.3.group")
            } header: {
                Text("GO widgets")
            } footer: {
                Text("Medium and large widgets open an app in one tap. Large shows up to 16 apps, medium up to 8.")
            }
        }
    }

    private func widgetRow(_ name: String, _ detail: String, symbol: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
        }
    }

    private var chooseGroupsContent: some View {
        Group {
            instructions([
                "Touch and hold a Go Group widget.",
                "Tap Edit Widget.",
                "Tap Section and choose a group.",
            ], footer: "Add a Go Group widget for each group you want on your Home Screen.")
            Section {
                ForEach(store.state.groups) { group in
                    Text(group.name)
                }
            } header: {
                Text("Your groups")
            } footer: {
                Text("Add or rename groups in Customize › Groups & Dock. Widgets update when you change them.")
            }
        }
    }

    private var addSearchContent: some View {
        Group {
            if #unavailable(iOS 18) {
                Section {
                    Label("The GO Search control needs iOS 18 or later. Until then, turn on “Open search when GO opens” below and keep GO in your Dock.", systemImage: "exclamationmark.triangle")
                }
            }
            instructions([
                "Swipe down from the top-right corner to open Control Center.",
                "Touch and hold an empty area (or tap + at the top left).",
                "Tap Add a Control, search for GO, and tap Go Search.",
            ], footer: nil, header: "Control Center")
            instructions([
                "Touch and hold the Lock Screen, then tap Customize and choose the Lock Screen.",
                "Tap a control at the bottom to replace it (or − to remove one first), then pick Go Search.",
            ], footer: nil, header: "Lock Screen")
            instructions([
                "Open Settings › Action Button.",
                "Swipe to Controls, tap Choose a Control, and pick Go Search.",
            ], footer: "On iPhones with an Action Button.", header: "Action Button")
            Section {
                Toggle("Open search when GO opens", isOn: $store.state.theme.searchOnOpen)
            } footer: {
                Text("Also useful with GO in your Dock: tap GO and start typing.")
            }
        }
    }

    private var hidePagesContent: some View {
        Group {
            instructions([
                "Touch and hold an empty area of your Home Screen until the apps jiggle.",
                "Tap the page dots above the Dock.",
                "Tap the circle under each page you want to hide, leaving your GO page checked. Tap Done.",
            ], footer: "Hidden pages aren't deleted, and their apps stay in the App Library (swipe left past your last page).", header: "Hide pages")
            instructions([
                "Touch and hold an empty area, then tap the page dots.",
                "Tap the circle under a hidden page to show it again, then tap Done.",
            ], footer: nil, header: "Show them again")
        }
    }

    private var logLaunchesContent: some View {
        Group {
            Section {
                Text("iOS doesn't tell GO when you open an app from Apple's Home Screen, Spotlight or another app. Recently Used and Most Used count apps opened through GO: the launcher, GO widgets, GO search and Siri's “Open … with Go”.")
                    .font(.subheadline)
            }
            instructions([
                "Open the Shortcuts app and tap Automation, then New Automation.",
                "Choose App, pick the app (for example Slack), select Is Opened, and choose Run Immediately.",
                "Add the action Log App in Go Recents and choose the same app.",
            ], footer: "One automation per app. Shortcuts may show a notification when it runs.", header: "Count an app from anywhere")
        }
    }

    private func instructions(_ lines: [String], footer: String?, header: String? = nil) -> some View {
        Section {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1).")
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(line)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            if let header { Text(header) }
        } footer: {
            if let footer { Text(footer) }
        }
    }
}

/// Preview of the wallpaper GO will save, saving it, and what to do if Photos access is off.
struct WallpaperStepContent: View {
    @EnvironmentObject private var store: LauncherStore
    @Environment(\.openURL) private var openURL
    let onSaved: () -> Void

    private enum Phase: Equatable { case idle, saving, saved, denied, failed }
    @State private var phase: Phase = .idle
    @State private var preview: UIImage?

    var body: some View {
        Section {
            HStack {
                Spacer()
                Group {
                    if let preview {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                    } else {
                        ProgressView()
                    }
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.quaternary))
                .accessibilityLabel("Preview of your GO wallpaper")
                Spacer()
            }
            .padding(.vertical, 6)

            Button {
                Task { await save() }
            } label: {
                HStack {
                    Label(phase == .saved ? "Save Again" : "Save to Photos", systemImage: "photo.badge.arrow.down")
                    if phase == .saving {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(phase == .saving)
        } footer: {
            Text("Saved at this iPhone's full screen size, using your current Design.")
        }
        .task(id: store.state.theme) {
            preview = WallpaperExporter.render(theme: store.state.theme, store: store)
            if PHPhotoLibrary.authorizationStatus(for: .addOnly) == .denied, phase == .idle {
                phase = .denied
            }
        }

        switch phase {
        case .saved:
            Section {
                Label("Saved to Photos", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Text("Open Photos and open the new image. Tap the Share button, then Use as Wallpaper, and follow the prompts to use it on your Home Screen.")
                    .font(.subheadline)
            } header: {
                Text("Now set it as your wallpaper")
            }
        case .denied:
            Section {
                Text("GO doesn't have permission to add to Photos. Turn on Photos access for GO (Add Photos Only is enough), then come back and tap Save to Photos.")
                    .font(.subheadline)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Label("Open GO's Settings", systemImage: "gear")
                }
            } header: {
                Text("Photos access is off")
            }
        case .failed:
            Section {
                Text("GO couldn't save the image. Check there's free space on your iPhone, then try again.")
                    .font(.subheadline)
            }
        case .idle, .saving:
            EmptyView()
        }
    }

    @MainActor
    private func save() async {
        phase = .saving
        guard let image = WallpaperExporter.render(theme: store.state.theme, store: store) else {
            phase = .failed
            return
        }
        switch await WallpaperExporter.saveToPhotos(image) {
        case .saved:
            phase = .saved
            onSaved()
        case .denied:
            phase = .denied
        case .failed:
            phase = .failed
        }
    }
}
