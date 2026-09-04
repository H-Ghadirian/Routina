import SwiftData
import SwiftUI

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
    var showsCalendarFilterButton = true
    var listFilterButtonIsActive = false
    var listFilterButtonAccessibilityValue: String? = nil
    var calendarSearchText = ""
    var calendarTaskFilter: (RoutineTask) -> Bool = { _ in true }
    var calendarTaskFilterCacheSeed = 0
    var calendarListRevealsHiddenTasks = false
    var listContent: ((DayPlanTimelineDateJumpRequest?) -> AnyView)? = nil
    var timelineActivityDates: [Date] = []
    var onSelectUnplannedCompletedDate: ((Date) -> Void)? = nil
    var onOpenTaskDetails: ((UUID) -> Void)? = nil
    var onOpenCalendarListTaskDetails: ((DayPlanDayTaskListItem, Date) -> Void)? = nil
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
                showsCalendarFilterButton: showsCalendarFilterButton,
                displayMode: displayMode,
                calendarTaskViewMode: calendarTaskViewMode,
                showsDisplayModePicker: listContent != nil,
                isTaskDetailInspectorPresented: isTaskDetailInspectorPresented,
                parentAvailableWidth: macHeaderAvailableWidth,
                listFilterButtonIsActive: listFilterButtonIsActive,
                listFilterButtonAccessibilityValue: listFilterButtonAccessibilityValue,
                onCalendarFilterButtonPressed: onCalendarFilterButtonPressed
            )

            if displayMode.wrappedValue == .list, let listContent {
                plannerListContent(listContent)
            } else {
                DayPlanTimelinePanelView(
                    planner: planner,
                    onSelectUnplannedCompletedDate: onSelectUnplannedCompletedDate,
                    onOpenTaskDetails: onOpenTaskDetails,
                    onOpenCalendarListTaskDetails: onOpenCalendarListTaskDetails,
                    onOpenEventDetails: onOpenEventDetails,
                    calendarFilters: calendarFilters,
                    calendarSearchText: calendarSearchText,
                    calendarTaskFilter: calendarTaskFilter,
                    calendarTaskFilterCacheSeed: calendarTaskFilterCacheSeed,
                    calendarListRevealsHiddenTasks: calendarListRevealsHiddenTasks,
                    calendarTaskViewMode: calendarTaskViewMode.wrappedValue,
                    isCalendarFilterSidebarPresented: $isCalendarFilterSidebarPresented,
                    isDatePickerSidebarPresented: $isDatePickerSidebarPresented,
                    parentAvailableWidth: macHeaderAvailableWidth,
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
