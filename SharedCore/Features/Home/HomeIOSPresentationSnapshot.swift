import Foundation

struct HomeIOSPresentationSnapshotResult: @unchecked Sendable {
    let presentation: HomeTaskListPresentation<HomeRoutineDisplay>
    let searchTaskCreationText: String?
}

struct HomeIOSPresentationSnapshotRequest: @unchecked Sendable {
    private var filteringConfiguration: HomeTaskListFilteringConfiguration
    private let taskListMode: HomeTaskListMode
    private let routineDisplays: [HomeRoutineDisplay]
    private let awayRoutineDisplays: [HomeRoutineDisplay]
    private let archivedRoutineDisplays: [HomeRoutineDisplay]
    private let hideUnavailableRoutines: Bool
    private let showArchivedTasks: Bool

    init(
        filteringConfiguration: HomeTaskListFilteringConfiguration,
        taskListMode: HomeTaskListMode,
        routineDisplays: [HomeRoutineDisplay],
        awayRoutineDisplays: [HomeRoutineDisplay],
        archivedRoutineDisplays: [HomeRoutineDisplay],
        hideUnavailableRoutines: Bool,
        showArchivedTasks: Bool
    ) {
        self.filteringConfiguration = filteringConfiguration
        self.taskListMode = taskListMode
        self.routineDisplays = routineDisplays
        self.awayRoutineDisplays = awayRoutineDisplays
        self.archivedRoutineDisplays = archivedRoutineDisplays
        self.hideUnavailableRoutines = hideUnavailableRoutines
        self.showArchivedTasks = showArchivedTasks
    }

    var requiresMainActorBuild: Bool {
        filteringConfiguration.taskListViewMode == .actionable
    }

    func preparedForDetachedBuild() -> Self {
        var request = self
        // SwiftData models stay actor-bound. The all-items view mode never
        // consults this legacy relationship collection while filtering.
        request.filteringConfiguration.routineTasks = []
        return request
    }

    func build() -> HomeIOSPresentationSnapshotResult? {
        guard !Task.isCancelled else { return nil }

        let taskListMode = taskListMode
        let filtering = HomeTaskListFiltering<HomeRoutineDisplay>(
            configuration: filteringConfiguration,
            matchesCurrentTaskListMode: { display in
                switch taskListMode {
                case .all:
                    return true
                case .routines:
                    return display.scheduleMode.taskType == .routine
                case .todos:
                    return display.isOneOffTask
                }
            }
        )
        let searchSeed = filteringConfiguration.searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let allTaskSearchSourceDisplays =
            searchSeed.isEmpty
            ? []
            : sourceDisplays(includingArchivedTasks: true)

        if !searchSeed.isEmpty {
            let containsKnownTask = allTaskSearchSourceDisplays.contains(
                where: filtering.matchesSearch
            )
            guard !Task.isCancelled else { return nil }

            if !containsKnownTask {
                return HomeIOSPresentationSnapshotResult(
                    presentation: HomeTaskListPresentation(
                        sections: [],
                        hiddenUnavailableTaskCount: 0,
                        emptyState: HomeTaskListPresentation<HomeRoutineDisplay>.iOSEmptyState(
                            isEmpty: true,
                            hiddenUnavailableTaskCount: 0,
                            taskListKind: filterTaskListKind
                        )
                    ),
                    searchTaskCreationText: searchSeed
                )
            }
        }

        let searchSourceDisplays =
            showArchivedTasks && !allTaskSearchSourceDisplays.isEmpty
            ? allTaskSearchSourceDisplays
            : sourceDisplays(includingArchivedTasks: showArchivedTasks)

        guard !Task.isCancelled else { return nil }
        let presentation = HomeTaskListPresentation.iOS(
            filtering: filtering,
            routineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays,
            hideUnavailableRoutines: hideUnavailableRoutines,
            showArchivedTasks: showArchivedTasks,
            taskListKind: filterTaskListKind
        )
        .appendingFlagRuleRevealResults(
            from: searchSourceDisplays,
            filtering: filtering
        )

        guard !Task.isCancelled else { return nil }
        guard !Task.isCancelled else { return nil }
        return HomeIOSPresentationSnapshotResult(
            presentation: presentation,
            searchTaskCreationText: nil
        )
    }

    private func sourceDisplays(
        includingArchivedTasks: Bool
    ) -> [HomeRoutineDisplay] {
        var seenTaskIDs: Set<UUID> = []
        var displays: [HomeRoutineDisplay] = []
        displays.reserveCapacity(
            routineDisplays.count
                + awayRoutineDisplays.count
                + (includingArchivedTasks ? archivedRoutineDisplays.count : 0)
        )

        func appendUnique(_ source: [HomeRoutineDisplay]) -> Bool {
            for display in source {
                guard !Task.isCancelled else { return false }
                if seenTaskIDs.insert(display.taskID).inserted {
                    displays.append(display)
                }
            }
            return true
        }

        guard appendUnique(routineDisplays), appendUnique(awayRoutineDisplays) else { return [] }
        if includingArchivedTasks {
            guard appendUnique(archivedRoutineDisplays) else { return [] }
        }

        return displays
    }

    private var filterTaskListKind: HomeFilterTaskListKind {
        switch taskListMode {
        case .all:
            return .all
        case .routines:
            return .routines
        case .todos:
            return .todos
        }
    }
}
