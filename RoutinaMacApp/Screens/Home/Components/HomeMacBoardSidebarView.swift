import SwiftUI

struct HomeMacBoardSidebarView: View {
    let presentation: HomeBoardPresentation
    let sprintBoardData: SprintBoardData
    let creatingBacklogTitle: String?
    let creatingSprintTitle: String?
    let renamingSprintID: UUID?
    let renamingSprintTitle: String
    let deletingSprintID: UUID?
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
                    boardScopeButton(title: backlog.title, scope: .namedBacklog(backlog.id))
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
            creationField(
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
            creationField(
                placeholder: "Sprint name…",
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

    private func creationField(
        placeholder: String,
        title: Binding<String>,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        focus: FocusState<Bool>.Binding
    ) -> some View {
        HStack(spacing: 6) {
            TextField(
                placeholder,
                text: title
            )
            .textFieldStyle(.plain)
            .font(.caption.weight(.semibold))
            .focused(focus)
            .onSubmit {
                onConfirm()
            }
            .onAppear {
                focus.wrappedValue = true
            }

            Button(action: onConfirm) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .disabled(title.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty)

            Button(action: onCancel) {
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
    }

    @ViewBuilder
    private func sprintScopeRow(_ sprint: BoardSprint) -> some View {
        let isRenaming = renamingSprintID == sprint.id

        if isRenaming {
            sprintRenameField
        } else {
            sprintScopeButton(sprint)
        }
    }

    private var sprintRenameField: some View {
        HStack(spacing: 6) {
            TextField(
                "Sprint name…",
                text: Binding(
                    get: { renamingSprintTitle },
                    set: { send(.renamingSprintTitleChanged($0)) }
                )
            )
            .textFieldStyle(.plain)
            .font(.caption.weight(.semibold))
            .focused(sprintRenameFocus)
            .onSubmit { send(.renameSprintConfirmed) }
            .onAppear {
                sprintRenameFocus.wrappedValue = true
            }

            Button(action: { send(.renameSprintConfirmed) }) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .disabled(renamingSprintTitle.trimmingCharacters(in: .whitespaces).isEmpty)

            Button(action: { send(.renameSprintCanceled) }) {
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
    }

    private func sprintScopeButton(_ sprint: BoardSprint) -> some View {
        Button {
            send(.selectedBoardScopeChanged(.sprint(sprint.id)))
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
                send(.renameSprintTapped(sprint.id))
            }

            if sprint.status != .active {
                Button("Set as Active") {
                    send(.startSprintTapped(sprint.id))
                }
            }

            Divider()

            Button("Delete", role: .destructive) {
                send(.deleteSprintTapped(sprint.id))
            }
            .disabled(sprint.status == .active)
        }
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
        Button {
            send(.selectedBoardScopeChanged(scope))
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

    private func deleteSprintMessage(for sprintID: UUID) -> Text {
        let title = presentation.sprints.first(where: { $0.id == sprintID })?.title ?? "this sprint"
        let hasAssignments = sprintBoardData.assignments.contains { $0.sprintID == sprintID }
        if hasAssignments {
            return Text("\"\(title)\" will be deleted and all its tasks will be moved to the backlog.")
        }
        return Text("\"\(title)\" will be deleted.")
    }
}
