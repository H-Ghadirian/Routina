import ComposableArchitecture
import SwiftData
import SwiftUI

struct TimelineView: View {
    let store: StoreOf<TimelineFeature>
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \RoutineLog.timestamp, order: .reverse) private var logs: [RoutineLog]
    @Query private var tasks: [RoutineTask]
    @State private var relatedFilterTagSuggestionAnchor: String?

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                content
                    .navigationTitle("Timeline")
                    .routinaTimelineNavigationTitleDisplayMode()
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            filterSheetButton
                        }
                    }
                    .navigationDestination(for: UUID.self) { taskID in
                        timelineDetailDestination(taskID: taskID)
                    }
                    .sheet(isPresented: filterSheetBinding) {
                        timelineFiltersSheet
                    }
            }
            .task {
                store.send(.setData(tasks: tasks, logs: logs))
            }
            .onChange(of: tasks) { _, newValue in
                store.send(.setData(tasks: newValue, logs: logs))
            }
            .onChange(of: logs) { _, newValue in
                store.send(.setData(tasks: tasks, logs: newValue))
            }
        }
    }

    private var filterSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isFilterSheetPresented },
            set: { store.send(.setFilterSheet($0)) }
        )
    }

    private var selectedRangeBinding: Binding<TimelineRange> {
        Binding(
            get: { store.selectedRange },
            set: { store.send(.selectedRangeChanged($0)) }
        )
    }

    private var filterTypeBinding: Binding<TimelineFilterType> {
        Binding(
            get: { store.filterType },
            set: { store.send(.filterTypeChanged($0)) }
        )
    }

    private var groupedByDay: [TimelineFeature.TimelineSection] {
        store.groupedEntries
    }

    private var availableTags: [String] {
        store.availableTags
    }

    private var suggestedRelatedFilterTags: [String] {
        let selectedTags = store.effectiveSelectedTags
        guard !selectedTags.isEmpty else { return [] }
        let suggestionSource = relatedFilterTagSuggestionAnchor.map { [$0] } ?? Array(selectedTags)
        return RoutineTagRelations.relatedTags(
            for: suggestionSource,
            rules: store.relatedTagRules,
            availableTags: availableTags
        )
    }

    private var availableExcludeTags: [String] {
        availableTags.filter { tag in
            !store.effectiveSelectedTags.contains { RoutineTag.contains($0, in: [tag]) }
        }
    }

    private func isIncludedTagSelected(_ tag: String) -> Bool {
        store.effectiveSelectedTags.contains { RoutineTag.contains($0, in: [tag]) }
    }

    private func toggleIncludedTag(_ tag: String) {
        var selected = store.effectiveSelectedTags
        if selected.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
            selected = selected.filter { !RoutineTag.contains($0, in: [tag]) }
        } else {
            selected.insert(tag)
            relatedFilterTagSuggestionAnchor = tag
        }
        store.send(.selectedTagsChanged(selected))
        if selected.isEmpty { relatedFilterTagSuggestionAnchor = nil }
    }

    private func addIncludedTag(_ tag: String) {
        var selected = store.effectiveSelectedTags
        selected.insert(tag)
        store.send(.selectedTagsChanged(selected))
    }

    private func toggleExcludedTag(_ tag: String) {
        var excluded = store.excludedTags
        if excluded.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
            excluded = excluded.filter { !RoutineTag.contains($0, in: [tag]) }
        } else {
            excluded.insert(tag)
            let selected = store.effectiveSelectedTags.filter { !RoutineTag.contains($0, in: [tag]) }
            store.send(.selectedTagsChanged(selected))
        }
        store.send(.excludedTagsChanged(excluded))
    }

    private var hasActiveFilters: Bool {
        store.hasActiveFilters
    }

    @ViewBuilder
    private var content: some View {
        if logs.isEmpty {
            ContentUnavailableView(
                "No timeline entries yet",
                systemImage: "clock.arrow.circlepath",
                description: Text("Completed and canceled items will appear here in chronological order.")
            )
        } else {
            VStack(spacing: 0) {
                if groupedByDay.isEmpty {
                    ContentUnavailableView(
                        "No matches",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Try a different time range or filter.")
                    )
                } else {
                    timelineList
                }
            }
        }
    }

    private var timelineList: some View {
        List {
            ForEach(groupedByDay, id: \.date) { section in
                Section {
                    ForEach(section.entries) { entry in
                        timelineRow(entry)
                    }
                } header: {
                    Text(TimelineLogic.daySectionTitle(for: section.date, calendar: calendar))
                }
            }
        }
        .listStyle(.plain)
    }

    private var filterSheetButton: some View {
        Button {
            store.send(.setFilterSheet(true))
        } label: {
            Image(
                systemName: hasActiveFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .foregroundStyle(hasActiveFilters ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filters")
    }

    private var timelineFiltersSheet: some View {
        NavigationStack {
            List {
                Section("Range") {
                    Picker("Range", selection: selectedRangeBinding) {
                        ForEach(TimelineRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.inline)
                }

                if tasks.contains(where: { $0.isOneOffTask }) {
                    Section("Type") {
                        Picker("Type", selection: filterTypeBinding) {
                            ForEach(TimelineFilterType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }

                if !availableTags.isEmpty {
                    Section("Tag Rules") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Show items with")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Picker("Show items with", selection: Binding(
                                    get: { store.includeTagMatchMode },
                                    set: { store.send(.includeTagMatchModeChanged($0)) }
                                )) {
                                    ForEach(RoutineTagMatchMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 180)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if store.effectiveSelectedTags.isEmpty {
                                        timelineTagButton(title: "All Tags", isSelected: true) {
                                            relatedFilterTagSuggestionAnchor = nil
                                            store.send(.selectedTagsChanged([]))
                                        }
                                    } else {
                                        ForEach(store.effectiveSelectedTags.sorted(), id: \.self) { tag in
                                            timelineTagButton(title: "#\(tag)", isSelected: true) {
                                                toggleIncludedTag(tag)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            if !suggestedRelatedFilterTags.isEmpty {
                                Text("Suggested")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(suggestedRelatedFilterTags, id: \.self) { tag in
                                            timelineTagButton(title: "#\(tag)", isSelected: false) {
                                                addIncludedTag(tag)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }

                            Text("Add more")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(availableTags.filter { !isIncludedTagSelected($0) }, id: \.self) { tag in
                                        timelineTagButton(title: "#\(tag)", isSelected: false) {
                                            toggleIncludedTag(tag)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Hide items with")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Picker("Hide items with", selection: Binding(
                                    get: { store.excludeTagMatchMode },
                                    set: { store.send(.excludeTagMatchModeChanged($0)) }
                                )) {
                                    ForEach(RoutineTagMatchMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 180)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    if store.excludedTags.isEmpty {
                                        Text("No hidden tags")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        ForEach(store.excludedTags.sorted(), id: \.self) { tag in
                                            timelineTagButton(title: "#\(tag)", isSelected: true, selectedColor: .red) {
                                                toggleExcludedTag(tag)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            if !availableExcludeTags.isEmpty {
                                Text("Add tags to hide")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(availableExcludeTags.filter { tag in
                                            !store.excludedTags.contains { RoutineTag.contains($0, in: [tag]) }
                                        }, id: \.self) { tag in
                                            timelineTagButton(title: "#\(tag)", isSelected: false, selectedColor: .red) {
                                                toggleExcludedTag(tag)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }

                if hasActiveFilters {
                    Section {
                        Button("Clear Filters") {
                            store.send(.clearFilters)
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem {
                    Button("Done") {
                        store.send(.setFilterSheet(false))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: availableTags) { _, newValue in
            store.send(.selectedTagsChanged(store.effectiveSelectedTags.filter { RoutineTag.contains($0, in: newValue) }))
        }
    }

    private func timelineRow(_ entry: TimelineEntry) -> some View {
        NavigationLink(value: entry.taskID) {
            HStack(spacing: 12) {
                Text(entry.taskEmoji)
                    .font(.title2)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.taskName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    Text(entry.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text(entry.kind == .canceled ? "Canceled" : (entry.isOneOff ? "Todo" : "Routine"))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(
                                entry.kind == .canceled
                                    ? Color.orange.opacity(0.15)
                                    : (entry.isOneOff
                                        ? Color.purple.opacity(0.15)
                                        : Color.accentColor.opacity(0.15))
                            )
                    )
                    .foregroundStyle(entry.kind == .canceled ? .orange : (entry.isOneOff ? .purple : .accentColor))
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func timelineDetailDestination(taskID: UUID) -> some View {
        if let task = tasks.first(where: { $0.id == taskID }) {
            TaskDetailTCAView(
                store: Store(
                    initialState: makeTaskDetailState(for: task)
                ) {
                    TaskDetailFeature()
                }
            )
        } else {
            ContentUnavailableView(
                "Task not found",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected task is no longer available.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func makeTaskDetailState(for task: RoutineTask) -> TaskDetailFeature.State {
        let detailTask = task.detachedCopy()
        let now = Date()
        let defaultSelectedDate = (detailTask.isCompletedOneOff || detailTask.isCanceledOneOff)
            ? calendar.startOfDay(for: detailTask.lastDone ?? detailTask.canceledAt ?? now)
            : calendar.startOfDay(for: now)

        return TaskDetailFeature.State(
            task: detailTask,
            logs: [],
            selectedDate: defaultSelectedDate,
            daysSinceLastRoutine: RoutineDateMath.elapsedDaysSinceLastDone(
                from: detailTask.lastDone,
                referenceDate: now
            ),
            overdueDays: detailTask.isArchived()
                ? 0
                : RoutineDateMath.overdueDays(for: detailTask, referenceDate: now, calendar: calendar),
            isDoneToday: detailTask.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        )
    }

    private func timelineTagButton(
        title: String,
        isSelected: Bool,
        selectedColor: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? selectedColor.opacity(0.16) : Color.secondary.opacity(0.12))
                )
                .foregroundStyle(isSelected ? selectedColor : .primary)
        }
        .buttonStyle(.plain)
    }
}
