import Foundation

/// One section of Go (an automatic section or a group), ready to show in a widget.
struct SectionContent {
    let key: String
    let title: String
    let symbol: String?
    let apps: [LauncherApp]
    let totalCount: Int
}

extension LauncherState {
    /// Every section a Home Screen widget can show: the automatic sections, then your groups.
    var widgetSectionChoices: [(key: String, title: String)] {
        SmartSection.allCases.map { (key: $0.rawValue, title: $0.title) }
            + groups.map { (key: $0.id.uuidString, title: $0.name) }
    }

    /// The apps in a section, in the same order the app shows them.
    func sectionContent(for key: String, limit: Int) -> SectionContent? {
        if let smart = SmartSection(rawValue: key) {
            let list: [LauncherApp]
            switch smart {
            case .recent:
                list = apps.filter { $0.lastLaunched != nil }
                    .sorted { ($0.lastLaunched ?? .distantPast) > ($1.lastLaunched ?? .distantPast) }
            case .favorites:
                list = favoriteAppIDs.compactMap { id in apps.first { $0.id == id } }
            case .mostUsed:
                list = apps.filter { $0.launchCount > 0 }.sorted { $0.launchCount > $1.launchCount }
            case .attention:
                list = apps.filter(\.needsAttention)
            }
            return SectionContent(key: key, title: smart.title, symbol: smart.symbol,
                                  apps: Array(list.prefix(limit)), totalCount: list.count)
        }
        if let group = groups.first(where: { $0.id.uuidString == key }) {
            let list = apps.filter { $0.groupID == group.id }
            return SectionContent(key: key, title: group.name, symbol: nil,
                                  apps: Array(list.prefix(limit)), totalCount: list.count)
        }
        return nil
    }

    /// Counts launches made from widgets that the app hasn't merged yet.
    func applyingWidgetLaunches(_ launches: [WidgetLaunch]) -> LauncherState {
        guard !launches.isEmpty else { return self }
        var copy = self
        for launch in launches {
            guard let index = copy.apps.firstIndex(where: { $0.id == launch.appID }) else { continue }
            copy.apps[index].launchCount += 1
            if (copy.apps[index].lastLaunched ?? .distantPast) < launch.date {
                copy.apps[index].lastLaunched = launch.date
            }
            copy.apps[index].needsAttention = false
        }
        return copy
    }
}
