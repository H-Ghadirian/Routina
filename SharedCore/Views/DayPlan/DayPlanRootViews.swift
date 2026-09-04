import SwiftData
import SwiftUI

struct DayPlanView: View {
    @StateObject private var planner = DayPlanPlannerState()
    @State private var isDatePickerSidebarPresented = false
    @State private var calendarTaskViewMode: DayPlanCalendarTaskViewMode = .schedule

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
            VStack(alignment: .leading, spacing: 16) {
                DayPlanHeaderView(
                    planner: planner,
                    isDatePickerSidebarPresented: $isDatePickerSidebarPresented,
                    calendarTaskViewMode: $calendarTaskViewMode
                )

                HSplitView {
                    DayPlanSidebarView(planner: planner)
                        .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)

                    DayPlanTimelinePanelView(
                        planner: planner,
                        calendarTaskViewMode: calendarTaskViewMode,
                        isDatePickerSidebarPresented: $isDatePickerSidebarPresented
                    )
                    .frame(minWidth: 520)
                }
            }
            .padding(DayPlanWeekCalendarSizing.detailPadding)
        #else
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    DayPlanHeaderView(
                        planner: planner,
                        isDatePickerSidebarPresented: $isDatePickerSidebarPresented,
                        calendarTaskViewMode: $calendarTaskViewMode
                    )
                    .padding(.horizontal)
                    .padding(.top)

                    DayPlanSidebarView(planner: planner)
                        .frame(maxHeight: 320)
                        .padding(.horizontal)

                    DayPlanTimelinePanelView(
                        planner: planner,
                        calendarTaskViewMode: calendarTaskViewMode,
                        isDatePickerSidebarPresented: $isDatePickerSidebarPresented
                    )
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
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var focusSessions: [FocusSession]
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
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false

    var body: some View {
        taskPanel
    }

    private var visibleAwaySessions: [AwaySession] {
        isAwayEnabled ? awaySessions : []
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

            Text(
                "Ends \(DayPlanFormatting.timeText(for: planner.startMinute + planner.durationMinutes, on: planner.selectedDate, calendar: calendar))"
            )
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
                plannedBlocks: visiblePlannedBlocks(on: focusedDate),
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

    private func visiblePlannedBlocks(on date: Date) -> [DayPlanBlock] {
        DayPlanVisibleBlocks.blocks(
            planner.blocks(on: date, calendar: calendar, context: modelContext),
            tasks: tasks,
            logs: logs,
            calendar: calendar,
            activeFocusSessions: activeTaskAndTagFocusSessions
        )
    }

    private var activeTaskAndTagFocusSessions: [FocusSession] {
        focusSessions.filter { session in
            (session.isTaskFocus || session.isTagFocus)
                && session.startedAt != nil
                && session.completedAt == nil
                && session.abandonedAt == nil
        }
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
