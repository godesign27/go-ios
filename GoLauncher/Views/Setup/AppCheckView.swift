import SwiftUI
import UIKit

/// Which of your GO apps this iPhone can open, as far as iOS lets GO tell. Separates an app
/// you added (configured), one iOS confirms is installed (detected), and one that has
/// actually opened from GO.
struct AppCheckView: View {
    @EnvironmentObject private var store: LauncherStore

    enum Status: Int, CaseIterable {
        case failed, notFound, notChecked, shortcut, website, apple, detected

        var title: String {
            switch self {
            case .failed: return "Didn't open last time"
            case .notFound: return "Not found on this iPhone"
            case .notChecked: return "Can't be checked"
            case .shortcut: return "Opens with a Shortcut"
            case .website: return "Opens a website or link"
            case .apple: return "Apple apps"
            case .detected: return "Found on this iPhone"
            }
        }

        var footer: String {
            switch self {
            case .failed: return "iOS refused to open these. The app may be deleted or its link changed. Tap one to edit its link or switch it to a Shortcut."
            case .notFound: return "iOS says no app answers this link. If the app is installed, its link may have changed: switch it to a Shortcut."
            case .notChecked: return "iOS lets GO check at most 25 kinds of app links. These open normally if installed; GO just can't confirm it ahead of time."
            case .shortcut: return "Runs the Shortcut you named. Works for any app."
            case .website: return "Opens in Safari or the app that handles the link."
            case .apple: return "Built into iOS, so GO assumes they're here."
            case .detected: return "iOS confirms an app answers this link."
            }
        }

        var symbol: String {
            switch self {
            case .failed: return "xmark.octagon.fill"
            case .notFound: return "questionmark.circle"
            case .notChecked: return "minus.circle"
            case .shortcut: return "square.stack.3d.up"
            case .website: return "link"
            case .apple: return "apple.logo"
            case .detected: return "checkmark.circle.fill"
            }
        }
    }

    static func status(of app: LauncherApp) -> Status {
        if app.lastLaunchFailed { return .failed }
        switch app.launch {
        case .shortcut:
            return .shortcut
        case .url(let string):
            guard let scheme = AppCatalog.scheme(ofURL: string) else { return .notFound }
            if ["http", "https"].contains(scheme) { return .website }
            if AppCatalog.entry(named: app.name)?.category == .apple,
               AppCatalog.entry(named: app.name)?.url.lowercased().hasPrefix(scheme) == true {
                return .apple
            }
            guard AppCatalog.detectableSchemes.contains(scheme) else { return .notChecked }
            let url = URL(string: "\(scheme)://")
            return url.map(UIApplication.shared.canOpenURL) == true ? .detected : .notFound
        }
    }

    private var grouped: [(Status, [LauncherApp])] {
        let pairs = store.state.apps.map { (Self.status(of: $0), $0) }
        return Status.allCases.compactMap { status in
            let apps = pairs.filter { $0.0 == status }.map(\.1)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return apps.isEmpty ? nil : (status, apps)
        }
    }

    var body: some View {
        List {
            Section {
                Text("\(store.state.apps.count) apps in GO. iOS doesn't give apps a list of what's installed, so this is GO's best check.")
                    .font(.subheadline)
            }
            ForEach(grouped, id: \.0) { status, apps in
                Section {
                    ForEach(apps) { app in
                        NavigationLink {
                            AppCheckEditor(app: app)
                        } label: {
                            row(app)
                        }
                    }
                } header: {
                    Label(status.title, systemImage: status.symbol)
                } footer: {
                    Text(status.footer)
                }
            }
        }
        .navigationTitle("Check My Apps")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ app: LauncherApp) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(app.name.isEmpty ? "Untitled" : app.name)
            Text(app.launchCount > 0 ? "Opened from GO \(app.launchCount) \(app.launchCount == 1 ? "time" : "times")" : "Not opened from GO yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The app editor pushed from Check My Apps.
private struct AppCheckEditor: View {
    @Environment(\.dismiss) private var dismiss
    let app: LauncherApp

    var body: some View {
        AppEditorView(app: app, isNew: false) { dismiss() }
    }
}

/// Saved copies of your layout GO can go back to.
struct RestorePointsView: View {
    @EnvironmentObject private var store: LauncherStore
    @State private var backups: [StateBackups.Backup] = []
    @State private var pending: StateBackups.Backup?
    @State private var message: String?

    var body: some View {
        List {
            if backups.isEmpty {
                Section {
                    Text("No restore points yet. GO makes one when it updates, before a reset, and before restoring.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(backups) { backup in
                        Button {
                            pending = backup
                        } label: {
                            row(backup)
                        }
                        .foregroundStyle(.primary)
                    }
                } footer: {
                    Text("Restoring replaces your apps, groups, favorites, dock and design with the copy. Your current layout is saved as a restore point first.")
                }
            }
        }
        .navigationTitle("Restore Points")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { backups = store.backups }
        .confirmationDialog(
            "Restore this layout?",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible
        ) {
            Button("Restore") {
                if let backup = pending {
                    message = store.restore(backup) ? "Layout restored." : "That restore point couldn't be read, so nothing changed."
                }
                pending = nil
                backups = store.backups
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            Text("Your current layout is saved as a restore point first.")
        }
        .alert("Restore Points", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private func row(_ backup: StateBackups.Backup) -> some View {
        let state = StateBackups.live.load(backup)
        return VStack(alignment: .leading, spacing: 2) {
            Text(backup.date, format: .dateTime.month(.abbreviated).day().hour().minute())
            Text(detail(backup, state))
                .font(.footnote)
                .foregroundStyle(state == nil ? .red : .secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func detail(_ backup: StateBackups.Backup, _ state: LauncherState?) -> String {
        let reason: String
        switch backup.reason {
        case "update": reason = "Before updating GO"
        case "restore": reason = "Before a restore"
        case "manual": reason = "Before a reset"
        case "unreadable": reason = "Original file GO couldn't fully read"
        default: reason = backup.reason
        }
        guard let state else { return "\(reason) · can't be read" }
        return "\(reason) · \(state.apps.count) apps, \(state.groups.count) groups"
    }
}
