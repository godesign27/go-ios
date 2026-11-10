import SwiftUI

struct AddAppView: View {
    @EnvironmentObject private var store: LauncherStore
    @Environment(\.dismiss) private var dismiss

    let preselectedGroup: UUID?
    @State private var query = ""

    private var targetGroup: UUID {
        preselectedGroup ?? store.state.groups.first?.id ?? UUID()
    }

    private var filtered: [CatalogEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return AppCatalog.entries }
        return AppCatalog.entries.filter {
            $0.name.lowercased().contains(q) || $0.keywords.lowercased().contains(q)
        }
    }

    private var addedNames: Set<String> {
        Set(store.state.apps.map(\.name))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AppEditorView(app: .blank(groupID: targetGroup), isNew: true) { dismiss() }
                    } label: {
                        Label("Custom App, Website or Shortcut", systemImage: "plus.app")
                    }
                } footer: {
                    Text("Don't see your app? Add it as custom — any app can be opened with a Shortcut.")
                }

                ForEach(CatalogEntry.Category.allCases, id: \.self) { category in
                    let entries = filtered.filter { $0.category == category }
                    if !entries.isEmpty {
                        Section(category.rawValue) {
                            ForEach(entries) { entry in
                                NavigationLink {
                                    AppEditorView(app: entry.makeApp(groupID: targetGroup), isNew: true) { dismiss() }
                                } label: {
                                    HStack(spacing: 12) {
                                        IconTile(
                                            glyph: .symbol(entry.symbol),
                                            backgroundHex: entry.colorHex,
                                            maxSize: 34,
                                            cornerFactor: store.state.theme.cornerFactor
                                        )
                                        .frame(width: 34, height: 34)
                                        Text(entry.name)
                                        Spacer()
                                        if addedNames.contains(entry.name) {
                                            Text("Added").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search apps")
            .navigationTitle("Add App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
