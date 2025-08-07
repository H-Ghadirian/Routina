import ComposableArchitecture
import SwiftUI

extension HomeTCAView {
    var boardSprints: [BoardSprint] {
        store.sprintBoardData.sprints.sorted { lhs, rhs in
            if lhs.status == rhs.status {
                return lhs.createdAt > rhs.createdAt
            }

            let sortOrder: [SprintStatus: Int] = [.active: 0, .planned: 1, .finished: 2]
            return (sortOrder[lhs.status] ?? 99) < (sortOrder[rhs.status] ?? 99)
        }
    }

    var boardActiveSprint: BoardSprint? {
        store.sprintBoardData.activeSprint
    }

    var boardScopeTitle: String {
        switch store.selectedBoardScope {
        case .backlog:
            return "Backlog"
        case .currentSprint:
            return boardActiveSprint?.title ?? "Current Sprint"
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
                        activeSprintID: boardActiveSprint?.id
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

                        ForEach(boardSprints) { sprint in
                            sprintScopeRow(sprint)
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

                        if let activeSprint = boardActiveSprint {
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

                            Button("Finish active sprint") {
                                store.send(.finishSprintTapped(activeSprint.id))
                            }
                            .buttonStyle(.borderless)
                            .font(.caption.weight(.semibold))
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
        HomeMacTodoBoardView(
            columns: macTodoBoardColumns,
            layout: store.selectedBoardScope == .backlog ? .backlogList : .board,
            selectedTaskID: store.selectedTaskID,
            isCompactLayout: isMacTodoBoardCompactCards,
            availableSprints: boardSprints,
            activeSprint: boardActiveSprint,
            onSelectTask: { taskID in
                store.send(.setSelectedTask(taskID))
            },
            onOpenTask: { taskID in
                store.send(.setSelectedTask(taskID))
                isBoardTaskDetailSheetPresented = true
            },
            onMoveTask: { taskID, state in
                store.send(.moveTodoToState(taskID, state))
            },
            onAssignTaskToSprint: { taskID, sprintID in
                store.send(.assignTodoToSprint(taskID: taskID, sprintID: sprintID))
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
        .sheet(isPresented: $isBoardTaskDetailSheetPresented) {
            if let detailStore = store.scope(
                state: \.taskDetailState,
                action: \.taskDetail
            ) {
                TaskDetailTCAView(store: detailStore)
                    .frame(minWidth: 720, minHeight: 640)
            } else {
                ContentUnavailableView(
                    "Task unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Select a task on the board to open its details.")
                )
                .frame(minWidth: 520, minHeight: 420)
            }
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
                HStack(spacing: 8) {
                    Circle()
                        .fill(boardSprintTint(for: sprint.status))
                        .frame(width: 8, height: 8)

                    Text(sprint.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)

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
        case let (.sprint(lhs), .sprint(rhs)):
            return lhs == rhs
        case (.currentSprint, .sprint(let id)):
            return boardActiveSprint?.id == id
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
