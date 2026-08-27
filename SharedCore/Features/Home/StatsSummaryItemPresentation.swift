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
            return "Active repeating tasks"
        case .todos:
            return "Active one-time tasks"
        }
    }

    var archivedTitle: String {
        switch taskTypeFilter {
        case .all:
            return "Archived items"
        case .routines:
            return "Archived repeating tasks"
        case .todos:
            return "Archived one-time tasks"
        }
    }

    var activeCaption: String {
        if filteredTaskCount == 0 {
            switch taskTypeFilter {
            case .all:
                return "No items created yet"
            case .routines:
                return "No repeating tasks created yet"
            case .todos:
                return "No one-time tasks created yet"
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
                    ? "Your only repeating task is paused"
                    : "All repeating tasks are currently paused"
            case .todos:
                return archivedItemCount == 1
                    ? "Your only one-time task is archived"
                    : "All one-time tasks are currently archived"
            }
        }

        if archivedItemCount == 0 {
            switch taskTypeFilter {
            case .all:
                return "Everything is currently active"
            case .routines:
                return "Everything is currently in rotation"
            case .todos:
                return "All matching one-time tasks are currently active"
            }
        }

        switch taskTypeFilter {
        case .all:
            return archivedItemCount == 1
                ? "1 archived excluded"
                : "\(archivedItemCount) archived items excluded"
        case .routines:
            return archivedItemCount == 1
                ? "1 paused excluded"
                : "\(archivedItemCount) paused repeating tasks excluded"
        case .todos:
            return archivedItemCount == 1
                ? "1 archived excluded"
                : "\(archivedItemCount) archived one-time tasks excluded"
        }
    }

    var archivedCaption: String {
        if filteredTaskCount == 0 {
            switch taskTypeFilter {
            case .all:
                return "No items created yet"
            case .routines:
                return "No repeating tasks created yet"
            case .todos:
                return "No one-time tasks created yet"
            }
        }

        if archivedItemCount == 0 {
            switch taskTypeFilter {
            case .all:
                return "No archived items right now"
            case .routines:
                return "No archived repeating tasks right now"
            case .todos:
                return "No archived one-time tasks right now"
            }
        }

        switch taskTypeFilter {
        case .all:
            return "Hidden from Home"
        case .routines:
            return "Paused and hidden from Home"
        case .todos:
            return "Hidden from Home"
        }
    }
}
