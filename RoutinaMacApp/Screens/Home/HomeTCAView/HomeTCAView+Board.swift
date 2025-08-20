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

        return HomeMacBoardSidebarView(
            presentation: presentation,
            sprintBoardData: store.sprintBoardData,
            creatingBacklogTitle: store.creatingBacklogTitle,
            creatingSprintTitle: store.creatingSprintTitle,
            renamingSprintID: store.renamingSprintID,
            renamingSprintTitle: store.renamingSprintTitle,
            deletingSprintID: store.deletingSprintID,
            backlogCreationFocus: $isBacklogCreationFieldFocused,
            sprintCreationFocus: $isSprintCreationFieldFocused,
            sprintRenameFocus: $isSprintRenameFieldFocused,
            isFinishedSprintsExpanded: $isFinishedSprintsExpanded,
            send: { store.send($0) }
        )
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
                HomeMacBoardScopeInspectorView(
                    presentation: presentation,
                    sprintFocusSessions: store.sprintBoardData.focusSessions,
                    allocationSessionID: store.sprintFocusAllocationSessionID,
                    allocationDrafts: store.sprintFocusAllocationDrafts,
                    onStartSprintFocus: { store.send(.startSprintFocusTapped($0)) },
                    onStopSprintFocus: { store.send(.stopSprintFocusTapped($0)) },
                    onReviewSprintFocusAllocation: { store.send(.reviewSprintFocusAllocationTapped($0)) },
                    onAllocationMinutesChanged: { taskID, minutes in
                        store.send(.sprintFocusAllocationMinutesChanged(taskID: taskID, minutes: minutes))
                    },
                    onSaveSprintFocusAllocation: { store.send(.sprintFocusAllocationSaveTapped) },
                    onCancelSprintFocusAllocation: { store.send(.sprintFocusAllocationCancelTapped) }
                )
            }
        }
        .background(.regularMaterial)
        .clipped()
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
