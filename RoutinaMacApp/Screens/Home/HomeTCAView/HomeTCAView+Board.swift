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

                        boardScopeButton(title: "Backlog", scope: .backlog, presentation: presentation)

                        ForEach(presentation.backlogs) { backlog in
                            boardScopeButton(title: backlog.title, scope: .namedBacklog(backlog.id), presentation: presentation)
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
                        } else if presentation.openSprints.isEmpty && store.creatingSprintTitle == nil {
                            Text("Create a sprint to start planning work beyond the backlog.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
        let commands = HomeMacBoardViewCommandRouter { store.send($0) }

        return HomeMacTodoBoardView(
            columns: macTodoBoardColumns(from: presentation.columns),
            layout: presentation.isBacklogScope ? .backlogList : .board,
            selectedTaskID: presentation.selectedTaskID,
            isCompactLayout: isMacTodoBoardCompactCards,
            availableBacklogs: presentation.backlogs,
            availableSprints: presentation.sprints,
            activeSprints: presentation.activeSprints,
            onSelectTask: commands.selectTask,
            onOpenTask: commands.selectTask,
            onMoveTask: commands.moveTask(_:to:),
            onAssignTaskToBacklog: commands.assignTaskToBacklog(taskID:backlogID:),
            onAssignTasksToBacklog: commands.assignTasksToBacklog(taskIDs:backlogID:),
            onAssignTaskToSprint: commands.assignTaskToSprint(taskID:sprintID:),
            onAssignTasksToSprint: commands.assignTasksToSprint(taskIDs:sprintID:),
            onDropTask: commands.dropTask(taskID:state:orderedTaskIDs:),
            onMoveUp: { taskID, state, orderedTaskIDs in
                commands.moveTaskInBoardSection(
                    taskID: taskID,
                    state: state,
                    orderedTaskIDs: orderedTaskIDs,
                    direction: .up
                )
            },
            onMoveDown: { taskID, state, orderedTaskIDs in
                commands.moveTaskInBoardSection(
                    taskID: taskID,
                    state: state,
                    orderedTaskIDs: orderedTaskIDs,
                    direction: .down
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
                HomeMacBoardScopeInspectorView(presentation: presentation)
            }
        }
        .background(.regularMaterial)
        .clipped()
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
