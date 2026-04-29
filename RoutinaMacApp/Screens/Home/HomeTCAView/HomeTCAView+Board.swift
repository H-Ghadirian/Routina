import ComposableArchitecture
import SwiftUI

extension HomeTCAView {
    var boardBacklogs: [BoardBacklog] {
        store.sprintBoardData.backlogs.sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }
    }

    var boardSprints: [BoardSprint] {
        store.sprintBoardData.sprints.sorted { lhs, rhs in
            if lhs.status == rhs.status {
                return lhs.createdAt > rhs.createdAt
            }

            let sortOrder: [SprintStatus: Int] = [.active: 0, .planned: 1, .finished: 2]
            return (sortOrder[lhs.status] ?? 99) < (sortOrder[rhs.status] ?? 99)
        }
    }

    var boardActiveSprints: [BoardSprint] {
        boardSprints.filter { $0.status == .active }
    }

    var boardOpenSprints: [BoardSprint] {
        boardSprints.filter { $0.status != .finished }
    }

    var boardFinishedSprints: [BoardSprint] {
        boardSprints.filter { $0.status == .finished }
    }

    var boardActiveSprintIDs: Set<UUID> {
        Set(boardActiveSprints.map(\.id))
    }

    var boardFinishableSprintsInCurrentScope: [BoardSprint] {
        switch store.selectedBoardScope {
        case .currentSprint:
            return boardActiveSprints
        case let .sprint(sprintID):
            return boardSprints.filter { $0.id == sprintID && $0.status == .active }
        case .backlog, .namedBacklog:
            return []
        }
    }

    var boardScopeTitle: String {
        switch store.selectedBoardScope {
        case .backlog:
            return "Backlog"
        case let .namedBacklog(backlogID):
            return boardBacklogs.first(where: { $0.id == backlogID })?.title ?? "Backlog"
        case .currentSprint:
            if boardActiveSprints.count == 1 {
                return boardActiveSprints[0].title
            }
            return "Active Sprints"
        case let .sprint(sprintID):
            return boardSprints.first(where: { $0.id == sprintID })?.title ?? "Sprint"
        }
    }

    var boardFilteredTodoDisplays: [HomeFeature.RoutineDisplay] {
        store.boardTodoDisplays
            .filter { task in
                task.isOneOffTask
                    && HomeFeature.matchesBoardScope(
                        task,
                        selectedScope: store.selectedBoardScope,
                        activeSprintIDs: boardActiveSprintIDs
                    )
                    && matchesSearch(task)
                    && matchesFilter(task)
                    && matchesManualPlaceFilter(task)
                    && HomeFeature.matchesImportanceUrgencyFilter(
                        store.selectedImportanceUrgencyFilter,
                        importance: task.importance,
                        urgency: task.urgency
                    )
                    && HomeFeature.matchesSelectedTags(store.selectedTags, mode: store.includeTagMatchMode, in: task.tags)
                    && HomeFeature.matchesExcludedTags(store.excludedTags, mode: store.excludeTagMatchMode, in: task.tags)
            }
    }

    var boardOpenTodoCount: Int {
        boardFilteredTodoDisplays.count { display in
            display.todoState != .done
        }
    }

    var boardDoneTodoCount: Int {
        boardFilteredTodoDisplays.count { display in
            display.todoState == .done
        }
    }

    var boardBlockedTodoCount: Int {
        boardFilteredTodoDisplays.count { display in
            display.todoState == .blocked
        }
    }

    var boardInProgressTodoCount: Int {
        boardFilteredTodoDisplays.count { display in
            display.todoState == .inProgress
        }
    }

    var macTodoBoardColumns: [HomeMacTodoBoardView.Column] {
        [
            HomeMacTodoBoardView.Column(
                state: .ready,
                title: "Ready / Paused",
                tint: .orange,
                tasks: boardTasks(for: .ready)
            ),
            HomeMacTodoBoardView.Column(
                state: .inProgress,
                title: "In Progress",
                tint: .blue,
                tasks: boardTasks(for: .inProgress)
            ),
            HomeMacTodoBoardView.Column(
                state: .blocked,
                title: "Blocked",
                tint: .red,
                tasks: boardTasks(for: .blocked)
            ),
            HomeMacTodoBoardView.Column(
                state: .done,
                title: "Done",
                tint: .green,
                tasks: boardTasks(for: .done)
            )
        ]
    }

    var boardSelectedTodoDisplay: HomeFeature.RoutineDisplay? {
        guard let selectedTaskID = store.selectedTaskID else { return nil }
        return boardFilteredTodoDisplays.first(where: { $0.id == selectedTaskID })
    }

    var macBoardSidebarView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                HomeMacSidebarSectionCard(title: "Sprint Scope") {
                    VStack(alignment: .leading, spacing: 8) {
                        boardScopeButton(title: "Backlog", scope: .backlog)

                        ForEach(boardBacklogs) { backlog in
                            boardScopeButton(title: backlog.title, scope: .namedBacklog(backlog.id))
                        }

                        if !boardActiveSprints.isEmpty {
                            boardScopeButton(
                                title: boardActiveSprints.count == 1 ? "Active Sprint" : "Active Sprints",
                                scope: .currentSprint
                            )
                        }

                        ForEach(boardOpenSprints) { sprint in
                            sprintScopeRow(sprint)
                        }

                        if !boardFinishedSprints.isEmpty {
                            finishedSprintsDisclosure
                        }
                    }
                }

                HomeMacSidebarSectionCard(title: "Backlogs") {
                    VStack(alignment: .leading, spacing: 10) {
                        if let creatingTitle = store.creatingBacklogTitle {
                            HStack(spacing: 6) {
                                TextField("Backlog name...", text: Binding(
                                    get: { creatingTitle },
                                    set: { store.send(.createBacklogTitleChanged($0)) }
                                ))
                                .textFieldStyle(.plain)
                                .font(.caption.weight(.semibold))
                                .focused($isBacklogCreationFieldFocused)
                                .onSubmit { store.send(.createBacklogConfirmed) }
                                .onAppear { isBacklogCreationFieldFocused = true }

                                Button(action: { store.send(.createBacklogConfirmed) }) {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)
                                .disabled(creatingTitle.trimmingCharacters(in: .whitespaces).isEmpty)

                                Button(action: { store.send(.createBacklogCanceled) }) {
                                    Image(systemName: "xmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                        } else {
                            Button {
                                store.send(.createBacklogTapped)
                            } label: {
                                Label("Create backlog", systemImage: "plus")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                HomeMacSidebarSectionCard(title: "Sprints") {
                    VStack(alignment: .leading, spacing: 10) {
                        if let creatingTitle = store.creatingSprintTitle {
                            HStack(spacing: 6) {
                                TextField("Sprint name…", text: Binding(
                                    get: { creatingTitle },
                                    set: { store.send(.createSprintTitleChanged($0)) }
                                ))
                                .textFieldStyle(.plain)
                                .font(.caption.weight(.semibold))
                                .focused($isSprintCreationFieldFocused)
                                .onSubmit { store.send(.createSprintConfirmed) }
                                .onAppear { isSprintCreationFieldFocused = true }

                                Button(action: { store.send(.createSprintConfirmed) }) {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)
                                .disabled(creatingTitle.trimmingCharacters(in: .whitespaces).isEmpty)

                                Button(action: { store.send(.createSprintCanceled) }) {
                                    Image(systemName: "xmark")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                        } else {
                            Button {
                                store.send(.createSprintTapped)
                            } label: {
                                Label("Create sprint", systemImage: "plus")
                                    .font(.caption.weight(.semibold))
                            }
                            .buttonStyle(.borderless)
                        }

                        if !boardActiveSprints.isEmpty {
                            ForEach(boardActiveSprints) { activeSprint in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(activeSprint.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)

                                        Text("Active")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.green)
                                    }

                                    if let activeDayCount = activeSprint.activeDayCount(relativeTo: Date()) {
                                        Text(activeDayCount == 1 ? "Day 1" : "Day \(activeDayCount)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if let dateSummary = sprintDateSummary(for: activeSprint) {
                                        Text(dateSummary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } else if let nextSprint = boardSprints.first(where: { $0.status == .planned }) {
                            Text("No active sprint")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("Start \(nextSprint.title)") {
                                store.send(.startSprintTapped(nextSprint.id))
                            }
                            .buttonStyle(.borderless)
                            .font(.caption.weight(.semibold))
                        } else if store.creatingSprintTitle == nil {
                            Text("Create a sprint to start planning work beyond the backlog.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HomeMacSidebarSectionCard(title: "Board") {
                    VStack(alignment: .leading, spacing: 12) {
                        boardSidebarStatRow(
                            title: "Ready / Paused",
                            value: boardTasks(for: .ready).count,
                            tint: .orange
                        )
                        boardSidebarStatRow(
                            title: "In Progress",
                            value: boardInProgressTodoCount,
                            tint: .blue
                        )
                        boardSidebarStatRow(
                            title: "Blocked",
                            value: boardBlockedTodoCount,
                            tint: .red
                        )
                        boardSidebarStatRow(
                            title: "Done",
                            value: boardDoneTodoCount,
                            tint: .green
                        )
                    }
                }

                HomeMacSidebarSectionCard(title: "Visible") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(boardFilteredTodoDisplays.count) cards in \(boardScopeTitle)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("Search and filters shape these counts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HomeMacSidebarSectionCard(title: "Selected") {
                    if let selected = boardSelectedTodoDisplay {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center, spacing: 8) {
                                Text(selected.emoji)
                                    .font(.headline)

                                Text(selected.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                            }

                            if let notes = selected.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }

                            HStack(spacing: 8) {
                                boardStatePill(for: selected.todoState ?? .ready)

                                if let assignedSprintTitle = selected.assignedSprintTitle {
                                    Text(assignedSprintTitle)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.purple)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(Color.purple.opacity(0.12))
                                        )
                                }

                                if let dueDate = selected.dueDate {
                                    Text(dueDate, style: .date)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("Select a card on the board to inspect it here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(12)
        }
        .alert(
            "Delete Sprint",
            isPresented: Binding(
                get: { store.deletingSprintID != nil },
                set: { if !$0 { store.send(.deleteSprintCanceled) } }
            ),
            presenting: store.deletingSprintID
        ) { sprintID in
            Button("Delete", role: .destructive) {
                store.send(.deleteSprintConfirmed(sprintID))
            }
            Button("Cancel", role: .cancel) {}
        } message: { sprintID in
            let title = boardSprints.first(where: { $0.id == sprintID })?.title ?? "this sprint"
            let hasAssignments = store.sprintBoardData.assignments.contains(where: { $0.sprintID == sprintID })
            if hasAssignments {
                Text("\"\(title)\" will be deleted and all its tasks will be moved to the backlog.")
            } else {
                Text("\"\(title)\" will be deleted.")
            }
        }
    }

    @ViewBuilder
    var macTodoBoardDetailView: some View {
        macBoardCenterContent
    }

    @ViewBuilder
    var macBoardCenterContent: some View {
        if store.isMacFilterDetailPresented {
            macActiveFiltersDetailView
        } else {
            macTodoBoardContent
        }
    }

    var macTodoBoardContent: some View {
        HomeMacTodoBoardView(
            columns: macTodoBoardColumns,
            layout: isBacklogScope(store.selectedBoardScope) ? .backlogList : .board,
            selectedTaskID: store.selectedTaskID,
            isCompactLayout: isMacTodoBoardCompactCards,
            availableBacklogs: boardBacklogs,
            availableSprints: boardSprints,
            activeSprints: boardActiveSprints,
            onSelectTask: { taskID in
                store.send(.setSelectedTask(taskID))
            },
            onOpenTask: { taskID in
                store.send(.setSelectedTask(taskID))
            },
            onMoveTask: { taskID, state in
                store.send(.moveTodoToState(taskID, state))
            },
            onAssignTaskToBacklog: { taskID, backlogID in
                store.send(.assignTodoToBacklog(taskID: taskID, backlogID: backlogID))
            },
            onAssignTasksToBacklog: { taskIDs, backlogID in
                store.send(.assignTodosToBacklog(taskIDs: taskIDs, backlogID: backlogID))
            },
            onAssignTaskToSprint: { taskID, sprintID in
                store.send(.assignTodoToSprint(taskID: taskID, sprintID: sprintID))
            },
            onAssignTasksToSprint: { taskIDs, sprintID in
                store.send(.assignTodosToSprint(taskIDs: taskIDs, sprintID: sprintID))
            },
            onDropTask: { taskID, state, orderedTaskIDs in
                store.send(
                    .moveTodoOnBoard(
                        taskID: taskID,
                        targetState: state,
                        orderedTaskIDs: orderedTaskIDs
                    )
                )
            },
            onMoveUp: { taskID, state, orderedTaskIDs in
                store.send(
                    .moveTaskInSection(
                        taskID: taskID,
                        sectionKey: HomeFeature.boardSectionKey(for: state),
                        orderedTaskIDs: orderedTaskIDs,
                        direction: .up
                    )
                )
            },
            onMoveDown: { taskID, state, orderedTaskIDs in
                store.send(
                    .moveTaskInSection(
                        taskID: taskID,
                        sectionKey: HomeFeature.boardSectionKey(for: state),
                        orderedTaskIDs: orderedTaskIDs,
                        direction: .down
                    )
                )
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var macBoardTaskInspector: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(boardInspectorTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if store.selectedTaskID != nil {
                    Button {
                        store.send(.setSelectedTask(nil))
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close ticket details")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if let selectedTaskID = store.selectedTaskID,
               let detailStore = store.scope(
                   state: \.taskDetailState,
                   action: \.taskDetail
               ) {
                TaskDetailTCAView(store: detailStore)
                    .id(selectedTaskID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                boardScopeInspector
            }
        }
        .background(.regularMaterial)
        .clipped()
    }

    var boardInspectorTitle: String {
        if store.selectedTaskID != nil {
            return "Ticket Details"
        }

        switch store.selectedBoardScope {
        case .backlog, .namedBacklog:
            return "Backlog Details"
        case .currentSprint, .sprint:
            return "Sprint Details"
        }
    }

    private var boardScopeInspector: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                boardScopeSummaryCard
                boardScopeCountsCard
                boardScopeDateCard
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var boardScopeSummaryCard: some View {
        boardInspectorCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(boardScopeTitle, systemImage: boardScopeIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(boardScopeDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var boardScopeCountsCard: some View {
        boardInspectorCard(title: "Tasks") {
            VStack(alignment: .leading, spacing: 8) {
                boardInspectorStatRow("Open", boardOpenTodoCount, tint: .secondary)
                boardInspectorStatRow("In Progress", boardInProgressTodoCount, tint: .blue)
                boardInspectorStatRow("Blocked", boardBlockedTodoCount, tint: .red)

                if !isBacklogScope(store.selectedBoardScope) {
                    boardInspectorStatRow("Done", boardDoneTodoCount, tint: .green)
                }
            }
        }
    }

    @ViewBuilder
    private var boardScopeDateCard: some View {
        boardInspectorCard(title: boardScopeDateCardTitle) {
            VStack(alignment: .leading, spacing: 8) {
                switch store.selectedBoardScope {
                case .backlog:
                    boardInspectorDateRow("Created", nil)
                case let .namedBacklog(backlogID):
                    let backlog = boardBacklogs.first(where: { $0.id == backlogID })
                    boardInspectorDateRow("Created", backlog?.createdAt)
                case .currentSprint:
                    if boardActiveSprints.isEmpty {
                        Text("No active sprint.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(boardActiveSprints) { sprint in
                            boardSprintInspectorDateSummary(sprint)
                        }
                    }
                case let .sprint(sprintID):
                    if let sprint = boardSprints.first(where: { $0.id == sprintID }) {
                        boardSprintInspectorDateSummary(sprint)
                    }
                }
            }
        }
    }

    private var boardScopeDateCardTitle: String {
        isBacklogScope(store.selectedBoardScope) ? "Timeline" : "Sprint Dates"
    }

    private var boardScopeIcon: String {
        switch store.selectedBoardScope {
        case .backlog, .namedBacklog:
            return "tray.full"
        case .currentSprint, .sprint:
            return "flag.checkered"
        }
    }

    private var boardScopeDescription: String {
        switch store.selectedBoardScope {
        case .backlog:
            return "Default backlog for todos that are not assigned to a named backlog or sprint."
        case .namedBacklog:
            return "Named backlog for grouping todos before they move into a sprint."
        case .currentSprint:
            return boardActiveSprints.count == 1
                ? "Currently active sprint."
                : "\(boardActiveSprints.count) active sprints are shown together."
        case let .sprint(sprintID):
            let status = boardSprints.first(where: { $0.id == sprintID })?.status.displayTitle ?? "Sprint"
            return "\(status) sprint."
        }
    }

    private func boardInspectorCard<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func boardInspectorStatRow(_ title: String, _ value: Int, tint: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Text("\(value)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func boardSprintInspectorDateSummary(_ sprint: BoardSprint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sprint.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            boardInspectorDateRow("Start", sprint.startedAt)
            boardInspectorDateRow("Finish", sprint.finishedAt)

            if let activeDayCount = sprint.activeDayCount(relativeTo: Date()) {
                boardInspectorDetailRow("Day", activeDayCount == 1 ? "Day 1" : "Day \(activeDayCount)")
            }
        }
    }

    @ViewBuilder
    private func boardInspectorDateRow(_ title: String, _ date: Date?) -> some View {
        boardInspectorDetailRow(title, date.map(boardDateLabel(for:)) ?? "Not set")
    }

    private func boardInspectorDetailRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    func isBacklogScope(_ scope: HomeFeature.BoardScope) -> Bool {
        switch scope {
        case .backlog, .namedBacklog:
            return true
        case .currentSprint, .sprint:
            return false
        }
    }

    private func boardTasks(for columnState: TodoState) -> [HomeFeature.RoutineDisplay] {
        let sectionKey = HomeFeature.boardSectionKey(for: columnState)
        let tasks = boardFilteredTodoDisplays.filter { task in
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

    @ViewBuilder
    private func sprintScopeRow(_ sprint: BoardSprint) -> some View {
        let isRenaming = store.renamingSprintID == sprint.id

        if isRenaming {
            HStack(spacing: 6) {
                TextField("Sprint name…", text: Binding(
                    get: { store.renamingSprintTitle },
                    set: { store.send(.renamingSprintTitleChanged($0)) }
                ))
                .textFieldStyle(.plain)
                .font(.caption.weight(.semibold))
                .focused($isSprintRenameFieldFocused)
                .onSubmit { store.send(.renameSprintConfirmed) }
                .onAppear { isSprintRenameFieldFocused = true }

                Button(action: { store.send(.renameSprintConfirmed) }) {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .disabled(store.renamingSprintTitle.trimmingCharacters(in: .whitespaces).isEmpty)

                Button(action: { store.send(.renameSprintCanceled) }) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
            )
        } else {
            Button {
                store.send(.selectedBoardScopeChanged(.sprint(sprint.id)))
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(boardSprintTint(for: sprint.status))
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(sprint.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)

                        if let dateSummary = sprintDateSummary(for: sprint) {
                            Text(dateSummary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)

                    Text(sprint.status.displayTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelectedBoardScope(.sprint(sprint.id)) ? Color.accentColor.opacity(0.14) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Rename") {
                    store.send(.renameSprintTapped(sprint.id))
                }

                if sprint.status != .active {
                    Button("Set as Active") {
                        store.send(.startSprintTapped(sprint.id))
                    }
                }

                Divider()

                Button("Delete", role: .destructive) {
                    store.send(.deleteSprintTapped(sprint.id))
                }
                .disabled(sprint.status == .active)
            }
        }
    }

    private var finishedSprintsDisclosure: some View {
        DisclosureGroup(isExpanded: $isFinishedSprintsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(boardFinishedSprints) { sprint in
                    sprintScopeRow(sprint)
                }
            }
            .padding(.top, 6)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)

                Text("Finished Sprints")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Text("\(boardFinishedSprints.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .font(.caption)
        .accentColor(.secondary)
    }

    private func sprintDateSummary(for sprint: BoardSprint) -> String? {
        switch (sprint.startedAt, sprint.finishedAt) {
        case let (startedAt?, finishedAt?):
            return "Start \(boardDateLabel(for: startedAt)) · Finish \(boardDateLabel(for: finishedAt))"
        case let (startedAt?, nil):
            return "Start \(boardDateLabel(for: startedAt))"
        case let (nil, finishedAt?):
            return "Finish \(boardDateLabel(for: finishedAt))"
        case (nil, nil):
            return nil
        }
    }

    private func boardDateLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func boardSidebarStatRow(title: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text("\(value)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
        }
    }

    private func boardScopeButton(title: String, scope: HomeFeature.BoardScope) -> some View {
        Button {
            store.send(.selectedBoardScopeChanged(scope))
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelectedBoardScope(scope) ? Color.accentColor.opacity(0.14) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func isSelectedBoardScope(_ scope: HomeFeature.BoardScope) -> Bool {
        switch (store.selectedBoardScope, scope) {
        case (.backlog, .backlog):
            return true
        case let (.namedBacklog(lhs), .namedBacklog(rhs)):
            return lhs == rhs
        case let (.sprint(lhs), .sprint(rhs)):
            return lhs == rhs
        case (.currentSprint, .sprint(let id)):
            return boardActiveSprintIDs.contains(id)
        case (.currentSprint, .currentSprint):
            return true
        default:
            return false
        }
    }

    private func boardSprintTint(for status: SprintStatus) -> Color {
        switch status {
        case .planned:
            return .orange
        case .active:
            return .green
        case .finished:
            return .secondary
        }
    }

    private func boardStatePill(for state: TodoState) -> some View {
        Text(state == .paused ? "Paused" : state.displayTitle)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(boardTint(for: state))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(boardTint(for: state).opacity(0.12))
            )
    }

    private func boardTint(for state: TodoState) -> Color {
        switch state {
        case .ready, .paused:
            return .orange
        case .inProgress:
            return .blue
        case .blocked:
            return .red
        case .done:
            return .green
        }
    }
}
