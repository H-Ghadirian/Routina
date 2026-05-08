import ComposableArchitecture
import SwiftData
import SwiftUI
import UIKit

struct TimelineView: View {
    let store: StoreOf<TimelineFeature>
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \RoutineLog.timestamp, order: .reverse) private var logs: [RoutineLog]
    @Query private var tasks: [RoutineTask]
    @State private var relatedFilterTagSuggestionAnchor: String?
    @State private var selectedTimelineEntryID: UUID?

    var body: some View {
        WithPerceptionTracking {
            timelineRoot
                .sheet(isPresented: filterSheetBinding) {
                    timelineFiltersSheet
                }
            .task {
                store.send(.setData(tasks: tasks, logs: logs))
                ensureTimelineSelection()
            }
            .onChange(of: tasks) { _, newValue in
                store.send(.setData(tasks: newValue, logs: logs))
            }
            .onChange(of: logs) { _, newValue in
                store.send(.setData(tasks: tasks, logs: newValue))
            }
            .onChange(of: visibleTimelineEntryIDs) { _, _ in
                ensureTimelineSelection()
            }
        }
    }

    @ViewBuilder
    private var timelineRoot: some View {
        if usesSidebarLayout {
            NavigationSplitView {
                timelineSidebarContent
                    .navigationSplitViewColumnWidth(min: 320, ideal: 420, max: 520)
            } detail: {
                timelineSidebarDetail
            }
            .navigationSplitViewStyle(.balanced)
        } else {
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
            }
        }
    }

    private var usesSidebarLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular
    }

    private var visibleTimelineEntryIDs: [UUID] {
        groupedByDay.flatMap { $0.entries.map(\.id) }
    }

    private var selectedTimelineEntry: TimelineEntry? {
        groupedByDay
            .flatMap(\.entries)
            .first { $0.id == selectedTimelineEntryID }
    }

    private func ensureTimelineSelection() {
        selectedTimelineEntryID = TimelineSelectionSupport.resolvedSelection(
            currentSelection: selectedTimelineEntryID,
            visibleEntryIDs: visibleTimelineEntryIDs,
            usesSidebarLayout: usesSidebarLayout
        )
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

    private var filterPresentation: TimelineFilterPresentation {
        TimelineFilterPresentation(
            selectedTags: store.effectiveSelectedTags,
            excludedTags: store.excludedTags,
            includeTagMatchMode: store.includeTagMatchMode,
            availableTags: availableTags,
            relatedTagRules: store.relatedTagRules
        )
    }

    private var suggestedRelatedFilterTags: [String] {
        filterPresentation.suggestedRelatedTags(suggestionAnchor: relatedFilterTagSuggestionAnchor)
    }

    private var availableExcludeTags: [String] {
        let baseEntries = TimelineLogic.filteredEntries(
            logs: store.logs,
            tasks: store.tasks,
            range: store.selectedRange,
            filterType: store.filterType,
            now: Date(),
            calendar: calendar
        ).filter { entry in
            HomeFeature.matchesImportanceUrgencyFilter(
                store.selectedImportanceUrgencyFilter,
                importance: entry.importance,
                urgency: entry.urgency
            )
        }

        return filterPresentation.availableExcludeTags(from: baseEntries)
    }

    private var tagRuleBindings: HomeTagRuleBindings {
        HomeTagRuleBindings(
            includeTagMatchMode: Binding(
                get: { store.includeTagMatchMode },
                set: { store.send(.includeTagMatchModeChanged($0)) }
            ),
            excludeTagMatchMode: Binding(
                get: { store.excludeTagMatchMode },
                set: { store.send(.excludeTagMatchModeChanged($0)) }
            )
        )
    }

    private var tagRuleData: HomeTagFilterData {
        filterPresentation.tagRuleData(
            suggestedRelatedTags: suggestedRelatedFilterTags,
            availableExcludeTags: availableExcludeTags
        )
    }

    private var tagRuleActions: HomeTagFilterActions {
        HomeTagFilterActions(
            onShowAllTags: {
                relatedFilterTagSuggestionAnchor = nil
                store.send(.selectedTagsChanged([]))
            },
            onToggleIncludedTag: toggleIncludedTag,
            onAddIncludedTag: addIncludedTag,
            onToggleExcludedTag: toggleExcludedTag
        )
    }

    private func isIncludedTagSelected(_ tag: String) -> Bool {
        filterPresentation.isIncludedTagSelected(tag)
    }

    private func toggleIncludedTag(_ tag: String) {
        let mutation = filterPresentation.toggledIncludedTag(
            tag,
            currentSuggestionAnchor: relatedFilterTagSuggestionAnchor
        )
        relatedFilterTagSuggestionAnchor = mutation.suggestionAnchor
        store.send(.selectedTagsChanged(mutation.selectedTags))
    }

    private func addIncludedTag(_ tag: String) {
        guard let mutation = filterPresentation.addedIncludedTag(
            tag,
            currentSuggestionAnchor: relatedFilterTagSuggestionAnchor
        ) else { return }
        relatedFilterTagSuggestionAnchor = mutation.suggestionAnchor
        store.send(.selectedTagsChanged(mutation.selectedTags))
    }

    private func toggleExcludedTag(_ tag: String) {
        let mutation = filterPresentation.toggledExcludedTag(tag)
        store.send(.selectedTagsChanged(mutation.selectedTags))
        store.send(.excludedTagsChanged(mutation.excludedTags))
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
                if hasActiveFilters {
                    activeFilterChipBar
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }

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

    private var activeFilterChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("Clear All") {
                    store.send(.clearFilters)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                if store.selectedRange != .all {
                    compactFilterChip(title: store.selectedRange.rawValue) {
                        store.send(.selectedRangeChanged(.all))
                    }
                }

                if store.filterType != .all {
                    compactFilterChip(title: store.filterType.rawValue) {
                        store.send(.filterTypeChanged(.all))
                    }
                }

                ForEach(store.effectiveSelectedTags.sorted(), id: \.self) { tag in
                    compactFilterChip(title: "#\(tag)") {
                        var selected = store.effectiveSelectedTags
                        selected = selected.filter { !RoutineTag.contains($0, in: [tag]) }
                        store.send(.selectedTagsChanged(selected))
                    }
                }

                if let selectedImportanceUrgencyFilterLabel {
                    compactFilterChip(title: selectedImportanceUrgencyFilterLabel) {
                        store.send(.selectedImportanceUrgencyFilterChanged(nil))
                    }
                }

                ForEach(store.excludedTags.sorted(), id: \.self) { tag in
                    compactFilterChip(title: "not #\(tag)", tintColor: .red) {
                        store.send(.excludedTagsChanged(store.excludedTags.filter { $0 != tag }))
                    }
                }
            }
        }
    }

    private func compactFilterChip(
        title: String,
        tintColor: Color = .secondary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.medium))

                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .foregroundStyle(tintColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tintColor.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
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

    @ViewBuilder
    private var timelineSidebarContent: some View {
        VStack(spacing: 0) {
            if hasActiveFilters {
                activeFilterChipBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }

            if logs.isEmpty {
                ContentUnavailableView(
                    "No timeline entries yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Completed and canceled items will appear here in chronological order.")
                )
            } else if groupedByDay.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Try a different time range or filter.")
                )
            } else {
                List(selection: $selectedTimelineEntryID) {
                    ForEach(groupedByDay, id: \.date) { section in
                        Section {
                            ForEach(section.entries) { entry in
                                timelineRowContent(entry)
                                    .tag(entry.id)
                            }
                        } header: {
                            Text(TimelineLogic.daySectionTitle(for: section.date, calendar: calendar))
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Timeline")
        .routinaTimelineNavigationTitleDisplayMode()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                filterSheetButton
            }
        }
    }

    @ViewBuilder
    private var timelineSidebarDetail: some View {
        if let taskID = selectedTimelineEntry?.taskID {
            timelineDetailDestination(taskID: taskID)
        } else {
            ContentUnavailableView(
                "Select a done",
                systemImage: "clock.arrow.circlepath",
                description: Text("Choose a completed or canceled item from the sidebar to see its task detail.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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

                HomeFiltersImportanceUrgencySection(
                    selectedImportanceUrgencyFilter: Binding(
                        get: { store.selectedImportanceUrgencyFilter },
                        set: { store.send(.selectedImportanceUrgencyFilterChanged($0)) }
                    ),
                    summary: importanceUrgencyFilterSummary
                )

                HomeFiltersTagRulesSection(
                    bindings: tagRuleBindings,
                    data: tagRuleData,
                    actions: tagRuleActions,
                    labels: HomeTagFilterSectionLabels(
                        includedTitle: "Show items with",
                        includedPickerTitle: "Show items with",
                        excludedTitle: "Hide items with",
                        excludedPickerTitle: "Hide items with"
                    )
                )

                HomeFiltersClearSection(
                    hasActiveOptionalFilters: hasActiveFilters,
                    onClearOptionalFilters: { store.send(.clearFilters) }
                )
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        store.send(.setFilterSheet(false))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: availableTags) { _, newValue in
            let selected = store.effectiveSelectedTags.filter { RoutineTag.contains($0, in: newValue) }
            store.send(.selectedTagsChanged(selected))
        }
    }

    private var selectedImportanceUrgencyFilterLabel: String? {
        guard let filter = store.selectedImportanceUrgencyFilter else { return nil }
        return "\(filter.importance.shortTitle)/\(filter.urgency.shortTitle)+"
    }

    private var importanceUrgencyFilterSummary: String {
        guard let filter = store.selectedImportanceUrgencyFilter else {
            return "Choose a cell to show done items from tasks that meet or exceed that importance and urgency."
        }
        return "Showing done items from tasks with at least \(filter.importance.title.lowercased()) importance and \(filter.urgency.title.lowercased()) urgency."
    }

    private func timelineRow(_ entry: TimelineEntry) -> some View {
        NavigationLink(value: entry.taskID) {
            timelineRowContent(entry)
        }
    }

    private func timelineRowContent(_ entry: TimelineEntry) -> some View {
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

            Text(timelineKindLabel(for: entry))
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(timelineKindColor(for: entry).opacity(0.15))
                )
                .foregroundStyle(timelineKindColor(for: entry))
        }
        .padding(.vertical, 2)
    }

    private func timelineKindLabel(for entry: TimelineEntry) -> String {
        switch entry.kind {
        case .completed:
            return entry.isOneOff ? "Todo" : "Routine"
        case .canceled:
            return "Canceled"
        case .missed:
            return "Missed"
        }
    }

    private func timelineKindColor(for entry: TimelineEntry) -> Color {
        switch entry.kind {
        case .completed:
            return entry.isOneOff ? .purple : .accentColor
        case .canceled:
            return .orange
        case .missed:
            return .yellow
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

}
