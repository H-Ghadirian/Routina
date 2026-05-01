import ComposableArchitecture
import SwiftUI

extension HomeTCAView {
    var boardFinishableSprintsInCurrentScope: [BoardSprint] {
        boardPresentation.finishableSprintsInCurrentScope
    }

    var boardPresentation: HomeBoardPresentation {
        HomeBoardPresentation(
            boardTodoDisplays: store.boardTodoDisplays,
            sprintBoardData: store.sprintBoardData,
            selectedScope: store.selectedBoardScope,
            selectedTaskID: store.selectedTaskID,
            selectedImportanceUrgencyFilter: store.selectedImportanceUrgencyFilter,
            selectedTags: store.selectedTags,
            includeTagMatchMode: store.includeTagMatchMode,
            excludedTags: store.excludedTags,
            excludeTagMatchMode: store.excludeTagMatchMode,
            referenceDate: Date(),
            matchesSearch: matchesSearch,
            matchesFilter: matchesFilter,
            matchesManualPlaceFilter: matchesManualPlaceFilter
        )
    }

    var macBoardSidebarView: some View {
        let presentation = boardPresentation

        return ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                HomeMacSidebarSectionCard(title: "Sprint Scope") {
                    VStack(alignment: .leading, spacing: 8) {
                        boardScopeButton(title: "Backlog", scope: .backlog, presentation: presentation)

                        ForEach(presentation.backlogs) { backlog in
                            boardScopeButton(title: backlog.title, scope: .namedBacklog(backlog.id), presentation: presentation)
                        }

                        if !presentation.activeSprints.isEmpty {
                            boardScopeButton(
                                title: presentation.activeSprints.count == 1 ? "Active Sprint" : "Active Sprints",
                                scope: .currentSprint,
                                presentation: presentation
                            )
                        }

                        ForEach(presentation.openSprints) { sprint in
                            sprintScopeRow(sprint, presentation: presentation)
                        }

                        if !presentation.finishedSprints.isEmpty {
                            finishedSprintsDisclosure(presentation: presentation)
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

                        if !presentation.activeSprints.isEmpty {
                            ForEach(presentation.activeSprints) { activeSprint in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(activeSprint.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)

                                        Text("Active")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.green)
                                    }

                                    if let activeDayTitle = presentation.activeDayTitle(for: activeSprint) {
                                        Text(activeDayTitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if let dateSummary = presentation.sprintDateSummary(for: activeSprint) {
                                        Text(dateSummary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } else if let nextSprint = presentation.sprints.first(where: { $0.status == .planned }) {
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
                            value: presentation.columns.first(where: { $0.state == .ready })?.tasks.count ?? 0,
                            tint: .orange
                        )
                        boardSidebarStatRow(
                            title: "In Progress",
                            value: presentation.inProgressTodoCount,
                            tint: .blue
                        )
                        boardSidebarStatRow(
                            title: "Blocked",
                            value: presentation.blockedTodoCount,
                            tint: .red
                        )
                        boardSidebarStatRow(
                            title: "Done",
                            value: presentation.doneTodoCount,
                            tint: .green
                        )
                    }
                }

                HomeMacSidebarSectionCard(title: "Visible") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(presentation.filteredTodoDisplays.count) cards in \(presentation.scopeTitle)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("Search and filters shape these counts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HomeMacSidebarSectionCard(title: "Selected") {
                    if let selected = presentation.selectedTodoDisplay {
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
            let title = presentation.sprints.first(where: { $0.id == sprintID })?.title ?? "this sprint"
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

    private func macTodoBoardColumns(
        from columns: [HomeBoardPresentation.Column]
    ) -> [HomeMacTodoBoardView.Column] {
        columns.map { column in
            HomeMacTodoBoardView.Column(
                state: column.state,
                title: column.title,
                tint: boardTint(for: column.state),
                tasks: column.tasks
            )
        }
    }

    var macTodoBoardContent: some View {
        let presentation = boardPresentation

        return HomeMacTodoBoardView(
            columns: macTodoBoardColumns(from: presentation.columns),
            layout: presentation.isBacklogScope ? .backlogList : .board,
            selectedTaskID: presentation.selectedTaskID,
            isCompactLayout: isMacTodoBoardCompactCards,
            availableBacklogs: presentation.backlogs,
            availableSprints: presentation.sprints,
            activeSprints: presentation.activeSprints,
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
        let presentation = boardPresentation

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(presentation.inspectorTitle)
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
                boardScopeInspector(presentation: presentation)
            }
        }
        .background(.regularMaterial)
        .clipped()
    }

    private func boardScopeInspector(presentation: HomeBoardPresentation) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                boardScopeSummaryCard(presentation: presentation)
                boardScopeCountsCard(presentation: presentation)
                boardScopeDateCard(presentation: presentation)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func boardScopeSummaryCard(presentation: HomeBoardPresentation) -> some View {
        boardInspectorCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(presentation.scopeTitle, systemImage: presentation.scopeIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(presentation.scopeDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func boardScopeCountsCard(presentation: HomeBoardPresentation) -> some View {
        boardInspectorCard(title: "Tasks") {
            VStack(alignment: .leading, spacing: 8) {
                boardInspectorStatRow("Open", presentation.openTodoCount, tint: .secondary)
                boardInspectorStatRow("In Progress", presentation.inProgressTodoCount, tint: .blue)
                boardInspectorStatRow("Blocked", presentation.blockedTodoCount, tint: .red)

                if !presentation.isBacklogScope {
                    boardInspectorStatRow("Done", presentation.doneTodoCount, tint: .green)
                }
            }
        }
    }

    @ViewBuilder
    private func boardScopeDateCard(presentation: HomeBoardPresentation) -> some View {
        boardInspectorCard(title: presentation.scopeDateCardTitle) {
            VStack(alignment: .leading, spacing: 8) {
                switch presentation.selectedScope {
                case .backlog:
                    boardInspectorDateRow("Created", nil, presentation: presentation)
                case let .namedBacklog(backlogID):
                    let backlog = presentation.backlogs.first(where: { $0.id == backlogID })
                    boardInspectorDateRow("Created", backlog?.createdAt, presentation: presentation)
                case .currentSprint:
                    if presentation.activeSprints.isEmpty {
                        Text("No active sprint.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(presentation.activeSprints) { sprint in
                            boardSprintInspectorDateSummary(sprint, presentation: presentation)
                        }
                    }
                case let .sprint(sprintID):
                    if let sprint = presentation.sprints.first(where: { $0.id == sprintID }) {
                        boardSprintInspectorDateSummary(sprint, presentation: presentation)
                    }
                }
            }
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
    private func boardSprintInspectorDateSummary(
        _ sprint: BoardSprint,
        presentation: HomeBoardPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sprint.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            boardInspectorDateRow("Start", sprint.startedAt, presentation: presentation)
            boardInspectorDateRow("Finish", sprint.finishedAt, presentation: presentation)

            if let activeDayTitle = presentation.activeDayTitle(for: sprint) {
                boardInspectorDetailRow("Day", activeDayTitle)
            }
        }
    }

    @ViewBuilder
    private func boardInspectorDateRow(
        _ title: String,
        _ date: Date?,
        presentation: HomeBoardPresentation
    ) -> some View {
        boardInspectorDetailRow(title, date.map(presentation.dateLabel(for:)) ?? "Not set")
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

    @ViewBuilder
    private func sprintScopeRow(
        _ sprint: BoardSprint,
        presentation: HomeBoardPresentation
    ) -> some View {
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

                        if let dateSummary = presentation.sprintDateSummary(for: sprint) {
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
                        .fill(presentation.isSelectedScope(.sprint(sprint.id)) ? Color.accentColor.opacity(0.14) : Color.clear)
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

    private func finishedSprintsDisclosure(presentation: HomeBoardPresentation) -> some View {
        DisclosureGroup(isExpanded: $isFinishedSprintsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(presentation.finishedSprints) { sprint in
                    sprintScopeRow(sprint, presentation: presentation)
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

                Text("\(presentation.finishedSprints.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .font(.caption)
        .accentColor(.secondary)
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

    private func boardScopeButton(
        title: String,
        scope: HomeFeature.BoardScope,
        presentation: HomeBoardPresentation
    ) -> some View {
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
                        .fill(presentation.isSelectedScope(scope) ? Color.accentColor.opacity(0.14) : Color.clear)
                )
        }
        .buttonStyle(.plain)
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
