import SwiftUI

/// ••• › Groups & Dock: arrange every section, rename/add/delete groups, hide automatic sections, turn the dock on.
struct GroupsView: View {
    @EnvironmentObject private var store: LauncherStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.sections) { section in
                        row(for: section)
                            .deleteDisabled(!canDelete(section))
                    }
                    .onMove { store.moveSections(fromOffsets: $0, toOffset: $1) }
                    .onDelete(perform: delete)
                } header: {
                    Text("Home screen order")
                } footer: {
                    Text("Drag ≡ to rearrange. Recently Used, Most Used and Needs Attention fill in by themselves; switch one off to hide it. Deleting a group moves its apps into another group, so no apps are lost.")
                }

                Section {
                    Button {
                        store.addGroup(named: "New Group")
                    } label: {
                        Label("New Group", systemImage: "plus")
                    }
                }

                Section {
                    Toggle("Show Dock", isOn: $store.state.showDock)
                } header: {
                    Text("Dock")
                } footer: {
                    Text(store.state.showDock
                         ? "Long-press any app and choose Add to Dock. The dock holds up to 5 apps."
                         : "Turn on to keep up to 5 favorite apps in a bar at the bottom of the screen.")
                }
            }
            // Always show the drag handles so arranging is one step.
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Groups & Dock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for section: HomeSection) -> some View {
        switch section {
        case .smart(let kind):
            HStack(spacing: 12) {
                Image(systemName: kind.symbol)
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                Text(kind.title)
                Spacer()
                Toggle(kind.title, isOn: Binding(
                    get: { !store.isSectionHidden(kind.rawValue) },
                    set: { store.setSection(kind.rawValue, hidden: !$0) }
                ))
                .labelsHidden()
            }
        case .group(let group):
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                TextField("Group name", text: Binding(
                    get: { group.name },
                    set: { store.renameGroup(group.id, to: $0) }
                ))
                Text("\(store.apps(in: group.id).count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func canDelete(_ section: HomeSection) -> Bool {
        if case .group = section { return store.state.groups.count > 1 }
        return false
    }

    private func delete(at offsets: IndexSet) {
        let sections = store.sections
        var ids = Set<UUID>()
        for index in offsets {
            if case .group(let group) = sections[index] { ids.insert(group.id) }
        }
        guard !ids.isEmpty, store.state.groups.count > ids.count else { return }
        store.deleteGroups(ids: ids)
    }
}
