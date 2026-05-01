import ComposableArchitecture
import SwiftUI

struct GoalsTCAView: View {
    let store: StoreOf<GoalsFeature>

    var body: some View {
        WithPerceptionTracking {
            NavigationSplitView {
                MacGoalsSidebarView(store: store)
                    .navigationTitle("Goals")
                    .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
                    .searchable(text: searchBinding, prompt: "Search goals")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            MacGoalsNewGoalButton(store: store)
                        }
                    }
            } detail: {
                MacGoalsDetailView(store: store)
            }
            .navigationSplitViewStyle(.balanced)
        }
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { store.searchText },
            set: { store.send(.searchTextChanged($0)) }
        )
    }
}

struct MacGoalsNewGoalButton: View {
    let store: StoreOf<GoalsFeature>

    var body: some View {
        Button {
            store.send(.addGoalTapped)
        } label: {
            Label("New Goal", systemImage: "plus")
        }
        .help("New Goal")
    }
}

struct MacGoalsSidebarView: View {
    let store: StoreOf<GoalsFeature>

    var body: some View {
        WithPerceptionTracking {
            content
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.filteredGoals.isEmpty {
            ContentUnavailableView.search(text: store.searchText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(selection: selectionBinding) {
                if !store.activeGoals.isEmpty {
                    Section("Active") {
                        ForEach(store.activeGoals) { goal in
                            GoalListRow(goal: goal)
                                .tag(goal.id as UUID?)
                        }
                    }
                }

                if !store.archivedGoals.isEmpty {
                    Section("Archived") {
                        ForEach(store.archivedGoals) { goal in
                            GoalListRow(goal: goal)
                                .tag(goal.id as UUID?)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedGoalID },
            set: { store.send(.selectGoal($0)) }
        )
    }
}

struct MacGoalsDetailView: View {
    let store: StoreOf<GoalsFeature>

    var body: some View {
        WithPerceptionTracking {
            content
                .sheet(isPresented: editorBinding) {
                    GoalsEditorSheet(store: store)
                        .frame(minWidth: 440, minHeight: 420)
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
                    Text("Tasks linked to this goal will keep the task, but the goal link will be removed.")
                }
                .task {
                    store.send(.onAppear)
                }
                .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
                    store.send(.refreshRequested)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let goal = store.selectedGoal {
            GoalDetailPane(store: store, goal: goal)
        } else {
            ContentUnavailableView(
                "Select a goal",
                systemImage: "target"
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Goals")
        }
    }

    private var editorBinding: Binding<Bool> {
        Binding(
            get: { store.isEditorPresented },
            set: { isPresented in
                if !isPresented {
                    store.send(.dismissEditor)
                }
            }
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
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(goal.color.swiftUIColor?.opacity(0.16) ?? Color.secondary.opacity(0.12))
                Text(goal.displayEmoji)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(goal.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                Text("\(goal.openTaskCount) open, \(goal.linkedTasks.count) linked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 3)
    }
}

private struct GoalDetailPane: View {
    let store: StoreOf<GoalsFeature>
    var goal: GoalsFeature.GoalDisplay

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                Divider()

                metrics

                if let notes = goal.notes {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Linked Tasks")
                        .font(.headline)

                    if goal.linkedTasks.isEmpty {
                        ContentUnavailableView(
                            "No linked tasks",
                            systemImage: "checklist"
                        )
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(goal.linkedTasks) { task in
                                GoalTaskInlineRow(task: task)
                                if task.id != goal.linkedTasks.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(32)
        }
        .navigationTitle(goal.displayTitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.send(.editGoalTapped(goal.id))
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }

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
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(goal.color.swiftUIColor?.opacity(0.16) ?? Color.secondary.opacity(0.12))
                Text(goal.displayEmoji)
                    .font(.system(size: 32))
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 8) {
                Text(goal.displayTitle)
                    .font(.largeTitle.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label(goal.status.title, systemImage: goal.status == .active ? "target" : "archivebox")
                    if let targetDate = goal.targetDate {
                        Label(targetDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private var metrics: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 32, verticalSpacing: 12) {
            GridRow {
                MetricLabel(title: "Open Items", value: "\(goal.openTaskCount)")
                MetricLabel(title: "Routines", value: "\(goal.routineCount)")
                MetricLabel(title: "Todos", value: "\(goal.todoCount)")
            }

            GridRow {
                MetricLabel(title: "Done Todos", value: "\(goal.completedTodoCount)")
                MetricLabel(
                    title: "Linked Tasks",
                    value: "\(goal.linkedTasks.count)"
                )
                MetricLabel(
                    title: "Next Due",
                    value: goal.nextDueDate?.formatted(date: .abbreviated, time: .omitted) ?? "None"
                )
            }
        }
    }
}

private struct MetricLabel: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 100, alignment: .leading)
    }
}

private struct GoalTaskInlineRow: View {
    var task: GoalsFeature.GoalTaskDisplay

    var body: some View {
        HStack(spacing: 12) {
            Text(task.displayEmoji)
                .frame(width: 28, height: 28)
                .background(Color.secondary.opacity(0.12), in: Circle())

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
        .padding(.vertical, 4)
    }
}
