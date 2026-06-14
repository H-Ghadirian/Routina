import SwiftData
import SwiftUI

struct HomeMacFocusTimerTaskPickerSheet: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let duration: TimeInterval
    let tasks: [RoutineTask]
    @State private var searchText = ""

    private var filteredTasks: [RoutineTask] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return tasks }

        return tasks.filter { task in
            taskTitle(task).localizedCaseInsensitiveContains(trimmedSearch)
                || task.tags.contains { $0.localizedCaseInsensitiveContains(trimmedSearch) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            HomeMacSearchField(placeholder: "Search tasks", text: $searchText)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            Divider()

            if filteredTasks.isEmpty {
                ContentUnavailableView(
                    "No Tasks Found",
                    systemImage: "magnifyingglass",
                    description: Text("Try another search.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredTasks) { task in
                    Button {
                        startFocus(for: task)
                    } label: {
                        taskRow(task)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 520, height: 560)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 32, height: 32)
                .routinaGlassPill(tint: .orange, tintOpacity: 0.16)

            VStack(alignment: .leading, spacing: 2) {
                Text("Start Focus Timer")
                    .font(.headline)

                Text(durationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(20)
    }

    private func taskRow(_ task: RoutineTask) -> some View {
        HStack(spacing: 10) {
            Image(systemName: task.isOneOffTask ? "checkmark.circle" : "repeat")
                .font(.headline)
                .foregroundStyle(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(taskTitle(task))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !task.tags.isEmpty {
                    Text(task.tags.prefix(4).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "play.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }

    private var durationText: String {
        duration > 0
            ? FocusSessionFormatting.compactDurationText(seconds: duration)
            : "Count up"
    }

    private func startFocus(for task: RoutineTask) {
        do {
            _ = try FocusSessionSupport.startTaskFocus(
                task: task,
                plannedDurationSeconds: duration,
                context: modelContext,
                calendar: calendar
            )
            dismiss()
        } catch {
            NSLog("Failed to start focus from toolbar task picker: \(error.localizedDescription)")
        }
    }

    private func taskTitle(_ task: RoutineTask) -> String {
        RoutineTask.trimmedName(task.name).flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled task"
    }
}

struct HomeMacUnassignedFocusAssignmentPopover: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var focusSessions: [FocusSession]
    @Query private var tasks: [RoutineTask]
    @Query(sort: \BoardSprintRecord.createdAt, order: .reverse) private var sprintRecords: [BoardSprintRecord]

    var body: some View {
        let sessions = FocusSessionSupport.unassignedCompletedSessions(from: focusSessions)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "tray.full")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 28, height: 28)
                    .routinaGlassPill(tint: .orange, tintOpacity: 0.16)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Unassigned Focus")
                        .font(.headline)

                    Text("\(sessions.count) \(sessions.count == 1 ? "session" : "sessions") waiting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }

            if sessions.isEmpty {
                Text("All focus sessions are assigned.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(sessions) { session in
                            assignmentRow(for: session)

                            if session.id != sessions.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    private func assignmentRow(for session: FocusSession) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.completedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Finished focus")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(FocusSessionFormatting.compactDurationText(seconds: session.actualDurationSeconds))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Menu {
                taskAssignmentMenuItems(session)
                sprintAssignmentMenuItems(session)
            } label: {
                Label("Assign", systemImage: "arrowshape.turn.up.right")
            }
            .menuStyle(.button)
            .controlSize(.small)
            .disabled(assignableTasks.isEmpty && activeSprints.isEmpty)
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func taskAssignmentMenuItems(_ session: FocusSession) -> some View {
        if !assignableTasks.isEmpty {
            Section("Task") {
                ForEach(assignableTasks.prefix(12)) { task in
                    Button(taskTitle(task)) {
                        assign(session, toTask: task)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sprintAssignmentMenuItems(_ session: FocusSession) -> some View {
        if !activeSprints.isEmpty {
            Section("Board") {
                ForEach(activeSprints.prefix(8)) { sprint in
                    Button(sprintTitle(sprint)) {
                        assign(session, toSprint: sprint)
                    }
                }
            }
        }
    }

    private var assignableTasks: [RoutineTask] {
        tasks
            .filter { task in
                !task.isArchived()
                    && !task.isCompletedOneOff
                    && !task.isCanceledOneOff
            }
            .sorted {
                taskTitle($0).localizedCaseInsensitiveCompare(taskTitle($1)) == .orderedAscending
            }
    }

    private var activeSprints: [BoardSprintRecord] {
        sprintRecords
            .filter { $0.statusRawValue == SprintStatus.active.rawValue }
            .sorted {
                sprintTitle($0).localizedCaseInsensitiveCompare(sprintTitle($1)) == .orderedAscending
            }
    }

    private func assign(_ session: FocusSession, toTask task: RoutineTask) {
        do {
            _ = try FocusSessionSupport.assignUnassignedFocus(
                sessionID: session.id,
                toTask: task.id,
                context: modelContext
            )
        } catch {
            NSLog("Failed to assign focus session to task: \(error.localizedDescription)")
        }
    }

    private func assign(_ session: FocusSession, toSprint sprint: BoardSprintRecord) {
        do {
            _ = try FocusSessionSupport.assignUnassignedFocusToSprint(
                sessionID: session.id,
                sprintID: sprint.id,
                context: modelContext
            )
        } catch {
            NSLog("Failed to assign focus session to board: \(error.localizedDescription)")
        }
    }

    private func taskTitle(_ task: RoutineTask) -> String {
        RoutineTask.trimmedName(task.name).flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled task"
    }

    private func sprintTitle(_ sprint: BoardSprintRecord) -> String {
        let title = sprint.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Active board" : title
    }
}
