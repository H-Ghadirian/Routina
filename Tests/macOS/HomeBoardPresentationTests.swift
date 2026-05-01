import Foundation
import Testing
@testable @preconcurrency import RoutinaMacOSDev

struct HomeBoardPresentationTests {
    @Test
    func currentSprintScopeUsesInjectedFiltersAndActiveSprintIDs() {
        let referenceDate = Date(timeIntervalSince1970: 1_764_547_200)
        let activeSprint = BoardSprint(
            id: UUID(),
            title: "Launch",
            status: .active,
            createdAt: referenceDate,
            startedAt: referenceDate
        )
        let plannedSprint = BoardSprint(
            id: UUID(),
            title: "Later",
            status: .planned,
            createdAt: referenceDate.addingTimeInterval(-86_400)
        )
        let visible = makeBoardDisplay(
            name: "Visible",
            todoState: .inProgress,
            assignedSprintID: activeSprint.id
        )
        let hiddenByScope = makeBoardDisplay(
            name: "Other sprint",
            todoState: .inProgress,
            assignedSprintID: plannedSprint.id
        )
        let hiddenByInjectedSearch = makeBoardDisplay(
            name: "Hidden",
            todoState: .inProgress,
            assignedSprintID: activeSprint.id
        )
        let routine = makeBoardDisplay(
            name: "Routine",
            isOneOffTask: false
        )

        let presentation = makePresentation(
            boardTodoDisplays: [visible, hiddenByScope, hiddenByInjectedSearch, routine],
            sprintBoardData: SprintBoardData(sprints: [plannedSprint, activeSprint]),
            selectedScope: .currentSprint,
            selectedTaskID: visible.id,
            referenceDate: referenceDate,
            matchesSearch: { $0.name != "Hidden" }
        )

        #expect(presentation.scopeTitle == "Launch")
        #expect(presentation.filteredTodoDisplays.map(\.id) == [visible.id])
        #expect(presentation.selectedTodoDisplay?.id == visible.id)
        #expect(presentation.inProgressTodoCount == 1)
        #expect(presentation.columns.first(where: { $0.state == .inProgress })?.tasks.map(\.id) == [visible.id])
    }

    @Test
    func readyColumnSortsByManualOrderThenPinDueDateAndName() throws {
        let referenceDate = Date(timeIntervalSince1970: 1_764_547_200)
        let sectionKey = HomeFeature.boardSectionKey(for: .ready)
        let orderedSecond = makeBoardDisplay(
            name: "Ordered second",
            manualSectionOrders: [sectionKey: 2]
        )
        let orderedFirst = makeBoardDisplay(
            name: "Ordered first",
            manualSectionOrders: [sectionKey: 1]
        )
        let dueSoon = makeBoardDisplay(
            name: "Due soon",
            dueDate: referenceDate.addingTimeInterval(86_400)
        )
        let pinned = makeBoardDisplay(
            name: "Pinned",
            dueDate: referenceDate.addingTimeInterval(172_800),
            pinnedAt: referenceDate
        )

        let presentation = makePresentation(
            boardTodoDisplays: [orderedSecond, dueSoon, pinned, orderedFirst],
            selectedScope: .backlog,
            referenceDate: referenceDate
        )

        let readyColumn = try #require(presentation.columns.first { $0.state == .ready })
        #expect(readyColumn.tasks.map(\.name) == [
            "Ordered first",
            "Ordered second",
            "Pinned",
            "Due soon"
        ])
    }

    @Test
    func scopeMetadataReflectsBacklogAndSprintSelection() {
        let referenceDate = Date(timeIntervalSince1970: 1_764_547_200)
        let backlog = BoardBacklog(
            id: UUID(),
            title: "Writing",
            createdAt: referenceDate
        )
        let sprint = BoardSprint(
            id: UUID(),
            title: "Finish",
            status: .finished,
            createdAt: referenceDate,
            startedAt: referenceDate,
            finishedAt: referenceDate.addingTimeInterval(86_400)
        )

        let backlogPresentation = makePresentation(
            sprintBoardData: SprintBoardData(sprints: [sprint], backlogs: [backlog]),
            selectedScope: .namedBacklog(backlog.id),
            referenceDate: referenceDate
        )
        let sprintPresentation = makePresentation(
            sprintBoardData: SprintBoardData(sprints: [sprint], backlogs: [backlog]),
            selectedScope: .sprint(sprint.id),
            referenceDate: referenceDate
        )

        #expect(backlogPresentation.scopeTitle == "Writing")
        #expect(backlogPresentation.inspectorTitle == "Backlog Details")
        #expect(backlogPresentation.scopeIcon == "tray.full")
        #expect(sprintPresentation.scopeTitle == "Finish")
        #expect(sprintPresentation.inspectorTitle == "Sprint Details")
        #expect(sprintPresentation.scopeIcon == "flag.checkered")
        #expect(sprintPresentation.activeDayTitle(for: sprint) == "Day 2")
    }
}

private func makePresentation(
    boardTodoDisplays: [HomeFeature.RoutineDisplay] = [],
    sprintBoardData: SprintBoardData = SprintBoardData(),
    selectedScope: HomeFeature.BoardScope,
    selectedTaskID: UUID? = nil,
    selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil,
    selectedTags: Set<String> = [],
    includeTagMatchMode: RoutineTagMatchMode = .all,
    excludedTags: Set<String> = [],
    excludeTagMatchMode: RoutineTagMatchMode = .any,
    referenceDate: Date,
    matchesSearch: @escaping (HomeFeature.RoutineDisplay) -> Bool = { _ in true },
    matchesFilter: @escaping (HomeFeature.RoutineDisplay) -> Bool = { _ in true },
    matchesManualPlaceFilter: @escaping (HomeFeature.RoutineDisplay) -> Bool = { _ in true }
) -> HomeBoardPresentation {
    HomeBoardPresentation(
        boardTodoDisplays: boardTodoDisplays,
        sprintBoardData: sprintBoardData,
        selectedScope: selectedScope,
        selectedTaskID: selectedTaskID,
        selectedImportanceUrgencyFilter: selectedImportanceUrgencyFilter,
        selectedTags: selectedTags,
        includeTagMatchMode: includeTagMatchMode,
        excludedTags: excludedTags,
        excludeTagMatchMode: excludeTagMatchMode,
        referenceDate: referenceDate,
        matchesSearch: matchesSearch,
        matchesFilter: matchesFilter,
        matchesManualPlaceFilter: matchesManualPlaceFilter
    )
}

private func makeBoardDisplay(
    id: UUID = UUID(),
    name: String,
    todoState: TodoState? = .ready,
    isOneOffTask: Bool = true,
    assignedSprintID: UUID? = nil,
    assignedBacklogID: UUID? = nil,
    tags: [String] = [],
    manualSectionOrders: [String: Int] = [:],
    dueDate: Date? = nil,
    pinnedAt: Date? = nil
) -> HomeFeature.RoutineDisplay {
    var display = HomeFeature.RoutineDisplay(
        taskID: id,
        name: name,
        emoji: "T",
        notes: nil,
        hasImage: false,
        placeID: nil,
        placeName: nil,
        locationAvailability: .unrestricted,
        tags: tags,
        steps: [],
        interval: 1,
        recurrenceRule: .interval(days: 1),
        scheduleMode: isOneOffTask ? .oneOff : .fixedInterval,
        isSoftIntervalRoutine: false,
        lastDone: todoState == .done ? Date(timeIntervalSince1970: 1_764_547_200) : nil,
        canceledAt: nil,
        dueDate: dueDate,
        priority: .none,
        importance: .level2,
        urgency: .level2,
        scheduleAnchor: nil,
        pausedAt: todoState == .paused ? Date(timeIntervalSince1970: 1_764_547_200) : nil,
        snoozedUntil: nil,
        pinnedAt: pinnedAt,
        daysUntilDue: 0,
        isOneOffTask: isOneOffTask,
        isCompletedOneOff: false,
        isCanceledOneOff: false,
        isDoneToday: todoState == .done,
        isPaused: todoState == .paused,
        isSnoozed: false,
        isPinned: pinnedAt != nil,
        isOngoing: false,
        ongoingSince: nil,
        hasPassedSoftThreshold: false,
        completedStepCount: 0,
        isInProgress: todoState == .inProgress,
        nextStepTitle: nil,
        checklistItemCount: 0,
        completedChecklistItemCount: 0,
        dueChecklistItemCount: 0,
        nextPendingChecklistItemTitle: nil,
        nextDueChecklistItemTitle: nil,
        doneCount: 0
    )
    display.todoState = todoState
    display.assignedSprintID = assignedSprintID
    display.assignedBacklogID = assignedBacklogID
    display.manualSectionOrders = manualSectionOrders
    return display
}
