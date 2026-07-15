import SwiftData
#if os(macOS)
import AppKit
#endif
import SwiftUI

#if os(macOS)
@MainActor
enum RoutinaMacScrollInteractionGate {
    private static let quietWindowMilliseconds: Int64 = 1_200
    private static var eventMonitor: Any?
    private static var lastScrollEventAt = Date.distantPast

    static func start() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            lastScrollEventAt = Date()
            return event
        }
    }

    static var isScrollActive: Bool {
        start()
        return Date().timeIntervalSince(lastScrollEventAt) < quietWindow
    }

    static var quietRetryDelayMilliseconds: Int64 {
        start()
        let elapsedMilliseconds = Int64((Date().timeIntervalSince(lastScrollEventAt) * 1_000).rounded(.down))
        return max(120, quietWindowMilliseconds - elapsedMilliseconds)
    }

    private static var quietWindow: TimeInterval {
        TimeInterval(quietWindowMilliseconds) / 1_000
    }
}
#endif

struct DayPlanTimelineDateJumpRequest: Equatable, Identifiable {
    let id = UUID()
    let date: Date
}

enum DayPlanTimelineDateJumpTarget {
    static func matchingSectionDate(
        for requestedDate: Date?,
        in sectionDates: [Date],
        calendar: Calendar
    ) -> Date? {
        guard let requestedDate else { return nil }
        let requestedDay = calendar.startOfDay(for: requestedDate)
        return sectionDates.first { sectionDate in
            calendar.isDate(sectionDate, inSameDayAs: requestedDay)
        }
    }
}

enum DayPlanSidebarDateAvailability {
    static func dayStarts(for activityDates: [Date], calendar: Calendar) -> Set<Date> {
        Set(activityDates.map { calendar.startOfDay(for: $0) })
    }

    static func contains(_ date: Date, in activityDayStarts: Set<Date>, calendar: Calendar) -> Bool {
        activityDayStarts.contains(calendar.startOfDay(for: date))
    }
}

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
            .dayPlanLifecycle(
                planner: planner,
                tasks: tasks,
                sleepSessions: sleepSessions,
                awaySessions: visibleAwaySessions,
                focusSessions: focusSessions,
                calendar: calendar
            )
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

private struct DayPlanSelectedTaskSyncToken: Equatable {
    var id: UUID?
    var estimatedDurationMinutes: Int?

    init(task: RoutineTask?) {
        id = task?.id
        estimatedDurationMinutes = task?.estimatedDurationMinutes
    }
}

struct DayPlanDetailView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var planner: DayPlanPlannerState
    var selectedTaskID: UUID? = nil
    var selectedTask: RoutineTask? = nil
    var isTaskDetailInspectorPresented = false
    var macHeaderAvailableWidth: CGFloat? = nil
    var displayMode: Binding<DayPlanDisplayMode> = .constant(.calendar)
    var calendarTaskViewMode: Binding<DayPlanCalendarTaskViewMode> = .constant(.schedule)
    var calendarFilters: Binding<DayPlanCalendarFilterState> = .constant(DayPlanCalendarFilterState())
    var isCalendarFilterDetailPresented = false
    var listFilterButtonIsActive = false
    var listFilterButtonAccessibilityValue: String? = nil
    var calendarSearchText = ""
    var calendarTaskFilter: (RoutineTask) -> Bool = { _ in true }
    var calendarTaskFilterCacheSeed = 0
    var macHeaderFocusControl: (() -> AnyView)? = nil
    var listContent: ((DayPlanTimelineDateJumpRequest?) -> AnyView)? = nil
    var timelineActivityDates: [Date] = []
    var onSelectUnplannedCompletedDate: ((Date) -> Void)? = nil
    var onOpenTaskDetails: ((UUID) -> Void)? = nil
    var onOpenEventDetails: ((UUID) -> Void)? = nil
    var onCalendarFilterButtonPressed: (() -> Void)? = nil
    var onPlannerSidebarPresentationRequested: (() -> Void)? = nil
    @State private var isCalendarFilterSidebarPresented = false
    @State private var isDatePickerSidebarPresented = false
    @State private var timelineDateJumpRequest: DayPlanTimelineDateJumpRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DayPlanHeaderView(
                planner: planner,
                calendarFilters: calendarFilters.wrappedValue,
                isCalendarFilterSidebarPresented: $isCalendarFilterSidebarPresented,
                isDatePickerSidebarPresented: $isDatePickerSidebarPresented,
                isCalendarFilterDetailPresented: isCalendarFilterDetailPresented,
                showsCalendarFilterButton: true,
                displayMode: displayMode,
                calendarTaskViewMode: calendarTaskViewMode,
                showsDisplayModePicker: listContent != nil,
                isTaskDetailInspectorPresented: isTaskDetailInspectorPresented,
                parentAvailableWidth: macHeaderAvailableWidth,
                listFilterButtonIsActive: listFilterButtonIsActive,
                listFilterButtonAccessibilityValue: listFilterButtonAccessibilityValue,
                macFocusControl: macHeaderFocusControl,
                onCalendarFilterButtonPressed: onCalendarFilterButtonPressed
            )

            if displayMode.wrappedValue == .list, let listContent {
                plannerListContent(listContent)
            } else {
                DayPlanTimelinePanelView(
                    planner: planner,
                    onSelectUnplannedCompletedDate: onSelectUnplannedCompletedDate,
                    onOpenTaskDetails: onOpenTaskDetails,
                    onOpenEventDetails: onOpenEventDetails,
                    calendarFilters: calendarFilters,
                    calendarSearchText: calendarSearchText,
                    calendarTaskFilter: calendarTaskFilter,
                    calendarTaskFilterCacheSeed: calendarTaskFilterCacheSeed,
                    calendarTaskViewMode: calendarTaskViewMode.wrappedValue,
                    isCalendarFilterSidebarPresented: $isCalendarFilterSidebarPresented,
                    isDatePickerSidebarPresented: $isDatePickerSidebarPresented,
                    isExternalInspectorPresented: isTaskDetailInspectorPresented,
                    onSidebarPresentationRequested: {
                        onPlannerSidebarPresentationRequested?()
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            syncSelectedTask()
        }
        .onChange(of: selectedTaskID) { _, _ in
            syncSelectedTask()
        }
        .onChange(of: selectedTaskSyncToken) { _, _ in
            syncSelectedTask()
        }
        .onChange(of: isTaskDetailInspectorPresented) { _, isPresented in
            guard isPresented else { return }
            dismissPlannerSidebars()
        }
        .onChange(of: displayMode.wrappedValue) { _, mode in
            if mode == .list {
                isCalendarFilterSidebarPresented = false
            }
        }
        .onChange(of: isCalendarFilterSidebarPresented) { _, isPresented in
            guard isPresented else { return }
            onPlannerSidebarPresentationRequested?()
        }
        .onChange(of: isDatePickerSidebarPresented) { _, isPresented in
            guard isPresented else { return }
            onPlannerSidebarPresentationRequested?()
        }
    }

    private func syncSelectedTask() {
        guard
            let selectedTaskID,
            let selectedTask,
            selectedTask.id == selectedTaskID
        else { return }

        if planner.selectedTaskID != selectedTaskID {
            planner.selectedBlockID = nil
        }
        planner.selectTask(selectedTask)
    }

    private var selectedTaskSyncToken: DayPlanSelectedTaskSyncToken {
        DayPlanSelectedTaskSyncToken(task: selectedTask)
    }

    private func dismissPlannerSidebars() {
        isCalendarFilterSidebarPresented = false
        isDatePickerSidebarPresented = false
    }

    private func plannerListContent(_ listContent: (DayPlanTimelineDateJumpRequest?) -> AnyView) -> some View {
        HStack(spacing: 0) {
            listContent(timelineDateJumpRequest)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if isDatePickerSidebarPresented {
                Divider()

                ScrollView {
                    DayPlanDatePickerSidebar(
                        selectedDate: selectedDateBinding,
                        summaryTitle: planner.selectedDate.formatted(date: .abbreviated, time: .omitted),
                        blocksCount: planner.blocks.count,
                        plannedMinutes: planner.plannedMinutes,
                        calendar: calendar,
                        activityDates: timelineActivityDates,
                        showsActivityAvailability: true,
                        onDismiss: {
                            isDatePickerSidebarPresented = false
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .scrollIndicators(.visible)
                .frame(width: DayPlanSlotSidebarPresentation.width)
                .background(Color.secondary.opacity(0.045))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.16), value: isDatePickerSidebarPresented)
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: {
                planner.selectedDate
            },
            set: { date in
                let selectedDay = calendar.startOfDay(for: date)
                planner.showDate(selectedDay, calendar: calendar, context: modelContext)
                if displayMode.wrappedValue == .list {
                    timelineDateJumpRequest = DayPlanTimelineDateJumpRequest(date: selectedDay)
                }
            }
        )
    }
}

private struct DayPlanHeaderView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var planner: DayPlanPlannerState
    var calendarFilters = DayPlanCalendarFilterState()
    var isCalendarFilterSidebarPresented: Binding<Bool> = .constant(false)
    var isDatePickerSidebarPresented: Binding<Bool> = .constant(false)
    var isCalendarFilterDetailPresented = false
    var showsCalendarFilterButton = false
    var displayMode: Binding<DayPlanDisplayMode> = .constant(.calendar)
    var calendarTaskViewMode: Binding<DayPlanCalendarTaskViewMode> = .constant(.schedule)
    var showsDisplayModePicker = false
    var isTaskDetailInspectorPresented = false
    var parentAvailableWidth: CGFloat? = nil
    var listFilterButtonIsActive = false
    var listFilterButtonAccessibilityValue: String? = nil
    var macFocusControl: (() -> AnyView)? = nil
    var onCalendarFilterButtonPressed: (() -> Void)? = nil
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areMacEventEmotionActionsEnabled = false
    @State private var macHeaderAvailableWidth: CGFloat = 0
    @State private var macHeaderFullControlsWidth: CGFloat = 0
    @State private var macHeaderCollapsedRegularDateControlsWidth: CGFloat = 0

    var body: some View {
#if os(macOS)
        macHeader
#else
        compactHeader
#endif
    }

    private var macHeader: some View {
        ZStack(alignment: .leading) {
            macHeaderRow(showsRangePicker: shouldShowMacHeaderRangePicker)
                .background {
                    ZStack {
                        macHeaderFullControlsWidthProbe
                        macHeaderCollapsedRegularDateControlsWidthProbe
                    }
                }
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .background(macHeaderAvailableWidthReader)
            .onPreferenceChange(DayPlanHeaderAvailableWidthPreferenceKey.self) { width in
                guard abs(macHeaderAvailableWidth - width) > 0.5 else { return }
                macHeaderAvailableWidth = width
            }
            .onPreferenceChange(DayPlanHeaderFullControlsWidthPreferenceKey.self) { width in
                guard abs(macHeaderFullControlsWidth - width) > 0.5 else { return }
                macHeaderFullControlsWidth = width
            }
            .onPreferenceChange(DayPlanHeaderCollapsedRegularDateControlsWidthPreferenceKey.self) { width in
                guard abs(macHeaderCollapsedRegularDateControlsWidth - width) > 0.5 else { return }
                macHeaderCollapsedRegularDateControlsWidth = width
            }
    }

    private var shouldShowMacHeaderRangePicker: Bool {
        guard effectiveDisplayMode == .calendar else { return false }

        return DayPlanHeaderRangePickerVisibility.shouldShow(
            availableWidth: Double(effectiveMacHeaderAvailableWidth),
            fullControlsWidth: Double(macHeaderFullControlsWidth),
            isTaskDetailInspectorPresented: isTaskDetailInspectorPresented,
            visibleRangeMode: planner.visibleRangeMode
        )
    }

    private func macHeaderRow(showsRangePicker: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            plannerViewControlsCluster(showsRangePicker: showsRangePicker)

            Spacer(minLength: 16)

            plannerUtilityCluster
        }
        .frame(maxWidth: .infinity)
    }

    private var macHeaderAvailableWidthReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: DayPlanHeaderAvailableWidthPreferenceKey.self,
                value: proxy.size.width
            )
        }
    }

    private var macHeaderFullControlsWidthProbe: some View {
        macHeaderFittingControls(showsRangePicker: true)
            .fixedSize(horizontal: true, vertical: false)
            .hidden()
            .accessibilityHidden(true)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: DayPlanHeaderFullControlsWidthPreferenceKey.self,
                        value: proxy.size.width
                    )
                }
            }
    }

    private var macHeaderCollapsedRegularDateControlsWidthProbe: some View {
        macHeaderFittingControls(
            showsRangePicker: false,
            forceIconOnlyDisplayModePicker: true,
            forceCompactDatePickerButton: false
        )
        .fixedSize(horizontal: true, vertical: false)
        .hidden()
        .accessibilityHidden(true)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: DayPlanHeaderCollapsedRegularDateControlsWidthPreferenceKey.self,
                    value: proxy.size.width
                )
            }
        }
    }

    private func macHeaderFittingControls(
        showsRangePicker: Bool,
        forceIconOnlyDisplayModePicker: Bool? = nil,
        forceCompactDatePickerButton: Bool? = nil
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            plannerViewControlsCluster(
                showsRangePicker: showsRangePicker,
                forceIconOnlyDisplayModePicker: forceIconOnlyDisplayModePicker
            )
            Color.clear.frame(width: 16, height: 1)
            plannerUtilityCluster(forceCompactDatePickerButton: forceCompactDatePickerButton)
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            if effectiveDisplayMode == .calendar {
                HStack(alignment: .center, spacing: 10) {
                    plannerDateNavigationCluster

                    Spacer(minLength: 8)

                    plannerUtilityCluster
                }
            }

            HStack(spacing: 8) {
                if showsDisplayModePicker {
                    displayModePicker
                }
                if effectiveDisplayMode == .calendar {
                    calendarTaskViewModePicker
                    visibleRangeModePicker
                }
            }
        }
    }

    private func plannerViewControlsCluster(
        showsRangePicker: Bool = true,
        forceIconOnlyDisplayModePicker: Bool? = nil
    ) -> some View {
        HStack(alignment: .center, spacing: DayPlanHeaderRangePickerVisibility.segmentedControlSpacing) {
            if showsDisplayModePicker {
                displayModePicker(forceIconOnly: forceIconOnlyDisplayModePicker)
            }
            if effectiveDisplayMode == .calendar {
                calendarTaskViewModePicker(forceIconOnly: forceIconOnlyDisplayModePicker)
                if showsRangePicker {
                    visibleRangeModePicker
                }
            }
        }
    }

    private var plannerUtilityCluster: some View {
        plannerUtilityCluster(forceCompactDatePickerButton: nil)
    }

    private func plannerUtilityCluster(forceCompactDatePickerButton: Bool?) -> some View {
        HStack(alignment: .center, spacing: 8) {
#if os(macOS)
            if effectiveDisplayMode == .calendar, let macFocusControl {
                macFocusControl()
            }
#endif

            if showsCalendarFilterButton {
                calendarFilterButton
            }

#if os(macOS)
            if effectiveDisplayMode == .calendar {
                plannerDateNavigationCluster
            }
#endif

            if showsPlannerDatePickerButton {
                plannerDatePickerButton(forceCompactWidth: forceCompactDatePickerButton)
            }
        }
    }

    private var showsPlannerDatePickerButton: Bool {
        effectiveDisplayMode == .calendar || effectiveDisplayMode == .list
    }

    private var todayButton: some View {
        Button("Show today") {
            planner.moveToToday(calendar: calendar, context: modelContext)
        }
        .buttonStyle(.bordered)
    }

    private var shouldShowTodayButton: Bool {
        !planner.visibleDates(calendar: calendar).contains { date in
            calendar.isDateInToday(date)
        }
    }

    private var plannerDateNavigationCluster: some View {
        HStack(alignment: .center, spacing: 10) {
            if shouldShowTodayButton {
                todayButton
            }
            rangeNavigationButtons
        }
    }

    private var rangeNavigationButtons: some View {
        HStack(spacing: 4) {
            rangeNavigationButton(
                systemName: "chevron.left",
                accessibilityLabel: previousRangeAccessibilityLabel
            ) {
                planner.moveVisibleRange(by: -1, calendar: calendar, context: modelContext)
            }

            rangeNavigationButton(
                systemName: "chevron.right",
                accessibilityLabel: nextRangeAccessibilityLabel
            ) {
                planner.moveVisibleRange(by: 1, calendar: calendar, context: modelContext)
            }
        }
    }

    private func rangeNavigationButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .frame(width: 34, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.07))
                }
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .help(accessibilityLabel)
    }

    private var previousRangeAccessibilityLabel: String {
        switch planner.visibleRangeMode {
        case .day:
            return "Previous day"
        case .threeDays:
            return "Previous 3 days"
        case .week:
            return "Previous week"
        }
    }

    private var nextRangeAccessibilityLabel: String {
        switch planner.visibleRangeMode {
        case .day:
            return "Next day"
        case .threeDays:
            return "Next 3 days"
        case .week:
            return "Next week"
        }
    }

    private var calendarFilterButton: some View {
        let isPresented = onCalendarFilterButtonPressed == nil
            ? isCalendarFilterSidebarPresented.wrappedValue
            : isCalendarFilterDetailPresented
        let availability = calendarFilterAvailability
        let isListMode = effectiveDisplayMode == .list
        let isActive = isListMode
            ? listFilterButtonIsActive
            : calendarFilters.hasActiveFilters(availability: availability)
        let accessibilityLabel = isListMode ? "Timeline filters" : "Planner filters"
        let accessibilityValue = isListMode
            ? (listFilterButtonAccessibilityValue ?? "No timeline filters")
            : calendarFilters.summaryText(availability: availability)

        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                if let onCalendarFilterButtonPressed {
                    onCalendarFilterButtonPressed()
                    return
                }
                let shouldPresent = !isCalendarFilterSidebarPresented.wrappedValue
                isCalendarFilterSidebarPresented.wrappedValue = shouldPresent
                if shouldPresent {
                    isDatePickerSidebarPresented.wrappedValue = false
                }
            }
        } label: {
            Image(
                systemName: isActive
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .font(.title3)
            .foregroundStyle(isPresented || isActive ? Color.accentColor : Color.secondary)
            .frame(width: 34, height: 34)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isPresented ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.07))
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .help(accessibilityLabel)
    }

    private var plannerDatePickerButton: some View {
        plannerDatePickerButton(forceCompactWidth: nil)
    }

    private func plannerDatePickerButton(forceCompactWidth: Bool?) -> some View {
        let title = plannerDatePickerButtonTitle
        let isPresented = isDatePickerSidebarPresented.wrappedValue
        let usesCompactWidth = forceCompactWidth ?? usesCompactMacDatePickerButton

        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                let shouldPresent = !isDatePickerSidebarPresented.wrappedValue
                isDatePickerSidebarPresented.wrappedValue = shouldPresent
                if shouldPresent {
                    isCalendarFilterSidebarPresented.wrappedValue = false
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isPresented ? "calendar.circle.fill" : "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: 34)
            .frame(
                minWidth: plannerDatePickerButtonMinimumWidth,
                maxWidth: plannerDatePickerButtonMaximumWidth(usesCompactWidth: usesCompactWidth),
                alignment: .leading
            )
            .routinaGlassCard(
                cornerRadius: 8,
                tint: isPresented ? Color.accentColor : nil,
                tintOpacity: 0.14,
                interactive: true
            )
        }
        .layoutPriority(3)
        .buttonStyle(.plain)
        .accessibilityLabel("Go to date")
        .accessibilityValue(title)
        .accessibilityHint(plannerDatePickerAccessibilityHint)
        .help("Go to date")
    }

    private var plannerDatePickerButtonTitle: String {
        switch effectiveDisplayMode {
        case .calendar:
            return planner.visibleRangeTitle(calendar: calendar)
        case .list:
            return planner.selectedDate.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private var plannerDatePickerAccessibilityHint: String {
        let plannedText = DayPlanFormatting.durationText(planner.plannedMinutes)
        switch effectiveDisplayMode {
        case .calendar:
            return "\(planner.blocks.count) blocks on selected day, \(plannedText) planned"
        case .list:
            return "\(planner.selectedDate.formatted(date: .abbreviated, time: .omitted)), \(planner.blocks.count) blocks, \(plannedText) planned"
        }
    }

    private var plannerDatePickerButtonMinimumWidth: CGFloat? {
        nil
    }

    private func plannerDatePickerButtonMaximumWidth(usesCompactWidth: Bool) -> CGFloat? {
        usesCompactWidth ? 154 : nil
    }

    private var calendarFilterAvailability: DayPlanCalendarFilterAvailability {
        DayPlanCalendarFilterAvailability(
            includesEvents: areMacEventEmotionActionsEnabled,
            includesAway: isAwayEnabled,
            includesSleep: isAwayEnabled
        )
    }

    private var visibleRangeModePicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Planner range",
            options: DayPlanVisibleRangeMode.allCases,
            selection: visibleRangeModeBinding
        ) { mode in
            Text(mode.title)
        }
        .frame(width: DayPlanHeaderRangePickerVisibility.visibleRangeModePickerWidth)
        .accessibilityLabel("Planner range")
    }

    private var displayModePicker: some View {
        displayModePicker(forceIconOnly: nil)
    }

    private func displayModePicker(forceIconOnly: Bool?) -> some View {
        let usesIconOnlySegments = forceIconOnly ?? usesIconOnlyMacDisplayModePicker

        return RoutinaGlassSegmentedControl(
            accessibilityLabel: "Planner view",
            options: DayPlanDisplayMode.allCases,
            selection: displayMode,
            minimumSegmentWidth: usesIconOnlySegments ? 42 : 84,
            horizontalPadding: usesIconOnlySegments ? 8 : 11
        ) { mode in
            if usesIconOnlySegments {
                Image(systemName: mode.systemImage)
                    .accessibilityLabel(mode.title)
                    .help(mode.title)
            } else {
                Label(mode.title, systemImage: mode.systemImage)
                    .labelStyle(.titleAndIcon)
            }
        }
        .frame(
            width: usesIconOnlySegments
                ? DayPlanHeaderRangePickerVisibility.iconOnlyDisplayModePickerWidth
                : DayPlanHeaderRangePickerVisibility.displayModePickerWidth
        )
        .accessibilityLabel("Planner view")
    }

    private var calendarTaskViewModePicker: some View {
        calendarTaskViewModePicker(forceIconOnly: nil)
    }

    private func calendarTaskViewModePicker(forceIconOnly: Bool?) -> some View {
        let usesIconOnlySegments = forceIconOnly ?? usesIconOnlyMacDisplayModePicker

        return RoutinaGlassSegmentedControl(
            accessibilityLabel: "Calendar task view",
            options: DayPlanCalendarTaskViewMode.allCases,
            selection: calendarTaskViewMode,
            minimumSegmentWidth: usesIconOnlySegments ? 42 : 74,
            horizontalPadding: usesIconOnlySegments ? 8 : 11
        ) { mode in
            if usesIconOnlySegments {
                Image(systemName: mode.systemImage)
                    .accessibilityLabel(mode.title)
                    .help(mode.title)
            } else {
                Label(mode.title, systemImage: mode.systemImage)
                    .labelStyle(.titleAndIcon)
            }
        }
        .frame(
            width: usesIconOnlySegments
                ? DayPlanHeaderRangePickerVisibility.iconOnlyCalendarTaskViewModePickerWidth
                : DayPlanHeaderRangePickerVisibility.calendarTaskViewModePickerWidth
        )
        .accessibilityLabel("Calendar task view")
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

    private var effectiveDisplayMode: DayPlanDisplayMode {
        showsDisplayModePicker ? displayMode.wrappedValue : .calendar
    }

    private var usesIconOnlyMacDisplayModePicker: Bool {
#if os(macOS)
        DayPlanHeaderRangePickerVisibility.shouldUseIconOnlyDisplayModePicker(
            availableWidth: Double(effectiveMacHeaderAvailableWidth),
            isTaskDetailInspectorPresented: isTaskDetailInspectorPresented
        )
#else
        false
#endif
    }

    private var usesCompactMacDatePickerButton: Bool {
#if os(macOS)
        DayPlanHeaderRangePickerVisibility.shouldUseCompactDatePickerButton(
            availableWidth: Double(effectiveMacHeaderAvailableWidth),
            isTaskDetailInspectorPresented: isTaskDetailInspectorPresented,
            collapsedRegularDateControlsWidth: Double(macHeaderCollapsedRegularDateControlsWidth)
        )
#else
        false
#endif
    }

    private var effectiveMacHeaderAvailableWidth: CGFloat {
        if let parentAvailableWidth, parentAvailableWidth > 0 {
            return parentAvailableWidth
        }
        return macHeaderAvailableWidth
    }

}

enum DayPlanHeaderRangePickerVisibility {
    static let segmentedControlSpacing: CGFloat = 16
    static let displayModePickerWidth: CGFloat = 220
    static let iconOnlyDisplayModePickerWidth: CGFloat = 100
    static let calendarTaskViewModePickerWidth: CGFloat = 190
    static let iconOnlyCalendarTaskViewModePickerWidth: CGFloat = 100
    static let visibleRangeModePickerWidth: CGFloat = 234
    static let inspectorRangePickerMinimumAvailableWidth: Double = 860
    static let iconOnlyDisplayModePickerMaximumAvailableWidth: Double = 860
    static let compactDatePickerButtonMaximumAvailableWidth: Double = 660

    static func shouldShow(
        availableWidth: Double,
        fullControlsWidth: Double,
        isTaskDetailInspectorPresented: Bool,
        visibleRangeMode: DayPlanVisibleRangeMode
    ) -> Bool {
        if isTaskDetailInspectorPresented {
            guard visibleRangeMode != .day else { return false }
            guard availableWidth >= inspectorRangePickerMinimumAvailableWidth else { return false }
        }
        guard availableWidth > 0, fullControlsWidth > 0 else {
            return !isTaskDetailInspectorPresented
        }
        return fullControlsWidth <= availableWidth + 0.5
    }

    static func shouldUseIconOnlyDisplayModePicker(
        availableWidth: Double,
        isTaskDetailInspectorPresented: Bool
    ) -> Bool {
        guard isTaskDetailInspectorPresented, availableWidth > 0 else { return false }
        return availableWidth < iconOnlyDisplayModePickerMaximumAvailableWidth
    }

    static func shouldUseCompactDatePickerButton(
        availableWidth: Double,
        isTaskDetailInspectorPresented: Bool,
        collapsedRegularDateControlsWidth: Double
    ) -> Bool {
        guard isTaskDetailInspectorPresented, availableWidth > 0 else { return false }
        guard collapsedRegularDateControlsWidth > 0 else {
            return availableWidth < compactDatePickerButtonMaximumAvailableWidth
        }
        guard availableWidth < compactDatePickerButtonMaximumAvailableWidth else { return false }
        return collapsedRegularDateControlsWidth > availableWidth + 0.5
    }

    static func shouldUseCompactDatePickerButton(
        availableWidth: Double,
        isTaskDetailInspectorPresented: Bool
    ) -> Bool {
        shouldUseCompactDatePickerButton(
            availableWidth: availableWidth,
            isTaskDetailInspectorPresented: isTaskDetailInspectorPresented,
            collapsedRegularDateControlsWidth: 0
        )
    }
}

private struct DayPlanHeaderAvailableWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct DayPlanHeaderFullControlsWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct DayPlanHeaderCollapsedRegularDateControlsWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct DayPlanTimelinePanelView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var planner: DayPlanPlannerState
    var onSelectUnplannedCompletedDate: ((Date) -> Void)? = nil
    var onOpenTaskDetails: ((UUID) -> Void)? = nil
    var onOpenEventDetails: ((UUID) -> Void)? = nil
    var calendarFilters: Binding<DayPlanCalendarFilterState> = .constant(DayPlanCalendarFilterState())
    var calendarSearchText = ""
    var calendarTaskFilter: (RoutineTask) -> Bool = { _ in true }
    var calendarTaskFilterCacheSeed = 0
    var calendarTaskViewMode: DayPlanCalendarTaskViewMode = .schedule
    var isCalendarFilterSidebarPresented: Binding<Bool> = .constant(false)
    var isDatePickerSidebarPresented: Binding<Bool> = .constant(false)
    var isExternalInspectorPresented = false
    var onSidebarPresentationRequested: (() -> Void)? = nil
    @State private var dataSnapshot = DayPlanTimelineDataSnapshot()
    @State private var hasDeferredTimelineDataSnapshotRefresh = false
#if os(macOS)
    @State private var deferredTimelineDataSnapshotRefreshTask: Task<Void, Never>?
#endif
    @StateObject private var timelinePlacementCache = DayPlanTimelinePlacementCache()
    @StateObject private var allDayBlocksCache = DayPlanAllDayBlocksCache()
    @StateObject private var visibleBlockContextCache = DayPlanVisibleBlockContextCache()
    @StateObject private var sleepBlocksCache = DayPlanSleepBlocksCache()
    @StateObject private var awayBlocksCache = DayPlanAwayBlocksCache()
    @StateObject private var completedSprintFocusBlocksCache = DayPlanSprintFocusBlocksCache()
    @StateObject private var activeSprintFocusBlocksCache = DayPlanSprintFocusBlocksCache()
    @StateObject private var renderSnapshotCache = DayPlanTimelineRenderSnapshotCache()
    @StateObject private var plannedDateTaskVisibilityCache = DayPlanPlannedDateTaskVisibilityCache()
    @StateObject private var dayTaskListItemsCache = DayPlanDayTaskListItemsCache()
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areMacEventEmotionActionsEnabled = false

    var body: some View {
        DayPlanTimelinePanelContentView(
            planner: planner,
            onSelectUnplannedCompletedDate: onSelectUnplannedCompletedDate,
            onOpenTaskDetails: onOpenTaskDetails,
            onOpenEventDetails: onOpenEventDetails,
            dataSnapshotID: dataSnapshot.id,
            tasks: dataSnapshot.tasks,
            logs: dataSnapshot.logs,
            sleepSessions: dataSnapshot.sleepSessions,
            awaySessions: isAwayEnabled ? dataSnapshot.awaySessions : [],
            events: dataSnapshot.events,
            sprintFocusSessions: dataSnapshot.sprintFocusSessions,
            sprintFocusAllocations: dataSnapshot.sprintFocusAllocations,
            boardSprints: dataSnapshot.boardSprints,
            focusSessions: dataSnapshot.focusSessions,
            includesEvents: areMacEventEmotionActionsEnabled,
            includesAway: isAwayEnabled,
            timelinePlacementCache: timelinePlacementCache,
            allDayBlocksCache: allDayBlocksCache,
            visibleBlockContextCache: visibleBlockContextCache,
            sleepBlocksCache: sleepBlocksCache,
            awayBlocksCache: awayBlocksCache,
            completedSprintFocusBlocksCache: completedSprintFocusBlocksCache,
            activeSprintFocusBlocksCache: activeSprintFocusBlocksCache,
            renderSnapshotCache: renderSnapshotCache,
            plannedDateTaskVisibilityCache: plannedDateTaskVisibilityCache,
            dayTaskListItemsCache: dayTaskListItemsCache,
            calendarFilters: calendarFilters,
            calendarSearchText: calendarSearchText,
            calendarTaskFilter: calendarTaskFilter,
            calendarTaskFilterCacheSeed: calendarTaskFilterCacheSeed,
            calendarTaskViewMode: calendarTaskViewMode,
            isCalendarFilterSidebarPresented: isCalendarFilterSidebarPresented,
            isDatePickerSidebarPresented: isDatePickerSidebarPresented,
            isExternalInspectorPresented: isExternalInspectorPresented,
            onSidebarPresentationRequested: onSidebarPresentationRequested
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            refreshTimelineDataSnapshot()
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            requestTimelineDataSnapshotRefresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshTimelineDataSnapshot()
            }
        }
        .onChange(of: isExternalInspectorPresented) { _, isPresented in
            guard !isPresented else { return }
            refreshDeferredTimelineDataSnapshotIfNeeded()
        }
    }

    private func requestTimelineDataSnapshotRefresh() {
#if os(macOS)
        guard !isExternalInspectorPresented else {
            hasDeferredTimelineDataSnapshotRefresh = true
            return
        }
        guard !RoutinaMacScrollInteractionGate.isScrollActive else {
            hasDeferredTimelineDataSnapshotRefresh = true
            scheduleDeferredTimelineDataSnapshotRefreshRetry()
            return
        }
#else
        guard !isExternalInspectorPresented else {
            hasDeferredTimelineDataSnapshotRefresh = true
            return
        }
#endif

        hasDeferredTimelineDataSnapshotRefresh = false
        refreshTimelineDataSnapshot()
    }

    private func refreshDeferredTimelineDataSnapshotIfNeeded() {
        guard hasDeferredTimelineDataSnapshotRefresh else { return }
#if os(macOS)
        guard !isExternalInspectorPresented else { return }
        guard !RoutinaMacScrollInteractionGate.isScrollActive else {
            scheduleDeferredTimelineDataSnapshotRefreshRetry()
            return
        }
#endif
        hasDeferredTimelineDataSnapshotRefresh = false
#if os(macOS)
        deferredTimelineDataSnapshotRefreshTask?.cancel()
        deferredTimelineDataSnapshotRefreshTask = nil
#endif
        refreshTimelineDataSnapshot()
    }

#if os(macOS)
    private func scheduleDeferredTimelineDataSnapshotRefreshRetry() {
        deferredTimelineDataSnapshotRefreshTask?.cancel()
        let delayMilliseconds = RoutinaMacScrollInteractionGate.quietRetryDelayMilliseconds
        deferredTimelineDataSnapshotRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            guard !Task.isCancelled else { return }
            refreshDeferredTimelineDataSnapshotIfNeeded()
        }
    }
#endif

    private func refreshTimelineDataSnapshot() {
        do {
            let refreshedSnapshot = try DayPlanTimelineDataSnapshot.fetch(from: modelContext)
            if refreshedSnapshot.signature != dataSnapshot.signature {
                dataSnapshot = refreshedSnapshot
            }
        } catch {
            NSLog("DayPlanTimelinePanelView: failed to refresh planner data snapshot - \(error.localizedDescription)")
        }
    }
}

private struct DayPlanTimelineDataSnapshot {
    var id = UUID()
    var signature = DayPlanTimelineDataSnapshotSignature()
    var tasks: [RoutineTask] = []
    var logs: [RoutineLog] = []
    var sleepSessions: [SleepSession] = []
    var awaySessions: [AwaySession] = []
    var events: [RoutineEvent] = []
    var sprintFocusSessions: [SprintFocusSessionRecord] = []
    var sprintFocusAllocations: [SprintFocusAllocationRecord] = []
    var boardSprints: [BoardSprintRecord] = []
    var focusSessions: [FocusSession] = []

    init() {}

    init(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        events: [RoutineEvent],
        sprintFocusSessions: [SprintFocusSessionRecord],
        sprintFocusAllocations: [SprintFocusAllocationRecord],
        boardSprints: [BoardSprintRecord],
        focusSessions: [FocusSession]
    ) {
        signature = DayPlanTimelineDataSnapshotSignature(
            tasks: tasks,
            logs: logs,
            sleepSessions: sleepSessions,
            awaySessions: awaySessions,
            events: events,
            sprintFocusSessions: sprintFocusSessions,
            sprintFocusAllocations: sprintFocusAllocations,
            boardSprints: boardSprints,
            focusSessions: focusSessions
        )
        self.tasks = tasks
        self.logs = logs
        self.sleepSessions = sleepSessions
        self.awaySessions = awaySessions
        self.events = events
        self.sprintFocusSessions = sprintFocusSessions
        self.sprintFocusAllocations = sprintFocusAllocations
        self.boardSprints = boardSprints
        self.focusSessions = focusSessions
    }

    static func fetch(from context: ModelContext) throws -> DayPlanTimelineDataSnapshot {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        let sleepSessions = try context.fetch(
            FetchDescriptor<SleepSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )
        let awaySessions = try context.fetch(
            FetchDescriptor<AwaySession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )
        let events = try context.fetch(
            FetchDescriptor<RoutineEvent>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )
        let sprintFocusSessions = try context.fetch(
            FetchDescriptor<SprintFocusSessionRecord>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )
        let sprintFocusAllocations = try context.fetch(FetchDescriptor<SprintFocusAllocationRecord>())
        let boardSprints = try context.fetch(FetchDescriptor<BoardSprintRecord>())
        let focusSessions = try context.fetch(
            FetchDescriptor<FocusSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )

        return DayPlanTimelineDataSnapshot(
            tasks: tasks,
            logs: logs,
            sleepSessions: sleepSessions,
            awaySessions: awaySessions,
            events: events,
            sprintFocusSessions: sprintFocusSessions,
            sprintFocusAllocations: sprintFocusAllocations,
            boardSprints: boardSprints,
            focusSessions: focusSessions
        )
    }
}

private struct DayPlanTimelineDataSnapshotSignature: Equatable {
    var tasks: [TaskSnapshot] = []
    var logs: [LogSnapshot] = []
    var sleepSessions: [SleepSessionSnapshot] = []
    var awaySessions: [AwaySessionSnapshot] = []
    var events: [EventSnapshot] = []
    var sprintFocusSessions: [SprintFocusSessionSnapshot] = []
    var sprintFocusAllocations: [SprintFocusAllocationSnapshot] = []
    var boardSprints: [BoardSprintSnapshot] = []
    var focusSessions: [FocusSessionSnapshot] = []

    init() {}

    init(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        events: [RoutineEvent],
        sprintFocusSessions: [SprintFocusSessionRecord],
        sprintFocusAllocations: [SprintFocusAllocationRecord],
        boardSprints: [BoardSprintRecord],
        focusSessions: [FocusSession]
    ) {
        self.tasks = tasks
            .map(TaskSnapshot.init(task:))
            .sorted { $0.idSortKey < $1.idSortKey }
        self.logs = logs
            .map(LogSnapshot.init(log:))
            .sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.sleepSessions = sleepSessions
            .map(SleepSessionSnapshot.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.awaySessions = awaySessions
            .map(AwaySessionSnapshot.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.events = events
            .map(EventSnapshot.init(event:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.sprintFocusSessions = sprintFocusSessions
            .map(SprintFocusSessionSnapshot.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return lhs.startedAt < rhs.startedAt
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.sprintFocusAllocations = sprintFocusAllocations
            .map(SprintFocusAllocationSnapshot.init(allocation:))
            .sorted { lhs, rhs in
                if lhs.sessionIDSortKey != rhs.sessionIDSortKey {
                    return lhs.sessionIDSortKey < rhs.sessionIDSortKey
                }
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.boardSprints = boardSprints
            .map(BoardSprintSnapshot.init(sprint:))
            .sorted { $0.idSortKey < $1.idSortKey }
        self.focusSessions = focusSessions
            .map(FocusSessionSnapshot.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
                }
                return lhs.idSortKey < rhs.idSortKey
            }
    }

    struct TaskSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var name: String?
        var emoji: String?
        var notes: String?
        var deadline: Date?
        var isAllDay: Bool
        var routineDurationModeRawValue: String
        var availabilityStartDate: Date?
        var availabilityEndDate: Date?
        var scheduleModeRawValue: String
        var recurrenceStorageVersion: Int16
        var recurrenceKindRawValue: String
        var recurrenceTimeOfDayHour: Int?
        var recurrenceTimeOfDayMinute: Int?
        var recurrenceTimeRangeStartHour: Int?
        var recurrenceTimeRangeStartMinute: Int?
        var recurrenceTimeRangeEndHour: Int?
        var recurrenceTimeRangeEndMinute: Int?
        var recurrenceWeekday: Int?
        var recurrenceDayOfMonth: Int?
        var recurrenceRuleStorage: String
        var interval: Int16
        var lastDone: Date?
        var canceledAt: Date?
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var snoozedUntil: Date?
        var createdAt: Date?
        var colorRawValue: String
        var autoAssumeDailyDone: Bool
        var autoAssumeDoneTimeOfDayHour: Int?
        var autoAssumeDoneTimeOfDayMinute: Int?
        var estimatedDurationMinutes: Int?
        var stepsStorage: String
        var checklistItemsStorage: String
        var completedChecklistItemIDsStorage: String
        var completedChecklistProgressStartedAt: Date?

        init(task: RoutineTask) {
            id = task.id
            idSortKey = task.id.uuidString
            name = task.name
            emoji = task.emoji
            notes = task.notes
            deadline = task.deadline
            isAllDay = task.isAllDay
            routineDurationModeRawValue = task.routineDurationModeRawValue
            availabilityStartDate = task.availabilityStartDate
            availabilityEndDate = task.availabilityEndDate
            scheduleModeRawValue = task.scheduleModeRawValue
            recurrenceStorageVersion = task.recurrenceStorageVersion
            recurrenceKindRawValue = task.recurrenceKindRawValue
            recurrenceTimeOfDayHour = task.recurrenceTimeOfDayHour
            recurrenceTimeOfDayMinute = task.recurrenceTimeOfDayMinute
            recurrenceTimeRangeStartHour = task.recurrenceTimeRangeStartHour
            recurrenceTimeRangeStartMinute = task.recurrenceTimeRangeStartMinute
            recurrenceTimeRangeEndHour = task.recurrenceTimeRangeEndHour
            recurrenceTimeRangeEndMinute = task.recurrenceTimeRangeEndMinute
            recurrenceWeekday = task.recurrenceWeekday
            recurrenceDayOfMonth = task.recurrenceDayOfMonth
            recurrenceRuleStorage = task.recurrenceRuleStorage
            interval = task.interval
            lastDone = task.lastDone
            canceledAt = task.canceledAt
            scheduleAnchor = task.scheduleAnchor
            pausedAt = task.pausedAt
            snoozedUntil = task.snoozedUntil
            createdAt = task.createdAt
            colorRawValue = task.colorRawValue
            autoAssumeDailyDone = task.autoAssumeDailyDone
            autoAssumeDoneTimeOfDayHour = task.autoAssumeDoneTimeOfDayHour
            autoAssumeDoneTimeOfDayMinute = task.autoAssumeDoneTimeOfDayMinute
            estimatedDurationMinutes = task.estimatedDurationMinutes
            stepsStorage = task.stepsStorage
            checklistItemsStorage = task.checklistItemsStorage
            completedChecklistItemIDsStorage = task.completedChecklistItemIDsStorage
            completedChecklistProgressStartedAt = task.completedChecklistProgressStartedAt
        }
    }

    struct LogSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var timestamp: Date?
        var taskID: UUID
        var kindRawValue: String
        var actualDurationMinutes: Int?
        var sourceTaskID: UUID?

        init(log: RoutineLog) {
            id = log.id
            idSortKey = log.id.uuidString
            timestamp = log.timestamp
            taskID = log.taskID
            kindRawValue = log.kindRawValue
            actualDurationMinutes = log.actualDurationMinutes
            sourceTaskID = log.sourceTaskID
        }
    }

    struct SleepSessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var startedAt: Date?
        var endedAt: Date?
        var targetDurationMinutes: Int

        init(session: SleepSession) {
            id = session.id
            idSortKey = session.id.uuidString
            startedAt = session.startedAt
            endedAt = session.endedAt
            targetDurationMinutes = session.targetDurationMinutes
        }
    }

    struct AwaySessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var presetRawValue: String
        var title: String
        var linkedTaskID: UUID?
        var startedAt: Date?
        var plannedDurationSeconds: TimeInterval
        var completedAt: Date?
        var endedEarlyAt: Date?

        init(session: AwaySession) {
            id = session.id
            idSortKey = session.id.uuidString
            presetRawValue = session.presetRawValue
            title = session.title
            linkedTaskID = session.linkedTaskID
            startedAt = session.startedAt
            plannedDurationSeconds = session.plannedDurationSeconds
            completedAt = session.completedAt
            endedEarlyAt = session.endedEarlyAt
        }
    }

    struct EventSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var title: String?
        var emoji: String?
        var isAllDay: Bool
        var startedAt: Date?
        var endedAt: Date?

        init(event: RoutineEvent) {
            id = event.id
            idSortKey = event.id.uuidString
            title = event.title
            emoji = event.emoji
            isAllDay = event.isAllDay
            startedAt = event.startedAt
            endedAt = event.endedAt
        }
    }

    struct SprintFocusSessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var sprintID: UUID
        var startedAt: Date
        var stoppedAt: Date?
        var pausedAt: Date?
        var accumulatedPausedSeconds: TimeInterval

        init(session: SprintFocusSessionRecord) {
            id = session.id
            idSortKey = session.id.uuidString
            sprintID = session.sprintID
            startedAt = session.startedAt
            stoppedAt = session.stoppedAt
            pausedAt = session.pausedAt
            accumulatedPausedSeconds = session.accumulatedPausedSeconds
        }
    }

    struct SprintFocusAllocationSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var sessionID: UUID
        var sessionIDSortKey: String
        var taskID: UUID
        var minutes: Int
        var sortOrder: Int

        init(allocation: SprintFocusAllocationRecord) {
            id = allocation.id
            idSortKey = allocation.id.uuidString
            sessionID = allocation.sessionID
            sessionIDSortKey = allocation.sessionID.uuidString
            taskID = allocation.taskID
            minutes = allocation.minutes
            sortOrder = allocation.sortOrder
        }
    }

    struct BoardSprintSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var title: String

        init(sprint: BoardSprintRecord) {
            id = sprint.id
            idSortKey = sprint.id.uuidString
            title = sprint.title
        }
    }

    struct FocusSessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var taskID: UUID
        var startedAt: Date?
        var plannedDurationSeconds: TimeInterval
        var completedAt: Date?
        var abandonedAt: Date?
        var pausedAt: Date?
        var accumulatedPausedSeconds: TimeInterval
        var tagName: String?

        init(session: FocusSession) {
            id = session.id
            idSortKey = session.id.uuidString
            taskID = session.taskID
            startedAt = session.startedAt
            plannedDurationSeconds = session.plannedDurationSeconds
            completedAt = session.completedAt
            abandonedAt = session.abandonedAt
            pausedAt = session.pausedAt
            accumulatedPausedSeconds = session.accumulatedPausedSeconds
            tagName = session.tagName
        }
    }
}

private struct DayPlanTimelineRenderSnapshot {
    var visibleDates: [Date]
    var tasks: [RoutineTask]
    var logs: [RoutineLog]
    var sleepSessions: [SleepSession]
    var awaySessions: [AwaySession]
    var events: [RoutineEvent]
    var sprintFocusSessions: [SprintFocusSessionRecord]
    var sprintFocusAllocations: [SprintFocusAllocationRecord]
    var boardSprints: [BoardSprintRecord]
    var focusSessions: [FocusSession]
    var activeSprintFocusSessions: [SprintFocusSessionRecord]
    var plannedBlocksByDayKey: [String: [DayPlanBlock]]
    var rawPlannedBlocks: [DayPlanBlock]
    var sleepBlocksByDayKey: [String: [DayPlanSleepBlock]]
    var linkedAwayBlocksByDayKey: [String: [DayPlanAwayBlock]]
    var sprintFocusBlocksByDayKey: [String: [DayPlanSprintFocusBlock]]
    var eventBlocksByDayKey: [String: [DayPlanEventBlock]]
    var blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    var timelineBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]]
    var unplaceableAutomaticSuggestionBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]]
    var automaticSuggestionBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]]
    var assumedDoneSummaryBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]]
    var allDayBlocks: [DayPlanAllDayBlock]
    var visibleBlockContext: DayPlanVisibleBlockContext
    var selectedDayBlockedMinutes: Int
    var tintsByTaskID: [UUID: Color]
    var activeFocusRenderSessions: [FocusSession]
    var planFocusAllocatedMinutesBySessionID: [UUID: Int]
}

@MainActor
private final class DayPlanTimelineRenderSnapshotCache: ObservableObject {
    private var cachedKey: DayPlanTimelineRenderSnapshotKey?
    private var cachedSnapshot: DayPlanTimelineRenderSnapshot?

    func snapshot(
        dataSnapshotID: UUID,
        planner: DayPlanPlannerState,
        tasks: [RoutineTask],
        logs: [RoutineLog],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        events: [RoutineEvent],
        sprintFocusSessions: [SprintFocusSessionRecord],
        sprintFocusAllocations: [SprintFocusAllocationRecord],
        boardSprints: [BoardSprintRecord],
        focusSessions: [FocusSession],
        referenceDate: Date,
        calendar: Calendar,
        modelContext: ModelContext,
        showsTimelineTasksInDayPlanner: Bool,
        hiddenTimelineActivityStorage: String,
        timelinePlacementCache: DayPlanTimelinePlacementCache,
        allDayBlocksCache: DayPlanAllDayBlocksCache,
        visibleBlockContextCache: DayPlanVisibleBlockContextCache,
        sleepBlocksCache: DayPlanSleepBlocksCache,
        awayBlocksCache: DayPlanAwayBlocksCache,
        completedSprintFocusBlocksCache: DayPlanSprintFocusBlocksCache,
        activeSprintFocusBlocksCache: DayPlanSprintFocusBlocksCache
    ) -> DayPlanTimelineRenderSnapshot {
        let visibleDates = planner.visibleDates(calendar: calendar)
        let refreshesEveryMinute = Self.hasVisibleOpenEndedTimelineBlock(
            visibleDates: visibleDates,
            sleepSessions: sleepSessions,
            awaySessions: awaySessions,
            sprintFocusSessions: sprintFocusSessions,
            referenceDate: referenceDate,
            calendar: calendar
        ) || tasks.contains { RoutineAssumedCompletion.isEligible($0) }
        let key = DayPlanTimelineRenderSnapshotKey(
            dataSnapshotID: dataSnapshotID,
            visibleDates: visibleDates,
            selectedDate: planner.selectedDate,
            focusedUnplannedCompletedDate: planner.focusedUnplannedCompletedDate,
            plannerBlocks: planner.blocks,
            plannerWeekBlocksByDayKey: planner.weekBlocksByDayKey,
            referenceDate: referenceDate,
            refreshesEveryMinute: refreshesEveryMinute,
            calendar: calendar,
            showsTimelineTasksInDayPlanner: showsTimelineTasksInDayPlanner,
            hiddenTimelineActivityStorage: hiddenTimelineActivityStorage
        )

        if cachedKey == key, let cachedSnapshot {
            return cachedSnapshot
        }

        let activeTaskAndTagFocusSessions = activeTaskAndTagFocusSessions(from: focusSessions)
        let visibleBlockContext = visibleBlockContextCache.context(
            tasks: tasks,
            logs: logs,
            calendar: calendar,
            referenceDate: referenceDate,
            activeFocusSessions: activeTaskAndTagFocusSessions
        )
        let plannedBlockPresentation = plannedBlockPresentation(
            for: visibleDates,
            planner: planner,
            visibleBlockContext: visibleBlockContext,
            calendar: calendar,
            context: modelContext
        )
        let plannedBlocksByDayKey = plannedBlockPresentation.visibleBlocksByDayKey
        let rawPlannedBlocks = plannedBlockPresentation.rawBlocks
        let hiddenTimelineActivityIDs = DayPlanHiddenTimelineActivityStore.hiddenIDs(from: hiddenTimelineActivityStorage)
        let sleepBlocksByDayKey = sleepBlocksCache.blocksByDayKey(
            on: visibleDates,
            from: sleepSessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let awayBlocksByDayKey = awayBlocksCache.blocksByDayKey(
            on: visibleDates,
            from: awaySessions,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let completedSprintFocusSessions = sprintFocusSessions.filter { !$0.isActive }
        let activeSprintFocusSessions = sprintFocusSessions.filter(\.isActive)
        let sprintFocusBlocksByDayKey = completedSprintFocusBlocksCache.blocksByDayKey(
            on: visibleDates,
            from: completedSprintFocusSessions,
            allocations: sprintFocusAllocations,
            sprints: boardSprints,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        let activeSprintFocusBlocksByDayKey = activeSprintFocusBlocksCache.blocksByDayKey(
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
        let automaticOccupiedBlocksByDayKey = mergePlannerBlocks(
            plannedBlocksByDayKey,
            eventBlocksByDayKey.mapValues { $0.map(\.block) }
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
        let rawAutomaticSuggestionPlacementsByDayKey = timelinePlacementCache.automaticSuggestionPlacementsByDayKey(
            on: visibleDates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: automaticOccupiedBlocksByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenTimelineActivityIDs,
            referenceDate: referenceDate
        )
        let rawAutomaticSuggestionBlocksByDayKey = rawAutomaticSuggestionPlacementsByDayKey.mapValues(\.placed)
        let assumedDoneSummaryBlocksByDayKey = DayPlanTimelineTasks.assumedDoneSummaryBlocksByDayKey(
            on: visibleDates,
            from: tasks,
            logs: logs,
            calendar: calendar,
            hiddenActivityIDs: hiddenTimelineActivityIDs,
            referenceDate: referenceDate
        )
        let linkedAwayBlocksByDayKey = DayPlanAwayBlocks.linkedBlocksByDayKey(
            awayBlocksByDayKey,
            timelineActivitiesByDayKey: rawAutomaticSuggestionBlocksByDayKey
        )
        let timelineBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]] =
            showsTimelineTasksInDayPlanner
            ? [:]
            : DayPlanTimelineTasks.activityBlocksByDayKey(
                on: visibleDates,
                from: tasks,
                logs: logs,
                plannedBlocksByDayKey: automaticOccupiedBlocksByDayKey,
                blockedIntervalsByDayKey: blockedIntervalsByDayKey,
                calendar: calendar,
                hiddenActivityIDs: hiddenTimelineActivityIDs,
                referenceDate: referenceDate
            )
        let visibleAutomaticSuggestionPlacementsByDayKey: [String: DayPlanTimelineActivityPlacement] =
            showsTimelineTasksInDayPlanner
            ? Dictionary(
                uniqueKeysWithValues: rawAutomaticSuggestionPlacementsByDayKey.map { dayKey, placement in
                    (
                        dayKey,
                        placement.filteringBlockedIntervals(blockedIntervalsByDayKey[dayKey] ?? [])
                    )
                }
            )
            : [:]
        let allDayBlocks = allDayBlocksCache.blocks(
            on: visibleDates,
            from: tasks,
            logs: logs,
            events: events,
            calendar: calendar
        )
        let selectedDayKey = DayPlanStorage.dayKey(for: planner.selectedDate, calendar: calendar)
        let selectedDayBlockedMinutes = blockedIntervalsByDayKey[selectedDayKey, default: []]
            .reduce(0) { $0 + $1.durationMinutes }
        let activeFocusRenderSessions = activeFocusSessions(from: focusSessions)
        let snapshot = DayPlanTimelineRenderSnapshot(
            visibleDates: visibleDates,
            tasks: tasks,
            logs: logs,
            sleepSessions: sleepSessions,
            awaySessions: awaySessions,
            events: events,
            sprintFocusSessions: sprintFocusSessions,
            sprintFocusAllocations: sprintFocusAllocations,
            boardSprints: boardSprints,
            focusSessions: focusSessions,
            activeSprintFocusSessions: activeSprintFocusSessions,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            rawPlannedBlocks: rawPlannedBlocks,
            sleepBlocksByDayKey: sleepBlocksByDayKey,
            linkedAwayBlocksByDayKey: linkedAwayBlocksByDayKey,
            sprintFocusBlocksByDayKey: sprintFocusBlocksByDayKey,
            eventBlocksByDayKey: eventBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            timelineBlocksByDayKey: timelineBlocksByDayKey,
            unplaceableAutomaticSuggestionBlocksByDayKey: visibleAutomaticSuggestionPlacementsByDayKey.mapValues(\.unplaced),
            automaticSuggestionBlocksByDayKey: visibleAutomaticSuggestionPlacementsByDayKey.mapValues(\.placed),
            assumedDoneSummaryBlocksByDayKey: assumedDoneSummaryBlocksByDayKey,
            allDayBlocks: allDayBlocks,
            visibleBlockContext: visibleBlockContext,
            selectedDayBlockedMinutes: selectedDayBlockedMinutes,
            tintsByTaskID: tintsByTaskID(from: tasks),
            activeFocusRenderSessions: activeFocusRenderSessions,
            planFocusAllocatedMinutesBySessionID: DayPlanFocusSessionPlannerSync.planFocusAllocatedMinutesBySessionID(
                for: activeFocusRenderSessions.filter(\.isUnassigned),
                context: modelContext
            )
        )
        cachedKey = key
        cachedSnapshot = snapshot
        return snapshot
    }

    private func plannedBlockPresentation(
        for dates: [Date],
        planner: DayPlanPlannerState,
        visibleBlockContext: DayPlanVisibleBlockContext,
        calendar: Calendar,
        context: ModelContext
    ) -> DayPlanPlannedBlockPresentation {
        var visibleBlocksByDayKey: [String: [DayPlanBlock]] = [:]
        var rawBlocksByDayKey: [String: [DayPlanBlock]] = [:]
        var rawBlocks: [DayPlanBlock] = []
        visibleBlocksByDayKey.reserveCapacity(dates.count)
        rawBlocksByDayKey.reserveCapacity(dates.count)

        for date in dates {
            let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            let blocks = planner.blocks(on: date, calendar: calendar, context: context)
            rawBlocksByDayKey[dayKey] = blocks
            rawBlocks.append(contentsOf: blocks)
        }

        for date in dates {
            let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            let blocks = rawBlocksByDayKey[dayKey] ?? []
            visibleBlocksByDayKey[dayKey] = DayPlanVisibleBlocks.blocks(
                blocks,
                context: visibleBlockContext,
                activeFocusSegmentSearchBlocks: rawBlocks
            )
        }

        return DayPlanPlannedBlockPresentation(
            visibleBlocksByDayKey: visibleBlocksByDayKey,
            rawBlocks: rawBlocks
        )
    }

    private func activeTaskAndTagFocusSessions(from sessions: [FocusSession]) -> [FocusSession] {
        sessions.filter { session in
            (session.isTaskFocus || session.isTagFocus)
                && session.startedAt != nil
                && session.completedAt == nil
                && session.abandonedAt == nil
        }
    }

    private func activeFocusSessions(from sessions: [FocusSession]) -> [FocusSession] {
        sessions
            .filter { $0.startedAt != nil }
            .filter { $0.completedAt == nil && $0.abandonedAt == nil }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
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

    private func mergePlannerBlocks(
        _ lhs: [String: [DayPlanBlock]],
        _ rhs: [String: [DayPlanBlock]]
    ) -> [String: [DayPlanBlock]] {
        var result = lhs
        for (dayKey, blocks) in rhs {
            result[dayKey, default: []].append(contentsOf: blocks)
        }
        return result
    }

    private func tintsByTaskID(from tasks: [RoutineTask]) -> [UUID: Color] {
        var result: [UUID: Color] = [:]
        for task in tasks {
            result[task.id] = task.color.swiftUIColor ?? .accentColor
        }
        return result
    }

    private static func hasVisibleOpenEndedTimelineBlock(
        visibleDates: [Date],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        sprintFocusSessions: [SprintFocusSessionRecord],
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        let visibleDayStarts = visibleDates
            .map { calendar.startOfDay(for: $0) }
            .sorted()
        guard
            let visibleRangeStart = visibleDayStarts.first,
            let lastVisibleDayStart = visibleDayStarts.last,
            let visibleRangeEnd = calendar.date(byAdding: .day, value: 1, to: lastVisibleDayStart)
        else {
            return false
        }

        let hasActiveSleepBlock = sleepSessions.contains { session in
            guard let startedAt = session.startedAt, session.endedAt == nil else { return false }
            return intersectsVisibleRange(
                startedAt: startedAt,
                endedAt: referenceDate,
                visibleRangeStart: visibleRangeStart,
                visibleRangeEnd: visibleRangeEnd
            )
        }
        if hasActiveSleepBlock {
            return true
        }

        let hasActiveAwayBlock = awaySessions.contains { session in
            guard
                let startedAt = session.startedAt,
                session.isActive,
                session.plannedEndAt == nil
            else {
                return false
            }
            return intersectsVisibleRange(
                startedAt: startedAt,
                endedAt: referenceDate,
                visibleRangeStart: visibleRangeStart,
                visibleRangeEnd: visibleRangeEnd
            )
        }
        if hasActiveAwayBlock {
            return true
        }

        return sprintFocusSessions.contains { session in
            guard session.isActive else { return false }
            return intersectsVisibleRange(
                startedAt: session.startedAt,
                endedAt: referenceDate,
                visibleRangeStart: visibleRangeStart,
                visibleRangeEnd: visibleRangeEnd
            )
        }
    }

    private static func intersectsVisibleRange(
        startedAt: Date,
        endedAt: Date,
        visibleRangeStart: Date,
        visibleRangeEnd: Date
    ) -> Bool {
        max(startedAt, endedAt) >= visibleRangeStart && startedAt < visibleRangeEnd
    }
}

private struct DayPlanTimelineRenderSnapshotKey: Equatable {
    var dataSnapshotID: UUID
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var visibleDayKeys: [String]
    var selectedDayKey: String
    var focusedUnplannedCompletedDayKey: String?
    var referenceMinute: ReferenceMinute?
    var showsTimelineTasksInDayPlanner: Bool
    var hiddenTimelineActivityStorage: String
    var plannerBlocks: [DayPlanBlock]
    var plannerWeekBlocksByDayKey: [String: [DayPlanBlock]]

    init(
        dataSnapshotID: UUID,
        visibleDates: [Date],
        selectedDate: Date,
        focusedUnplannedCompletedDate: Date?,
        plannerBlocks: [DayPlanBlock],
        plannerWeekBlocksByDayKey: [String: [DayPlanBlock]],
        referenceDate: Date,
        refreshesEveryMinute: Bool,
        calendar: Calendar,
        showsTimelineTasksInDayPlanner: Bool,
        hiddenTimelineActivityStorage: String
    ) {
        self.dataSnapshotID = dataSnapshotID
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        visibleDayKeys = visibleDates
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
            .sorted()
        selectedDayKey = DayPlanStorage.dayKey(for: selectedDate, calendar: calendar)
        focusedUnplannedCompletedDayKey = focusedUnplannedCompletedDate.map {
            DayPlanStorage.dayKey(for: $0, calendar: calendar)
        }
        referenceMinute = refreshesEveryMinute
            ? ReferenceMinute(referenceDate: referenceDate, calendar: calendar)
            : nil
        self.showsTimelineTasksInDayPlanner = showsTimelineTasksInDayPlanner
        self.hiddenTimelineActivityStorage = hiddenTimelineActivityStorage
        self.plannerBlocks = plannerBlocks
        self.plannerWeekBlocksByDayKey = plannerWeekBlocksByDayKey
    }

    struct ReferenceMinute: Equatable {
        var dayKey: String
        var minute: Int

        init(referenceDate: Date, calendar: Calendar) {
            dayKey = DayPlanStorage.dayKey(for: referenceDate, calendar: calendar)
            let components = calendar.dateComponents([.hour, .minute], from: referenceDate)
            minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        }
    }
}

private struct DayPlanTimelinePanelContentView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @ObservedObject var planner: DayPlanPlannerState
    var onSelectUnplannedCompletedDate: ((Date) -> Void)? = nil
    var onOpenTaskDetails: ((UUID) -> Void)? = nil
    var onOpenEventDetails: ((UUID) -> Void)? = nil
    var dataSnapshotID: UUID
    var tasks: [RoutineTask]
    var logs: [RoutineLog]
    var sleepSessions: [SleepSession]
    var awaySessions: [AwaySession]
    var events: [RoutineEvent]
    var sprintFocusSessions: [SprintFocusSessionRecord]
    var sprintFocusAllocations: [SprintFocusAllocationRecord]
    var boardSprints: [BoardSprintRecord]
    var focusSessions: [FocusSession]
    var includesEvents: Bool
    var includesAway: Bool
    @ObservedObject var timelinePlacementCache: DayPlanTimelinePlacementCache
    @ObservedObject var allDayBlocksCache: DayPlanAllDayBlocksCache
    @ObservedObject var visibleBlockContextCache: DayPlanVisibleBlockContextCache
    @ObservedObject var sleepBlocksCache: DayPlanSleepBlocksCache
    @ObservedObject var awayBlocksCache: DayPlanAwayBlocksCache
    @ObservedObject var completedSprintFocusBlocksCache: DayPlanSprintFocusBlocksCache
    @ObservedObject var activeSprintFocusBlocksCache: DayPlanSprintFocusBlocksCache
    @ObservedObject var renderSnapshotCache: DayPlanTimelineRenderSnapshotCache
    @ObservedObject var plannedDateTaskVisibilityCache: DayPlanPlannedDateTaskVisibilityCache
    @ObservedObject var dayTaskListItemsCache: DayPlanDayTaskListItemsCache
    var calendarFilters: Binding<DayPlanCalendarFilterState> = .constant(DayPlanCalendarFilterState())
    var calendarSearchText = ""
    var calendarTaskFilter: (RoutineTask) -> Bool = { _ in true }
    var calendarTaskFilterCacheSeed = 0
    var calendarTaskViewMode: DayPlanCalendarTaskViewMode = .schedule
    var isCalendarFilterSidebarPresented: Binding<Bool> = .constant(false)
    var isDatePickerSidebarPresented: Binding<Bool> = .constant(false)
    var isExternalInspectorPresented = false
    var onSidebarPresentationRequested: (() -> Void)? = nil
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
        let renderSnapshot = renderSnapshotCache.snapshot(
            dataSnapshotID: dataSnapshotID,
            planner: planner,
            tasks: tasks,
            logs: logs,
            sleepSessions: sleepSessions,
            awaySessions: awaySessions,
            events: events,
            sprintFocusSessions: sprintFocusSessions,
            sprintFocusAllocations: sprintFocusAllocations,
            boardSprints: boardSprints,
            focusSessions: focusSessions,
            referenceDate: referenceDate,
            calendar: calendar,
            modelContext: modelContext,
            showsTimelineTasksInDayPlanner: showsTimelineTasksInDayPlanner,
            hiddenTimelineActivityStorage: hiddenTimelineActivityStorage,
            timelinePlacementCache: timelinePlacementCache,
            allDayBlocksCache: allDayBlocksCache,
            visibleBlockContextCache: visibleBlockContextCache,
            sleepBlocksCache: sleepBlocksCache,
            awayBlocksCache: awayBlocksCache,
            completedSprintFocusBlocksCache: completedSprintFocusBlocksCache,
            activeSprintFocusBlocksCache: activeSprintFocusBlocksCache
        )
        let visibleDates = renderSnapshot.visibleDates
        let allTaskIDs = Set(renderSnapshot.tasks.map(\.id))
        let currentTasks = renderSnapshot.tasks.filter(calendarTaskFilter)
        let currentSleepSessions = renderSnapshot.sleepSessions
        let currentAwaySessions = renderSnapshot.awaySessions
        let currentFocusSessions = renderSnapshot.focusSessions
        let currentSprintFocusAllocations = renderSnapshot.sprintFocusAllocations
        let currentBoardSprints = renderSnapshot.boardSprints
        let plannedBlocksByDayKey = renderSnapshot.plannedBlocksByDayKey
        let rawPlannedBlocks = renderSnapshot.rawPlannedBlocks
        let sleepBlocksByDayKey = renderSnapshot.sleepBlocksByDayKey
        let linkedAwayBlocksByDayKey = renderSnapshot.linkedAwayBlocksByDayKey
        let sprintFocusBlocksByDayKey = renderSnapshot.sprintFocusBlocksByDayKey
        let eventBlocksByDayKey = renderSnapshot.eventBlocksByDayKey
        let blockedIntervalsByDayKey = renderSnapshot.blockedIntervalsByDayKey
        let timelineBlocksByDayKey = renderSnapshot.timelineBlocksByDayKey
        let unplaceableAutomaticSuggestionBlocksByDayKey = renderSnapshot.unplaceableAutomaticSuggestionBlocksByDayKey
        let automaticSuggestionBlocksByDayKey = renderSnapshot.automaticSuggestionBlocksByDayKey
        let assumedDoneSummaryBlocksByDayKey = renderSnapshot.assumedDoneSummaryBlocksByDayKey
        let allDayBlocks = renderSnapshot.allDayBlocks
        let tintsByTaskID = renderSnapshot.tintsByTaskID
        let activeFocusRenderSessions = renderSnapshot.activeFocusRenderSessions
        let activeSprintFocusSessions = renderSnapshot.activeSprintFocusSessions
        let planFocusAllocatedMinutesBySessionID = renderSnapshot.planFocusAllocatedMinutesBySessionID
        let currentTaskIDs = Set(currentTasks.map(\.id))
        let isCalendarTaskFilterActive = currentTaskIDs != allTaskIDs
        let filterAvailability = DayPlanCalendarFilterAvailability(
            includesEvents: includesEvents,
            includesAway: includesAway,
            includesSleep: includesAway
        )
        let calendarFilterState = calendarFilters.wrappedValue.normalized(availability: filterAvailability)
        let dayTaskListVisibilitySignature = DayPlanDayTaskListVisibilitySignature(
            filters: calendarFilterState,
            availability: filterAvailability,
            calendarSearchText: calendarSearchText,
            calendarTaskFilterCacheSeed: calendarTaskFilterCacheSeed
        )
        let timelineSuggestionsVisible = showsTimelineTasksInDayPlanner
            && calendarFilterState.showsTimelineSuggestions
        let calendarSearchTasks = tasksMatchingCalendarSearch(from: currentTasks)
        let calendarSearchTaskIDs = Set(calendarSearchTasks.map(\.id))
        let visibleTimedBlocksByDayKey = filteredBlocksByDayKey(
            plannedBlocksByDayKey,
            filters: calendarFilterState,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let visibleAutomaticSuggestionBlocksByDayKey = filteredTimelineBlocksByDayKey(
            automaticSuggestionBlocksByDayKey,
            filters: calendarFilterState,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let dayTaskListAutomaticSuggestionBlocksByDayKey = filteredTimelineBlocksByDayKey(
            automaticSuggestionBlocksByDayKey,
            filters: calendarFilterState,
            includesAssumedDone: true,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let visibleUnplaceableAutomaticSuggestionBlocksByDayKey = filteredTimelineBlocksByDayKey(
            unplaceableAutomaticSuggestionBlocksByDayKey,
            filters: calendarFilterState,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let dayTaskListUnplaceableAutomaticSuggestionBlocksByDayKey = filteredTimelineBlocksByDayKey(
            unplaceableAutomaticSuggestionBlocksByDayKey,
            filters: calendarFilterState,
            includesAssumedDone: true,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let visibleAssumedDoneSummaryBlocksByDayKey = filteredTimelineBlocksByDayKey(
            assumedDoneSummaryBlocksByDayKey,
            filters: calendarFilterState,
            includesAssumedDone: true,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let visibleTimelineBlocksByDayKey = filteredTimelineBlocksByDayKey(
            timelineBlocksByDayKey,
            filters: calendarFilterState,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let visibleAllDayBlocks = filteredAllDayBlocks(
            allDayBlocks,
            filters: calendarFilterState,
            matchingTaskIDs: calendarSearchTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isCalendarTaskFilterActive
        )
        let scheduleAllDayBlocks = DayPlanScheduleViewVisibility.allDayBlocks(
            visibleAllDayBlocks,
            context: renderSnapshot.visibleBlockContext
        )
        let calendarDayTaskListItems: (Date) -> [DayPlanDayTaskListItem] = { date in
            dayTaskListItems(
                on: date,
                plannedBlocksByDayKey: visibleTimedBlocksByDayKey,
                allDayBlocks: visibleAllDayBlocks,
                plannedDateTasks: calendarFilterState.showsAllDayTasks
                    ? calendarSearchTasks
                    : [],
                tasks: currentTasks,
                logs: logs,
                timelineActivityBlocks: timelineSuggestionsVisible
                    ? dayTimelineActivityBlocks(
                        on: date,
                        automaticSuggestionBlocksByDayKey: dayTaskListAutomaticSuggestionBlocksByDayKey,
                        unplaceableAutomaticSuggestionBlocksByDayKey: dayTaskListUnplaceableAutomaticSuggestionBlocksByDayKey,
                        assumedDoneSummaryBlocksByDayKey: visibleAssumedDoneSummaryBlocksByDayKey
                    )
                    : [],
                visibilitySignature: dayTaskListVisibilitySignature
            )
        }

        VStack(alignment: .leading, spacing: 12) {
            DayPlanWeekCalendarView(
                dates: visibleDates,
                selectedBlockID: planner.selectedBlockID,
                highlightedBlockID: planner.highlightedBlockID,
                highlightedBlockScrollMinute: planner.highlightedBlockScrollMinute,
                selectedDate: planner.selectedDate,
                focusedUnplannedCompletedDate: activeFocusedUnplannedCompletedDate,
                focusedSleep: planner.focusedSleep,
                calendar: calendar,
                hourHeight: CGFloat(planner.calendarHourHeight),
                dropDurationMinutes: planner.durationMinutes,
                calendarTaskViewMode: calendarTaskViewMode,
                showsUnplannedCompletedBadges: !timelineSuggestionsVisible,
                showsHourSpacingControls: planner.visibleRangeMode == .day,
                canDecreaseHourSpacing: planner.canDecreaseDayHourSpacing,
                canIncreaseHourSpacing: planner.canIncreaseDayHourSpacing,
                hourSpacingAccessibilityValue: "\(Int(planner.dayHourSpacing.hourHeight)) points per hour",
                blocksForDate: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return visibleTimedBlocksByDayKey[dayKey] ?? []
                },
                automaticTimelineBlocksForDate: { date in
                    guard timelineSuggestionsVisible else { return [] }
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return DayPlanScheduleViewVisibility.automaticTimelineBlocks(
                        visibleAutomaticSuggestionBlocksByDayKey[dayKey] ?? []
                    )
                },
                unplaceableAutomaticTimelineBlocksForDate: { date in
                    guard timelineSuggestionsVisible else { return [] }
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return DayPlanScheduleViewVisibility.automaticTimelineBlocks(
                        visibleUnplaceableAutomaticSuggestionBlocksByDayKey[dayKey] ?? []
                    )
                },
                eventBlocksForDate: { date in
                    guard calendarFilterState.showsEvents else { return [] }
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return eventBlocksByDayKey[dayKey] ?? []
                },
                sleepBlocksForDate: { date in
                    guard calendarFilterState.showsSleep else { return [] }
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return sleepBlocksByDayKey[dayKey] ?? []
                },
                awayBlocksForDate: { date in
                    guard calendarFilterState.showsAway else { return [] }
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return linkedAwayBlocksByDayKey[dayKey] ?? []
                },
                sprintFocusBlocksForDate: { date in
                    guard calendarFilterState.showsFocus else { return [] }
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return sprintFocusBlocksByDayKey[dayKey] ?? []
                },
                blockedIntervalsForDate: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return blockedIntervalsByDayKey[dayKey] ?? []
                },
                showsActiveFocusBlocks: calendarFilterState.showsFocus && !activeFocusRenderSessions.isEmpty,
                showsActiveSprintFocusBlocks: calendarFilterState.showsFocus && !activeSprintFocusSessions.isEmpty,
                onCalendarWidthChanged: { width in
                    updateAdaptiveVisibleRangeMode(for: width)
                },
                activeFocusSessionBlocks: { now in
                    guard calendarFilterState.showsFocus else { return [] }
                    let sessions = activeFocusRenderSessions.filter { session in
                        guard session.isUnassigned else { return true }
                        let allocatedMinutes = planFocusAllocatedMinutesBySessionID[session.id] ?? 0
                        let elapsedMinutes = Int(floor(session.activeDurationSeconds(at: now) / 60))
                        return allocatedMinutes < elapsedMinutes
                    }
                    return DayPlanFocusSessionBlocks.activeBlocks(
                        from: currentTasks,
                        sessions: sessions,
                        now: now,
                        calendar: calendar,
                        excluding: rawPlannedBlocks
                    )
                },
                activeSprintFocusBlocks: { now in
                    guard calendarFilterState.showsFocus else { return [] }
                    return activeSprintFocusBlocksCache.blocksByDayKey(
                        on: visibleDates,
                        from: activeSprintFocusSessions,
                        allocations: currentSprintFocusAllocations,
                        sprints: currentBoardSprints,
                        tasks: currentTasks,
                        referenceDate: now,
                        calendar: calendar
                    )
                    .values
                    .flatMap { $0 }
                },
                allDayBlocks: scheduleAllDayBlocks,
                unplannedCompletedCount: { date in
                    let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
                    return visibleTimelineBlocksByDayKey[dayKey]?.count ?? 0
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
                dayTaskCounts: { date in
                    DayPlanDayTaskCounts(items: calendarDayTaskListItems(date))
                },
                dayTaskListItems: calendarDayTaskListItems,
                dayTaskTint: { taskID in
                    tintsByTaskID[taskID] ?? .accentColor
                },
                isDayTaskOpenable: { taskID in
                    onOpenTaskDetails != nil && currentTaskIDs.contains(taskID)
                },
                onOpenDayTaskDetails: { taskID in
                    onOpenTaskDetails?(taskID)
                },
                onConfirmAssumedDayTask: { item, date in
                    confirmAssumedDayTask(item, on: date)
                },
                onMarkAssumedDayTaskMissed: { item, date in
                    markAssumedDayTaskMissed(item, on: date)
                },
                onSelectSlot: { date, minute in
                    planner.selectSlot(on: date, startMinute: minute, calendar: calendar, context: modelContext)
                },
                onSelectBlock: { block, date in
                    planner.edit(block, on: date, calendar: calendar, context: modelContext)
                },
                onOpenBlockDetails: { block, date in
                    planner.edit(block, on: date, calendar: calendar, context: modelContext)
                    if currentTasks.contains(where: { $0.id == block.taskID }) {
                        onOpenTaskDetails?(block.taskID)
                    }
                },
                onOpenTimelineTaskDetails: { taskID in
                    if let task = currentTasks.first(where: { $0.id == taskID }) {
                        planner.selectedBlockID = nil
                        planner.selectTask(task)
                    }
                    onOpenTaskDetails?(taskID)
                },
                onOpenEventDetails: { eventID in
                    if let onOpenEventDetails {
                        selectedEventID = nil
                        onOpenEventDetails(eventID)
                    } else {
                        selectedEventID = eventID
                    }
                },
                onOpenFocusTaskDetails: { taskID in
                    if let task = currentTasks.first(where: { $0.id == taskID }) {
                        planner.selectedBlockID = nil
                        planner.selectTask(task)
                        onOpenTaskDetails?(taskID)
                    }
                },
                onOpenAllDayTaskDetails: { taskID in
                    if let task = currentTasks.first(where: { $0.id == taskID }) {
                        planner.selectedBlockID = nil
                        planner.selectTask(task)
                    }
                    onOpenTaskDetails?(taskID)
                },
                onDeleteBlock: { block in
                    planner.deleteBlock(block.id, calendar: calendar, context: modelContext)
                },
                onDecreaseHourSpacing: {
                    planner.decreaseDayHourSpacing()
                },
                onIncreaseHourSpacing: {
                    planner.increaseDayHourSpacing()
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
                    activatePlannerUndoManager()
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
                onBeginResizeBlock: { block, date in
                    activatePlannerUndoManager()
                    planner.beginResizeBlock(block, on: date, calendar: calendar, context: modelContext)
                },
                onResizeBlock: { blockID, date, startMinute, durationMinutes in
                    activatePlannerUndoManager()
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
                onEndResizeBlock: { blockID in
                    activatePlannerUndoManager()
                    planner.endResizeBlock(blockID, calendar: calendar, context: modelContext)
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
                },
                slotSidebarContent: { date, minute, draftDurationMinutes, dismiss in
                    AnyView(
                        DayPlanSlotActionSidebar(
                            date: date,
                            startMinute: minute,
                            durationMinutes: draftDurationMinutes,
                            tasks: DayPlanTaskSorting.availableTasks(from: currentTasks),
                            defaultTaskID: planner.selectedTaskID,
                            now: referenceDate,
                            calendar: calendar,
                            includesAway: includesAway,
                            onCreateTaskBlock: { taskID, durationMinutes in
                                createTaskBlock(
                                    taskID,
                                    on: date,
                                    startMinute: minute,
                                    durationMinutes: durationMinutes,
                                    blockedIntervalsByDayKey: blockedIntervalsByDayKey
                                )
                            },
                            onCreateTaskAndBlock: { title, durationMinutes in
                                createTaskAndBlock(
                                    title: title,
                                    on: date,
                                    startMinute: minute,
                                    durationMinutes: durationMinutes,
                                    blockedIntervalsByDayKey: blockedIntervalsByDayKey
                                )
                            },
                            onLogAway: { preset, title, linkedTaskID, durationMinutes in
                                logAway(
                                    preset: preset,
                                    title: title,
                                    linkedTaskID: linkedTaskID,
                                    on: date,
                                    startMinute: minute,
                                    durationMinutes: durationMinutes,
                                    blockedIntervalsByDayKey: blockedIntervalsByDayKey
                                )
                            },
                            onLogSleep: { durationMinutes in
                                logSleep(
                                    on: date,
                                    startMinute: minute,
                                    durationMinutes: durationMinutes,
                                    blockedIntervalsByDayKey: blockedIntervalsByDayKey
                                )
                            },
                            onDismiss: dismiss
                        )
                    )
                },
                dayTaskListSidebarContent: { date, dismiss in
                    AnyView(
                        DayPlanDayTaskListSidebar(
                            date: date,
                            items: calendarDayTaskListItems(date),
                            taskTint: { taskID in
                                tintsByTaskID[taskID] ?? .accentColor
                            },
                            calendar: calendar,
                            isTaskOpenable: { taskID in
                                onOpenTaskDetails != nil && currentTaskIDs.contains(taskID)
                            },
                            onConfirmAssumedDayTask: { item, date in
                                confirmAssumedDayTask(item, on: date)
                            },
                            onMarkAssumedDayTaskMissed: { item, date in
                                markAssumedDayTaskMissed(item, on: date)
                            },
                            onOpenTaskDetails: { taskID in
                                dismiss()
                                onOpenTaskDetails?(taskID)
                            },
                            onDismiss: dismiss
                        )
                    )
                },
                isFilterSidebarPresented: isCalendarFilterSidebarPresented,
                filterSidebarContent: { dismiss in
                    AnyView(
                        DayPlanCalendarFilterSidebar(
                            filters: calendarFilters,
                            availability: filterAvailability,
                            timelineSuggestionsAvailable: showsTimelineTasksInDayPlanner,
                            onDismiss: dismiss
                        )
                    )
                },
                isDatePickerSidebarPresented: isDatePickerSidebarPresented,
                datePickerSidebarContent: { dismiss in
                    AnyView(
                        DayPlanDatePickerSidebar(
                            selectedDate: selectedDateBinding,
                            summaryTitle: planner.visibleRangeTitle(calendar: calendar),
                            blocksCount: planner.blocks.count,
                            plannedMinutes: planner.plannedMinutes,
                            calendar: calendar,
                            onDismiss: dismiss
                        )
                    )
                },
                isExternalInspectorPresented: isExternalInspectorPresented,
                onSidebarPresentationRequested: onSidebarPresentationRequested
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dayPlanLifecycle(
            planner: planner,
            tasks: currentTasks,
            sleepSessions: currentSleepSessions,
            awaySessions: currentAwaySessions,
            focusSessions: currentFocusSessions,
            calendar: calendar
        )
        .onAppear {
            activatePlannerUndoManager()
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            timelinePlacementCache.requireFullValidation()
            allDayBlocksCache.requireFullValidation()
            visibleBlockContextCache.requireFullValidation()
            sleepBlocksCache.invalidate()
            awayBlocksCache.invalidate()
        }
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

    private func updateAdaptiveVisibleRangeMode(for width: CGFloat) {
#if os(macOS)
        planner.setAdaptiveVisibleRangeMode(
            forAvailableWidth: Double(width),
            isExternalInspectorPresented: isExternalInspectorPresented,
            calendar: calendar,
            context: modelContext
        )
#endif
    }

    private func filteredAllDayBlocks(
        _ blocks: [DayPlanAllDayBlock],
        filters: DayPlanCalendarFilterState,
        matchingTaskIDs: Set<UUID>,
        allTaskIDs: Set<UUID>,
        isTaskFilterActive: Bool
    ) -> [DayPlanAllDayBlock] {
        blocks.filter { block in
            if block.isEvent {
                return filters.showsEvents
            }
            return filters.showsAllDayTasks
                && matchesCalendarSearch(
                    taskID: block.taskID,
                    title: block.title,
                    emoji: block.emoji,
                    matchingTaskIDs: matchingTaskIDs,
                    allTaskIDs: allTaskIDs,
                    isTaskFilterActive: isTaskFilterActive
                )
        }
    }

    private func tasksMatchingCalendarSearch(from tasks: [RoutineTask]) -> [RoutineTask] {
        guard isCalendarSearchActive else { return tasks }
        return DayPlanTaskSorting.filteredTasks(from: tasks, query: calendarSearchText)
    }

    private func filteredBlocksByDayKey(
        _ blocksByDayKey: [String: [DayPlanBlock]],
        filters: DayPlanCalendarFilterState,
        matchingTaskIDs: Set<UUID>,
        allTaskIDs: Set<UUID>,
        isTaskFilterActive: Bool
    ) -> [String: [DayPlanBlock]] {
        return blocksByDayKey.mapValues { blocks in
            blocks.filter { block in
                if block.taskID == FocusSession.unassignedTaskID {
                    guard filters.showsFocus else { return false }
                } else {
                    guard filters.showsPlannedTasks else { return false }
                }
                return matchesCalendarSearch(
                    taskID: block.taskID,
                    title: block.titleSnapshot,
                    emoji: block.emojiSnapshot,
                    matchingTaskIDs: matchingTaskIDs,
                    allTaskIDs: allTaskIDs,
                    isTaskFilterActive: isTaskFilterActive
                )
            }
        }
    }

    private func filteredTimelineBlocksByDayKey(
        _ blocksByDayKey: [String: [DayPlanTimelineActivityBlock]],
        filters: DayPlanCalendarFilterState,
        includesAssumedDone: Bool = false,
        matchingTaskIDs: Set<UUID>,
        allTaskIDs: Set<UUID>,
        isTaskFilterActive: Bool
    ) -> [String: [DayPlanTimelineActivityBlock]] {
        DayPlanCalendarTimelineActivityPresentationFilter.filteredBlocksByDayKey(
            blocksByDayKey,
            filters: filters,
            includesAssumedDone: includesAssumedDone,
            matchingTaskIDs: matchingTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isTaskFilterActive,
            normalizedSearchText: normalizedCalendarSearchText
        )
    }

    private func matchesCalendarSearch(
        taskID: UUID?,
        title: String,
        emoji: String?,
        matchingTaskIDs: Set<UUID>,
        allTaskIDs: Set<UUID>,
        isTaskFilterActive: Bool
    ) -> Bool {
        DayPlanCalendarTaskPresentationFilter.matches(
            taskID: taskID,
            title: title,
            emoji: emoji,
            matchingTaskIDs: matchingTaskIDs,
            allTaskIDs: allTaskIDs,
            isTaskFilterActive: isTaskFilterActive,
            normalizedSearchText: normalizedCalendarSearchText
        )
    }

    private var isCalendarSearchActive: Bool {
        !normalizedCalendarSearchText.isEmpty
    }

    private var normalizedCalendarSearchText: String {
        calendarSearchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func activatePlannerUndoManager() {
        RoutinaUndoSupport.setActiveUndoManager(undoManager)
        RoutinaUndoSupport.setActiveScopedUndo(
            undo: { [weak planner] in
                planner?.performPlannerUndo(calendar: calendar, context: modelContext) == true
            },
            redo: { [weak planner] in
                planner?.performPlannerRedo(calendar: calendar, context: modelContext) == true
            }
        )
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

    private func dayTaskListItems(
        on date: Date,
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        allDayBlocks: [DayPlanAllDayBlock],
        plannedDateTasks: [RoutineTask],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        timelineActivityBlocks: [DayPlanTimelineActivityBlock] = [],
        visibilitySignature: DayPlanDayTaskListVisibilitySignature
    ) -> [DayPlanDayTaskListItem] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        return dayTaskListItemsCache.items(
            dataSnapshotID: dataSnapshotID,
            on: date,
            timedBlocks: plannedBlocksByDayKey[dayKey] ?? [],
            allDayBlocks: allDayBlocks,
            plannedDateTasks: plannedDateTasks,
            timelineActivityBlocks: timelineActivityBlocks,
            tasks: tasks,
            logs: logs,
            calendar: calendar,
            visibilitySignature: visibilitySignature,
            visibilityCache: plannedDateTaskVisibilityCache
        )
    }

    private func dayTimelineActivityBlocks(
        on date: Date,
        automaticSuggestionBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]],
        unplaceableAutomaticSuggestionBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]],
        assumedDoneSummaryBlocksByDayKey: [String: [DayPlanTimelineActivityBlock]]
    ) -> [DayPlanTimelineActivityBlock] {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        var blocks = (automaticSuggestionBlocksByDayKey[dayKey] ?? [])
            + (unplaceableAutomaticSuggestionBlocksByDayKey[dayKey] ?? [])
        let existingIDs = Set(blocks.map(\.id))
        blocks.append(
            contentsOf: (assumedDoneSummaryBlocksByDayKey[dayKey] ?? [])
                .filter { !existingIDs.contains($0.id) }
        )
        return blocks
    }

    private func activeFocusSessions(from sessions: [FocusSession]) -> [FocusSession] {
        sessions
            .filter { $0.completedAt == nil && $0.abandonedAt == nil }
            .sorted { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) }
    }

    private var activeFocusSessions: [FocusSession] {
        activeFocusSessions(from: focusSessions)
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

                if plannedDateTaskVisibilityCache.isDailyRoutineForTaskList(task) {
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

    private func plannedBlockPresentation(
        for dates: [Date],
        visibleBlockContext: DayPlanVisibleBlockContext
    ) -> DayPlanPlannedBlockPresentation {
        var visibleBlocksByDayKey: [String: [DayPlanBlock]] = [:]
        var rawBlocksByDayKey: [String: [DayPlanBlock]] = [:]
        var rawBlocks: [DayPlanBlock] = []
        visibleBlocksByDayKey.reserveCapacity(dates.count)
        rawBlocksByDayKey.reserveCapacity(dates.count)

        for date in dates {
            let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            let blocks = planner.blocks(on: date, calendar: calendar, context: modelContext)
            rawBlocksByDayKey[dayKey] = blocks
            rawBlocks.append(contentsOf: blocks)
        }

        for date in dates {
            let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
            let blocks = rawBlocksByDayKey[dayKey] ?? []
            visibleBlocksByDayKey[dayKey] = DayPlanVisibleBlocks.blocks(
                blocks,
                context: visibleBlockContext,
                activeFocusSegmentSearchBlocks: rawBlocks
            )
        }

        return DayPlanPlannedBlockPresentation(
            visibleBlocksByDayKey: visibleBlocksByDayKey,
            rawBlocks: rawBlocks
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

    private func mergePlannerBlocks(
        _ lhs: [String: [DayPlanBlock]],
        _ rhs: [String: [DayPlanBlock]]
    ) -> [String: [DayPlanBlock]] {
        var result = lhs
        for (dayKey, blocks) in rhs {
            result[dayKey, default: []].append(contentsOf: blocks)
        }
        return result
    }

    private func tintsByTaskID(from tasks: [RoutineTask]) -> [UUID: Color] {
        var result: [UUID: Color] = [:]
        for task in tasks {
            result[task.id] = task.color.swiftUIColor ?? .accentColor
        }
        return result
    }

    private func tintsByTaskID() -> [UUID: Color] {
        tintsByTaskID(from: tasks)
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
        if activity.source.isSyntheticAssumedDone {
            var adjustedActivity = activity
            adjustedActivity.block = DayPlanBlock(
                id: activity.block.id,
                taskID: activity.block.taskID,
                dayKey: DayPlanStorage.dayKey(for: date, calendar: calendar),
                startMinute: startMinute,
                durationMinutes: activity.block.durationMinutes,
                titleSnapshot: activity.block.titleSnapshot,
                emojiSnapshot: activity.block.emojiSnapshot,
                createdAt: activity.block.createdAt,
                updatedAt: activity.block.updatedAt
            )
            planner.confirmTimelineActivity(adjustedActivity, on: date, calendar: calendar, context: modelContext)
            return
        }

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

    private func confirmAssumedDayTask(_ item: DayPlanDayTaskListItem, on date: Date) {
        guard item.section == .assumedDone else { return }
        let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext)
        let referenceDate = Date()
        do {
            _ = try RoutineLogHistory.confirmTaskCompletions(
                taskID: item.taskID,
                on: [date],
                context: context,
                referenceDate: referenceDate,
                calendar: calendar
            )
            WidgetStatsService.refreshAndReload(using: context)
            NotificationCenter.default.postRoutineDidUpdate()
        } catch {
            NSLog("Failed to confirm assumed planner day task: \(error.localizedDescription)")
        }
    }

    private func markAssumedDayTaskMissed(_ item: DayPlanDayTaskListItem, on date: Date) {
        guard item.section == .assumedDone else { return }
        let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext)
        let referenceDate = Date()
        do {
            _ = try RoutineLogHistory.markAssumedCompletionMissed(
                taskID: item.taskID,
                on: date,
                context: context,
                referenceDate: referenceDate,
                calendar: calendar
            )
            WidgetStatsService.refreshAndReload(using: context)
            NotificationCenter.default.postRoutineDidUpdate()
        } catch {
            NSLog("Failed to mark assumed planner day task missed: \(error.localizedDescription)")
        }
    }

    private func createTaskBlock(
        _ taskID: UUID,
        on date: Date,
        startMinute: Int,
        durationMinutes: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) -> String? {
        guard let task = tasks.first(where: { $0.id == taskID }) else {
            return "Choose a task."
        }
        let clampedStart = DayPlanBlock.clampedStartMinute(startMinute)
        let clampedDuration = DayPlanBlock.clampedDuration(
            durationMinutes,
            startMinute: clampedStart
        )

        if let conflict = plannerBlockConflict(on: date, startMinute: clampedStart, durationMinutes: clampedDuration) {
            return "Overlaps \(conflict.titleSnapshot)."
        }
        if let conflict = protectedIntervalConflict(
            on: date,
            startMinute: clampedStart,
            durationMinutes: clampedDuration,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey
        ) {
            return "Overlaps \(conflict.title)."
        }

        planner.selectSlot(on: date, startMinute: clampedStart, calendar: calendar, context: modelContext)
        planner.selectTask(task)
        planner.durationMinutes = clampedDuration
        planner.commitBlock(task: task, calendar: calendar, context: modelContext)
        return nil
    }

    private func createTaskAndBlock(
        title: String,
        on date: Date,
        startMinute: Int,
        durationMinutes: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) -> String? {
        let trimmedTitle = DayPlanSlotTaskPickerPresentation.normalizedNewTaskName(title)
        guard !trimmedTitle.isEmpty else {
            return "Name the task."
        }

        let clampedStart = DayPlanBlock.clampedStartMinute(startMinute)
        let clampedDuration = DayPlanBlock.clampedDuration(
            durationMinutes,
            startMinute: clampedStart
        )

        if let conflict = plannerBlockConflict(on: date, startMinute: clampedStart, durationMinutes: clampedDuration) {
            return "Overlaps \(conflict.titleSnapshot)."
        }
        if let conflict = protectedIntervalConflict(
            on: date,
            startMinute: clampedStart,
            durationMinutes: clampedDuration,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey
        ) {
            return "Overlaps \(conflict.title)."
        }

        let context = RoutinaUndoSupport.undoableMutationContext(from: modelContext)
        let task = RoutineTask(
            name: trimmedTitle,
            plannedDate: date,
            scheduleMode: .oneOff,
            recurrenceRule: .interval(days: 1),
            estimatedDurationMinutes: clampedDuration
        )
        context.insert(task)

        planner.selectSlot(on: date, startMinute: clampedStart, calendar: calendar, context: context)
        planner.selectTask(task)
        planner.durationMinutes = clampedDuration
        planner.commitBlock(task: task, calendar: calendar, context: context)
        NotificationCenter.default.postRoutineDidUpdate()
        return nil
    }

    private func logAway(
        preset: AwaySessionPreset,
        title: String?,
        linkedTaskID: UUID?,
        on date: Date,
        startMinute: Int,
        durationMinutes: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) -> String? {
        let clampedStart = DayPlanBlock.clampedStartMinute(
            startMinute,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        let clampedDuration = DayPlanBlock.clampedDuration(
            durationMinutes,
            startMinute: clampedStart,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        guard let startedAt = slotDate(on: date, startMinute: clampedStart),
              let endedAt = calendar.date(byAdding: .minute, value: clampedDuration, to: startedAt)
        else {
            return "Choose a valid time."
        }
        guard endedAt <= Date() else {
            return "Away logs need an interval that has already ended."
        }
        if let conflict = plannerBlockConflict(on: date, startMinute: clampedStart, durationMinutes: clampedDuration) {
            return "Overlaps \(conflict.titleSnapshot)."
        }
        if let conflict = protectedIntervalConflict(
            on: date,
            startMinute: clampedStart,
            durationMinutes: clampedDuration,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey
        ) {
            return "Overlaps \(conflict.title)."
        }

        do {
            _ = try AwaySessionSupport.logAway(
                preset: preset,
                durationMinutes: clampedDuration,
                title: title,
                linkedTaskID: linkedTaskID,
                startedAt: startedAt,
                context: modelContext
            )
            return nil
        } catch {
            NSLog("Failed to log away session from planner: \(error.localizedDescription)")
            return error.localizedDescription
        }
    }

    private func logSleep(
        on date: Date,
        startMinute: Int,
        durationMinutes: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) -> String? {
        let clampedStart = DayPlanBlock.clampedStartMinute(
            startMinute,
            minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
        )
        let clampedDuration = min(max(durationMinutes, 5), 16 * 60)
        guard let startedAt = slotDate(on: date, startMinute: clampedStart),
              let endedAt = calendar.date(byAdding: .minute, value: clampedDuration, to: startedAt)
        else {
            return "Choose a valid time."
        }
        guard endedAt <= Date() else {
            return "Sleep logs need an interval that has already ended."
        }
        if let conflict = plannerBlockConflict(startedAt: startedAt, endedAt: endedAt) {
            return "Overlaps \(conflict.titleSnapshot)."
        }
        if let conflict = protectedIntervalConflict(
            on: date,
            startMinute: clampedStart,
            durationMinutes: clampedDuration,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey
        ) {
            return "Overlaps \(conflict.title)."
        }

        do {
            _ = try SleepSessionSupport.logSleep(
                durationMinutes: clampedDuration,
                startedAt: startedAt,
                context: modelContext
            )
            return nil
        } catch {
            NSLog("Failed to log sleep session from planner: \(error.localizedDescription)")
            return error.localizedDescription
        }
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

    private func protectedIntervalConflict(
        on date: Date,
        startMinute: Int,
        durationMinutes: Int,
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]]
    ) -> DayPlanBlockedInterval? {
        let dayKey = DayPlanStorage.dayKey(for: date, calendar: calendar)
        guard let intervals = blockedIntervalsByDayKey[dayKey] else { return nil }
        return intervals.first {
            $0.overlaps(startMinute: startMinute, durationMinutes: durationMinutes)
        }
    }

    private func plannerBlockConflict(
        on date: Date,
        startMinute: Int,
        durationMinutes: Int
    ) -> DayPlanBlock? {
        let start = DayPlanBlock.clampedStartMinute(startMinute)
        let duration = DayPlanBlock.clampedDuration(durationMinutes, startMinute: start)
        let end = start + duration
        return DayPlanVisibleBlocks.blocks(
            planner.blocks(on: date, calendar: calendar, context: modelContext),
            tasks: tasks,
            logs: logs,
            calendar: calendar,
            activeFocusSessions: activeTaskAndTagFocusSessions
        )
        .first { block in
            max(start, block.startMinute) < min(end, block.endMinute)
        }
    }

    private func plannerBlockConflict(startedAt: Date, endedAt: Date) -> DayPlanBlock? {
        guard endedAt > startedAt else { return nil }

        var day = calendar.startOfDay(for: startedAt)
        while day < endedAt {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                return nil
            }

            let intervalStart = max(startedAt, day)
            let intervalEnd = min(endedAt, nextDay)
            if intervalEnd > intervalStart {
                let startMinute = minuteOfDay(for: intervalStart)
                let durationMinutes = max(1, Int(ceil(intervalEnd.timeIntervalSince(intervalStart) / 60)))
                if let conflict = plannerBlockConflict(
                    on: day,
                    startMinute: startMinute,
                    durationMinutes: durationMinutes
                ) {
                    return conflict
                }
            }

            day = nextDay
        }

        return nil
    }

    private func minuteOfDay(for date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }

    private func activeTaskAndTagFocusSessions(from sessions: [FocusSession]) -> [FocusSession] {
        sessions.filter { session in
            (session.isTaskFocus || session.isTagFocus)
                && session.startedAt != nil
                && session.completedAt == nil
                && session.abandonedAt == nil
        }
    }

    private var activeTaskAndTagFocusSessions: [FocusSession] {
        activeTaskAndTagFocusSessions(from: focusSessions)
    }

    private func slotDate(on date: Date, startMinute: Int) -> Date? {
        calendar.date(
            byAdding: .minute,
            value: DayPlanBlock.clampedStartMinute(
                startMinute,
                minimumDurationMinutes: DayPlanBlock.minimumStoredDurationMinutes
            ),
            to: calendar.startOfDay(for: date)
        )
    }

    private func plannedBlock(with id: DayPlanBlock.ID) -> DayPlanBlock? {
        planner.weekBlocksByDayKey.values.lazy.compactMap { blocks in
            blocks.first { $0.id == id }
        }
        .first
            ?? planner.blocks.first { $0.id == id }
    }
}

private struct DayPlanPlannedBlockPresentation {
    var visibleBlocksByDayKey: [String: [DayPlanBlock]]
    var rawBlocks: [DayPlanBlock]
}

@MainActor
private final class DayPlanVisibleBlockContextCache: ObservableObject {
    private var cachedReuseSignature: DayPlanVisibleBlockContextReuseSignature?
    private var cachedKey: DayPlanVisibleBlockContextCacheKey?
    private var cachedContext: DayPlanVisibleBlockContext?
    private var requiresFullValidation = false

    func context(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        calendar: Calendar,
        referenceDate: Date,
        activeFocusSessions: [FocusSession]
    ) -> DayPlanVisibleBlockContext {
        let reuseSignature = DayPlanVisibleBlockContextReuseSignature(
            tasks: tasks,
            logs: logs,
            activeFocusSessions: activeFocusSessions,
            calendar: calendar,
            referenceDate: referenceDate
        )

        if !requiresFullValidation, cachedReuseSignature == reuseSignature, let cachedContext {
            return cachedContext
        }

        let key = DayPlanVisibleBlockContextCacheKey(
            tasks: tasks,
            logs: logs,
            activeFocusSessions: activeFocusSessions,
            calendar: calendar,
            referenceDate: referenceDate
        )

        if cachedKey == key, let cachedContext {
            cachedReuseSignature = reuseSignature
            requiresFullValidation = false
            return cachedContext
        }

        let context = DayPlanVisibleBlockContext(
            tasks: tasks,
            logs: logs,
            calendar: calendar,
            referenceDate: referenceDate,
            activeFocusSessions: activeFocusSessions
        )
        cachedReuseSignature = reuseSignature
        cachedKey = key
        cachedContext = context
        requiresFullValidation = false
        return context
    }

    func requireFullValidation() {
        requiresFullValidation = true
    }

    func invalidate() {
        cachedReuseSignature = nil
        cachedKey = nil
        cachedContext = nil
        requiresFullValidation = false
    }
}

private struct DayPlanVisibleBlockContextReuseSignature: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var taskObjects: [ObjectIdentifier]
    var logObjects: [ObjectIdentifier]
    var activeFocusSessionObjects: [ObjectIdentifier]
    var referenceMinute: DayPlanTimelineRenderSnapshotKey.ReferenceMinute

    init(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        activeFocusSessions: [FocusSession],
        calendar: Calendar,
        referenceDate: Date
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        taskObjects = tasks.map { ObjectIdentifier($0) }
        logObjects = logs.map { ObjectIdentifier($0) }
        activeFocusSessionObjects = activeFocusSessions.map { ObjectIdentifier($0) }
        referenceMinute = DayPlanTimelineRenderSnapshotKey.ReferenceMinute(
            referenceDate: referenceDate,
            calendar: calendar
        )
    }
}

private struct DayPlanVisibleBlockContextCacheKey: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var tasks: [TaskSnapshot]
    var logs: [LogSnapshot]
    var activeFocusSessions: [FocusSessionSnapshot]
    var referenceMinute: DayPlanTimelineRenderSnapshotKey.ReferenceMinute

    init(
        tasks: [RoutineTask],
        logs: [RoutineLog],
        activeFocusSessions: [FocusSession],
        calendar: Calendar,
        referenceDate: Date
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        referenceMinute = DayPlanTimelineRenderSnapshotKey.ReferenceMinute(
            referenceDate: referenceDate,
            calendar: calendar
        )
        self.tasks = tasks
            .map(TaskSnapshot.init(task:))
            .sorted { $0.idSortKey < $1.idSortKey }

        let completedKind = RoutineLogKind.completed.rawValue
        let fulfilledKind = RoutineLogKind.fulfilled.rawValue
        let canceledKind = RoutineLogKind.canceled.rawValue
        let missedKind = RoutineLogKind.missed.rawValue
        self.logs = logs
            .compactMap { log -> LogSnapshot? in
                guard log.kindRawValue == completedKind
                    || log.kindRawValue == fulfilledKind
                    || log.kindRawValue == canceledKind
                    || log.kindRawValue == missedKind,
                      log.timestamp != nil else {
                    return nil
                }
                return LogSnapshot(log: log)
            }
            .sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
                }
                if lhs.taskIDSortKey != rhs.taskIDSortKey {
                    return lhs.taskIDSortKey < rhs.taskIDSortKey
                }
                if lhs.kindRawValue != rhs.kindRawValue {
                    return lhs.kindRawValue < rhs.kindRawValue
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.activeFocusSessions = activeFocusSessions
            .map(FocusSessionSnapshot.init(session:))
            .sorted { $0.idSortKey < $1.idSortKey }
    }

    struct TaskSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var scheduleModeRawValue: String
        var recurrenceStorageVersion: Int16
        var recurrenceKindRawValue: String
        var recurrenceTimeOfDayHour: Int?
        var recurrenceTimeOfDayMinute: Int?
        var recurrenceTimeRangeStartHour: Int?
        var recurrenceTimeRangeStartMinute: Int?
        var recurrenceTimeRangeEndHour: Int?
        var recurrenceTimeRangeEndMinute: Int?
        var recurrenceWeekday: Int?
        var recurrenceDayOfMonth: Int?
        var recurrenceRuleStorage: String
        var interval: Int16
        var lastDone: Date?
        var canceledAt: Date?
        var createdAt: Date?
        var pausedAt: Date?
        var snoozedUntil: Date?
        var autoAssumeDailyDone: Bool
        var autoAssumeDoneTimeOfDayHour: Int?
        var autoAssumeDoneTimeOfDayMinute: Int?
        var hasSequentialSteps: Bool
        var hasChecklistItems: Bool

        init(task: RoutineTask) {
            id = task.id
            idSortKey = task.id.uuidString
            scheduleModeRawValue = task.scheduleModeRawValue
            recurrenceStorageVersion = task.recurrenceStorageVersion
            recurrenceKindRawValue = task.recurrenceKindRawValue
            recurrenceTimeOfDayHour = task.recurrenceTimeOfDayHour
            recurrenceTimeOfDayMinute = task.recurrenceTimeOfDayMinute
            recurrenceTimeRangeStartHour = task.recurrenceTimeRangeStartHour
            recurrenceTimeRangeStartMinute = task.recurrenceTimeRangeStartMinute
            recurrenceTimeRangeEndHour = task.recurrenceTimeRangeEndHour
            recurrenceTimeRangeEndMinute = task.recurrenceTimeRangeEndMinute
            recurrenceWeekday = task.recurrenceWeekday
            recurrenceDayOfMonth = task.recurrenceDayOfMonth
            recurrenceRuleStorage = task.recurrenceRuleStorage
            interval = task.interval
            lastDone = task.lastDone
            canceledAt = task.canceledAt
            createdAt = task.createdAt
            pausedAt = task.pausedAt
            snoozedUntil = task.snoozedUntil
            autoAssumeDailyDone = task.autoAssumeDailyDone
            autoAssumeDoneTimeOfDayHour = task.autoAssumeDoneTimeOfDay?.hour
            autoAssumeDoneTimeOfDayMinute = task.autoAssumeDoneTimeOfDay?.minute
            hasSequentialSteps = task.hasSequentialSteps
            hasChecklistItems = task.hasChecklistItems
        }
    }

    struct LogSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var timestamp: Date?
        var taskID: UUID
        var taskIDSortKey: String
        var kindRawValue: String
        var sourceTaskID: UUID?

        init(log: RoutineLog) {
            id = log.id
            idSortKey = log.id.uuidString
            timestamp = log.timestamp
            taskID = log.taskID
            taskIDSortKey = log.taskID.uuidString
            kindRawValue = log.kindRawValue
            sourceTaskID = log.sourceTaskID
        }
    }

    struct FocusSessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var taskID: UUID
        var plannedDurationSeconds: TimeInterval
        var startedAt: Date?
        var completedAt: Date?
        var abandonedAt: Date?
        var pausedAt: Date?
        var tagName: String?

        init(session: FocusSession) {
            id = session.id
            idSortKey = session.id.uuidString
            taskID = session.taskID
            plannedDurationSeconds = session.plannedDurationSeconds
            startedAt = session.startedAt
            completedAt = session.completedAt
            abandonedAt = session.abandonedAt
            pausedAt = session.pausedAt
            tagName = session.tagName
        }
    }
}

@MainActor
private final class DayPlanSleepBlocksCache: ObservableObject {
    private var cachedKey: DayPlanSleepBlocksCacheKey?
    private var cachedBlocksByDayKey: [String: [DayPlanSleepBlock]] = [:]

    func blocksByDayKey(
        on dates: [Date],
        from sessions: [SleepSession],
        referenceDate: Date,
        calendar: Calendar
    ) -> [String: [DayPlanSleepBlock]] {
        let key = DayPlanSleepBlocksCacheKey(
            dates: dates,
            sessions: sessions,
            referenceDate: referenceDate,
            calendar: calendar
        )

        if cachedKey == key {
            return cachedBlocksByDayKey
        }

        let blocksByDayKey = DayPlanSleepBlocks.blocksByDayKey(
            on: dates,
            from: sessions,
            referenceDate: referenceDate,
            calendar: calendar
        )
        cachedKey = key
        cachedBlocksByDayKey = blocksByDayKey
        return blocksByDayKey
    }

    func invalidate() {
        cachedKey = nil
        cachedBlocksByDayKey = [:]
    }
}

private struct DayPlanSleepBlocksCacheKey: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var visibleDayKeys: [String]
    var referenceMinute: ReferenceMinute?
    var sessions: [SessionSnapshot]

    init(
        dates: [Date],
        sessions: [SleepSession],
        referenceDate: Date,
        calendar: Calendar
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        let visibleDayStarts = dates
            .map { calendar.startOfDay(for: $0) }
            .sorted()
        visibleDayKeys = visibleDayStarts
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
        let visibleRangeStart = visibleDayStarts.first
        let visibleRangeEnd = visibleDayStarts.last.flatMap {
            calendar.date(byAdding: .day, value: 1, to: $0)
        }
        let relevantSessions: [SleepSession]
        if let visibleRangeStart, let visibleRangeEnd {
            relevantSessions = sessions.filter { session in
                guard let startedAt = session.startedAt else { return false }
                let endedAt = session.endedAt ?? referenceDate
                return startedAt < visibleRangeEnd && endedAt >= visibleRangeStart
            }
        } else {
            relevantSessions = []
        }
        referenceMinute = relevantSessions.contains { $0.endedAt == nil }
            ? ReferenceMinute(referenceDate: referenceDate, calendar: calendar)
            : nil
        self.sessions = relevantSessions
            .map(SessionSnapshot.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
                }
                return lhs.idSortKey < rhs.idSortKey
            }
    }

    struct ReferenceMinute: Equatable {
        var dayKey: String
        var minute: Int

        init(referenceDate: Date, calendar: Calendar) {
            dayKey = DayPlanStorage.dayKey(for: referenceDate, calendar: calendar)
            let components = calendar.dateComponents([.hour, .minute], from: referenceDate)
            minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        }
    }

    struct SessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var startedAt: Date?
        var endedAt: Date?

        init(session: SleepSession) {
            id = session.id
            idSortKey = session.id.uuidString
            startedAt = session.startedAt
            endedAt = session.endedAt
        }
    }
}

@MainActor
private final class DayPlanAwayBlocksCache: ObservableObject {
    private var cachedKey: DayPlanAwayBlocksCacheKey?
    private var cachedBlocksByDayKey: [String: [DayPlanAwayBlock]] = [:]

    func blocksByDayKey(
        on dates: [Date],
        from sessions: [AwaySession],
        tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) -> [String: [DayPlanAwayBlock]] {
        let key = DayPlanAwayBlocksCacheKey(
            dates: dates,
            sessions: sessions,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )

        if cachedKey == key {
            return cachedBlocksByDayKey
        }

        let blocksByDayKey = DayPlanAwayBlocks.blocksByDayKey(
            on: dates,
            from: sessions,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        cachedKey = key
        cachedBlocksByDayKey = blocksByDayKey
        return blocksByDayKey
    }

    func invalidate() {
        cachedKey = nil
        cachedBlocksByDayKey = [:]
    }
}

private struct DayPlanAwayBlocksCacheKey: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var visibleDayKeys: [String]
    var referenceMinute: ReferenceMinute?
    var sessions: [SessionSnapshot]
    var tasks: [TaskSnapshot]

    init(
        dates: [Date],
        sessions: [AwaySession],
        tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        let visibleDayStarts = dates
            .map { calendar.startOfDay(for: $0) }
            .sorted()
        visibleDayKeys = visibleDayStarts
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
        let visibleRangeStart = visibleDayStarts.first
        let visibleRangeEnd = visibleDayStarts.last.flatMap {
            calendar.date(byAdding: .day, value: 1, to: $0)
        }
        let relevantSessions: [AwaySession]
        if let visibleRangeStart, let visibleRangeEnd {
            relevantSessions = sessions.filter { session in
                guard let startedAt = session.startedAt else { return false }
                let endedAt = session.finishedAt ?? session.plannedEndAt ?? referenceDate
                return startedAt < visibleRangeEnd && endedAt >= visibleRangeStart
            }
        } else {
            relevantSessions = []
        }
        referenceMinute = relevantSessions.contains { $0.isActive && $0.plannedEndAt == nil }
            ? ReferenceMinute(referenceDate: referenceDate, calendar: calendar)
            : nil
        self.sessions = relevantSessions
            .map(SessionSnapshot.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
                }
                return lhs.idSortKey < rhs.idSortKey
            }

        let linkedTaskIDs = Set(relevantSessions.compactMap(\.linkedTaskID))
        self.tasks = tasks
            .filter { linkedTaskIDs.contains($0.id) }
            .map(TaskSnapshot.init(task:))
            .sorted { $0.idSortKey < $1.idSortKey }
    }

    struct ReferenceMinute: Equatable {
        var dayKey: String
        var minute: Int

        init(referenceDate: Date, calendar: Calendar) {
            dayKey = DayPlanStorage.dayKey(for: referenceDate, calendar: calendar)
            let components = calendar.dateComponents([.hour, .minute], from: referenceDate)
            minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        }
    }

    struct SessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var presetRawValue: String
        var title: String
        var linkedTaskID: UUID?
        var linkedTaskIDSortKey: String?
        var startedAt: Date?
        var plannedDurationSeconds: TimeInterval
        var completedAt: Date?
        var endedEarlyAt: Date?

        init(session: AwaySession) {
            id = session.id
            idSortKey = session.id.uuidString
            presetRawValue = session.presetRawValue
            title = session.title
            linkedTaskID = session.linkedTaskID
            linkedTaskIDSortKey = session.linkedTaskID?.uuidString
            startedAt = session.startedAt
            plannedDurationSeconds = session.plannedDurationSeconds
            completedAt = session.completedAt
            endedEarlyAt = session.endedEarlyAt
        }
    }

    struct TaskSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var name: String?
        var emoji: String?

        init(task: RoutineTask) {
            id = task.id
            idSortKey = task.id.uuidString
            name = task.name
            emoji = task.emoji
        }
    }
}

@MainActor
private final class DayPlanSprintFocusBlocksCache: ObservableObject {
    private var cachedKey: DayPlanSprintFocusBlocksCacheKey?
    private var cachedBlocksByDayKey: [String: [DayPlanSprintFocusBlock]] = [:]

    func blocksByDayKey(
        on dates: [Date],
        from sessions: [SprintFocusSessionRecord],
        allocations: [SprintFocusAllocationRecord],
        sprints: [BoardSprintRecord],
        tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) -> [String: [DayPlanSprintFocusBlock]] {
        let key = DayPlanSprintFocusBlocksCacheKey(
            dates: dates,
            sessions: sessions,
            allocations: allocations,
            sprints: sprints,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )

        if cachedKey == key {
            return cachedBlocksByDayKey
        }

        let blocksByDayKey = DayPlanSprintFocusBlocks.blocksByDayKey(
            on: dates,
            from: sessions,
            allocations: allocations,
            sprints: sprints,
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar
        )
        cachedKey = key
        cachedBlocksByDayKey = blocksByDayKey
        return blocksByDayKey
    }

    func invalidate() {
        cachedKey = nil
        cachedBlocksByDayKey = [:]
    }
}

private struct DayPlanSprintFocusBlocksCacheKey: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var visibleDayKeys: [String]
    var referenceMinute: ReferenceMinute?
    var sessions: [SessionSnapshot]
    var allocations: [AllocationSnapshot]
    var sprints: [SprintSnapshot]
    var tasks: [TaskSnapshot]

    init(
        dates: [Date],
        sessions: [SprintFocusSessionRecord],
        allocations: [SprintFocusAllocationRecord],
        sprints: [BoardSprintRecord],
        tasks: [RoutineTask],
        referenceDate: Date,
        calendar: Calendar
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        let visibleDayStarts = dates
            .map { calendar.startOfDay(for: $0) }
            .sorted()
        visibleDayKeys = visibleDayStarts
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
        let visibleRangeStart = visibleDayStarts.first
        let visibleRangeEnd = visibleDayStarts.last.flatMap {
            calendar.date(byAdding: .day, value: 1, to: $0)
        }
        let relevantSessions: [SprintFocusSessionRecord]
        if let visibleRangeStart, let visibleRangeEnd {
            relevantSessions = sessions.filter { session in
                let sessionEnd = max(session.stoppedAt ?? referenceDate, session.startedAt)
                return session.startedAt < visibleRangeEnd && sessionEnd >= visibleRangeStart
            }
        } else {
            relevantSessions = []
        }
        let relevantSessionIDs = Set(relevantSessions.map(\.id))
        let relevantSprintIDs = Set(relevantSessions.map(\.sprintID))
        let relevantAllocations = allocations.filter {
            relevantSessionIDs.contains($0.sessionID) && $0.minutes > 0
        }
        let allocatedTaskIDs = Set(relevantAllocations.map(\.taskID))

        referenceMinute = relevantSessions.contains(where: \.isActive)
            ? ReferenceMinute(referenceDate: referenceDate, calendar: calendar)
            : nil
        self.sessions = relevantSessions
            .map(SessionSnapshot.init(session:))
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return lhs.startedAt < rhs.startedAt
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.allocations = relevantAllocations
            .map(AllocationSnapshot.init(allocation:))
            .sorted { lhs, rhs in
                if lhs.sessionID != rhs.sessionID {
                    return lhs.sessionIDSortKey < rhs.sessionIDSortKey
                }
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.idSortKey < rhs.idSortKey
            }
        self.sprints = sprints
            .filter { relevantSprintIDs.contains($0.id) }
            .map(SprintSnapshot.init(sprint:))
            .sorted { $0.idSortKey < $1.idSortKey }
        self.tasks = tasks
            .filter { allocatedTaskIDs.contains($0.id) }
            .map(TaskSnapshot.init(task:))
            .sorted { $0.idSortKey < $1.idSortKey }
    }

    struct ReferenceMinute: Equatable {
        var dayKey: String
        var minute: Int

        init(referenceDate: Date, calendar: Calendar) {
            dayKey = DayPlanStorage.dayKey(for: referenceDate, calendar: calendar)
            let components = calendar.dateComponents([.hour, .minute], from: referenceDate)
            minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
        }
    }

    struct SessionSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var sprintID: UUID
        var startedAt: Date
        var stoppedAt: Date?
        var pausedAt: Date?
        var accumulatedPausedSeconds: TimeInterval

        init(session: SprintFocusSessionRecord) {
            id = session.id
            idSortKey = session.id.uuidString
            sprintID = session.sprintID
            startedAt = session.startedAt
            stoppedAt = session.stoppedAt
            pausedAt = session.pausedAt
            accumulatedPausedSeconds = session.accumulatedPausedSeconds
        }
    }

    struct AllocationSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var sessionID: UUID
        var sessionIDSortKey: String
        var taskID: UUID
        var minutes: Int
        var sortOrder: Int

        init(allocation: SprintFocusAllocationRecord) {
            id = allocation.id
            idSortKey = allocation.id.uuidString
            sessionID = allocation.sessionID
            sessionIDSortKey = allocation.sessionID.uuidString
            taskID = allocation.taskID
            minutes = allocation.minutes
            sortOrder = allocation.sortOrder
        }
    }

    struct SprintSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var title: String

        init(sprint: BoardSprintRecord) {
            id = sprint.id
            idSortKey = sprint.id.uuidString
            title = sprint.title
        }
    }

    struct TaskSnapshot: Equatable {
        var id: UUID
        var idSortKey: String
        var name: String?
        var emoji: String?

        init(task: RoutineTask) {
            id = task.id
            idSortKey = task.id.uuidString
            name = task.name
            emoji = task.emoji
        }
    }
}

@MainActor
private final class DayPlanAllDayBlocksCache: ObservableObject {
    private var cachedReuseSignature: DayPlanAllDayBlocksReuseSignature?
    private var cachedFastSignature: DayPlanAllDayBlocksFastSignature?
    private var cachedKey: DayPlanAllDayBlocksCacheKey?
    private var cachedBlocks: [DayPlanAllDayBlock] = []
    private var requiresFullValidation = false

    func blocks(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        events: [RoutineEvent],
        calendar: Calendar
    ) -> [DayPlanAllDayBlock] {
        let reuseSignature = DayPlanAllDayBlocksReuseSignature(
            dates: dates,
            tasks: tasks,
            logs: logs,
            events: events,
            calendar: calendar
        )

        if !requiresFullValidation, cachedReuseSignature == reuseSignature, cachedKey != nil {
            return cachedBlocks
        }

        let fastSignature = DayPlanAllDayBlocksFastSignature(
            dates: dates,
            tasks: tasks,
            logs: logs,
            events: events,
            calendar: calendar
        )

        if !requiresFullValidation, cachedFastSignature == fastSignature, cachedKey != nil {
            cachedReuseSignature = reuseSignature
            return cachedBlocks
        }

        let key = DayPlanAllDayBlocksCacheKey(
            dates: dates,
            tasks: tasks,
            logs: logs,
            events: events,
            calendar: calendar
        )

        if cachedKey == key {
            cachedReuseSignature = reuseSignature
            cachedFastSignature = fastSignature
            requiresFullValidation = false
            return cachedBlocks
        }

        let blocks = DayPlanAllDayTasks.blocks(
            on: dates,
            from: tasks,
            logs: logs,
            events: events,
            calendar: calendar
        )
        cachedReuseSignature = reuseSignature
        cachedFastSignature = fastSignature
        cachedKey = key
        cachedBlocks = blocks
        requiresFullValidation = false
        return blocks
    }

    func requireFullValidation() {
        requiresFullValidation = true
    }

    func invalidate() {
        cachedReuseSignature = nil
        cachedFastSignature = nil
        cachedKey = nil
        cachedBlocks = []
        requiresFullValidation = false
    }
}

private struct DayPlanAllDayBlocksReuseSignature: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var visibleDayKeys: [String]
    var taskObjects: [ObjectIdentifier]
    var logObjects: [ObjectIdentifier]
    var eventObjects: [ObjectIdentifier]

    init(
        dates: [Date],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        events: [RoutineEvent],
        calendar: Calendar
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        visibleDayKeys = dates
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
            .sorted()
        taskObjects = tasks.map { ObjectIdentifier($0) }
        logObjects = logs.map { ObjectIdentifier($0) }
        eventObjects = events.map { ObjectIdentifier($0) }
    }
}

private struct DayPlanAllDayBlocksFastSignature: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var visibleDayKeys: [String]
    var taskIDs: Set<UUID>
    var logIDs: Set<UUID>
    var eventIDs: Set<UUID>

    init(
        dates: [Date],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        events: [RoutineEvent],
        calendar: Calendar
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        visibleDayKeys = dates
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
            .sorted()
        taskIDs = Set(tasks.map(\.id))
        logIDs = Set(logs.map(\.id))
        eventIDs = Set(events.map(\.id))
    }
}

private struct DayPlanAllDayBlocksCacheKey: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var visibleDayKeys: [String]
    var tasks: [TaskSnapshot]
    var logs: [LogSnapshot]
    var events: [EventSnapshot]

    init(
        dates: [Date],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        events: [RoutineEvent],
        calendar: Calendar
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        visibleDayKeys = dates
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
            .sorted()
        self.tasks = tasks
            .map { TaskSnapshot(task: $0) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        self.logs = logs
            .map { LogSnapshot(log: $0) }
            .sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        self.events = events
            .map { EventSnapshot(event: $0) }
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    struct TaskSnapshot: Equatable {
        var id: UUID
        var name: String?
        var emoji: String?
        var notes: String?
        var deadline: Date?
        var isAllDay: Bool
        var routineDurationModeRawValue: String
        var availabilityStartDate: Date?
        var availabilityEndDate: Date?
        var scheduleModeRawValue: String
        var recurrenceStorageVersion: Int16
        var recurrenceKindRawValue: String
        var recurrenceTimeOfDayHour: Int?
        var recurrenceTimeOfDayMinute: Int?
        var recurrenceTimeRangeStartHour: Int?
        var recurrenceTimeRangeStartMinute: Int?
        var recurrenceTimeRangeEndHour: Int?
        var recurrenceTimeRangeEndMinute: Int?
        var recurrenceWeekday: Int?
        var recurrenceDayOfMonth: Int?
        var recurrenceRuleStorage: String
        var interval: Int16
        var lastDone: Date?
        var canceledAt: Date?
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var snoozedUntil: Date?
        var createdAt: Date?

        init(task: RoutineTask) {
            id = task.id
            name = task.name
            emoji = task.emoji
            notes = task.notes
            deadline = task.deadline
            isAllDay = task.isAllDay
            routineDurationModeRawValue = task.routineDurationModeRawValue
            availabilityStartDate = task.availabilityStartDate
            availabilityEndDate = task.availabilityEndDate
            scheduleModeRawValue = task.scheduleModeRawValue
            recurrenceStorageVersion = task.recurrenceStorageVersion
            recurrenceKindRawValue = task.recurrenceKindRawValue
            recurrenceTimeOfDayHour = task.recurrenceTimeOfDayHour
            recurrenceTimeOfDayMinute = task.recurrenceTimeOfDayMinute
            recurrenceTimeRangeStartHour = task.recurrenceTimeRangeStartHour
            recurrenceTimeRangeStartMinute = task.recurrenceTimeRangeStartMinute
            recurrenceTimeRangeEndHour = task.recurrenceTimeRangeEndHour
            recurrenceTimeRangeEndMinute = task.recurrenceTimeRangeEndMinute
            recurrenceWeekday = task.recurrenceWeekday
            recurrenceDayOfMonth = task.recurrenceDayOfMonth
            recurrenceRuleStorage = task.recurrenceRuleStorage
            interval = task.interval
            lastDone = task.lastDone
            canceledAt = task.canceledAt
            scheduleAnchor = task.scheduleAnchor
            pausedAt = task.pausedAt
            snoozedUntil = task.snoozedUntil
            createdAt = task.createdAt
        }
    }

    struct LogSnapshot: Equatable {
        var id: UUID
        var timestamp: Date?
        var taskID: UUID
        var kindRawValue: String
        var sourceTaskID: UUID?

        init(log: RoutineLog) {
            id = log.id
            timestamp = log.timestamp
            taskID = log.taskID
            kindRawValue = log.kindRawValue
            sourceTaskID = log.sourceTaskID
        }
    }

    struct EventSnapshot: Equatable {
        var id: UUID
        var title: String?
        var emoji: String?
        var isAllDay: Bool
        var startedAt: Date?
        var endedAt: Date?

        init(event: RoutineEvent) {
            id = event.id
            title = event.title
            emoji = event.emoji
            isAllDay = event.isAllDay
            startedAt = event.startedAt
            endedAt = event.endedAt
        }
    }
}

@MainActor
private final class DayPlanTimelinePlacementCache: ObservableObject {
    private var cachedReuseSignature: DayPlanTimelinePlacementReuseSignature?
    private var cachedFastSignature: DayPlanTimelinePlacementFastSignature?
    private var cachedKey: DayPlanTimelinePlacementCacheKey?
    private var cachedPlacements: [String: DayPlanTimelineActivityPlacement] = [:]
    private var requiresFullValidation = false

    func automaticSuggestionPlacementsByDayKey(
        on dates: [Date],
        from tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]] = [:],
        calendar: Calendar,
        hiddenActivityIDs: Set<String> = [],
        referenceDate: Date = Date()
    ) -> [String: DayPlanTimelineActivityPlacement] {
        let reuseSignature = DayPlanTimelinePlacementReuseSignature(
            dates: dates,
            tasks: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            referenceDate: referenceDate
        )

        if !requiresFullValidation, cachedReuseSignature == reuseSignature, cachedKey != nil {
            return cachedPlacements
        }

        let fastSignature = DayPlanTimelinePlacementFastSignature(
            dates: dates,
            tasks: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            referenceDate: referenceDate
        )

        if !requiresFullValidation, cachedFastSignature == fastSignature, cachedKey != nil {
            cachedReuseSignature = reuseSignature
            return cachedPlacements
        }

        let key = DayPlanTimelinePlacementCacheKey(
            dates: dates,
            tasks: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            referenceDate: referenceDate
        )

        if cachedKey == key {
            cachedReuseSignature = reuseSignature
            cachedFastSignature = fastSignature
            requiresFullValidation = false
            return cachedPlacements
        }

        let placements = DayPlanTimelineTasks.automaticSuggestionPlacementsByDayKey(
            on: dates,
            from: tasks,
            logs: logs,
            plannedBlocksByDayKey: plannedBlocksByDayKey,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            hiddenActivityIDs: hiddenActivityIDs,
            referenceDate: referenceDate
        )
        cachedReuseSignature = reuseSignature
        cachedFastSignature = fastSignature
        cachedKey = key
        cachedPlacements = placements
        requiresFullValidation = false
        return placements
    }

    func requireFullValidation() {
        requiresFullValidation = true
    }

    func invalidate() {
        cachedReuseSignature = nil
        cachedFastSignature = nil
        cachedKey = nil
        cachedPlacements = [:]
        requiresFullValidation = false
    }
}

private struct DayPlanTimelinePlacementReuseSignature: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var referenceRenderBucket: DayPlanTimelineReferenceRenderBucket
    var visibleDayKeys: [String]
    var hiddenActivityIDs: [String]
    var taskObjects: [ObjectIdentifier]
    var logObjects: [ObjectIdentifier]
    var plannedDays: [DayPlanTimelinePlacementCacheKey.DayBlocksSnapshot]
    var blockedDays: [DayPlanTimelinePlacementCacheKey.DayBlockedIntervalsSnapshot]

    init(
        dates: [Date],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]],
        calendar: Calendar,
        hiddenActivityIDs: Set<String>,
        referenceDate: Date
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        referenceRenderBucket = DayPlanTimelineReferenceRenderBucket(
            dates: dates,
            calendar: calendar,
            referenceDate: referenceDate
        )
        visibleDayKeys = dates
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
            .sorted()
        self.hiddenActivityIDs = hiddenActivityIDs.sorted()
        taskObjects = tasks.map { ObjectIdentifier($0) }
        logObjects = logs.map { ObjectIdentifier($0) }
        plannedDays = plannedBlocksByDayKey
            .map { dayKey, blocks in
                DayPlanTimelinePlacementCacheKey.DayBlocksSnapshot(dayKey: dayKey, blocks: blocks)
            }
            .sorted { $0.dayKey < $1.dayKey }
        blockedDays = blockedIntervalsByDayKey
            .map { dayKey, intervals in
                DayPlanTimelinePlacementCacheKey.DayBlockedIntervalsSnapshot(dayKey: dayKey, intervals: intervals)
            }
            .sorted { $0.dayKey < $1.dayKey }
    }
}

private struct DayPlanTimelineReferenceRenderBucket: Equatable {
    var referenceDayKey: String
    var visibleCurrentMinute: Int?

    init(
        dates: [Date],
        calendar: Calendar,
        referenceDate: Date
    ) {
        referenceDayKey = DayPlanStorage.dayKey(for: referenceDate, calendar: calendar)
        let visibleDayKeys = Set(dates.map { DayPlanStorage.dayKey(for: $0, calendar: calendar) })
        guard visibleDayKeys.contains(referenceDayKey) else {
            visibleCurrentMinute = nil
            return
        }

        let components = calendar.dateComponents([.hour, .minute], from: referenceDate)
        visibleCurrentMinute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
    }
}

private struct DayPlanTimelinePlacementFastSignature: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var referenceAssumptionBucket: DayPlanTimelineReferenceAssumptionBucket
    var visibleDayKeys: [String]
    var hiddenActivityIDs: Set<String>
    var taskIDs: Set<UUID>
    var logIDs: Set<UUID>
    var plannedDays: [DayPlanTimelinePlacementCacheKey.DayBlocksSnapshot]
    var blockedDays: [DayPlanTimelinePlacementCacheKey.DayBlockedIntervalsSnapshot]

    init(
        dates: [Date],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]],
        calendar: Calendar,
        hiddenActivityIDs: Set<String>,
        referenceDate: Date
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        referenceAssumptionBucket = DayPlanTimelineReferenceAssumptionBucket(
            dates: dates,
            tasks: tasks,
            calendar: calendar,
            referenceDate: referenceDate
        )
        visibleDayKeys = dates
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
            .sorted()
        self.hiddenActivityIDs = hiddenActivityIDs
        taskIDs = Set(tasks.map(\.id))
        logIDs = Set(logs.map(\.id))
        plannedDays = plannedBlocksByDayKey
            .map { dayKey, blocks in
                DayPlanTimelinePlacementCacheKey.DayBlocksSnapshot(dayKey: dayKey, blocks: blocks)
            }
            .sorted { $0.dayKey < $1.dayKey }
        blockedDays = blockedIntervalsByDayKey
            .map { dayKey, intervals in
                DayPlanTimelinePlacementCacheKey.DayBlockedIntervalsSnapshot(dayKey: dayKey, intervals: intervals)
            }
            .sorted { $0.dayKey < $1.dayKey }
    }
}

private struct DayPlanTimelinePlacementCacheKey: Equatable {
    var calendarIdentifier: String
    var timeZoneIdentifier: String
    var firstWeekday: Int
    var minimumDaysInFirstWeek: Int
    var referenceAssumptionBucket: DayPlanTimelineReferenceAssumptionBucket
    var visibleDayKeys: [String]
    var hiddenActivityIDs: [String]
    var tasks: [TaskSnapshot]
    var logs: [LogSnapshot]
    var plannedDays: [DayBlocksSnapshot]
    var blockedDays: [DayBlockedIntervalsSnapshot]

    init(
        dates: [Date],
        tasks: [RoutineTask],
        logs: [RoutineLog],
        plannedBlocksByDayKey: [String: [DayPlanBlock]],
        blockedIntervalsByDayKey: [String: [DayPlanBlockedInterval]],
        calendar: Calendar,
        hiddenActivityIDs: Set<String>,
        referenceDate: Date
    ) {
        calendarIdentifier = String(describing: calendar.identifier)
        timeZoneIdentifier = calendar.timeZone.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
        referenceAssumptionBucket = DayPlanTimelineReferenceAssumptionBucket(
            dates: dates,
            tasks: tasks,
            calendar: calendar,
            referenceDate: referenceDate
        )
        visibleDayKeys = dates
            .map { DayPlanStorage.dayKey(for: $0, calendar: calendar) }
            .sorted()
        self.hiddenActivityIDs = hiddenActivityIDs.sorted()
        self.tasks = tasks
            .map { TaskSnapshot(task: $0) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
        self.logs = logs
            .map { LogSnapshot(log: $0) }
            .sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp {
                    return (lhs.timestamp ?? .distantPast) < (rhs.timestamp ?? .distantPast)
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        plannedDays = plannedBlocksByDayKey
            .map { dayKey, blocks in
                DayBlocksSnapshot(dayKey: dayKey, blocks: blocks)
            }
            .sorted { $0.dayKey < $1.dayKey }
        blockedDays = blockedIntervalsByDayKey
            .map { dayKey, intervals in
                DayBlockedIntervalsSnapshot(dayKey: dayKey, intervals: intervals)
            }
            .sorted { $0.dayKey < $1.dayKey }
    }

    struct TaskSnapshot: Equatable {
        var id: UUID
        var name: String?
        var emoji: String?
        var isAllDay: Bool
        var scheduleModeRawValue: String
        var recurrenceStorageVersion: Int16
        var recurrenceKindRawValue: String
        var recurrenceTimeOfDayHour: Int?
        var recurrenceTimeOfDayMinute: Int?
        var recurrenceTimeRangeStartHour: Int?
        var recurrenceTimeRangeStartMinute: Int?
        var recurrenceTimeRangeEndHour: Int?
        var recurrenceTimeRangeEndMinute: Int?
        var recurrenceWeekday: Int?
        var recurrenceDayOfMonth: Int?
        var recurrenceRuleStorage: String
        var interval: Int16
        var lastDone: Date?
        var canceledAt: Date?
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var snoozedUntil: Date?
        var createdAt: Date?
        var autoAssumeDailyDone: Bool
        var autoAssumeDoneTimeOfDayHour: Int?
        var autoAssumeDoneTimeOfDayMinute: Int?
        var estimatedDurationMinutes: Int?
        var hasStoredSequentialSteps: Bool
        var hasStoredChecklistItems: Bool
        var autoAssumeChecklistItemsStorage: String?
        var autoAssumeCompletedChecklistItemIDsStorage: String?
        var autoAssumeCompletedChecklistProgressStartedAt: Date?

        init(task: RoutineTask) {
            id = task.id
            name = task.name
            emoji = task.emoji
            let autoAssumeDailyDone = task.autoAssumeDailyDone
            let checklistItemsStorage = task.checklistItemsStorage
            isAllDay = task.isAllDay
            scheduleModeRawValue = task.scheduleModeRawValue
            recurrenceStorageVersion = task.recurrenceStorageVersion
            recurrenceKindRawValue = task.recurrenceKindRawValue
            recurrenceTimeOfDayHour = task.recurrenceTimeOfDayHour
            recurrenceTimeOfDayMinute = task.recurrenceTimeOfDayMinute
            recurrenceTimeRangeStartHour = task.recurrenceTimeRangeStartHour
            recurrenceTimeRangeStartMinute = task.recurrenceTimeRangeStartMinute
            recurrenceTimeRangeEndHour = task.recurrenceTimeRangeEndHour
            recurrenceTimeRangeEndMinute = task.recurrenceTimeRangeEndMinute
            recurrenceWeekday = task.recurrenceWeekday
            recurrenceDayOfMonth = task.recurrenceDayOfMonth
            recurrenceRuleStorage = task.recurrenceRuleStorage
            interval = task.interval
            lastDone = task.lastDone
            canceledAt = task.canceledAt
            scheduleAnchor = task.scheduleAnchor
            pausedAt = task.pausedAt
            snoozedUntil = task.snoozedUntil
            createdAt = task.createdAt
            self.autoAssumeDailyDone = autoAssumeDailyDone
            autoAssumeDoneTimeOfDayHour = autoAssumeDailyDone ? task.autoAssumeDoneTimeOfDayHour : nil
            autoAssumeDoneTimeOfDayMinute = autoAssumeDailyDone ? task.autoAssumeDoneTimeOfDayMinute : nil
            estimatedDurationMinutes = task.estimatedDurationMinutes
            hasStoredSequentialSteps = !task.stepsStorage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            hasStoredChecklistItems = !checklistItemsStorage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            autoAssumeChecklistItemsStorage = autoAssumeDailyDone ? checklistItemsStorage : nil
            autoAssumeCompletedChecklistItemIDsStorage = autoAssumeDailyDone
                ? task.completedChecklistItemIDsStorage
                : nil
            autoAssumeCompletedChecklistProgressStartedAt = autoAssumeDailyDone
                ? task.completedChecklistProgressStartedAt
                : nil
        }
    }

    struct LogSnapshot: Equatable {
        var id: UUID
        var timestamp: Date?
        var taskID: UUID
        var kindRawValue: String
        var actualDurationMinutes: Int?
        var sourceTaskID: UUID?

        init(log: RoutineLog) {
            id = log.id
            timestamp = log.timestamp
            taskID = log.taskID
            kindRawValue = log.kindRawValue
            actualDurationMinutes = log.actualDurationMinutes
            sourceTaskID = log.sourceTaskID
        }
    }

    struct DayBlocksSnapshot: Equatable {
        var dayKey: String
        var blocks: [BlockSnapshot]

        init(dayKey: String, blocks: [DayPlanBlock]) {
            self.dayKey = dayKey
            self.blocks = blocks
                .map { BlockSnapshot(block: $0) }
                .sorted { lhs, rhs in
                    if lhs.dayKey != rhs.dayKey {
                        return lhs.dayKey < rhs.dayKey
                    }
                    if lhs.startMinute != rhs.startMinute {
                        return lhs.startMinute < rhs.startMinute
                    }
                    if lhs.durationMinutes != rhs.durationMinutes {
                        return lhs.durationMinutes < rhs.durationMinutes
                    }
                    return lhs.taskID.uuidString < rhs.taskID.uuidString
                }
        }
    }

    struct BlockSnapshot: Equatable {
        var taskID: UUID
        var dayKey: String
        var startMinute: Int
        var durationMinutes: Int

        init(block: DayPlanBlock) {
            taskID = block.taskID
            dayKey = block.dayKey
            startMinute = block.startMinute
            durationMinutes = block.durationMinutes
        }
    }

    struct DayBlockedIntervalsSnapshot: Equatable {
        var dayKey: String
        var intervals: [BlockedIntervalSnapshot]

        init(dayKey: String, intervals: [DayPlanBlockedInterval]) {
            self.dayKey = dayKey
            self.intervals = intervals
                .map { BlockedIntervalSnapshot(interval: $0) }
                .sorted { lhs, rhs in
                    if lhs.startMinute != rhs.startMinute {
                        return lhs.startMinute < rhs.startMinute
                    }
                    return lhs.endMinute < rhs.endMinute
                }
        }
    }

    struct BlockedIntervalSnapshot: Equatable {
        var dayKey: String
        var startMinute: Int
        var endMinute: Int

        init(interval: DayPlanBlockedInterval) {
            dayKey = interval.dayKey
            startMinute = interval.startMinute
            endMinute = interval.endMinute
        }
    }
}

private struct DayPlanTimelineReferenceAssumptionBucket: Equatable {
    var referenceDayKey: String
    var passedAvailabilityBoundaryCount: Int

    init(
        dates: [Date],
        tasks: [RoutineTask],
        calendar: Calendar,
        referenceDate: Date
    ) {
        let today = calendar.startOfDay(for: referenceDate)
        referenceDayKey = DayPlanStorage.dayKey(for: today, calendar: calendar)

        let visibleDayKeys = Set(dates.map { DayPlanStorage.dayKey(for: $0, calendar: calendar) })
        guard visibleDayKeys.contains(referenceDayKey) else {
            passedAvailabilityBoundaryCount = 0
            return
        }

        let currentTime = RoutineTimeOfDay.from(referenceDate, calendar: calendar)
        let currentMinute = currentTime.minutesFromStartOfDay
        let boundaries = Set(tasks.compactMap(Self.availabilityBoundaryMinute))
        passedAvailabilityBoundaryCount = boundaries.filter { $0 <= currentMinute }.count
    }

    private static func availabilityBoundaryMinute(for task: RoutineTask) -> Int? {
        guard task.autoAssumeDailyDone else { return nil }

        if let hour = task.recurrenceTimeRangeStartHour,
           let minute = task.recurrenceTimeRangeStartMinute {
            return clampedMinute(hour: hour, minute: minute)
        }

        if let hour = task.recurrenceTimeOfDayHour,
           let minute = task.recurrenceTimeOfDayMinute {
            return clampedMinute(hour: hour, minute: minute)
        }

        return 0
    }

    private static func clampedMinute(hour: Int, minute: Int) -> Int {
        min(max(hour, 0), 23) * 60 + min(max(minute, 0), 59)
    }
}

private struct DayPlanEventPresentation: Identifiable {
    let id: UUID
}

private struct DayPlanFocusAllocationPresentation: Identifiable {
    let sessionID: UUID

    var id: UUID { sessionID }
}

private struct DayPlanDatePickerSidebar: View {
    @Binding var selectedDate: Date
    let summaryTitle: String
    let blocksCount: Int
    let plannedMinutes: Int
    let calendar: Calendar
    var activityDates: [Date] = []
    var showsActivityAvailability = false
    let onDismiss: () -> Void

    @State private var displayedMonthStart: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            DayPlanSidebarDateGrid(
                selectedDate: $selectedDate,
                displayedMonthStart: displayedMonthStartBinding,
                calendar: calendar,
                activityDayStarts: activityDayStarts,
                showsActivityAvailability: showsActivityAvailability
            )

            Button {
                selectedDate = calendar.startOfDay(for: Date())
            } label: {
                Label("Today", systemImage: "location.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            syncDisplayedMonthToSelectedDate(force: true)
        }
        .onChange(of: selectedDate) { _, _ in
            syncDisplayedMonthToSelectedDate()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "calendar")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Go to date")
                    .font(.headline.weight(.semibold))
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Close")
            .contentShape(Circle())
        }
    }

    private var summaryText: String {
        "\(summaryTitle) - \(blocksCount) blocks, \(DayPlanFormatting.durationText(plannedMinutes)) planned"
    }

    private var activityDayStarts: Set<Date> {
        DayPlanSidebarDateAvailability.dayStarts(for: activityDates, calendar: calendar)
    }

    private var displayedMonthStartBinding: Binding<Date> {
        Binding(
            get: {
                displayedMonthStart ?? calendar.dayPlanMonthStart(for: selectedDate)
            },
            set: { newValue in
                displayedMonthStart = calendar.dayPlanMonthStart(for: newValue)
            }
        )
    }

    private func syncDisplayedMonthToSelectedDate(force: Bool = false) {
        let selectedMonthStart = calendar.dayPlanMonthStart(for: selectedDate)
        guard force || displayedMonthStart.map({
            !calendar.isDate($0, equalTo: selectedMonthStart, toGranularity: .month)
        }) ?? true else {
            return
        }
        displayedMonthStart = selectedMonthStart
    }
}

private struct DayPlanSidebarDateGrid: View {
    @Binding var selectedDate: Date
    @Binding var displayedMonthStart: Date
    let calendar: Calendar
    let activityDayStarts: Set<Date>
    let showsActivityAvailability: Bool

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 32), spacing: 8), count: 7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            monthHeader
            weekdayHeader

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days) { day in
                    dayCell(day)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var monthHeader: some View {
        HStack(spacing: 8) {
            Text(displayedMonthStart.formatted(.dateTime.month(.wide).year()))
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .monospacedDigit()

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                monthNavigationButton(
                    systemName: "chevron.left",
                    accessibilityLabel: "Previous month"
                ) {
                    moveMonth(by: -1)
                }
                monthNavigationButton(
                    systemName: "chevron.right",
                    accessibilityLabel: "Next month"
                ) {
                    moveMonth(by: 1)
                }
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 8) {
            ForEach(Array(calendar.orderedShortStandaloneWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func monthNavigationButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.bold))
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(accessibilityLabel)
    }

    private func dayCell(_ day: DayPlanSidebarCalendarDay) -> some View {
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day.date)
        let hasActivity = showsActivityAvailability
            && DayPlanSidebarDateAvailability.contains(day.date, in: activityDayStarts, calendar: calendar)

        return Button {
            selectedDate = calendar.startOfDay(for: day.date)
            displayedMonthStart = calendar.dayPlanMonthStart(for: day.date)
        } label: {
            Text(day.date.formatted(.dateTime.day()))
                .font(.headline.weight(isSelected ? .bold : .semibold))
                .monospacedDigit()
                .foregroundStyle(
                    foregroundStyle(
                        isSelected: isSelected,
                        isInDisplayedMonth: day.isInDisplayedMonth,
                        hasActivity: hasActivity
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            backgroundColor(
                                isSelected: isSelected,
                                isToday: isToday,
                                hasActivity: hasActivity
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            borderColor(
                                isSelected: isSelected,
                                isToday: isToday,
                                hasActivity: hasActivity
                            ),
                            lineWidth: hasActivity && !isSelected ? 1.4 : 1
                        )
                }
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
        .accessibilityValue(accessibilityValue(isSelected: isSelected, hasActivity: hasActivity))
    }

    private var days: [DayPlanSidebarCalendarDay] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonthStart),
            let firstGridDate = calendar.date(
                byAdding: .day,
                value: -leadingEmptyDays(from: monthInterval.start),
                to: monthInterval.start
            )
        else {
            return []
        }

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstGridDate) else {
                return nil
            }
            return DayPlanSidebarCalendarDay(
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: displayedMonthStart, toGranularity: .month)
            )
        }
    }

    private func leadingEmptyDays(from firstDayOfMonth: Date) -> Int {
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        return (firstWeekday - calendar.firstWeekday + 7) % 7
    }

    private func moveMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonthStart) else {
            return
        }
        displayedMonthStart = calendar.dayPlanMonthStart(for: newMonth)
    }

    private func foregroundStyle(
        isSelected: Bool,
        isInDisplayedMonth: Bool,
        hasActivity: Bool
    ) -> Color {
        if isSelected {
            return .white
        }
        if showsActivityAvailability && !hasActivity {
            return isInDisplayedMonth ? .secondary.opacity(0.52) : .secondary.opacity(0.32)
        }
        if !isInDisplayedMonth {
            return .secondary.opacity(hasActivity ? 0.72 : 0.58)
        }
        return .primary
    }

    private func backgroundColor(isSelected: Bool, isToday: Bool, hasActivity: Bool) -> Color {
        if isSelected {
            return .accentColor
        }
        if hasActivity {
            return Color.accentColor.opacity(0.07)
        }
        if isToday {
            return showsActivityAvailability ? Color.secondary.opacity(0.08) : Color.accentColor.opacity(0.13)
        }
        return Color.clear
    }

    private func borderColor(isSelected: Bool, isToday: Bool, hasActivity: Bool) -> Color {
        if isSelected {
            return .clear
        }
        if hasActivity {
            return Color.accentColor.opacity(0.72)
        }
        if isToday {
            return showsActivityAvailability ? Color.secondary.opacity(0.34) : Color.accentColor.opacity(0.58)
        }
        return .clear
    }

    private func accessibilityValue(isSelected: Bool, hasActivity: Bool) -> String {
        var values: [String] = []
        if isSelected {
            values.append("Selected")
        }
        if showsActivityAvailability {
            values.append(hasActivity ? "Timeline activity available" : "No timeline activity")
        }
        return values.joined(separator: ", ")
    }
}

private struct DayPlanSidebarCalendarDay: Identifiable {
    let date: Date
    let isInDisplayedMonth: Bool

    var id: Date { date }
}

private extension Calendar {
    func dayPlanMonthStart(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }
}

private struct DayPlanCalendarFilterSidebar: View {
    let filters: Binding<DayPlanCalendarFilterState>
    let availability: DayPlanCalendarFilterAvailability
    let timelineSuggestionsAvailable: Bool
    let onDismiss: () -> Void

    private var currentFilters: DayPlanCalendarFilterState {
        filters.wrappedValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            VStack(alignment: .leading, spacing: 10) {
                filterToggle(
                    title: "Planned tasks",
                    systemImage: "checklist",
                    isOn: filterBinding(\.showsPlannedTasks)
                )
                filterToggle(
                    title: "All-day tasks",
                    systemImage: "calendar.badge.clock",
                    isOn: filterBinding(\.showsAllDayTasks)
                )
                filterToggle(
                    title: "Timeline suggestions",
                    systemImage: "clock.arrow.circlepath",
                    isOn: timelineSuggestionsBinding,
                    subtitle: timelineSuggestionsAvailable ? nil : "Off in Settings",
                    isEnabled: timelineSuggestionsAvailable
                )
                filterToggle(
                    title: "Assumed done",
                    systemImage: "checkmark.circle",
                    isOn: filterBinding(\.showsAssumedDone)
                )
                if availability.includesEvents {
                    filterToggle(
                        title: "Events",
                        systemImage: "calendar",
                        isOn: filterBinding(\.showsEvents)
                    )
                }
                filterToggle(
                    title: "Focus",
                    systemImage: "timer",
                    isOn: filterBinding(\.showsFocus)
                )
                if availability.includesAway {
                    filterToggle(
                        title: "Away",
                        systemImage: "figure.walk",
                        isOn: filterBinding(\.showsAway)
                    )
                }
                if availability.includesSleep {
                    filterToggle(
                        title: "Sleep",
                        systemImage: "bed.double",
                        isOn: filterBinding(\.showsSleep)
                    )
                }
            }

            Button {
                filters.wrappedValue.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!currentFilters.hasActiveFilters(availability: availability))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Calendar Filters")
                    .font(.headline.weight(.semibold))
                Text(currentFilters.summaryText(availability: availability))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Close")
            .contentShape(Circle())
        }
    }

    private func filterToggle(
        title: String,
        systemImage: String,
        isOn: Binding<Bool>,
        subtitle: String? = nil,
        isEnabled: Bool = true
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill((isEnabled ? Color.accentColor : Color.secondary).opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .toggleStyle(.switch)
        .disabled(!isEnabled)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.055))
        }
    }

    private func filterBinding(
        _ keyPath: WritableKeyPath<DayPlanCalendarFilterState, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: {
                filters.wrappedValue[keyPath: keyPath]
            },
            set: { isEnabled in
                filters.wrappedValue[keyPath: keyPath] = isEnabled
            }
        )
    }

    private var timelineSuggestionsBinding: Binding<Bool> {
        Binding(
            get: {
                timelineSuggestionsAvailable && filters.wrappedValue.showsTimelineSuggestions
            },
            set: { isEnabled in
                filters.wrappedValue.showsTimelineSuggestions = isEnabled
            }
        )
    }
}

private struct DayPlanDayTaskListSidebar: View {
    let date: Date
    let items: [DayPlanDayTaskListItem]
    let taskTint: (UUID) -> Color
    let calendar: Calendar
    let isTaskOpenable: (UUID) -> Bool
    let onConfirmAssumedDayTask: (DayPlanDayTaskListItem, Date) -> Void
    let onMarkAssumedDayTaskMissed: (DayPlanDayTaskListItem, Date) -> Void
    let onOpenTaskDetails: (UUID) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if items.isEmpty {
                ContentUnavailableView(
                    "No day tasks",
                    systemImage: "list.bullet.rectangle",
                    description: Text("No planned, assumed done, or done tasks for this day.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                DayPlanDayTaskListContentView(
                    items: items,
                    taskTint: taskTint,
                    date: date,
                    calendar: calendar,
                    isTaskOpenable: isTaskOpenable,
                    onOpenTaskDetails: onOpenTaskDetails,
                    onConfirmAssumedDayTask: onConfirmAssumedDayTask,
                    onMarkAssumedDayTaskMissed: onMarkAssumedDayTaskMissed,
                    onDragProvider: { item in
                        NSItemProvider(object: item.taskID.uuidString as NSString)
                    }
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Day Tasks")
                    .font(.headline.weight(.semibold))
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Close")
            .contentShape(Circle())
        }
    }

    private var headerSubtitle: String {
        let countText = taskCountText(items.count)
        let dateText = date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return "\(dateText) - \(countText)"
    }

    private func taskCountText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "task" : "tasks")"
    }
}

enum DayPlanSlotActionMode: String, CaseIterable, Hashable {
    case task
    case away

    var title: String {
        switch self {
        case .task:
            return "Task"
        case .away:
            return "Away"
        }
    }

    static func visibleCases(includingAway: Bool) -> [DayPlanSlotActionMode] {
        includingAway ? [.task, .away] : [.task]
    }

    static func showsModePicker(includingAway: Bool) -> Bool {
        visibleCases(includingAway: includingAway).count > 1
    }
}

enum DayPlanSlotTaskPickerPresentation {
    static func filteredTasks(
        _ tasks: [RoutineTask],
        matching query: String
    ) -> [RoutineTask] {
        let normalizedQuery = normalizedSearchText(query)
        guard !normalizedQuery.isEmpty else { return tasks }

        return tasks.filter { task in
            normalizedSearchText(DayPlanTaskSorting.title(for: task)).contains(normalizedQuery)
        }
    }

    static func creatableTaskName(
        from query: String,
        tasks: [RoutineTask]
    ) -> String? {
        let name = normalizedNewTaskName(query)
        guard !name.isEmpty else { return nil }
        let normalizedName = normalizedSearchText(name)
        let alreadyExists = tasks.contains { task in
            normalizedSearchText(DayPlanTaskSorting.title(for: task)) == normalizedName
        }
        return alreadyExists ? nil : name
    }

    static func normalizedNewTaskName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func normalizedSearchText(_ value: String) -> String {
        normalizedNewTaskName(value)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

private enum DayPlanAwayLogOption: Hashable, Identifiable {
    case away(AwaySessionPreset)
    case sleep

    static let options: [DayPlanAwayLogOption] = AwaySessionPreset.allCases.map(DayPlanAwayLogOption.away) + [.sleep]

    static func options(includingAway: Bool) -> [DayPlanAwayLogOption] {
        includingAway ? options : []
    }

    var id: String {
        switch self {
        case let .away(preset):
            return preset.rawValue
        case .sleep:
            return "sleep"
        }
    }

    var awayPreset: AwaySessionPreset? {
        guard case let .away(preset) = self else { return nil }
        return preset
    }

    var isSleep: Bool {
        self == .sleep
    }

    var title: String {
        switch self {
        case let .away(preset):
            return preset.title
        case .sleep:
            return "Sleep"
        }
    }

    var systemImage: String {
        switch self {
        case let .away(preset):
            return preset.systemImage
        case .sleep:
            return "bed.double.fill"
        }
    }

    var tint: Color {
        switch self {
        case let .away(preset):
            return preset.dayPlanTint
        case .sleep:
            return .orange
        }
    }

    var defaultDurationMinutes: Int {
        switch self {
        case let .away(preset):
            return preset.defaultDurationMinutes
        case .sleep:
            return 8 * 60
        }
    }

    var subtitle: String {
        switch self {
        case let .away(preset):
            return "\(preset.defaultDurationMinutes)m"
        case .sleep:
            return "8h"
        }
    }

    var durationTitle: String {
        isSleep ? "Sleep duration" : "Duration"
    }

    var logActionTitle: String {
        isSleep ? "Log Sleep" : "Log Away"
    }

    var logActionSystemImage: String {
        isSleep ? "bed.double.fill" : "lock.shield.fill"
    }

    var finishedIntervalMessage: String {
        isSleep ? "Sleep logs are for finished intervals." : "Away logs are for finished intervals."
    }
}

private struct DayPlanSlotActionSidebar: View {
    let date: Date
    let startMinute: Int
    @Binding var durationMinutes: Int
    let tasks: [RoutineTask]
    let defaultTaskID: UUID?
    let now: Date
    let calendar: Calendar
    let includesAway: Bool
    let onCreateTaskBlock: (UUID, Int) -> String?
    let onCreateTaskAndBlock: (String, Int) -> String?
    let onLogAway: (AwaySessionPreset, String?, UUID?, Int) -> String?
    let onLogSleep: (Int) -> String?
    let onDismiss: () -> Void

    @State private var mode: DayPlanSlotActionMode = .task
    @State private var selectedTaskID: UUID?
    @State private var taskQuery = ""
    @State private var selectedAwayOption: DayPlanAwayLogOption = .away(.custom)
    @State private var awayTitle = ""
    @State private var awayLinkedTaskID: UUID?
    @State private var errorText: String?

    init(
        date: Date,
        startMinute: Int,
        durationMinutes: Binding<Int>,
        tasks: [RoutineTask],
        defaultTaskID: UUID?,
        now: Date,
        calendar: Calendar,
        includesAway: Bool = true,
        onCreateTaskBlock: @escaping (UUID, Int) -> String?,
        onCreateTaskAndBlock: @escaping (String, Int) -> String?,
        onLogAway: @escaping (AwaySessionPreset, String?, UUID?, Int) -> String?,
        onLogSleep: @escaping (Int) -> String?,
        onDismiss: @escaping () -> Void
    ) {
        self.date = date
        self.startMinute = DayPlanBlock.clampedStartMinute(startMinute)
        self._durationMinutes = durationMinutes
        self.tasks = tasks
        self.defaultTaskID = defaultTaskID
        self.now = now
        self.calendar = calendar
        self.includesAway = includesAway
        self.onCreateTaskBlock = onCreateTaskBlock
        self.onCreateTaskAndBlock = onCreateTaskAndBlock
        self.onLogAway = onLogAway
        self.onLogSleep = onLogSleep
        self.onDismiss = onDismiss

        let initialTaskID = defaultTaskID.flatMap { id in tasks.first(where: { $0.id == id })?.id } ?? tasks.first?.id
        _selectedTaskID = State(initialValue: initialTaskID)
        _awayLinkedTaskID = State(initialValue: initialTaskID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if DayPlanSlotActionMode.showsModePicker(includingAway: includesAway) {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Slot action",
                    options: DayPlanSlotActionMode.visibleCases(includingAway: includesAway),
                    selection: $mode,
                    minimumSegmentWidth: 92,
                    fillsAvailableWidth: true
                ) { actionMode in
                    Text(actionMode.title)
                }
            }

            switch mode {
            case .task:
                taskBlockContent
            case .away:
                awayLogContent
            }

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            normalizeModeForAwayVisibility()
            setTaskDuration(durationMinutes)
        }
        .onChange(of: includesAway) { _, _ in
            normalizeModeForAwayVisibility()
        }
        .onChange(of: mode) { _, newMode in
            errorText = nil
            switch newMode {
            case .task:
                setTaskDuration(durationMinutes)
            case .away:
                if selectedAwayOption.isSleep {
                    selectedAwayOption = .away(.custom)
                }
                setAwayDuration(selectedAwayOption.defaultDurationMinutes, for: selectedAwayOption)
            }
        }
        .onChange(of: taskQuery) { _, _ in
            selectedTaskID = nil
            errorText = nil
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: mode == .task ? "calendar.badge.plus" : selectedAwayOption.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background((mode == .task ? Color.accentColor : selectedAwayOption.tint), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(intervalTitle)
                    .font(.headline.monospacedDigit().weight(.semibold))
                Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Close")
            .contentShape(Circle())
        }
    }

    private var taskBlockContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            taskChooser

            DayPlanSlotDurationControl(
                title: "Duration",
                minutes: taskDurationBinding,
                range: taskDurationRange,
                step: 15,
                presets: taskDurationPresets,
                tint: .accentColor
            )

            Button {
                submitTaskBlock()
            } label: {
                Label(taskSubmitTitle, systemImage: "calendar.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmitTaskBlock)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var taskChooser: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Find or create task", text: $taskQuery)
                    .textFieldStyle(.plain)

                if !taskQuery.isEmpty {
                    Button {
                        taskQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear")
                }
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .frame(height: 38)
            .routinaGlassPanel(cornerRadius: 8, interactive: true)

            ScrollView {
                LazyVStack(spacing: 6) {
                    if let creatableTaskName {
                        Button {
                            selectedTaskID = nil
                            errorText = nil
                        } label: {
                            DayPlanSlotCreateTaskRow(
                                title: creatableTaskName,
                                isSelected: selectedTaskID == nil
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    ForEach(filteredTasks) { task in
                        Button {
                            selectTask(task)
                        } label: {
                            DayPlanSlotTaskChoiceRow(
                                task: task,
                                isSelected: selectedTaskID == task.id
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    if filteredTasks.isEmpty && creatableTaskName == nil {
                        Text("No matching tasks")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.visible)
            .frame(maxHeight: 164)
        }
    }

    private var awayLogContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if includesAway {
                LazyVGrid(columns: awayOptionColumns, spacing: 8) {
                    ForEach(DayPlanAwayLogOption.options(includingAway: includesAway)) { option in
                        Button {
                            selectAwayOption(option)
                        } label: {
                            DayPlanAwayOptionCard(
                                option: option,
                                isSelected: selectedAwayOption == option
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            if !selectedAwayOption.isSleep {
                TextField("Title", text: $awayTitle)
                    .textFieldStyle(.roundedBorder)

                Picker("Linked task", selection: awayTaskSelectionBinding) {
                    Text("No linked task").tag(Optional<UUID>.none)
                    ForEach(tasks) { task in
                        Text(DayPlanTaskSorting.title(for: task)).tag(Optional(task.id))
                    }
                }
                .pickerStyle(.menu)
            }

            DayPlanSlotDurationControl(
                title: selectedAwayOption.durationTitle,
                minutes: awayDurationBinding,
                range: selectedAwayDurationRange,
                step: selectedAwayOption.isSleep ? 15 : 5,
                presets: selectedAwayDurationPresets,
                tint: selectedAwayOption.tint
            )

            Button {
                submitAwayLog()
            } label: {
                Label(selectedAwayOption.logActionTitle, systemImage: selectedAwayOption.logActionSystemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedAwayOption.tint)
            .disabled(!canLogAway)

            if !canLogAway {
                Text(selectedAwayOption.finishedIntervalMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var awayOptionColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    private var filteredTasks: [RoutineTask] {
        DayPlanSlotTaskPickerPresentation.filteredTasks(tasks, matching: taskQuery)
    }

    private var creatableTaskName: String? {
        DayPlanSlotTaskPickerPresentation.creatableTaskName(from: taskQuery, tasks: tasks)
    }

    private var canSubmitTaskBlock: Bool {
        selectedTaskID != nil || creatableTaskName != nil
    }

    private var taskSubmitTitle: String {
        selectedTaskID == nil && creatableTaskName != nil ? "Create Task & Add Block" : "Add Block"
    }

    private func selectTask(_ task: RoutineTask) {
        selectedTaskID = task.id
        errorText = nil
        if let estimate = task.estimatedDurationMinutes {
            setTaskDuration(estimate)
        }
    }

    private func selectAwayOption(_ option: DayPlanAwayLogOption) {
        guard includesAway else { return }
        selectedAwayOption = option
        errorText = nil
        if option.isSleep {
            awayLinkedTaskID = nil
        }
        setAwayDuration(option.defaultDurationMinutes, for: option)
    }

    private func normalizeModeForAwayVisibility() {
        guard !DayPlanSlotActionMode.visibleCases(includingAway: includesAway).contains(mode) else {
            return
        }

        mode = .task
        selectedAwayOption = .away(.custom)
        awayLinkedTaskID = nil
        setTaskDuration(durationMinutes)
    }

    private var taskDurationBinding: Binding<Int> {
        Binding(
            get: { clampedTaskDurationMinutes },
            set: { setTaskDuration($0) }
        )
    }

    private var awayDurationBinding: Binding<Int> {
        Binding(
            get: { clampedAwayDurationMinutes },
            set: { setAwayDuration($0, for: selectedAwayOption) }
        )
    }

    private var awayTaskSelectionBinding: Binding<UUID?> {
        Binding(
            get: { awayLinkedTaskID },
            set: { awayLinkedTaskID = $0 }
        )
    }

    private var taskDurationRange: ClosedRange<Int> {
        DayPlanBlock.minimumDurationMinutes...maximumDurationMinutes
    }

    private var taskDurationPresets: [Int] {
        [15, 30, 45, 60, 90, 120]
    }

    private var awayDurationRange: ClosedRange<Int> {
        5...max(5, maximumDurationMinutes)
    }

    private var sleepDurationRange: ClosedRange<Int> {
        5...(16 * 60)
    }

    private var selectedAwayDurationRange: ClosedRange<Int> {
        selectedAwayOption.isSleep ? sleepDurationRange : awayDurationRange
    }

    private var selectedAwayDurationPresets: [Int] {
        selectedAwayOption.isSleep
            ? [30, 60, 120, 240, 360, 480]
            : [10, 15, 20, 30, 45, 60]
    }

    private var maximumDurationMinutes: Int {
        max(DayPlanBlock.minimumDurationMinutes, DayPlanBlock.minutesPerDay - startMinute)
    }

    private var intervalTitle: String {
        guard let startedAt = selectedStartDate,
              let endedAt = calendar.date(byAdding: .minute, value: activeDurationMinutes, to: startedAt)
        else {
            return "\(DayPlanFormatting.timeText(for: startMinute, on: date, calendar: calendar)) - \(DayPlanFormatting.timeText(for: startMinute + activeDurationMinutes, on: date, calendar: calendar))"
        }
        return "\(timeText(startedAt)) - \(endTimeText(endedAt, relativeTo: startedAt))"
    }

    private var activeDurationMinutes: Int {
        mode == .task ? clampedTaskDurationMinutes : clampedAwayDurationMinutes
    }

    private var clampedTaskDurationMinutes: Int {
        Self.clampedDuration(
            durationMinutes,
            startMinute: startMinute,
            minimumDurationMinutes: DayPlanBlock.minimumDurationMinutes
        )
    }

    private var clampedAwayDurationMinutes: Int {
        selectedAwayOption.isSleep
            ? Self.clampedSleepDuration(durationMinutes)
            : Self.clampedDuration(
                durationMinutes,
                startMinute: startMinute,
                minimumDurationMinutes: 5
            )
    }

    private var selectedStartDate: Date? {
        calendar.date(byAdding: .minute, value: startMinute, to: calendar.startOfDay(for: date))
    }

    private var selectedAwayEndDate: Date? {
        guard let startDate = selectedStartDate else {
            return nil
        }
        return calendar.date(byAdding: .minute, value: clampedAwayDurationMinutes, to: startDate)
    }

    private var canLogAway: Bool {
        guard let selectedAwayEndDate else { return false }
        return selectedAwayEndDate <= now
    }

    private func submitTaskBlock() {
        let error: String?
        if let selectedTaskID {
            error = onCreateTaskBlock(selectedTaskID, clampedTaskDurationMinutes)
        } else if let creatableTaskName {
            error = onCreateTaskAndBlock(creatableTaskName, clampedTaskDurationMinutes)
        } else {
            error = "Choose or name a task."
        }

        if let error {
            errorText = error
        } else {
            errorText = nil
            onDismiss()
        }
    }

    private func submitAwayLog() {
        guard canLogAway else {
            errorText = selectedAwayOption.finishedIntervalMessage
            return
        }

        let error: String?
        if selectedAwayOption.isSleep {
            error = onLogSleep(clampedAwayDurationMinutes)
        } else if let awayPreset = selectedAwayOption.awayPreset {
            error = onLogAway(
                awayPreset,
                awayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : awayTitle,
                awayLinkedTaskID,
                clampedAwayDurationMinutes
            )
        } else {
            error = "Choose an option."
        }

        if let error {
            errorText = error
        } else {
            errorText = nil
            onDismiss()
        }
    }

    private func setTaskDuration(_ newValue: Int) {
        durationMinutes = Self.clampedDuration(
            newValue,
            startMinute: startMinute,
            minimumDurationMinutes: DayPlanBlock.minimumDurationMinutes
        )
    }

    private func setAwayDuration(_ newValue: Int, for option: DayPlanAwayLogOption) {
        if option.isSleep {
            durationMinutes = Self.clampedSleepDuration(newValue)
        } else {
            durationMinutes = Self.clampedDuration(
                newValue,
                startMinute: startMinute,
                minimumDurationMinutes: 5
            )
        }
    }

    private static func clampedDuration(
        _ durationMinutes: Int,
        startMinute: Int,
        minimumDurationMinutes: Int
    ) -> Int {
        DayPlanBlock.clampedDuration(
            durationMinutes,
            startMinute: startMinute,
            minimumDurationMinutes: minimumDurationMinutes
        )
    }

    private static func clampedSleepDuration(_ durationMinutes: Int) -> Int {
        min(max(durationMinutes, 5), 16 * 60)
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func endTimeText(_ endDate: Date, relativeTo startDate: Date) -> String {
        if calendar.isDate(endDate, inSameDayAs: startDate) {
            return timeText(endDate)
        }
        return endDate.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}

private struct DayPlanSlotTaskChoiceRow: View {
    let task: RoutineTask
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "*")
                .font(.callout)
                .frame(width: 26, height: 26)
                .background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(DayPlanTaskSorting.title(for: task))
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if let estimatedDurationMinutes = task.estimatedDurationMinutes {
                    Text(DayPlanFormatting.durationText(estimatedDurationMinutes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 46)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }

    private var rowBackground: some ShapeStyle {
        isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08)
    }
}

private struct DayPlanSlotCreateTaskRow: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(title)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 46)
        .background(
            isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.accentColor.opacity(0.24), lineWidth: 1)
        }
    }
}

private struct DayPlanAwayOptionCard: View {
    let option: DayPlanAwayLogOption
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: option.systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(option.tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(option.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.caption2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? option.tint : .secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .routinaGlassPanel(cornerRadius: 10, tint: option.tint, tintOpacity: isSelected ? 0.16 : 0.06, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(option.tint.opacity(isSelected ? 0.9 : 0.22), lineWidth: isSelected ? 1.2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct DayPlanSlotDurationControl: View {
    let title: String
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    let step: Int
    let presets: [Int]
    let tint: Color

    private var visiblePresets: [Int] {
        presets.filter { range.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(DayPlanFormatting.durationText(minutes))
                        .font(.headline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    durationButton(systemImage: "minus", isEnabled: minutes > range.lowerBound) {
                        setMinutes(minutes - step)
                    }

                    durationButton(systemImage: "plus", isEnabled: minutes < range.upperBound) {
                        setMinutes(minutes + step)
                    }
                }
            }

            if !visiblePresets.isEmpty {
                LazyVGrid(columns: presetColumns, spacing: 6) {
                    ForEach(visiblePresets, id: \.self) { preset in
                        Button {
                            setMinutes(preset)
                        } label: {
                            Text(DayPlanFormatting.durationText(preset))
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(tint.opacity(minutes == preset ? 0.24 : 0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(tint.opacity(minutes == preset ? 0.85 : 0.22), lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                }
            }
        }
        .padding(10)
        .routinaGlassPanel(cornerRadius: 10, tint: tint, tintOpacity: 0.06, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private var presetColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: max(visiblePresets.count, 1))
    }

    private func durationButton(
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .frame(width: 30, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.6))
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(isEnabled ? 0.14 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(isEnabled ? 0.28 : 0.12), lineWidth: 1)
        )
        .disabled(!isEnabled)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func setMinutes(_ newValue: Int) {
        minutes = min(max(newValue, range.lowerBound), range.upperBound)
    }
}

private extension AwaySessionPreset {
    var dayPlanTint: Color {
        switch self {
        case .wake:
            return .orange
        case .reset:
            return .teal
        case .outside:
            return .green
        case .windDown:
            return .indigo
        case .meal:
            return .pink
        case .custom:
            return .cyan
        }
    }
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
    var focusSessions: [FocusSession]
    var calendar: Calendar

    func body(content: Content) -> some View {
        content
            .onAppear {
                reconcileCountUpFocusSegments()
                planner.loadBlocks(calendar: calendar, context: modelContext)
                showExactTimedTasks()
                planner.selectDefaultTaskIfNeeded(from: tasks)
            }
            .onChange(of: planner.selectedDate) { _, _ in
                planner.handleSelectedDateChanged(calendar: calendar, context: modelContext)
                showExactTimedTasks()
            }
            .onChange(of: planner.visibleRangeMode) { _, _ in
                reconcileCountUpFocusSegments()
                planner.loadBlocks(
                    calendar: calendar,
                    context: modelContext,
                    preservingCachedUnassignedFocusBlocks: true
                )
                showExactTimedTasks()
            }
            .onChange(of: taskChangeToken) { _, _ in
                planner.loadBlocks(calendar: calendar, context: modelContext)
                showExactTimedTasks()
                planner.selectDefaultTaskIfNeeded(from: tasks)
            }
            .onChange(of: sleepSessionChangeToken) { _, _ in
                showExactTimedTasks()
            }
            .onChange(of: awaySessionChangeToken) { _, _ in
                showExactTimedTasks()
            }
            .onChange(of: focusSessionChangeToken) { _, _ in
                reconcileCountUpFocusSegments()
                planner.loadBlocks(calendar: calendar, context: modelContext)
                showExactTimedTasks()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    reconcileCountUpFocusSegments()
                    planner.loadBlocks(calendar: calendar, context: modelContext)
                    showExactTimedTasks()
                }
            }
    }

    private func reconcileCountUpFocusSegments() {
        DayPlanFocusSessionPlannerSync.reconcileCountUpFocusSegments(
            for: focusSessions,
            tasks: tasks,
            calendar: calendar,
            context: modelContext
        )
    }

    private var focusSessionChangeToken: [String] {
        DayPlanFocusSessionChangeToken.tokens(from: focusSessions)
    }

    private var taskChangeToken: [String] {
        tasks.map { task in
            [
                task.id.uuidString,
                task.scheduleModeRawValue,
                task.isAllDay.description,
                task.deadline?.timeIntervalSinceReferenceDate.description ?? "",
                task.availabilityStartDate?.timeIntervalSinceReferenceDate.description ?? "",
                task.availabilityEndDate?.timeIntervalSinceReferenceDate.description ?? "",
                task.recurrenceStorageVersion.description,
                task.recurrenceKindRawValue,
                task.recurrenceTimeOfDayHour?.description ?? "",
                task.recurrenceTimeOfDayMinute?.description ?? "",
                task.recurrenceTimeRangeStartHour?.description ?? "",
                task.recurrenceTimeRangeStartMinute?.description ?? "",
                task.recurrenceTimeRangeEndHour?.description ?? "",
                task.recurrenceTimeRangeEndMinute?.description ?? "",
                task.recurrenceWeekday?.description ?? "",
                task.recurrenceDayOfMonth?.description ?? "",
                task.recurrenceRuleStorage,
                task.interval.description,
                task.lastDone?.timeIntervalSinceReferenceDate.description ?? "",
                task.canceledAt?.timeIntervalSinceReferenceDate.description ?? "",
                task.scheduleAnchor?.timeIntervalSinceReferenceDate.description ?? "",
                task.pausedAt?.timeIntervalSinceReferenceDate.description ?? "",
                task.snoozedUntil?.timeIntervalSinceReferenceDate.description ?? "",
                task.estimatedDurationMinutes?.description ?? "",
            ].joined(separator: ":")
        }
        .sorted()
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
        focusSessions: [FocusSession] = [],
        calendar: Calendar
    ) -> some View {
        modifier(
            DayPlanLifecycleModifier(
                planner: planner,
                tasks: tasks,
                sleepSessions: sleepSessions,
                awaySessions: awaySessions,
                focusSessions: focusSessions,
                calendar: calendar
            )
        )
    }
}

enum DayPlanFocusSessionChangeToken {
    static func tokens(from sessions: [FocusSession]) -> [String] {
        sessions
            .map { session in
                [
                    session.id.uuidString,
                    session.taskID.uuidString,
                    session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                    session.completedAt?.timeIntervalSinceReferenceDate.description ?? "",
                    session.abandonedAt?.timeIntervalSinceReferenceDate.description ?? "",
                    session.pausedAt?.timeIntervalSinceReferenceDate.description ?? "",
                    session.accumulatedPausedSeconds.description,
                    session.plannedDurationSeconds.description,
                    session.focusTagName ?? "",
                ].joined(separator: ":")
            }
            .sorted()
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
