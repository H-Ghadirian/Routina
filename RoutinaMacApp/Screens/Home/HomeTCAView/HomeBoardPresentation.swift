import Foundation

struct HomeBoardPresentation: Equatable {
    struct Column: Equatable, Identifiable {
        let state: TodoState
        let title: String
        let tasks: [HomeFeature.RoutineDisplay]

        var id: String { state.rawValue }
    }

    let selectedScope: HomeFeature.BoardScope
    let selectedTaskID: UUID?
    let backlogs: [BoardBacklog]
    let sprints: [BoardSprint]
    let activeSprints: [BoardSprint]
    let openSprints: [BoardSprint]
    let finishedSprints: [BoardSprint]
    let activeSprintIDs: Set<UUID>
    let finishableSprintsInCurrentScope: [BoardSprint]
    let scopeTitle: String
    let boardTodoDisplays: [HomeFeature.RoutineDisplay]
    let filteredTodoDisplays: [HomeFeature.RoutineDisplay]
    let openTodoCount: Int
    let doneTodoCount: Int
    let blockedTodoCount: Int
    let inProgressTodoCount: Int
    let selectedTodoDisplay: HomeFeature.RoutineDisplay?
    let columns: [Column]
    let referenceDate: Date

    init(
        boardTodoDisplays: [HomeFeature.RoutineDisplay],
        sprintBoardData: SprintBoardData,
        selectedScope: HomeFeature.BoardScope,
        selectedTaskID: UUID?,
        selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?,
        selectedTags: Set<String>,
        includeTagMatchMode: RoutineTagMatchMode,
        excludedTags: Set<String>,
        excludeTagMatchMode: RoutineTagMatchMode,
        referenceDate: Date,
        matchesSearch: (HomeFeature.RoutineDisplay) -> Bool,
        matchesFilter: (HomeFeature.RoutineDisplay) -> Bool,
        matchesManualPlaceFilter: (HomeFeature.RoutineDisplay) -> Bool
    ) {
        let backlogs = Self.sortedBacklogs(sprintBoardData.backlogs)
        let sprints = Self.sortedSprints(sprintBoardData.sprints)
        let activeSprints = sprints.filter { $0.status == .active }
        let openSprints = sprints.filter { $0.status != .finished }
        let finishedSprints = sprints.filter { $0.status == .finished }
        let activeSprintIDs = Set(activeSprints.map(\.id))
        let filteredTodoDisplays = Self.filteredTodoDisplays(
            from: boardTodoDisplays,
            selectedScope: selectedScope,
            activeSprintIDs: activeSprintIDs,
            selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter,
            selectedTags: selectedTags,
            includeTagMatchMode: includeTagMatchMode,
            excludedTags: excludedTags,
            excludeTagMatchMode: excludeTagMatchMode,
            matchesSearch: matchesSearch,
            matchesFilter: matchesFilter,
            matchesManualPlaceFilter: matchesManualPlaceFilter
        )

        self.selectedScope = selectedScope
        self.selectedTaskID = selectedTaskID
        self.backlogs = backlogs
        self.sprints = sprints
        self.activeSprints = activeSprints
        self.openSprints = openSprints
        self.finishedSprints = finishedSprints
        self.activeSprintIDs = activeSprintIDs
        self.finishableSprintsInCurrentScope = Self.finishableSprints(
            in: selectedScope,
            activeSprints: activeSprints,
            sprints: sprints
        )
        self.scopeTitle = Self.scopeTitle(
            for: selectedScope,
            backlogs: backlogs,
            activeSprints: activeSprints,
            sprints: sprints
        )
        self.boardTodoDisplays = boardTodoDisplays
        self.filteredTodoDisplays = filteredTodoDisplays
        self.openTodoCount = filteredTodoDisplays.count { $0.todoState != .done }
        self.doneTodoCount = filteredTodoDisplays.count { $0.todoState == .done }
        self.blockedTodoCount = filteredTodoDisplays.count { $0.todoState == .blocked }
        self.inProgressTodoCount = filteredTodoDisplays.count { $0.todoState == .inProgress }
        self.selectedTodoDisplay = selectedTaskID.flatMap { selectedTaskID in
            filteredTodoDisplays.first { $0.id == selectedTaskID }
        }
        self.columns = Self.columns(from: filteredTodoDisplays)
        self.referenceDate = referenceDate
    }

    var isBacklogScope: Bool {
        Self.isBacklogScope(selectedScope)
    }

    var inspectorTitle: String {
        if selectedTaskID != nil {
            return "Ticket Details"
        }

        return isBacklogScope ? "Backlog Details" : "Sprint Details"
    }

    var scopeDateCardTitle: String {
        isBacklogScope ? "Timeline" : "Sprint Dates"
    }

    var scopeIcon: String {
        switch selectedScope {
        case .backlog, .namedBacklog:
            return "tray.full"
        case .currentSprint, .sprint:
            return "flag.checkered"
        }
    }

    var scopeDescription: String {
        switch selectedScope {
        case .backlog:
            return "Default backlog for todos that are not assigned to a named backlog or sprint."
        case .namedBacklog:
            return "Named backlog for grouping todos before they move into a sprint."
        case .currentSprint:
            return activeSprints.count == 1
                ? "Currently active sprint."
                : "\(activeSprints.count) active sprints are shown together."
        case let .sprint(sprintID):
            let status = sprints.first(where: { $0.id == sprintID })?.status.displayTitle ?? "Sprint"
            return "\(status) sprint."
        }
    }

    func isSelectedScope(_ scope: HomeFeature.BoardScope) -> Bool {
        switch (selectedScope, scope) {
        case (.backlog, .backlog):
            return true
        case let (.namedBacklog(lhs), .namedBacklog(rhs)):
            return lhs == rhs
        case let (.sprint(lhs), .sprint(rhs)):
            return lhs == rhs
        case (.currentSprint, .sprint(let id)):
            return activeSprintIDs.contains(id)
        case (.currentSprint, .currentSprint):
            return true
        default:
            return false
        }
    }

    func activeDayTitle(for sprint: BoardSprint) -> String? {
        guard let activeDayCount = sprint.activeDayCount(relativeTo: referenceDate) else { return nil }
        return activeDayCount == 1 ? "Day 1" : "Day \(activeDayCount)"
    }

    func sprintDateSummary(for sprint: BoardSprint) -> String? {
        switch (sprint.startedAt, sprint.finishedAt) {
        case let (startedAt?, finishedAt?):
            return "Start \(dateLabel(for: startedAt)) · Finish \(dateLabel(for: finishedAt))"
        case let (startedAt?, nil):
            return "Start \(dateLabel(for: startedAt))"
        case let (nil, finishedAt?):
            return "Finish \(dateLabel(for: finishedAt))"
        case (nil, nil):
            return nil
        }
    }

    func dateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func isBacklogScope(_ scope: HomeFeature.BoardScope) -> Bool {
        switch scope {
        case .backlog, .namedBacklog:
            return true
        case .currentSprint, .sprint:
            return false
        }
    }

    private static func sortedBacklogs(_ backlogs: [BoardBacklog]) -> [BoardBacklog] {
        backlogs.sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }
    }

    private static func sortedSprints(_ sprints: [BoardSprint]) -> [BoardSprint] {
        sprints.sorted { lhs, rhs in
            if lhs.status == rhs.status {
                return lhs.createdAt > rhs.createdAt
            }

            let sortOrder: [SprintStatus: Int] = [.active: 0, .planned: 1, .finished: 2]
            return (sortOrder[lhs.status] ?? 99) < (sortOrder[rhs.status] ?? 99)
        }
    }

    private static func finishableSprints(
        in selectedScope: HomeFeature.BoardScope,
        activeSprints: [BoardSprint],
        sprints: [BoardSprint]
    ) -> [BoardSprint] {
        switch selectedScope {
        case .currentSprint:
            return activeSprints
        case let .sprint(sprintID):
            return sprints.filter { $0.id == sprintID && $0.status == .active }
        case .backlog, .namedBacklog:
            return []
        }
    }

    private static func scopeTitle(
        for selectedScope: HomeFeature.BoardScope,
        backlogs: [BoardBacklog],
        activeSprints: [BoardSprint],
        sprints: [BoardSprint]
    ) -> String {
        switch selectedScope {
        case .backlog:
            return "Backlog"
        case let .namedBacklog(backlogID):
            return backlogs.first(where: { $0.id == backlogID })?.title ?? "Backlog"
        case .currentSprint:
            if activeSprints.count == 1 {
                return activeSprints[0].title
            }
            return "Active Sprints"
        case let .sprint(sprintID):
            return sprints.first(where: { $0.id == sprintID })?.title ?? "Sprint"
        }
    }

    private static func filteredTodoDisplays(
        from displays: [HomeFeature.RoutineDisplay],
        selectedScope: HomeFeature.BoardScope,
        activeSprintIDs: Set<UUID>,
        selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?,
        selectedTags: Set<String>,
        includeTagMatchMode: RoutineTagMatchMode,
        excludedTags: Set<String>,
        excludeTagMatchMode: RoutineTagMatchMode,
        matchesSearch: (HomeFeature.RoutineDisplay) -> Bool,
        matchesFilter: (HomeFeature.RoutineDisplay) -> Bool,
        matchesManualPlaceFilter: (HomeFeature.RoutineDisplay) -> Bool
    ) -> [HomeFeature.RoutineDisplay] {
        displays.filter { task in
            task.isOneOffTask
                && HomeFeature.matchesBoardScope(
                    task,
                    selectedScope: selectedScope,
                    activeSprintIDs: activeSprintIDs
                )
                && matchesSearch(task)
                && matchesFilter(task)
                && matchesManualPlaceFilter(task)
                && HomeFeature.matchesImportanceUrgencyFilter(
                    selectedImportanceUrgencyFilter,
                    importance: task.importance,
                    urgency: task.urgency
                )
                && HomeFeature.matchesSelectedTags(selectedTags, mode: includeTagMatchMode, in: task.tags)
                && HomeFeature.matchesExcludedTags(excludedTags, mode: excludeTagMatchMode, in: task.tags)
        }
    }

    private static func columns(from filteredTodoDisplays: [HomeFeature.RoutineDisplay]) -> [Column] {
        [
            Column(
                state: .ready,
                title: "Ready / Paused",
                tasks: tasks(for: .ready, in: filteredTodoDisplays)
            ),
            Column(
                state: .inProgress,
                title: "In Progress",
                tasks: tasks(for: .inProgress, in: filteredTodoDisplays)
            ),
            Column(
                state: .blocked,
                title: "Blocked",
                tasks: tasks(for: .blocked, in: filteredTodoDisplays)
            ),
            Column(
                state: .done,
                title: "Done",
                tasks: tasks(for: .done, in: filteredTodoDisplays)
            )
        ]
    }

    private static func tasks(
        for columnState: TodoState,
        in filteredTodoDisplays: [HomeFeature.RoutineDisplay]
    ) -> [HomeFeature.RoutineDisplay] {
        let sectionKey = HomeFeature.boardSectionKey(for: columnState)
        let tasks = filteredTodoDisplays.filter { task in
            switch columnState {
            case .ready:
                return task.todoState == .ready || task.todoState == .paused
            case .inProgress:
                return task.todoState == .inProgress
            case .blocked:
                return task.todoState == .blocked
            case .done:
                return task.todoState == .done
            case .paused:
                return false
            }
        }

        return tasks.sorted { lhs, rhs in
            let lhsOrder = lhs.manualSectionOrders[sectionKey] ?? Int.max
            let rhsOrder = rhs.manualSectionOrders[sectionKey] ?? Int.max
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }

            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }

            let lhsDue = lhs.dueDate ?? .distantFuture
            let rhsDue = rhs.dueDate ?? .distantFuture
            if lhsDue != rhsDue {
                return lhsDue < rhsDue
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
