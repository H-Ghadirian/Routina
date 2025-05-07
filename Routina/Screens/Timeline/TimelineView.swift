import ComposableArchitecture
import SwiftData
import SwiftUI

struct TimelineView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \RoutineLog.timestamp, order: .reverse) private var logs: [RoutineLog]
    @Query private var tasks: [RoutineTask]

    @State private var selectedRange: TimelineRange = .all
    @State private var filterType: TimelineFilterType = .all
    @State private var selectedTag: String?
    @State private var isFilterSheetPresented = false

    init(
        selectedRange: TimelineRange = .all,
        filterType: TimelineFilterType = .all
    ) {
        _selectedRange = State(initialValue: selectedRange)
        _filterType = State(initialValue: filterType)
    }

    private var baseEntries: [TimelineEntry] {
        TimelineLogic.filteredEntries(
            logs: logs,
            tasks: tasks,
            range: selectedRange,
            filterType: filterType,
            now: Date(),
            calendar: calendar
        )
    }

    private var entries: [TimelineEntry] {
        baseEntries.filter { entry in
            TimelineLogic.matchesSelectedTag(selectedTag, in: entry.tags)
        }
    }

    private var availableTags: [String] {
        TimelineLogic.availableTags(from: baseEntries)
    }

    private var groupedByDay: [(date: Date, entries: [TimelineEntry])] {
        TimelineLogic.groupedByDay(entries: entries, calendar: calendar)
    }

    var body: some View {
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
                .sheet(isPresented: $isFilterSheetPresented) {
                    timelineFiltersSheet
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if logs.isEmpty {
            ContentUnavailableView(
                "No completions yet",
                systemImage: "clock.arrow.circlepath",
                description: Text("Completed routines and todos will appear here in chronological order.")
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
            isFilterSheetPresented = true
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
                    Picker("Range", selection: $selectedRange) {
                        ForEach(TimelineRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.inline)
                }

                if tasks.contains(where: { $0.isOneOffTask }) {
                    Section("Type") {
                        Picker("Type", selection: $filterType) {
                            ForEach(TimelineFilterType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }

                if !availableTags.isEmpty {
                    Section("Tag") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                timelineTagButton(title: "All Tags", isSelected: selectedTag == nil) {
                                    selectedTag = nil
                                }

                                ForEach(availableTags, id: \.self) { tag in
                                    timelineTagButton(
                                        title: "#\(tag)",
                                        isSelected: selectedTag.map { RoutineTag.contains($0, in: [tag]) } ?? false
                                    ) {
                                        selectedTag = tag
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if hasActiveFilters {
                    Section {
                        Button("Clear Filters") {
                            clearFilters()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isFilterSheetPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: availableTags) { _, newValue in
            guard let selectedTag else { return }
            if !RoutineTag.contains(selectedTag, in: newValue) {
                self.selectedTag = nil
            }
        }
    }

    private var hasActiveFilters: Bool {
        selectedRange != .all || filterType != .all || selectedTag != nil
    }

    private func clearFilters() {
        selectedRange = .all
        filterType = .all
        selectedTag = nil
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

                Text(entry.isOneOff ? "Todo" : "Routine")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(entry.isOneOff
                                ? Color.purple.opacity(0.15)
                                : Color.accentColor.opacity(0.15)
                            )
                    )
                    .foregroundStyle(entry.isOneOff ? .purple : .accentColor)
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func timelineDetailDestination(taskID: UUID) -> some View {
        if let task = tasks.first(where: { $0.id == taskID }) {
            RoutineDetailTCAView(
                store: Store(
                    initialState: makeRoutineDetailState(for: task)
                ) {
                    RoutineDetailFeature()
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

    private func makeRoutineDetailState(for task: RoutineTask) -> RoutineDetailFeature.State {
        let detailTask = task.detachedCopy()
        let now = Date()
        let defaultSelectedDate = detailTask.isCompletedOneOff
            ? calendar.startOfDay(for: detailTask.lastDone ?? now)
            : calendar.startOfDay(for: now)

        return RoutineDetailFeature.State(
            task: detailTask,
            logs: [],
            selectedDate: defaultSelectedDate,
            daysSinceLastRoutine: RoutineDateMath.elapsedDaysSinceLastDone(
                from: detailTask.lastDone,
                referenceDate: now
            ),
            overdueDays: detailTask.isPaused
                ? 0
                : RoutineDateMath.overdueDays(for: detailTask, referenceDate: now, calendar: calendar),
            isDoneToday: detailTask.lastDone.map { calendar.isDate($0, inSameDayAs: now) } ?? false
        )
    }

    private func timelineTagButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12))
                )
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }
}
