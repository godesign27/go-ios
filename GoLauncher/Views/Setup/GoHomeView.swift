import SwiftUI

/// "GO Home Screen": the place to set up GO on the iPhone's own Home Screen, with Classic
/// Launcher one tap away. Progress is saved, so it can be closed and resumed anytime.
struct GoHomeView: View {
    @EnvironmentObject private var store: LauncherStore
    /// Closes this and shows the full-screen Classic Launcher.
    let openClassicLauncher: () -> Void

    @State private var path: [SetupStep] = []
    @State private var showingDesign = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                progressSection
                Section {
                    ForEach(SetupStep.required) { stepRow($0) }
                } header: {
                    Text("Steps").foregroundStyle(.secondaryText)
                }
                Section {
                    ForEach(SetupStep.optional) { stepRow($0) }
                } header: {
                    Text("Optional").foregroundStyle(.secondaryText)
                }
                Section {
                    Button(action: openClassicLauncher) {
                        Label("Open Classic Launcher", systemImage: "square.grid.3x3.fill")
                    }
                } header: {
                    Text("Classic Launcher").foregroundStyle(.secondaryText)
                } footer: {
                    Text("GO full screen, with all your groups, search and dock. Setting up your Home Screen doesn't change it.").foregroundStyle(.secondaryText)
                }
                Section {
                    Picker("When GO Opens", selection: $store.state.setup.startScreen) {
                        Text("Classic Launcher").tag(HomeSetupState.StartScreen.classicLauncher)
                        Text("GO Home Screen").tag(HomeSetupState.StartScreen.homeScreenSetup)
                    }
                } footer: {
                    Text("Taps on GO's widgets and search always go straight to the app or search.").foregroundStyle(.secondaryText)
                }
                Section {
                    NavigationLink {
                        AppCheckView()
                    } label: {
                        Label("Check My Apps", systemImage: "checkmark.seal")
                    }
                    NavigationLink {
                        RestorePointsView()
                    } label: {
                        Label("Restore Points", systemImage: "arrow.uturn.backward.circle")
                    }
                } header: {
                    Text("Tools").foregroundStyle(.secondaryText)
                } footer: {
                    Text("iOS doesn't let apps arrange your Home Screen, so these steps happen in iOS and GO can't check them. Mark each one done when you've finished it.").foregroundStyle(.secondaryText)
                }
            }
            .navigationTitle("GO Home Screen")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SetupStep.self) { step in
                SetupStepView(step: step, path: $path, openDesign: { showingDesign = true })
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", action: openClassicLauncher)
                }
            }
            .sheet(isPresented: $showingDesign) {
                ThemeView(openHomeSetup: nil)
                    .environmentObject(store)
            }
        }
    }

    private var progressSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Put GO on your iPhone Home Screen")
                    .font(.title3.weight(.bold))
                Text("GO's widgets, matching wallpaper and search, right on Apple's Home Screen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondaryText)
                ProgressView(value: Double(store.setupDoneCount), total: Double(SetupStep.required.count))
                    .accessibilityLabel("Setup progress")
                    .accessibilityValue("\(store.setupDoneCount) of \(SetupStep.required.count) steps done")
                Text("\(store.setupDoneCount) of \(SetupStep.required.count) steps done")
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
            if let next = store.nextSetupStep {
                Button {
                    path = [next]
                } label: {
                    Label(store.setupDoneCount == 0 && store.status(of: next) == .pending ? "Start Setup" : "Continue: \(next.title)",
                          systemImage: "arrow.right.circle.fill")
                        .font(.body.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Label("Your GO Home Screen is set up", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private func stepRow(_ step: SetupStep) -> some View {
        NavigationLink(value: step) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: step.symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title).font(.body.weight(.medium))
                    Text(step.summary).font(.footnote).foregroundStyle(.secondaryText)
                }
                Spacer(minLength: 8)
                statusBadge(store.status(of: step))
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func statusBadge(_ status: LauncherStore.StepStatus) -> some View {
        switch status {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Done")
        case .skipped:
            Text("Skipped")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondaryText)
        case .pending:
            EmptyView()
        }
    }
}

/// The first launch of a new install: choose how to start. Either way works, and both can be
/// switched later.
struct WelcomeView: View {
    @EnvironmentObject private var store: LauncherStore
    let chooseHomeScreen: () -> Void
    let chooseClassicLauncher: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to GO")
                        .font(.largeTitle.weight(.bold))
                    Text("Your apps, organized and designed your way. How do you want to start?")
                        .font(.body)
                        .foregroundStyle(.secondaryText)
                }
                .padding(.top, 24)

                choice(
                    title: "Set Up My GO Home Screen",
                    detail: "GO's widgets, matching wallpaper and search on your iPhone's Home Screen. A few minutes, step by step.",
                    symbol: "iphone.gen3",
                    prominent: true,
                    action: chooseHomeScreen
                )
                choice(
                    title: "Open Classic Launcher",
                    detail: "Use GO full screen, with your apps in groups and search one tap away.",
                    symbol: "square.grid.3x3.fill",
                    prominent: false,
                    action: chooseClassicLauncher
                )

                Text("You can switch anytime from Customize › Set Up GO Home Screen.")
                    .font(.footnote)
                    .foregroundStyle(.secondaryText)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .interactiveDismissDisabled()
    }

    private func choice(title: String, detail: String, symbol: String, prominent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2.weight(.semibold))
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(detail).font(.subheadline).opacity(prominent ? 1 : 0.85)
                }
                Spacer(minLength: 0)
            }
            .multilineTextAlignment(.leading)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    // Deep indigo: white text on it is 7:1 (the lighter accent color is only 4:1).
                    .fill(prominent ? Color(red: 0.31, green: 0.247, blue: 0.816) : Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(title)
    }
}
