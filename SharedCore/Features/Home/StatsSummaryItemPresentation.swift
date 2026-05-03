struct StatsActiveArchiveSummaryPresentation: Equatable {
    let taskTypeFilter: StatsTaskTypeFilter
    let filteredTaskCount: Int
    let activeItemCount: Int
    let archivedItemCount: Int

    var activeTitle: String {
        switch taskTypeFilter {
        case .all:
            return "Active items"
        case .routines:
            return "Active routines"
        case .todos:
            return "Active todos"
        }
    }

    var archivedTitle: String {
        switch taskTypeFilter {
        case .all:
            return "Archived items"
        case .routines:
            return "Archived routines"
        case .todos:
            return "Archived todos"
        }
    }

    var activeCaption: String {
        if filteredTaskCount == 0 {
            switch taskTypeFilter {
            case .all:
                return "No items created yet"
            case .routines:
                return "No routines created yet"
            case .todos:
                return "No todos created yet"
            }
        }

        if activeItemCount == 0 {
            switch taskTypeFilter {
            case .all:
                return archivedItemCount == 1
                    ? "Your only item is archived"
                    : "All matching items are archived"
            case .routines:
                return archivedItemCount == 1
                    ? "Your only routine is paused"
                    : "All routines are currently paused"
            case .todos:
                return archivedItemCount == 1
                    ? "Your only todo is archived"
                    : "All todos are currently archived"
            }
        }

        if archivedItemCount == 0 {
            switch taskTypeFilter {
            case .all:
                return "Everything is currently active"
            case .routines:
                return "Everything is currently in rotation"
            case .todos:
                return "All matching todos are currently active"
            }
        }

        switch taskTypeFilter {
        case .all:
            return archivedItemCount == 1
                ? "1 archived item excluded"
                : "\(archivedItemCount) archived items excluded"
        case .routines:
            return archivedItemCount == 1
                ? "1 paused routine excluded"
                : "\(archivedItemCount) paused routines excluded"
        case .todos:
            return archivedItemCount == 1
                ? "1 archived todo excluded"
                : "\(archivedItemCount) archived todos excluded"
        }
    }

    var archivedCaption: String {
        if filteredTaskCount == 0 {
            switch taskTypeFilter {
            case .all:
                return "No items created yet"
            case .routines:
                return "No routines created yet"
            case .todos:
                return "No todos created yet"
            }
        }

        if archivedItemCount == 0 {
            switch taskTypeFilter {
            case .all:
                return "No archived items right now"
            case .routines:
                return "No archived routines right now"
            case .todos:
                return "No archived todos right now"
            }
        }

        switch taskTypeFilter {
        case .all:
            return archivedItemCount == 1
                ? "1 item is archived and hidden from Home"
                : "\(archivedItemCount) items are archived and hidden from Home"
        case .routines:
            return archivedItemCount == 1
                ? "1 routine is paused and hidden from Home"
                : "\(archivedItemCount) routines are paused and hidden from Home"
        case .todos:
            return archivedItemCount == 1
                ? "1 todo is archived and hidden from Home"
                : "\(archivedItemCount) todos are archived and hidden from Home"
        }
    }
}
