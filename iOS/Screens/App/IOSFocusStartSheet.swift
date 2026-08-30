import SwiftData
import SwiftUI

struct IOSFocusStartTask: Identifiable {
    let model: RoutineTask
    let id: UUID
    let title: String
    let tags: [String]
    let isOneOffTask: Bool

    init(model: RoutineTask) {
        self.model = model
        id = model.id
        title = RoutineTask.trimmedName(model.name).flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled task"
        tags = model.tags
        isOneOffTask = model.isOneOffTask
    }
}

struct IOSFocusStartPresentation: Identifiable {
    let id = UUID()
    let tasks: [IOSFocusStartTask]
    let availableTags: [String]
    let defaults: FocusSessionStartDefaults

    static func make(
        tasks: [RoutineTask],
        focusSessions: [FocusSession]
    ) -> Self {
        let taskSnapshots = tasks
            .map(IOSFocusStartTask.init(model:))
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        let availableTags = FocusSessionTagRecency.orderedAvailableTags(
            RoutineTag.allTags(from: taskSnapshots.map(\.tags)),
            focusSessions: focusSessions
        )

        return Self(
            tasks: taskSnapshots,
            availableTags: availableTags,
            defaults: FocusSessionStartDefaults.latest(
                focusSessions: focusSessions,
                availableTags: availableTags,
                rememberedDuration: FocusSessionStartDefaults.rememberedDuration()
            )
        )
    }
}

struct IOSFocusStartSheet: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let presentation: IOSFocusStartPresentation
    let onCreateTask: () -> Void
    @State private var searchText = ""
    @State private var selectedDuration: TimeInterval
    @State private var selectedTag: String?
    @State private var errorMessage: String?

    init(
        presentation: IOSFocusStartPresentation,
        onCreateTask: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.onCreateTask = onCreateTask
        _selectedDuration = State(initialValue: presentation.defaults.duration)
        _selectedTag = State(initialValue: presentation.defaults.tagName)
    }

    var body: some View {
        NavigationStack {
            List {
                durationSection

                if !presentation.availableTags.isEmpty {
                    tagSection
                }

                taskSection
            }
            .navigationTitle("Focus")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search tasks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .alert(
            "Couldn’t Start Focus",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var durationSection: some View {
        Section("Duration") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(durationOptions, id: \.self) { duration in
                        durationButton(duration)
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private var tagSection: some View {
        Section("Tag") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    tagButton(title: "All", tag: nil)

                    ForEach(presentation.availableTags, id: \.self) { tag in
                        tagButton(title: "#\(tag)", tag: tag)
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            if let selectedTag {
                Button {
                    startTagFocus(selectedTag)
                } label: {
                    Label("Start Focus on #\(selectedTag)", systemImage: "play.fill")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    @ViewBuilder
    private var taskSection: some View {
        Section("Task") {
            if presentation.tasks.isEmpty {
                createTaskButton
            } else if filteredTasks.isEmpty {
                Text(emptyTaskMessage)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredTasks) { task in
                    Button {
                        startTaskFocus(task)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: task.isOneOffTask ? "checkmark.circle" : "repeat")
                                .font(.headline)
                                .foregroundStyle(.orange)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)

                                if !task.tags.isEmpty {
                                    Text(task.tags.prefix(4).map { "#\($0)" }.joined(separator: "  "))
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
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start Focus on \(task.title)")
                }
            }
        }
    }

    private var createTaskButton: some View {
        Button(action: onCreateTask) {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Create Task")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)

                    Text("Create an active task before starting Focus.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens task creation")
    }

    private var filteredTasks: [IOSFocusStartTask] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return presentation.tasks.filter { task in
            let matchesTag = selectedTag.map { RoutineTag.contains($0, in: task.tags) } ?? true
            guard matchesTag else { return false }
            guard !trimmedSearch.isEmpty else { return true }
            return task.title.localizedCaseInsensitiveContains(trimmedSearch)
                || task.tags.contains { $0.localizedCaseInsensitiveContains(trimmedSearch) }
        }
    }

    private var emptyTaskMessage: String {
        if selectedTag != nil {
            return "No active tasks use this tag."
        }
        return "No active tasks match this search."
    }

    private var durationOptions: [TimeInterval] {
        FocusSessionStartDefaults.durationOptions(including: selectedDuration)
    }

    private func durationButton(_ duration: TimeInterval) -> some View {
        let isSelected = duration == selectedDuration

        return Button {
            selectedDuration = duration
            FocusSessionStartDefaults.rememberDuration(duration)
        } label: {
            Text(durationTitle(duration))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.orange : Color.secondary)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background {
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.orange.opacity(0.14) : Color.secondary.opacity(0.08))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            isSelected ? Color.orange.opacity(0.32) : Color.secondary.opacity(0.16),
                            lineWidth: 0.75
                        )
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(durationTitle(duration))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func tagButton(title: String, tag: String?) -> some View {
        let isSelected = tagsMatch(selectedTag, tag)

        return Button {
            selectedTag = tag
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.orange : Color.secondary)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background {
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.orange.opacity(0.14) : Color.secondary.opacity(0.08))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            isSelected ? Color.orange.opacity(0.32) : Color.secondary.opacity(0.16),
                            lineWidth: 0.75
                        )
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func durationTitle(_ duration: TimeInterval) -> String {
        duration > 0
            ? FocusSessionFormatting.compactDurationText(seconds: duration)
            : "Count up"
    }

    private func startTaskFocus(_ task: IOSFocusStartTask) {
        do {
            _ = try FocusSessionSupport.startTaskFocus(
                task: task.model,
                plannedDurationSeconds: selectedDuration,
                context: modelContext,
                calendar: calendar
            )
            FocusSessionStartDefaults.rememberDuration(selectedDuration)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startTagFocus(_ tag: String) {
        do {
            _ = try FocusSessionSupport.startTagFocus(
                tagName: tag,
                plannedDurationSeconds: selectedDuration,
                context: modelContext,
                calendar: calendar
            )
            FocusSessionStartDefaults.rememberDuration(selectedDuration)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
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
