import SwiftData
import SwiftUI

struct HomeMacFocusTimerTaskPickerSheet: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let duration: TimeInterval
    let tasks: [RoutineTask]
    @State private var searchText = ""
    @State private var selectedTag: String?

    private var availableTags: [String] {
        RoutineTag.allTags(from: tasks.map(\.tags))
    }

    private var filteredTasks: [RoutineTask] {
        let trimmedSearch = tagAutocompleteDraft
        let tagFilteredTasks = tasks.filter { task in
            guard let selectedTag else { return true }
            return RoutineTag.contains(selectedTag, in: task.tags)
        }
        guard !trimmedSearch.isEmpty else { return tagFilteredTasks }

        return tagFilteredTasks.filter { task in
            taskTitle(task).localizedCaseInsensitiveContains(trimmedSearch)
                || task.tags.contains { $0.localizedCaseInsensitiveContains(trimmedSearch) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            HomeMacSearchField(
                placeholder: "Search tasks",
                text: $searchText,
                tagSuggestion: tagAutocompleteSuggestion,
                onAcceptTagSuggestion: acceptTagAutocompleteSuggestion
            )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            tagFilter
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

            Button {
                startFocusForSelectedTag()
            } label: {
                Label(selectedTagStartTitle, systemImage: "play.fill")
            }
            .disabled(selectedTag == nil)
            .keyboardShortcut(.defaultAction)

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(20)
    }

    @ViewBuilder
    private var tagFilter: some View {
        if availableTags.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    tagFilterButton(title: "All", tag: nil)

                    ForEach(availableTags, id: \.self) { tag in
                        tagFilterButton(title: "#\(tag)", tag: tag)
                    }
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func tagFilterButton(title: String, tag: String?) -> some View {
        let isSelected = tagsMatch(selectedTag, tag)

        return Button {
            selectedTag = tag
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.orange : Color.secondary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background {
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.orange.opacity(0.14) : Color.secondary.opacity(0.08))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(isSelected ? Color.orange.opacity(0.32) : Color.secondary.opacity(0.16), lineWidth: 0.75)
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
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

    private var selectedTagStartTitle: String {
        guard let selectedTag else { return "Start" }
        return "Start #\(selectedTag)"
    }

    private var tagAutocompleteSuggestion: String? {
        let draft = tagAutocompleteDraft
        guard !draft.isEmpty else { return nil }

        return RoutineTag.autocompleteSuggestion(
            for: draft,
            availableTags: availableTags,
            selectedTags: selectedTag.map { [$0] } ?? []
        )
    }

    private var tagAutocompleteDraft: String {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSearch.hasPrefix("#") else { return trimmedSearch }
        return String(trimmedSearch.dropFirst())
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func acceptTagAutocompleteSuggestion() {
        guard let suggestion = tagAutocompleteSuggestion else { return }
        selectedTag = suggestion
        searchText = ""
    }

    private func startFocusForSelectedTag() {
        guard let selectedTag else { return }

        do {
            _ = try FocusSessionSupport.startTagFocus(
                tagName: selectedTag,
                plannedDurationSeconds: duration,
                context: modelContext,
                calendar: calendar
            )
            dismiss()
        } catch {
            NSLog("Failed to start focus from toolbar tag picker: \(error.localizedDescription)")
        }
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

    private func tagsMatch(_ lhs: String?, _ rhs: String?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (.some(lhs), .some(rhs)):
            return RoutineTag.normalized(lhs) == RoutineTag.normalized(rhs)
        default:
            return false
        }
    }
}
