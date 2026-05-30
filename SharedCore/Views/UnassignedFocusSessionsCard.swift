import SwiftData
import SwiftUI

struct UnassignedFocusSessionsCard: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [RoutineTask]
    @Query(sort: \BoardSprintRecord.createdAt, order: .reverse) private var sprintRecords: [BoardSprintRecord]

    let focusSessions: [FocusSession]

    var body: some View {
        let sessions = FocusSessionSupport.unassignedCompletedSessions(from: focusSessions)

        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                header(sessions: sessions)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sessions.prefix(5)) { session in
                        unassignedFocusRow(session)

                        if session.id != sessions.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(16)
            .routinaGlassCard(cornerRadius: 12, tint: .orange, tintOpacity: 0.06)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.orange.opacity(0.22), lineWidth: 1)
            }
        }
    }

    private func header(sessions: [FocusSession]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "tray.full")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.orange)
                .frame(width: 30, height: 30)
                .routinaGlassPill(tint: .orange, tintOpacity: 0.16)

            VStack(alignment: .leading, spacing: 4) {
                Text("Unassigned Focus")
                    .font(.headline)

                Text("\(sessions.count) \(sessions.count == 1 ? "session" : "sessions") waiting for a task or board.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
    }

    private func unassignedFocusRow(_ session: FocusSession) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.completedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Finished focus")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(FocusSessionFormatting.compactDurationText(seconds: session.actualDurationSeconds))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

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
