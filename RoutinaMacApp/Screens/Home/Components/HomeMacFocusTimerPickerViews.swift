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
