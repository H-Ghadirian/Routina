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
                in: DayPlanBlock.minimumDurationMinutes...planner.maximumDurationForStart,
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
        HStack(alignment: .center, spacing: 12) {
            Button("Today") {
                planner.moveToToday(calendar: calendar, context: modelContext)
            }
            .buttonStyle(.bordered)

            HStack(spacing: 4) {
                Button {
                    planner.moveWeek(by: -1, calendar: calendar, context: modelContext)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Button {
                    planner.moveWeek(by: 1, calendar: calendar, context: modelContext)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)
            .font(.title3.weight(.medium))

            VStack(alignment: .leading, spacing: 3) {
                Text(planner.weekTitle(calendar: calendar))
                    .font(.title2.weight(.semibold))

                Text("\(planner.blocks.count) blocks on selected day, \(DayPlanFormatting.durationText(planner.plannedMinutes)) planned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            DatePicker("Selected day", selection: selectedDateBinding, displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
        }
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
    @Query(
        filter: #Predicate<FocusSession> { session in
            session.completedAt == nil && session.abandonedAt == nil
        },
        sort: \FocusSession.startedAt,
        order: .reverse
    ) private var activeFocusSessions: [FocusSession]
    @State private var selectedEventID: UUID?
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
        let weekDates = planner.weekDates(calendar: calendar)
        let plannedBlocksByDayKey = plannedBlocksByDayKey(for: weekDates)
        let hiddenTimelineActivityIDs = DayPlanHiddenTimelineActivityStore.hiddenIDs(from: hiddenTimelineActivityStorage)
        let timelineBlocksByDayKey = DayPlanTimelineTasks.activityBlocksByDayKey(
            on: weekDates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenTimelineActivityIDs
        )
        let automaticSuggestionBlocksByDayKey = DayPlanTimelineTasks.automaticSuggestionBlocksByDayKey(
            on: weekDates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenTimelineActivityIDs
        )
        let sleepBlocksByDayKey = DayPlanSleepBlocks.blocksByDayKey(
            on: weekDates,
            from: sleepSessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let awayBlocksByDayKey = DayPlanAwayBlocks.blocksByDayKey(
            on: weekDates,
            from: awaySessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let eventBlocksByDayKey = DayPlanEventBlocks.blocksByDayKey(
            on: weekDates,
            from: events,
            calendar: calendar
        )
        let blockedIntervalsByDayKey = mergeBlockedIntervals(
            sleepBlocksByDayKey.mapValues { blocks in blocks.map(\.interval) },
            awayBlocksByDayKey.mapValues { blocks in blocks.map(\.interval) }
        )
        let allDayBlocks = DayPlanAllDayTasks.blocks(
            on: weekDates,
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
                Text("Day")
                    .font(.headline)
                Spacer()
                Text("\(DayPlanFormatting.durationText(max(planner.unplannedMinutes - selectedDayBlockedMinutes, 0))) open on selected day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            DayPlanWeekCalendarView(
                dates: weekDates,
                selectedBlockID: planner.selectedBlockID,
                selectedDate: planner.selectedDate,
                focusedUnplannedCompletedDate: activeFocusedUnplannedCompletedDate,
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
                    return awayBlocksByDayKey[dayKey] ?? []
                },
                blockedIntervalsForDate: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return blockedIntervalsByDayKey[dayKey] ?? []
                },
                activeFocusSessionBlocks: { now in
                    DayPlanFocusSessionBlocks.activeBlocks(
                        from: tasks,
                        sessions: activeFocusSessions,
                        now: now,
                        calendar: calendar,
                        excluding: plannedBlocks
                    )
                },
                allDayBlocks: allDayBlocks,
                unplannedCompletedCount: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return timelineBlocksByDayKey[dayKey]?.count ?? 0
                },
                taskTint: { block in
                    tintsByTaskID[block.taskID] ?? .accentColor
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
                session.plannedEndAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: ":")
        }
    }

    private func showExactTimedTasks() {
        let dates = planner.weekDates(calendar: calendar) + [planner.selectedDate]
        var blockedIntervalsByDayKey = DayPlanSleepBlocks.blockedIntervalsByDayKey(
            on: dates,
            from: sleepSessions,
            referenceDate: Date(),
            calendar: calendar
        )
        let awayBlockedIntervalsByDayKey = DayPlanAwayBlocks.blockedIntervalsByDayKey(
            on: dates,
            from: awaySessions,
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
