import SwiftUI

struct HomeMacBoardSidebarView: View {
    let presentation: HomeBoardPresentation
    let sprintBoardData: SprintBoardData
    let creatingBacklogTitle: String?
    let creatingSprintTitle: String?
    let renamingSprintID: UUID?
    let renamingSprintTitle: String
    let deletingSprintID: UUID?
    let availableRoutingTags: [String]
    let backlogCreationFocus: FocusState<Bool>.Binding
    let sprintCreationFocus: FocusState<Bool>.Binding
    let sprintRenameFocus: FocusState<Bool>.Binding
    @Binding var isFinishedSprintsExpanded: Bool
    let send: (HomeFeature.Action) -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 12) {
                backlogsSection
                sprintsSection
            }
            .padding(12)
        }
        .alert(
            "Delete Sprint",
            isPresented: deleteSprintBinding,
            presenting: deletingSprintID
        ) { sprintID in
            Button("Delete", role: .destructive) {
                send(.deleteSprintConfirmed(sprintID))
            }
            Button("Cancel", role: .cancel) {}
        } message: { sprintID in
            deleteSprintMessage(for: sprintID)
        }
    }

    private var backlogsSection: some View {
        HomeMacSidebarSectionCard(title: "Backlogs") {
            VStack(alignment: .leading, spacing: 10) {
                backlogCreationControl
                boardScopeButton(title: "Backlog", scope: .backlog)

                ForEach(presentation.backlogs) { backlog in
                    backlogScopeRow(backlog)
                }
            }
        }
    }

    private var sprintsSection: some View {
        HomeMacSidebarSectionCard(title: "Sprints") {
            VStack(alignment: .leading, spacing: 10) {
                sprintCreationControl
                activeSprintScopeButton
                openSprintRows
                finishedSprintRows
            }
        }
    }

    @ViewBuilder
    private var backlogCreationControl: some View {
        if let creatingBacklogTitle {
            HomeMacBoardCreationFieldView(
                placeholder: "Backlog name...",
                title: Binding(
                    get: { creatingBacklogTitle },
                    set: { send(.createBacklogTitleChanged($0)) }
                ),
                onConfirm: { send(.createBacklogConfirmed) },
                onCancel: { send(.createBacklogCanceled) },
                focus: backlogCreationFocus
            )
        } else {
            Button {
                send(.createBacklogTapped)
            } label: {
                Label("Create backlog", systemImage: "plus")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var sprintCreationControl: some View {
        if let creatingSprintTitle {
            HomeMacBoardCreationFieldView(
                placeholder: "Sprint name...",
                title: Binding(
                    get: { creatingSprintTitle },
                    set: { send(.createSprintTitleChanged($0)) }
                ),
                onConfirm: { send(.createSprintConfirmed) },
                onCancel: { send(.createSprintCanceled) },
                focus: sprintCreationFocus
            )
        } else {
            Button {
                send(.createSprintTapped)
            } label: {
                Label("Create sprint", systemImage: "plus")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var activeSprintScopeButton: some View {
        if !presentation.activeSprints.isEmpty {
            boardScopeButton(
                title: presentation.activeSprints.count == 1 ? "Active Sprint" : "Active Sprints",
                scope: .currentSprint
            )
        }
    }

    @ViewBuilder
    private var openSprintRows: some View {
        ForEach(presentation.openSprints) { sprint in
            sprintScopeRow(sprint)
        }
    }

    @ViewBuilder
    private var finishedSprintRows: some View {
        if !presentation.finishedSprints.isEmpty {
            finishedSprintsDisclosure
        } else if presentation.openSprints.isEmpty && creatingSprintTitle == nil {
            Text("Create a sprint to start planning work beyond the backlog.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var deleteSprintBinding: Binding<Bool> {
        Binding(
            get: { deletingSprintID != nil },
            set: { if !$0 { send(.deleteSprintCanceled) } }
        )
    }

    @ViewBuilder
    private func sprintScopeRow(_ sprint: BoardSprint) -> some View {
        HomeMacBoardSprintScopeRow(
            sprint: sprint,
            dateSummary: presentation.sprintDateSummary(for: sprint),
            isSelected: presentation.isSelectedScope(.sprint(sprint.id)),
            isRenaming: renamingSprintID == sprint.id,
            renameTitle: Binding(
                get: { renamingSprintTitle },
                set: { send(.renamingSprintTitleChanged($0)) }
            ),
            renameFocus: sprintRenameFocus,
            onSelect: { send(.selectedBoardScopeChanged(.sprint(sprint.id))) },
            onRename: { send(.renameSprintTapped(sprint.id)) },
            onRenameTitleChanged: { send(.renamingSprintTitleChanged($0)) },
            onRenameConfirm: { send(.renameSprintConfirmed) },
            onRenameCancel: { send(.renameSprintCanceled) },
            onStart: { send(.startSprintTapped(sprint.id)) },
            onDelete: { send(.deleteSprintTapped(sprint.id)) }
        )
    }

    private var finishedSprintsDisclosure: some View {
        DisclosureGroup(isExpanded: $isFinishedSprintsExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(presentation.finishedSprints) { sprint in
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
        scope: HomeFeature.BoardScope
    ) -> some View {
        HomeMacBoardScopeButton(
            title: title,
            isSelected: presentation.isSelectedScope(scope),
            onSelect: { send(.selectedBoardScopeChanged(scope)) }
        )
    }

    @ViewBuilder
    private func backlogScopeRow(_ backlog: BoardBacklog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeMacBoardBacklogScopeRow(
                backlog: backlog,
                isSelected: presentation.isSelectedScope(.namedBacklog(backlog.id)),
                onSelect: {
                    send(.selectedBoardScopeChanged(.namedBacklog(backlog.id)))
                }
            )

            if presentation.isSelectedScope(.namedBacklog(backlog.id)) {
                HomeMacBacklogRoutingTagsEditor(
                    backlog: backlog,
                    availableTags: availableRoutingTags,
                    onChange: { tags in
                        send(.setBacklogRoutingTags(backlogID: backlog.id, tags: tags))
                    }
                )
            }
        }
    }

    private func deleteSprintMessage(for sprintID: UUID) -> Text {
        let title = presentation.sprints.first(where: { $0.id == sprintID })?.title ?? "this sprint"
        let hasAssignments = sprintBoardData.assignments.contains { $0.sprintID == sprintID }
        if hasAssignments {
            return Text("\"\(title)\" will be deleted and all its tasks will be moved to the backlog.")
        }
        return Text("\"\(title)\" will be deleted.")
    }
}
