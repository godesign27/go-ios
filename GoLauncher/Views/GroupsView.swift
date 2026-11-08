import SwiftUI

struct GroupsView: View {
    @EnvironmentObject private var store: LauncherStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($store.state.groups) { $group in
                        HStack {
                            TextField("Group name", text: $group.name)
                            Text("\(store.apps(in: group.id).count)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .onMove { store.state.groups.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { offsets in
                        guard store.state.groups.count > offsets.count else { return }
                        store.deleteGroups(at: offsets)
                    }
                } footer: {
                    Text("Tap a name to rename it. Use Edit to reorder. Deleting a group moves its apps into the first remaining group — no apps are lost.")
                }

                Section {
                    Button {
                        store.addGroup(named: "New Group")
                    } label: {
                        Label("New Group", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
