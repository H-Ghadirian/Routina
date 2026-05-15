import ComposableArchitecture
import SwiftUI

struct GoalsTCAView: View {
    let store: StoreOf<GoalsFeature>

    var body: some View {
        NavigationStack {
            Group {
                if store.isAddingGoal {
                    GoalsEditorForm(store: store)
                        .navigationTitle("New Goal")
                        .toolbar {
                            GoalsEditorToolbarContent(store: store)
                        }
                } else {
                    content
                        .navigationTitle("Goals")
                        .searchable(text: searchBinding, prompt: "Search goals")
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button {
                                    store.send(.addGoalTapped)
                                } label: {
                                    Label("New Goal", systemImage: "plus")
                                }
                            }
                        }
                }
            }
            .navigationDestination(for: UUID.self) { goalID in
                GoalDetailView(store: store, goalID: goalID)
            }
        }
        .confirmationDialog(
            "Delete Goal",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.send(.deleteGoalConfirmed)
            }
            Button("Cancel", role: .cancel) {
                store.send(.deleteGoalCanceled)
            }
        } message: {
            Text("Tasks linked to this goal keep the task, and sub-goals become top-level goals.")
        }
        .task {
            store.send(.onAppear)
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            store.send(.refreshRequested)
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.goals.isEmpty && !store.isLoading {
            ContentUnavailableView {
                Label("No goals yet", systemImage: "target")
            } description: {
                Text("Create a goal to group routines and todos by outcome.")
            } actions: {
                Button {
                    store.send(.addGoalTapped)
                } label: {
                    Label("New Goal", systemImage: "plus")
                }
            }
        } else if store.filteredGoals.isEmpty {
            ContentUnavailableView.search(text: store.searchText)
        } else {
            List {
                if !store.activeGoals.isEmpty {
                    Section("Active") {
                        ForEach(store.activeGoals) { goal in
                            NavigationLink(value: goal.id) {
                                GoalListRow(goal: goal)
                            }
                        }
                    }
                }

                if !store.archivedGoals.isEmpty {
                    Section("Archived") {
                        ForEach(store.archivedGoals) { goal in
                            NavigationLink(value: goal.id) {
                                GoalListRow(goal: goal)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                store.send(.refreshRequested)
            }
        }
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { store.searchText },
            set: { store.send(.searchTextChanged($0)) }
        )
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { store.pendingDeleteGoalID != nil },
            set: { isPresented in
                if !isPresented {
                    store.send(.deleteGoalCanceled)
                }
            }
        )
    }
}

private struct GoalListRow: View {
    var goal: GoalsFeature.GoalDisplay

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(goal.color.swiftUIColor?.opacity(0.16) ?? Color.secondary.opacity(0.12))
                Text(goal.displayEmoji)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.displayTitle)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text("\(goal.openTaskCount) open")
                    Text("\(goal.routineCount) routines")
                    Text("\(goal.todoCount) todos")
                    if goal.childGoalCount > 0 {
                        Text("\(goal.childGoalCount) sub-goals")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !goal.tags.isEmpty {
                    HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(goal.tags, id: \.self) { tag in
                            RoutineTagPill(name: tag, color: nil, size: .small)
                                .fixedSize()
                        }
                    }
                }
            }

            Spacer()

            if let targetDate = goal.targetDate {
                Text(targetDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct GoalDetailView: View {
    let store: StoreOf<GoalsFeature>
    var goalID: UUID

    var body: some View {
        if store.isEditorPresented && store.editorDraft.id == goalID {
            GoalsEditorForm(store: store)
                .navigationTitle("Edit Goal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    GoalsEditorToolbarContent(store: store)
                }
        } else if let goal = store.goals.first(where: { $0.id == goalID }) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(goal.color.swiftUIColor?.opacity(0.16) ?? Color.secondary.opacity(0.12))
                                Text(goal.displayEmoji)
                                    .font(.title2)
                            }
                            .frame(width: 54, height: 54)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.displayTitle)
                                    .font(.title3.weight(.semibold))
                                Text(goal.status.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let notes = goal.notes {
                            Text(notes)
                                .foregroundStyle(.secondary)
                        }

                        if !goal.tags.isEmpty {
                            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                                ForEach(goal.tags, id: \.self) { tag in
                                    RoutineTagPill(name: tag, color: nil, size: .regular)
                                        .fixedSize()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Overview") {
                    LabeledContent("Open Items", value: "\(goal.openTaskCount)")
                    LabeledContent("Routines", value: "\(goal.routineCount)")
                    LabeledContent("Todos", value: "\(goal.todoCount)")
                    if let parentGoal = goal.parentGoal {
                        LabeledContent("Parent Goal", value: parentGoal.displayTitle)
                    }
                    if goal.childGoalCount > 0 {
                        LabeledContent("Sub-goals", value: "\(goal.childGoalCount)")
                    }
                    if goal.completedTodoCount > 0 {
                        LabeledContent("Done Todos", value: "\(goal.completedTodoCount)")
                    }
                    if let targetDate = goal.targetDate {
                        LabeledContent(
                            "Target Date",
                            value: targetDate.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                    if let nextDueDate = goal.nextDueDate {
                        LabeledContent(
                            "Next Due",
                            value: nextDueDate.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                }

                if goal.parentGoal != nil || !goal.childGoals.isEmpty {
                    Section("Linked Goals") {
                        if let parentGoal = goal.parentGoal {
                            NavigationLink(value: parentGoal.id) {
                                GoalLinkInlineRow(goal: parentGoal, relationship: "Parent goal")
                            }
                        }

                        ForEach(goal.childGoals) { childGoal in
                            NavigationLink(value: childGoal.id) {
                                GoalLinkInlineRow(goal: childGoal, relationship: "Sub-goal")
                            }
                        }
                    }
                }

                if !goal.taskSuggestions.isEmpty {
                    Section {
                        ForEach(goal.taskSuggestions) { suggestion in
                            GoalTaskSuggestionRow(
                                suggestion: suggestion,
                                onAccept: {
                                    store.send(.acceptTaskSuggestion(goalID: goal.id, taskID: suggestion.id))
                                },
                                onReject: {
                                    store.send(.rejectTaskSuggestion(goalID: goal.id, taskID: suggestion.id))
                                }
                            )
                        }
                    } header: {
                        GoalTaskSuggestionsHeader(
                            onAcceptAll: {
                                store.send(.acceptAllTaskSuggestions(
                                    goalID: goal.id,
                                    taskIDs: goal.taskSuggestions.map(\.id)
                                ))
                            },
                            onRejectAll: {
                                store.send(.rejectAllTaskSuggestions(
                                    goalID: goal.id,
                                    taskIDs: goal.taskSuggestions.map(\.id)
                                ))
                            }
                        )
                    }
                }

                Section("Linked Tasks") {
                    if goal.linkedTasks.isEmpty {
                        ContentUnavailableView(
                            "No linked tasks",
                            systemImage: "checklist"
                        )
                    } else {
                        ForEach(goal.linkedTasks) { task in
                            GoalTaskInlineRow(task: task)
                        }
                    }
                }
            }
            .navigationTitle(goal.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.send(.editGoalTapped(goal.id))
                    } label: {
                        Label("Edit", systemImage: "square.and.pencil")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    GoalActionsMenu(store: store, goal: goal)
                }
            }
            .onAppear {
                store.send(.selectGoal(goalID))
            }
        } else {
            ContentUnavailableView("Goal unavailable", systemImage: "target")
        }
    }
}

private struct GoalTaskSuggestionsHeader: View {
    var onAcceptAll: () -> Void
    var onRejectAll: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("Suggested Tasks")
                .font(.subheadline.weight(.semibold))

            Spacer(minLength: 12)

            Button("Reject All", action: onRejectAll)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Reject all task suggestions")

            Button("Accept All", action: onAcceptAll)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("Accept all task suggestions")
        }
        .textCase(nil)
    }
}

private struct GoalTaskSuggestionRow: View {
    var suggestion: GoalsFeature.GoalTaskSuggestionDisplay
    var onAccept: () -> Void
    var onReject: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(suggestion.task.displayEmoji)
                .frame(width: 28, height: 28)
                .routinaGlassPill(tint: .secondary, tintOpacity: 0.12)

            VStack(alignment: .leading, spacing: 6) {
                Text(suggestion.task.displayName)
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    Text(suggestion.task.stateText)
                    if let dueDate = suggestion.task.dueDate {
                        Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(suggestion.matchedTags, id: \.self) { tag in
                        RoutineTagPill(name: tag, color: nil, size: .small)
                            .fixedSize()
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button(action: onReject) {
                    Image(systemName: "xmark")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Reject task suggestion")

                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("Accept task suggestion")
            }
        }
        .padding(.vertical, 3)
    }
}

private struct GoalActionsMenu: View {
    let store: StoreOf<GoalsFeature>
    var goal: GoalsFeature.GoalDisplay

    var body: some View {
        Menu {
            if goal.status == .active {
                Button {
                    store.send(.archiveGoalTapped(goal.id))
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
            } else {
                Button {
                    store.send(.unarchiveGoalTapped(goal.id))
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                }
            }

            Button(role: .destructive) {
                store.send(.deleteGoalRequested(goal.id))
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }
}

private struct GoalTaskInlineRow: View {
    var task: GoalsFeature.GoalTaskDisplay

    var body: some View {
        HStack(spacing: 12) {
            Text(task.displayEmoji)
                .frame(width: 28, height: 28)
                .routinaGlassPill(tint: .secondary, tintOpacity: 0.12)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.displayName)
                HStack(spacing: 8) {
                    Text(task.stateText)
                    if let dueDate = task.dueDate {
                        Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 3)
    }
}

private struct GoalLinkInlineRow: View {
    var goal: GoalsFeature.GoalLinkDisplay
    var relationship: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(goal.color.swiftUIColor?.opacity(0.16) ?? Color.secondary.opacity(0.12))
                Text(goal.displayEmoji)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(goal.displayTitle)
                Text(relationship)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 3)
    }
}
