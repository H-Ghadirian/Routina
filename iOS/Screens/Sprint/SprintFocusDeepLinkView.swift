import SwiftUI
import SwiftData
import ComposableArchitecture

struct SprintFocusDeepLinkView: View {
    let sprintID: UUID

    @Environment(\.dismiss) private var dismiss
    @Dependency(\.sprintBoardClient) private var sprintBoardClient
    @Query private var tasks: [RoutineTask]
    @State private var boardData: SprintBoardData?
    @State private var loadState: LoadState = .loading

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Sprint")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await loadBoard() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
        }
        .task(id: sprintID) {
            await loadBoard()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch loadState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .missing:
            ContentUnavailableView(
                "Sprint Not Found",
                systemImage: "flag.slash",
                description: Text("The timer may have ended or the sprint is no longer available on this iPhone.")
            )
        case let .failed(message):
            ContentUnavailableView(
                "Could Not Load Sprint",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        case .loaded:
            if let sprint {
                sprintBoardContent(for: sprint)
            } else {
                ContentUnavailableView("Sprint Not Found", systemImage: "flag.slash")
            }
        }
    }

    private func sprintBoardContent(for sprint: BoardSprint) -> some View {
        List {
            Section {
                sprintTimerHeader(sprint)
            }

            if assignedTasks.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Tasks",
                        systemImage: "checklist",
                        description: Text("This sprint does not have any assigned tasks yet.")
                    )
                }
            } else {
                ForEach(boardStates) { state in
                    let tasks = assignedTasks.filter { displayState(for: $0) == state }
                    if !tasks.isEmpty {
                        Section(state.displayTitle) {
                            ForEach(tasks) { task in
                                taskRow(task)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadBoard()
        }
    }

    private func sprintTimerHeader(_ sprint: BoardSprint) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(sprint.status.displayTitle, systemImage: statusImage(for: sprint.status))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(sprint.title)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Text("\(completedTaskCount)/\(assignedTasks.count)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let activeFocusSession {
                VStack(alignment: .leading, spacing: 4) {
                    Text(activeFocusSession.startedAt, style: .timer)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.teal)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("Running sprint focus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            } else if let latestSession {
                Label(
                    "\(FocusSessionFormatting.compactDurationText(seconds: latestSession.durationSeconds)) last recorded",
                    systemImage: "timer"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            } else {
                Label("No active sprint timer", systemImage: "timer")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private func taskRow(_ task: RoutineTask) -> some View {
        HStack(spacing: 12) {
            if let emoji = task.emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.title3)
                    .frame(width: 28)
            } else {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(taskTitle(task))
                    .font(.body.weight(.medium))
                    .lineLimit(2)

                if !task.tags.isEmpty {
                    Text(task.tags.prefix(3).map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            let state = displayState(for: task)
            Image(systemName: state.systemImage)
                .foregroundStyle(tint(for: state))
                .accessibilityLabel(state.displayTitle)
        }
        .padding(.vertical, 3)
    }

    @MainActor
    private func loadBoard() async {
        loadState = .loading

        do {
            let data = try await sprintBoardClient.load()
            boardData = data
            loadState = data.sprints.contains(where: { $0.id == sprintID }) ? .loaded : .missing
        } catch {
            boardData = nil
            loadState = .failed(error.localizedDescription)
        }
    }

    private var sprint: BoardSprint? {
        boardData?.sprints.first { $0.id == sprintID }
    }

    private var activeFocusSession: SprintFocusSession? {
        boardData?
            .focusSessions(for: sprintID)
            .first(where: \.isActive)
    }

    private var latestSession: SprintFocusSession? {
        boardData?
            .focusSessions(for: sprintID)
            .first
    }

    private var assignedTasks: [RoutineTask] {
        guard let boardData else { return [] }
        let assignedIDs = Set(
            boardData.assignments
                .filter { $0.sprintID == sprintID }
                .map(\.todoID)
        )

        return tasks
            .filter { assignedIDs.contains($0.id) && !$0.isCanceledOneOff }
            .sorted { lhs, rhs in
                taskTitle(lhs).localizedCaseInsensitiveCompare(taskTitle(rhs)) == .orderedAscending
            }
    }

    private var completedTaskCount: Int {
        assignedTasks.filter { displayState(for: $0) == .done }.count
    }

    private var boardStates: [TodoState] {
        [.inProgress, .ready, .blocked, .paused, .done]
    }

    private func displayState(for task: RoutineTask) -> TodoState {
        task.todoState ?? (task.isCompletedOneOff ? .done : .ready)
    }

    private func taskTitle(_ task: RoutineTask) -> String {
        let title = (task.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Untitled task" : title
    }

    private func statusImage(for status: SprintStatus) -> String {
        switch status {
        case .planned:
            return "calendar"
        case .active:
            return "flag.checkered"
        case .finished:
            return "checkmark.circle"
        }
    }

    private func tint(for state: TodoState) -> Color {
        switch state {
        case .ready:
            return .secondary
        case .inProgress:
            return .blue
        case .blocked:
            return .red
        case .done:
            return .green
        case .paused:
            return .orange
        }
    }
}

private enum LoadState: Equatable {
    case loading
    case loaded
    case missing
    case failed(String)
}
