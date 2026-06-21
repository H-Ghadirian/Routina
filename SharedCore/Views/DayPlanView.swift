import SwiftData
import SwiftUI

struct DayPlanView: View {
    @StateObject private var planner = DayPlanPlannerState()

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
#if os(macOS)
        VStack(alignment: .leading, spacing: 16) {
            DayPlanHeaderView(planner: planner)

            HSplitView {
                DayPlanSidebarView(planner: planner)
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)

                DayPlanTimelinePanelView(planner: planner)
                    .frame(minWidth: 520)
            }
        }
        .padding(20)
#else
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                DayPlanHeaderView(planner: planner)
                    .padding(.horizontal)
                    .padding(.top)

                DayPlanSidebarView(planner: planner)
                    .frame(maxHeight: 320)
                    .padding(.horizontal)

                DayPlanTimelinePanelView(planner: planner)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .navigationTitle("Plan")
        }
#endif
    }
}

struct DayPlanSidebarView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var planner: DayPlanPlannerState
    @Query private var tasks: [RoutineTask]
    @Query private var logs: [RoutineLog]
    @Query(sort: \SleepSession.startedAt, order: .reverse) private var sleepSessions: [SleepSession]
    @Query(sort: \AwaySession.startedAt, order: .reverse) private var awaySessions: [AwaySession]
    var usesPanelBackground = true
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowTimelineTasksInDayPlanner.rawValue,
        store: SharedDefaults.app
    ) private var showsTimelineTasksInDayPlanner = true
    @AppStorage(
        UserDefaultStringValueKey.appSettingHiddenDayPlanTimelineActivityIDs.rawValue,
        store: SharedDefaults.app
    ) private var hiddenTimelineActivityStorage = ""

    var body: some View {
        taskPanel
            .dayPlanLifecycle(planner: planner, tasks: tasks, sleepSessions: sleepSessions, awaySessions: awaySessions, calendar: calendar)
    }

    private var taskPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sidebarTitle)
                            .font(.headline)

                        if let focusedDate = activeFocusedUnplannedCompletedDate {
                            Text("Timeline activity on \(focusedDate.formatted(date: .abbreviated, time: .omitted)) and not in planner")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 8)

                    if activeFocusedUnplannedCompletedDate != nil {
                        Button("Clear") {
                            planner.clearFocusedUnplannedCompletedTasks()
                        }
                        .controlSize(.small)
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                TextField("Search tasks", text: $planner.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .routinaGlassCard(cornerRadius: 8, interactive: true)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    if filteredTasks.isEmpty {
                        ContentUnavailableView(
                            emptyStateTitle,
                            systemImage: "tray",
                            description: Text(emptyStateDescription)
                        )
                        .padding(.vertical, 24)
                    } else {
                        ForEach(filteredTasks) { task in
                            DayPlanTaskCandidateRow(
                                task: task,
                                title: DayPlanTaskSorting.title(for: task),
                                isSelected: task.id == planner.selectedTaskID
                            ) {
                                planner.selectTask(task)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Divider()

            editorPanel
        }
        .padding(usesPanelBackground ? 14 : 0)
        .routinaIf(usesPanelBackground) { view in
            view.routinaGlassPanel(cornerRadius: 8)
        }
    }

    private var editorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(planner.selectedBlock == nil ? "Add to timeline" : "Edit block")
                    .font(.headline)
                Spacer()
                if planner.selectedBlock != nil {
                    Button("New") {
                        planner.selectedBlockID = nil
                    }
                    .controlSize(.small)
                }
            }

            Picker("Task", selection: $planner.selectedTaskID) {
                Text("Choose a task").tag(Optional<UUID>.none)
                ForEach(availableTasks) { task in
                    Text(DayPlanTaskSorting.title(for: task)).tag(Optional(task.id))
                }
            }

            DatePicker("Start", selection: startDateBinding, displayedComponents: [.hourAndMinute])
                .datePickerStyle(.compact)

            Stepper(
                "Duration: \(DayPlanFormatting.durationText(planner.durationMinutes))",
                value: $planner.durationMinutes,
                in: durationStepperRange,
                step: 15
            )

            Text("Ends \(DayPlanFormatting.timeText(for: planner.startMinute + planner.durationMinutes, on: planner.selectedDate, calendar: calendar))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let conflictingBlock = planner.conflictingBlock {
                Label("Overlaps \(conflictingBlock.titleSnapshot)", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let sleepConflict {
                Label("Overlaps \(sleepConflict.title)", systemImage: "bed.double.fill")
                    .font(.caption)
                    .foregroundStyle(.indigo)
            }

            if let awayConflict {
                Label("Overlaps \(awayConflict.title)", systemImage: "lock.shield.fill")
                    .font(.caption)
                    .foregroundStyle(.teal)
            }

            HStack {
                Button(planner.selectedBlock == nil ? "Add" : "Save") {
                    if let selectedTask {
                        planner.commitBlock(task: selectedTask, calendar: calendar, context: modelContext)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCommitBlock)

                if let selectedBlock = planner.selectedBlock {
                    Button("Delete", role: .destructive) {
                        planner.deleteBlock(selectedBlock.id, calendar: calendar, context: modelContext)
                    }
                }
            }
        }
    }

    private var durationStepperRange: ClosedRange<Int> {
        let lowerBound = min(
            DayPlanBlock.minimumDurationMinutes,
            max(DayPlanBlock.minimumStoredDurationMinutes, planner.durationMinutes)
        )
        return lowerBound...planner.maximumDurationForStart
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: {
                let startOfDay = calendar.startOfDay(for: planner.selectedDate)
                return calendar.date(byAdding: .minute, value: planner.startMinute, to: startOfDay) ?? startOfDay
            },
            set: { date in
                let components = calendar.dateComponents([.hour, .minute], from: date)
                let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
                planner.startMinute = DayPlanBlock.clampedStartMinute(minute)
                planner.clampDurationForCurrentStart()
            }
        )
    }

    private var availableTasks: [RoutineTask] {
        if let focusedDate = activeFocusedUnplannedCompletedDate {
            return DayPlanTimelineTasks.tasks(
                on: focusedDate,
                from: tasks,
                logs: logs,
                plannedBlocks: planner.blocks(on: focusedDate, calendar: calendar, context: modelContext),
                calendar: calendar,
                hiddenActivityIDs: hiddenTimelineActivityIDs
            )
        }

        return DayPlanTaskSorting.availableTasks(from: tasks)
    }

    private var filteredTasks: [RoutineTask] {
        DayPlanTaskSorting.filteredTasks(from: availableTasks, query: planner.searchText)
    }

    private var activeFocusedUnplannedCompletedDate: Date? {
        showsTimelineTasksInDayPlanner ? nil : planner.focusedUnplannedCompletedDate
    }

    private var hiddenTimelineActivityIDs: Set<String> {
        DayPlanHiddenTimelineActivityStore.hiddenIDs(from: hiddenTimelineActivityStorage)
    }

    private var selectedTask: RoutineTask? {
        guard let selectedTaskID = planner.selectedTaskID else { return nil }
        return tasks.first { $0.id == selectedTaskID }
    }

    private var canCommitBlock: Bool {
        selectedTask != nil && planner.conflictingBlock == nil && sleepConflict == nil && awayConflict == nil
    }

    private var sleepConflict: DayPlanBlockedInterval? {
        planner.sleepConflict(
            in: DayPlanSleepBlocks.blockedIntervals(
                on: planner.selectedDate,
                from: sleepSessions,
                referenceDate: Date(),
                calendar: calendar
            ),
            startMinute: planner.startMinute,
            durationMinutes: planner.durationMinutes
        )
    }

    private var awayConflict: DayPlanBlockedInterval? {
        planner.sleepConflict(
            in: DayPlanAwayBlocks.blockedIntervals(
                on: planner.selectedDate,
                from: awaySessions,
                tasks: tasks,
                referenceDate: Date(),
                calendar: calendar
            ),
            startMinute: planner.startMinute,
            durationMinutes: planner.durationMinutes
        )
    }

    private var sidebarTitle: String {
        activeFocusedUnplannedCompletedDate == nil ? "Tasks" : "Timeline Activity"
    }

    private var emptyStateTitle: String {
        activeFocusedUnplannedCompletedDate == nil ? "No tasks found" : "All timeline activity is planned"
    }

    private var emptyStateDescription: String {
        activeFocusedUnplannedCompletedDate == nil
            ? "Create or search for a task to add it to the plan."
            : "Timeline tasks for this day are already placed in the planner."
    }
}

struct DayPlanDetailView: View {
    @Environment(\.calendar) private var calendar
    @ObservedObject var planner: DayPlanPlannerState
    var selectedTaskID: UUID? = nil
    var onSelectUnplannedCompletedDate: ((Date) -> Void)? = nil
    var onOpenTaskDetails: ((UUID) -> Void)? = nil
    @Query private var tasks: [RoutineTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DayPlanHeaderView(planner: planner)
            DayPlanTimelinePanelView(
                planner: planner,
                onSelectUnplannedCompletedDate: onSelectUnplannedCompletedDate,
                onOpenTaskDetails: onOpenTaskDetails
            )
        }
        .padding(20)
        .onAppear {
            syncSelectedTask()
        }
        .onChange(of: selectedTaskID) { _, _ in
            syncSelectedTask()
        }
        .onChange(of: tasks.map(\.id)) { _, _ in
            syncSelectedTask()
        }
    }

    private func syncSelectedTask() {
        guard
            let selectedTaskID,
            let task = tasks.first(where: { $0.id == selectedTaskID })
        else { return }

        if planner.selectedTaskID != selectedTaskID {
            planner.selectedBlockID = nil
        }
        planner.selectTask(task)
    }
}

private struct DayPlanHeaderView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var planner: DayPlanPlannerState

    var body: some View {
#if os(macOS)
        macHeader
#else
        compactHeader
#endif
    }

    private var macHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            todayButton

            rangeNavigationButtons

            VStack(alignment: .leading, spacing: 3) {
                Text(planner.visibleRangeTitle(calendar: calendar))
                    .font(.title2.weight(.semibold))

                Text("\(planner.blocks.count) blocks on selected day, \(DayPlanFormatting.durationText(planner.plannedMinutes)) planned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            visibleRangeModePicker
                .frame(width: 128)

            Spacer(minLength: 16)

            DatePicker("Selected day", selection: selectedDateBinding, displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                todayButton

                rangeNavigationButtons

                VStack(alignment: .leading, spacing: 3) {
                    Text(planner.visibleRangeTitle(calendar: calendar))
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)

                    Text("\(planner.blocks.count) blocks, \(DayPlanFormatting.durationText(planner.plannedMinutes)) planned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                DatePicker("Selected day", selection: selectedDateBinding, displayedComponents: [.date])
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }

            visibleRangeModePicker
        }
    }

    private var todayButton: some View {
        Button("Today") {
            planner.moveToToday(calendar: calendar, context: modelContext)
        }
        .buttonStyle(.bordered)
    }

    private var rangeNavigationButtons: some View {
        HStack(spacing: 4) {
            Button {
                planner.moveVisibleRange(by: -1, calendar: calendar, context: modelContext)
            } label: {
                Image(systemName: "chevron.left")
            }

            Button {
                planner.moveVisibleRange(by: 1, calendar: calendar, context: modelContext)
            } label: {
                Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(.plain)
        .font(.title3.weight(.medium))
    }

    private var visibleRangeModePicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Planner range",
            options: DayPlanVisibleRangeMode.allCases,
            selection: visibleRangeModeBinding
        ) { mode in
            Text(mode.title)
        }
        .accessibilityLabel("Planner range")
    }

    private var visibleRangeModeBinding: Binding<DayPlanVisibleRangeMode> {
        Binding(
            get: {
                planner.visibleRangeMode
            },
            set: { mode in
                planner.setVisibleRangeMode(mode, calendar: calendar, context: modelContext)
            }
        )
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: {
                planner.selectedDate
            },
            set: { date in
                planner.showDate(date, calendar: calendar, context: modelContext)
            }
        )
    }
}

private struct DayPlanTimelinePanelView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var planner: DayPlanPlannerState
    var onSelectUnplannedCompletedDate: ((Date) -> Void)? = nil
    var onOpenTaskDetails: ((UUID) -> Void)? = nil
    @Query private var tasks: [RoutineTask]
    @Query private var logs: [RoutineLog]
    @Query(sort: \SleepSession.startedAt, order: .reverse) private var sleepSessions: [SleepSession]
    @Query(sort: \AwaySession.startedAt, order: .reverse) private var awaySessions: [AwaySession]
    @Query(sort: \RoutineEvent.startedAt, order: .reverse) private var events: [RoutineEvent]
    @Query(sort: \SprintFocusSessionRecord.startedAt, order: .reverse) private var sprintFocusSessions: [SprintFocusSessionRecord]
    @Query private var sprintFocusAllocations: [SprintFocusAllocationRecord]
    @Query private var boardSprints: [BoardSprintRecord]
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var focusSessions: [FocusSession]
    @State private var selectedEventID: UUID?
    @State private var allocatingPlanFocusSession: DayPlanFocusAllocationPresentation?
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowTimelineTasksInDayPlanner.rawValue,
        store: SharedDefaults.app
    ) private var showsTimelineTasksInDayPlanner = true
    @AppStorage(
        UserDefaultStringValueKey.appSettingHiddenDayPlanTimelineActivityIDs.rawValue,
        store: SharedDefaults.app
    ) private var hiddenTimelineActivityStorage = ""

    var body: some View {
        let referenceDate = Date()
        let visibleDates = planner.visibleDates(calendar: calendar)
        let plannedBlocksByDayKey = plannedBlocksByDayKey(for: visibleDates)
        let hiddenTimelineActivityIDs = DayPlanHiddenTimelineActivityStore.hiddenIDs(from: hiddenTimelineActivityStorage)
        let sleepBlocksByDayKey = DayPlanSleepBlocks.blocksByDayKey(
            on: visibleDates,
            from: sleepSessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let awayBlocksByDayKey = DayPlanAwayBlocks.blocksByDayKey(
            on: visibleDates,
            from: awaySessions,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let completedSprintFocusSessions = sprintFocusSessions.filter { !$0.isActive }
        let activeSprintFocusSessions = sprintFocusSessions.filter(\.isActive)
        let sprintFocusBlocksByDayKey = DayPlanSprintFocusBlocks.blocksByDayKey(
            on: visibleDates,
            from: completedSprintFocusSessions,
            allocations: sprintFocusAllocations,
            sprints: boardSprints,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let activeSprintFocusBlocksByDayKey = DayPlanSprintFocusBlocks.blocksByDayKey(
            on: visibleDates,
            from: activeSprintFocusSessions,
            allocations: sprintFocusAllocations,
            sprints: boardSprints,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let eventBlocksByDayKey = DayPlanEventBlocks.blocksByDayKey(
            on: visibleDates,
            from: events,
            calendar: calendar
        )
        let blockedIntervalsByDayKey = mergeBlockedIntervals(
            mergeBlockedIntervals(
                sleepBlocksByDayKey.mapValues { blocks in blocks.map(\.interval) },
                awayBlocksByDayKey.mapValues { blocks in blocks.map(\.interval) }
            ),
            mergeBlockedIntervals(
                sprintFocusBlocksByDayKey.mapValues { blocks in blocks.map(\.interval) },
                activeSprintFocusBlocksByDayKey.mapValues { blocks in blocks.map(\.interval) }
            )
        )
        let rawAutomaticSuggestionBlocksByDayKey = DayPlanTimelineTasks.automaticSuggestionBlocksByDayKey(
            on: visibleDates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenTimelineActivityIDs
        )
        let linkedAwayBlocksByDayKey = DayPlanAwayBlocks.linkedBlocksByDayKey(
            awayBlocksByDayKey,
            timelineActivitiesByDayKey: rawAutomaticSuggestionBlocksByDayKey
        )
        let timelineBlocksByDayKey = DayPlanTimelineTasks.activityBlocksByDayKey(
            on: visibleDates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenTimelineActivityIDs
        )
        let automaticSuggestionBlocksByDayKey = DayPlanTimelineTasks.automaticSuggestionBlocksByDayKey(
            on: visibleDates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenTimelineActivityIDs
        )
        let allDayBlocks = DayPlanAllDayTasks.blocks(
            on: visibleDates,
            from: tasks,
            logs: logs,
            events: events,
            calendar: calendar
        )
        let selectedDayKey = DayPlanStorage.dayKey(for: planner.selectedDate, calendar: calendar)
        let selectedDayBlockedMinutes = blockedIntervalsByDayKey[selectedDayKey, default: []]
            .reduce(0) { $0 + $1.durationMinutes }
        let plannedBlocks = plannedBlocksByDayKey.values.flatMap { $0 }
        let tintsByTaskID = tintsByTaskID()

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(planner.visibleRangeMode.title)
                    .font(.headline)
                Spacer()
                Text("\(DayPlanFormatting.durationText(max(planner.unplannedMinutes - selectedDayBlockedMinutes, 0))) open on selected day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            DayPlanWeekCalendarView(
                dates: visibleDates,
                selectedBlockID: planner.selectedBlockID,
                selectedDate: planner.selectedDate,
                focusedUnplannedCompletedDate: activeFocusedUnplannedCompletedDate,
                focusedSleep: planner.focusedSleep,
                calendar: calendar,
                dropDurationMinutes: planner.durationMinutes,
                showsUnplannedCompletedBadges: !showsTimelineTasksInDayPlanner,
                blocksForDate: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return plannedBlocksByDayKey[dayKey] ?? []
                },
                automaticTimelineBlocksForDate: { date in
                    guard showsTimelineTasksInDayPlanner else { return [] }
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return automaticSuggestionBlocksByDayKey[dayKey] ?? []
                },
                eventBlocksForDate: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return eventBlocksByDayKey[dayKey] ?? []
                },
                sleepBlocksForDate: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return sleepBlocksByDayKey[dayKey] ?? []
                },
                awayBlocksForDate: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return linkedAwayBlocksByDayKey[dayKey] ?? []
                },
                sprintFocusBlocksForDate: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return sprintFocusBlocksByDayKey[dayKey] ?? []
                },
                blockedIntervalsForDate: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return blockedIntervalsByDayKey[dayKey] ?? []
                },
                activeFocusSessionBlocks: { now in
                    DayPlanFocusSessionBlocks.activeBlocks(
                        from: tasks,
                        sessions: focusSessions.filter { session in
                            guard session.isUnassigned else { return true }
                            let allocatedMinutes = DayPlanFocusSessionPlannerSync
                                .planFocusAllocationBlocks(for: session, context: modelContext)
                                .reduce(0) { $0 + $1.durationMinutes }
                            let elapsedMinutes = Int(floor(session.activeDurationSeconds(at: now) / 60))
                            return allocatedMinutes < elapsedMinutes
                        },
                        now: now,
                        calendar: calendar,
                        excluding: plannedBlocks
                    )
                },
                activeSprintFocusBlocks: { now in
                    DayPlanSprintFocusBlocks.blocksByDayKey(
                        on: visibleDates,
                        from: activeSprintFocusSessions,
                        allocations: sprintFocusAllocations,
                        sprints: boardSprints,
                        tasks: tasks,
                        referenceDate: now,
                        calendar: calendar
                    )
                    .values
                    .flatMap { $0 }
                },
                allDayBlocks: allDayBlocks,
                unplannedCompletedCount: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return timelineBlocksByDayKey[dayKey]?.count ?? 0
                },
                taskTint: { block in
                    if block.taskID == FocusSession.unassignedTaskID {
                        return .teal
                    }
                    return tintsByTaskID[block.taskID] ?? .accentColor
                },
                allDayTint: { block in
                    if block.isEvent {
                        return .teal
                    }
                    guard let taskID = block.taskID else {
                        return .accentColor
                    }
                    return tintsByTaskID[taskID] ?? .accentColor
                },
                onSelectUnplannedCompletedDate: { date in
                    planner.focusUnplannedCompletedTasks(on: date, calendar: calendar)
                    onSelectUnplannedCompletedDate?(date)
                },
                onSelectSlot: { date, minute in
                    planner.selectSlot(on: date, startMinute: minute, calendar: calendar, context: modelContext)
                },
                onSelectBlock: { block, date in
                    planner.edit(block, on: date, calendar: calendar, context: modelContext)
                },
                onOpenBlockDetails: { block, date in
                    planner.edit(block, on: date, calendar: calendar, context: modelContext)
                    onOpenTaskDetails?(block.taskID)
                },
                onOpenTimelineTaskDetails: { taskID in
                    if let task = tasks.first(where: { $0.id == taskID }) {
                        planner.selectedBlockID = nil
                        planner.selectTask(task)
                    }
                    onOpenTaskDetails?(taskID)
                },
                onOpenEventDetails: { eventID in
                    selectedEventID = eventID
                },
                onOpenFocusTaskDetails: { taskID in
                    if let task = tasks.first(where: { $0.id == taskID }) {
                        planner.selectedBlockID = nil
                        planner.selectTask(task)
                    }
                    onOpenTaskDetails?(taskID)
                },
                onOpenAllDayTaskDetails: { taskID in
                    if let task = tasks.first(where: { $0.id == taskID }) {
                        planner.selectedBlockID = nil
                        planner.selectTask(task)
                    }
                    onOpenTaskDetails?(taskID)
                },
                onDeleteBlock: { block in
                    planner.deleteBlock(block.id, calendar: calendar, context: modelContext)
                },
                onConfirmTimelineActivity: { activity, date in
                    guard !hasSleepConflict(
                        on: date,
                        startMinute: activity.block.startMinute,
                        durationMinutes: activity.block.durationMinutes,
                        blockedIntervalsByDayKey: blockedIntervalsByDayKey
                    ) else {
                        return
                    }
                    planner.confirmTimelineActivity(activity, on: date, calendar: calendar, context: modelContext)
                },
                onHideTimelineActivity: { activity, _ in
                    hideTimelineActivity(activity)
                },
                onMoveBlock: { blockID, date, minute in
                    let durationMinutes = plannedBlock(with: blockID)?.durationMinutes ?? planner.durationMinutes
                    guard !hasSleepConflict(
                        on: date,
                        startMinute: minute,
                        durationMinutes: durationMinutes,
                        blockedIntervalsByDayKey: blockedIntervalsByDayKey
                    ) else {
                        return
                    }
                    planner.moveBlock(blockID, to: date, startMinute: minute, calendar: calendar, context: modelContext)
                },
                onMoveTimelineActivity: { activity, date, minute in
                    guard !hasSleepConflict(
                        on: date,
                        startMinute: minute,
                        durationMinutes: activity.block.durationMinutes,
                        blockedIntervalsByDayKey: blockedIntervalsByDayKey
                    ) else {
                        return
                    }
                    moveTimelineActivity(activity, to: date, startMinute: minute)
                },
                onMoveBlockToAllDay: { blockID, date in
                    moveBlockToAllDay(blockID, on: date)
                },
                onMoveTimelineActivityToAllDay: { activity, date in
                    moveTimelineActivityToAllDay(activity, on: date)
                },
                onResizeBlock: { blockID, date, startMinute, durationMinutes in
                    guard !hasSleepConflict(
                        on: date,
                        startMinute: startMinute,
                        durationMinutes: durationMinutes,
                        blockedIntervalsByDayKey: blockedIntervalsByDayKey
                    ) else {
                        return
                    }
                    planner.resizeBlock(
                        blockID,
                        on: date,
                        startMinute: startMinute,
                        durationMinutes: durationMinutes,
                        calendar: calendar,
                        context: modelContext
                    )
                },
                onDropTask: { taskID, date, minute in
                    dropTask(
                        taskID,
                        on: date,
                        startMinute: minute,
                        blockedIntervalsByDayKey: blockedIntervalsByDayKey
                    )
                },
                onDropTaskToAllDay: { taskID, date in
                    dropTaskToAllDay(taskID, on: date)
                }
            )
        }
        .dayPlanLifecycle(planner: planner, tasks: tasks, sleepSessions: sleepSessions, awaySessions: awaySessions, calendar: calendar)
        .onChange(of: showsTimelineTasksInDayPlanner) { _, isEnabled in
            if isEnabled {
                planner.clearFocusedUnplannedCompletedTasks()
            }
        }
        .sheet(item: selectedEventPresentationBinding) { presentation in
            NavigationStack {
                DayPlanEventDetail(eventID: presentation.id)
            }
        }
        .sheet(item: $allocatingPlanFocusSession) { presentation in
            planFocusAllocationSheet(for: presentation.sessionID)
        }
    }

    @ViewBuilder
    private func planFocusBanner(hasActiveSprintFocus: Bool) -> some View {
        if let pendingPlanFocusSession, !planTodayTasks.isEmpty {
            pendingPlanFocusBanner(for: pendingPlanFocusSession)
        } else if activePlanFocusSession == nil, !planTodayTasks.isEmpty {
            planFocusStartBanner(hasActiveSprintFocus: hasActiveSprintFocus)
        }
    }

    private func planFocusStartBanner(hasActiveSprintFocus: Bool) -> some View {
        HStack(spacing: 10) {
            Label("Plan Focus", systemImage: "stopwatch")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Text("\(planTodayTasks.count) planned")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            planFocusStartMenu
                .disabled(activeTaskFocusSession != nil || hasActiveSprintFocus)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .routinaGlassCard(cornerRadius: 8, tint: .orange, tintOpacity: 0.07)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.orange.opacity(0.20), lineWidth: 1)
        }
    }

    private func activePlanFocusBanner(for session: FocusSession) -> some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
            let isCountUp = session.plannedDurationSeconds <= 0
            let elapsedSeconds = session.activeDurationSeconds(at: context.date)
            let displaySeconds = isCountUp
                ? elapsedSeconds
                : max(0, session.plannedDurationSeconds - elapsedSeconds)
            let statusText = session.isPaused
                ? "paused"
                : (isCountUp ? "elapsed" : "remaining")

            HStack(spacing: 10) {
                Label("Plan Focus", systemImage: "stopwatch.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)

                Text(FocusSessionFormatting.durationText(seconds: displaySeconds))
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
                    .transaction { transaction in
                        transaction.animation = nil
                    }

                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Button {
                    if session.isPaused {
                        resumePlanFocus(session)
                    } else {
                        pausePlanFocus(session)
                    }
                } label: {
                    Label(session.isPaused ? "Resume" : "Pause", systemImage: session.isPaused ? "play.fill" : "pause.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    allocatingPlanFocusSession = DayPlanFocusAllocationPresentation(sessionID: session.id)
                } label: {
                    Label("Allocate", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    finishPlanFocus(session)
                } label: {
                    Label("Finish", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .controlSize(.small)

                Menu {
                    Button(role: .destructive) {
                        abandonPlanFocus(session)
                    } label: {
                        Label("Abandon", systemImage: "xmark.circle")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                }
                .menuStyle(.button)
                .controlSize(.small)
                .accessibilityLabel("More plan focus actions")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .routinaGlassCard(cornerRadius: 8, tint: .orange, tintOpacity: 0.10)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.orange.opacity(0.24), lineWidth: 1)
            }
        }
    }

    private func pendingPlanFocusBanner(for session: FocusSession) -> some View {
        HStack(spacing: 10) {
            Label("Plan Focus", systemImage: "tray.full")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Text("\(FocusSessionFormatting.compactDurationText(seconds: session.actualDurationSeconds)) ready to allocate")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Button {
                allocatingPlanFocusSession = DayPlanFocusAllocationPresentation(sessionID: session.id)
            } label: {
                Label("Allocate", systemImage: "arrowshape.turn.up.right")
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .routinaGlassCard(cornerRadius: 8, tint: .orange, tintOpacity: 0.08)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.orange.opacity(0.22), lineWidth: 1)
        }
    }

    private var planFocusStartMenu: some View {
        Menu {
            Button {
                startPlanFocus(duration: 0)
            } label: {
                Label("Count up", systemImage: "stopwatch")
            }

            Divider()

            ForEach(planFocusDurationOptions, id: \.self) { duration in
                Button(FocusSessionFormatting.compactDurationText(seconds: duration)) {
                    startPlanFocus(duration: duration)
                }
            }
        } label: {
            Label("Start", systemImage: "play.fill")
        }
        .menuStyle(.button)
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .controlSize(.small)
    }

    @ViewBuilder
    private func planFocusAllocationSheet(for sessionID: UUID) -> some View {
        if let session = focusSessions.first(where: { session in
            session.id == sessionID
                && session.isUnassigned
                && session.abandonedAt == nil
        }) {
            DayPlanFocusAllocationSheet(
                session: session,
                planTodayTasks: planTodayTasks,
                existingBlocks: DayPlanFocusSessionPlannerSync.planFocusAllocationBlocks(
                    for: session,
                    context: modelContext
                ),
                onSave: { allocations in
                    savePlanFocusAllocations(session, allocations: allocations)
                }
            )
        } else {
            ContentUnavailableView("Focus allocated", systemImage: "checkmark.circle")
                .padding()
        }
    }

    private var selectedEventPresentationBinding: Binding<DayPlanEventPresentation?> {
        Binding(
            get: {
                selectedEventID.map(DayPlanEventPresentation.init(id:))
            },
            set: { presentation in
                selectedEventID = presentation?.id
            }
        )
    }

    private var activeFocusedUnplannedCompletedDate: Date? {
        showsTimelineTasksInDayPlanner ? nil : planner.focusedUnplannedCompletedDate
    }

    private var activeFocusSessions: [FocusSession] {
        focusSessions
            .filter { $0.completedAt == nil && $0.abandonedAt == nil }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
    }

    private var activePlanFocusSession: FocusSession? {
        activeFocusSessions.first(where: \.isUnassigned)
    }

    private var activeTaskFocusSession: FocusSession? {
        activeFocusSessions.first { !$0.isUnassigned }
    }

    private var pendingPlanFocusSession: FocusSession? {
        FocusSessionSupport.unassignedCompletedSessions(from: focusSessions)
            .first { session in
                guard let startedAt = session.startedAt else { return false }
                return calendar.isDate(startedAt, inSameDayAs: Date())
                    && !DayPlanFocusSessionPlannerSync.hasPlanFocusAllocations(
                        for: session,
                        context: modelContext
                    )
            }
    }

    private var planTodayTasks: [RoutineTask] {
        let referenceDate = Date()
        return tasks
            .filter { task in
                guard !task.isArchived(referenceDate: referenceDate, calendar: calendar),
                      !task.isCompletedOneOff,
                      !task.isCanceledOneOff,
                      !task.isPinned else {
                    return false
                }

                if task.isDailyRoutineForTaskList {
                    return true
                }

                guard let plannedDate = task.plannedDate else { return false }
                return calendar.isDate(plannedDate, inSameDayAs: referenceDate)
            }
            .sorted(by: planTodayTaskSort)
    }

    private var planFocusDurationOptions: [TimeInterval] {
        [
            15 * 60,
            25 * 60,
            45 * 60,
            60 * 60,
            90 * 60,
        ]
    }

    private func planTodayTaskSort(_ lhs: RoutineTask, _ rhs: RoutineTask) -> Bool {
        let lhsIsDaily = lhs.isDailyRoutineForTaskList
        let rhsIsDaily = rhs.isDailyRoutineForTaskList
        if lhsIsDaily != rhsIsDaily {
            return !lhsIsDaily && rhsIsDaily
        }

        let sectionKey = lhsIsDaily ? "daily" : "plannedToday"
        let lhsOrder = lhs.manualSectionOrders[sectionKey] ?? Int.max
        let rhsOrder = rhs.manualSectionOrders[sectionKey] ?? Int.max
        if lhsOrder != rhsOrder {
            return lhsOrder < rhsOrder
        }

        return DayPlanTaskSorting.title(for: lhs).localizedCaseInsensitiveCompare(
            DayPlanTaskSorting.title(for: rhs)
        ) == .orderedAscending
    }

    private func startPlanFocus(duration: TimeInterval) {
        do {
            _ = try FocusSessionSupport.startUnassignedFocus(
                plannedDurationSeconds: duration,
                context: modelContext
            )
        } catch {
            NSLog("Failed to start plan focus: \(error.localizedDescription)")
        }
    }

    private func pausePlanFocus(_ session: FocusSession) {
        do {
            _ = try FocusSessionSupport.pauseFocus(
                sessionID: session.id,
                kind: .unassigned,
                context: modelContext
            )
        } catch {
            NSLog("Failed to pause plan focus: \(error.localizedDescription)")
        }
    }

    private func resumePlanFocus(_ session: FocusSession) {
        do {
            _ = try FocusSessionSupport.resumeFocus(
                sessionID: session.id,
                kind: .unassigned,
                context: modelContext
            )
        } catch {
            NSLog("Failed to resume plan focus: \(error.localizedDescription)")
        }
    }

    private func finishPlanFocus(_ session: FocusSession) {
        do {
            _ = try FocusSessionSupport.finishFocus(
                sessionID: session.id,
                kind: .unassigned,
                context: modelContext,
                calendar: calendar
            )
        } catch {
            NSLog("Failed to finish plan focus: \(error.localizedDescription)")
        }
    }

    private func abandonPlanFocus(_ session: FocusSession) {
        do {
            _ = try FocusSessionSupport.abandonFocus(
                sessionID: session.id,
                kind: .unassigned,
                context: modelContext
            )
        } catch {
            NSLog("Failed to abandon plan focus: \(error.localizedDescription)")
        }
    }

    private func savePlanFocusAllocations(
        _ session: FocusSession,
        allocations: [DayPlanFocusTaskAllocation]
    ) {
        let didSave = DayPlanFocusSessionPlannerSync.savePlanFocusAllocations(
            for: session,
            allocations: allocations,
            tasks: planTodayTasks,
            calendar: calendar,
            context: modelContext
        )
        if didSave {
            planner.loadBlocks(calendar: calendar, context: modelContext)
            allocatingPlanFocusSession = nil
        }
    }

    private func plannedBlocksByDayKey(for dates: [Date]) -> [String: [DayPlanBlock]] {
        Dictionary(
            uniqueKeysWithValues: dates.map { date in
                let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                return (
                    dayKey,
                    planner.blocks(on: date, calendar: calendar, context: modelContext)
                )
            }
        )
    }

    private func mergeBlockedIntervals(
        _ lhs: [String: [DayPlanBlockedInterval]],
        _ rhs: [String: [DayPlanBlockedInterval]]
    ) -> [String: [DayPlanBlockedInterval]] {
        var result = lhs
        for (dayKey, intervals) in rhs {
            result[dayKey, default: []].append(contentsOf: intervals)
        }
        return result
    }

    private func tintsByTaskID() -> [UUID: Color] {
        var result: [UUID: Color] = [:]
        for task in tasks {
            result[task.id] = task.color.swiftUIColor ?? .accentColor
        }
        return result
    }

    private func moveBlockToAllDay(_ blockID: DayPlanBlock.ID, on date: Date) {
        guard let block = plannedBlock(with: blockID),
              makeTaskAllDay(block.taskID, on: date) else {
            return
        }

        planner.deleteBlock(blockID, calendar: calendar, context: modelContext)
    }

    private func moveTimelineActivityToAllDay(_ activity: DayPlanTimelineActivityBlock, on date: Date) {
        if !calendar.isDate(activity.block.updatedAt, inSameDayAs: date) {
            moveTimelineActivity(activity, to: date, startMinute: 0)
        }
        _ = makeTaskAllDay(activity.block.taskID, on: date)
    }

    private func moveTimelineActivity(
        _ activity: DayPlanTimelineActivityBlock,
        to date: Date,
        startMinute: Int
    ) {
        _ = DayPlanTimelineTasks.moveActivity(
            activity,
            to: date,
            startMinute: startMinute,
            tasks: tasks,
            logs: logs,
            context: modelContext,
            calendar: calendar
        )
    }

    private func dropTaskToAllDay(_ taskID: UUID, on date: Date) {
        guard makeTaskAllDay(taskID, on: date) else { return }
        if let task = tasks.first(where: { $0.id == taskID }) {
            planner.selectedBlockID = nil
            planner.selectTask(task)
        }
    }

    @discardableResult
    private func makeTaskAllDay(_ taskID: UUID, on date: Date) -> Bool {
        let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext)
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate<RoutineTask> { task in
                task.id == taskID
            }
        )

        do {
            guard let task = try context.fetch(descriptor).first else { return false }
            task.isAllDay = true
            if task.isOneOffTask {
                task.deadline = calendar.startOfDay(for: date)
            }
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
            return true
        } catch {
            NSLog("Failed to move task to all-day planner lane: \(error.localizedDescription)")
            return false
        }
    }

    private func hideTimelineActivity(_ activity: DayPlanTimelineActivityBlock) {
        let updatedStorage = DayPlanHiddenTimelineActivityStore.storageString(
            afterHiding: activity,
            in: hiddenTimelineActivityStorage
        )
        hiddenTimelineActivityStorage = updatedStorage
        CloudSettingsKeyValueSync.setString(
            updatedStorage.isEmpty ? nil : updatedStorage,
            for: .appSettingHiddenDayPlanTimelineActivityIDs
        )
    }

    private func dropTask(
        _ taskID: UUID,
        on date: Date,
        startMinute: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        let durationMinutes = task.estimatedDurationMinutes ?? planner.durationMinutes
        guard !hasSleepConflict(
            on: date,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey
        ) else {
            return
        }

        planner.selectSlot(on: date, startMinute: startMinute, calendar: calendar, context: modelContext)
        planner.selectTask(task)
        planner.commitBlock(task: task, calendar: calendar, context: modelContext)
    }

    private func hasSleepConflict(
        on date: Date,
        startMinute: Int,
        durationMinutes: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) -> Bool {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        guard let intervals = blockedIntervalsByDayKey[dayKey] else { return false }
        return intervals.contains {
            $0.overlaps(startMinute: startMinute, durationMinutes: durationMinutes)
        }
    }

    private func plannedBlock(with id: DayPlanBlock.ID) -> DayPlanBlock? {
        planner.weekBlocksByDayKey.values.lazy.compactMap { blocks in
            blocks.first { $0.id == id }
        }
        .first
            ?? planner.blocks.first { $0.id == id }
    }
}

private struct DayPlanEventPresentation: Identifiable {
    let id: UUID
}

private struct DayPlanFocusAllocationPresentation: Identifiable {
    let sessionID: UUID

    var id: UUID { sessionID }
}

private struct DayPlanFocusAllocationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let session: FocusSession
    let planTodayTasks: [RoutineTask]
    let existingBlocks: [DayPlanBlock]
    let onSave: ([DayPlanFocusTaskAllocation]) -> Void
    @State private var draftMinutesByTaskID: [UUID: Int]

    init(
        session: FocusSession,
        planTodayTasks: [RoutineTask],
        existingBlocks: [DayPlanBlock],
        onSave: @escaping ([DayPlanFocusTaskAllocation]) -> Void
    ) {
        self.session = session
        self.planTodayTasks = planTodayTasks
        self.existingBlocks = existingBlocks
        self.onSave = onSave
        _draftMinutesByTaskID = State(initialValue: Dictionary(
            uniqueKeysWithValues: existingBlocks.map { ($0.taskID, max(0, $0.durationMinutes)) }
        ))
    }

    var body: some View {
        NavigationStack {
            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                let availableMinutes = allocatableMinutes(at: context.date)

                List {
                    Section {
                        HStack {
                            Label(session.state == .completed ? "Recorded" : "Available", systemImage: "stopwatch")
                            Spacer()
                            Text(DayPlanFormatting.durationText(availableMinutes))
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Label("Allocated", systemImage: "slider.horizontal.3")
                            Spacer()
                            Text("\(DayPlanFormatting.durationText(totalDraftMinutes)) of \(DayPlanFormatting.durationText(availableMinutes))")
                                .foregroundStyle(totalDraftMinutes > availableMinutes ? .red : .secondary)
                        }
                    }

                    Section("Plan to do today") {
                        if planTodayTasks.isEmpty {
                            ContentUnavailableView("No planned tasks", systemImage: "tray")
                        } else {
                            ForEach(planTodayTasks) { task in
                                allocationRow(task, availableMinutes: availableMinutes)
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(allocations)
                            dismiss()
                        }
                        .disabled(totalDraftMinutes <= 0 || totalDraftMinutes > availableMinutes)
                    }
                }
            }
            .navigationTitle("Allocate Plan Focus")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #if os(macOS)
        .frame(width: 480, height: 460)
        #else
        .presentationDetents([.medium, .large])
        #endif
    }

    private var totalDraftMinutes: Int {
        draftMinutesByTaskID.values.reduce(0) { $0 + max(0, $1) }
    }

    private var allocations: [DayPlanFocusTaskAllocation] {
        planTodayTasks.compactMap { task in
            let minutes = max(0, draftMinutesByTaskID[task.id] ?? 0)
            guard minutes > 0 else { return nil }
            return DayPlanFocusTaskAllocation(taskID: task.id, minutes: minutes)
        }
    }

    private func allocationRow(_ task: RoutineTask, availableMinutes: Int) -> some View {
        let taskMinutes = draftMinutesByTaskID[task.id] ?? 0
        let otherMinutes = totalDraftMinutes - taskMinutes
        let upperBound = max(0, availableMinutes - otherMinutes)

        return Stepper(
            value: allocationBinding(for: task.id, upperBound: upperBound),
            in: 0...upperBound,
            step: 1
        ) {
            HStack(spacing: 10) {
                Text(CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "*")
                Text(DayPlanTaskSorting.title(for: task))
                    .foregroundStyle(.primary)
                Spacer()
                Text(DayPlanFormatting.durationText(taskMinutes))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func allocationBinding(for taskID: UUID, upperBound: Int) -> Binding<Int> {
        Binding(
            get: {
                min(max(0, draftMinutesByTaskID[taskID] ?? 0), upperBound)
            },
            set: { value in
                draftMinutesByTaskID[taskID] = min(max(0, value), upperBound)
            }
        )
    }

    private func allocatableMinutes(at date: Date) -> Int {
        let seconds: TimeInterval
        if let completedAt = session.completedAt {
            seconds = session.activeDurationSeconds(at: completedAt)
        } else {
            seconds = session.activeDurationSeconds(at: date)
        }
        return max(0, Int(floor(seconds / 60)))
    }
}

private struct DayPlanEventDetail: View {
    let eventID: UUID
    @Query(sort: \RoutineEvent.startedAt, order: .reverse) private var events: [RoutineEvent]

    var body: some View {
        if let event = events.first(where: { $0.id == eventID }) {
            RoutineEventDetailView(event: event)
        } else {
            ContentUnavailableView(
                "Event not found",
                systemImage: "calendar",
                description: Text("The selected event is no longer available.")
            )
        }
    }
}

private struct DayPlanLifecycleModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var planner: DayPlanPlannerState
    var tasks: [RoutineTask]
    var sleepSessions: [SleepSession]
    var awaySessions: [AwaySession]
    var calendar: Calendar

    func body(content: Content) -> some View {
        content
            .onAppear {
                planner.loadBlocks(calendar: calendar, context: modelContext)
                showExactTimedTasks()
                planner.selectDefaultTaskIfNeeded(from: tasks)
            }
            .onChange(of: planner.selectedDate) { _, _ in
                planner.handleSelectedDateChanged(calendar: calendar, context: modelContext)
                showExactTimedTasks()
            }
            .onChange(of: planner.visibleRangeMode) { _, _ in
                planner.loadBlocks(calendar: calendar, context: modelContext)
                showExactTimedTasks()
            }
            .onChange(of: tasks.map(\.id)) { _, _ in
                showExactTimedTasks()
                planner.selectDefaultTaskIfNeeded(from: tasks)
            }
            .onChange(of: sleepSessionChangeToken) { _, _ in
                showExactTimedTasks()
            }
            .onChange(of: awaySessionChangeToken) { _, _ in
                showExactTimedTasks()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    planner.loadBlocks(calendar: calendar, context: modelContext)
                    showExactTimedTasks()
                }
            }
    }

    private var sleepSessionChangeToken: [String] {
        sleepSessions.map { session in
            [
                session.id.uuidString,
                session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.endedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: ":")
        }
    }

    private var awaySessionChangeToken: [String] {
        awaySessions.map { session in
            [
                session.id.uuidString,
                session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.finishedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.plannedDurationSeconds.description,
                session.plannedEndAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.linkedTaskID?.uuidString ?? "",
                session.title,
                session.presetRawValue,
            ].joined(separator: ":")
        }
    }

    private func showExactTimedTasks() {
        let dates = planner.visibleAndSelectedDates(calendar: calendar)
        var blockedIntervalsByDayKey = DayPlanSleepBlocks.blockedIntervalsByDayKey(
            on: dates,
            from: sleepSessions,
            referenceDate: Date(),
            calendar: calendar
        )
        let awayBlockedIntervalsByDayKey = DayPlanAwayBlocks.blockedIntervalsByDayKey(
            on: dates,
            from: awaySessions,
            tasks: tasks,
            referenceDate: Date(),
            calendar: calendar
        )
        for (dayKey, intervals) in awayBlockedIntervalsByDayKey {
            blockedIntervalsByDayKey[dayKey, default: []].append(contentsOf: intervals)
        }
        planner.showExactTimedTasks(
            from: tasks,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            context: modelContext
        )
    }
}

private extension View {
    func dayPlanLifecycle(
        planner: DayPlanPlannerState,
        tasks: [RoutineTask],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        calendar: Calendar
    ) -> some View {
        modifier(
            DayPlanLifecycleModifier(
                planner: planner,
                tasks: tasks,
                sleepSessions: sleepSessions,
                awaySessions: awaySessions,
                calendar: calendar
            )
        )
    }
}

private struct DayPlanTaskCandidateRow: View {
    var task: RoutineTask
    var title: String
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 10) {
                DayPlanTaskAvatar(emoji: task.emoji, tint: task.color.swiftUIColor ?? .accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if task.isPinned {
                            Label("Pinned", systemImage: "pin.fill")
                        }
                        if let estimatedDurationMinutes = task.estimatedDurationMinutes {
                            Label(DayPlanFormatting.durationText(estimatedDurationMinutes), systemImage: "timer")
                        }
                        Text(task.isOneOffTask ? "Task" : "Routine")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding(10)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .onDrag {
            NSItemProvider(object: task.id.uuidString as NSString)
        }
    }
}
