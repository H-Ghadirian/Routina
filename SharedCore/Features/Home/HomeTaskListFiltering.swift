import Foundation

struct HomeTaskListFiltering<Display: HomeTaskListDisplay> {
    static var pinnedManualOrderSectionKey: String {
        HomeTaskListSorter<Display>.pinnedManualOrderSectionKey
    }

    static var plannedTodayManualOrderSectionKey: String {
        HomeTaskListSorter<Display>.plannedTodayManualOrderSectionKey
    }

    static var plannedTomorrowManualOrderSectionKey: String {
        HomeTaskListSorter<Display>.plannedTomorrowManualOrderSectionKey
    }

    static var trackingManualOrderSectionKey: String {
        HomeTaskListSorter<Display>.trackingManualOrderSectionKey
    }

    static var ungroupedManualOrderSectionKey: String {
        HomeTaskListSorter<Display>.ungroupedManualOrderSectionKey
    }

    static var dailyManualOrderSectionKey: String {
        HomeTaskListSorter<Display>.dailyManualOrderSectionKey
    }

    static var archivedManualOrderSectionKey: String {
        HomeTaskListSorter<Display>.archivedManualOrderSectionKey
    }

    private var predicate: HomeTaskListPredicate<Display>
    private var sorter: HomeTaskListSorter<Display>
    private var sectionBuilder: HomeTaskListSectionBuilder<Display>
    private var metrics: HomeTaskListMetrics<Display>

    init(
        configuration: HomeTaskListFilteringConfiguration,
        matchesCurrentTaskListMode: @escaping (Display) -> Bool
    ) {
        let metrics = HomeTaskListMetrics<Display>(configuration: configuration)
        let sorter = HomeTaskListSorter(configuration: configuration, metrics: metrics)
        self.init(
            predicate: HomeTaskListPredicate(
                configuration: configuration,
                metrics: metrics,
                matchesCurrentTaskListMode: matchesCurrentTaskListMode
            ),
            sorter: sorter,
            sectionBuilder: HomeTaskListSectionBuilder(
                configuration: configuration,
                metrics: metrics,
                sorter: sorter
            ),
            metrics: metrics
        )
    }

    init(
        predicate: HomeTaskListPredicate<Display>,
        sorter: HomeTaskListSorter<Display>,
        sectionBuilder: HomeTaskListSectionBuilder<Display>,
        metrics: HomeTaskListMetrics<Display>
    ) {
        self.predicate = predicate
        self.sorter = sorter
        self.sectionBuilder = sectionBuilder
        self.metrics = metrics
    }

    func sortedTasks(_ displays: [Display]) -> [Display] {
        sorter.sortedTasks(displays)
    }

    func filteredTasks(_ displays: [Display]) -> [Display] {
        sorter.sortedTasks(displays.filter(predicate.matchesVisibleTask))
    }

    func filteredAwayTasks(_ displays: [Display]) -> [Display] {
        sorter.sortedTasks(displays.filter(predicate.matchesVisibleTask))
    }

    func filteredArchivedTasks(
        _ displays: [Display],
        includePinned: Bool = true
    ) -> [Display] {
        displays
            .filter { predicate.matchesArchivedTask($0, includePinned: includePinned) }
            .sorted(by: sorter.archivedTaskSort)
    }

    func filteredPinnedTasks(
        activeDisplays: [Display],
        awayDisplays: [Display],
        archivedDisplays: [Display]
    ) -> [Display] {
        let activePinned = sorter.sortedTasks(
            (activeDisplays + awayDisplays).filter { task in
                task.isPinned && predicate.matchesVisibleTask(task)
            }
        )
        let archivedPinned = filteredArchivedTasks(archivedDisplays).filter(\.isPinned)

        return (activePinned + archivedPinned).sorted(by: sorter.pinnedTaskSort)
    }

    func sidebarVisibleTaskCount(
        activeDisplays: [Display],
        awayDisplays: [Display],
        archivedDisplays: [Display],
        showArchivedTasks: Bool = true
    ) -> Int {
        let activeDisplays = activeDisplays + awayDisplays
        let visibleArchivedDisplays = showArchivedTasks ? archivedDisplays : []
        let activePinnedCount = activeDisplays.count { task in
            task.isPinned && predicate.matchesVisibleTask(task)
        }
        let activeUnpinnedCount = activeDisplays.count { task in
            !task.isPinned && predicate.matchesVisibleTask(task)
        }
        let archivedPinnedCount = visibleArchivedDisplays.count { task in
            task.isPinned && predicate.matchesArchivedTask(task, includePinned: true)
        }
        let archivedUnpinnedCount = visibleArchivedDisplays.count { task in
            predicate.matchesArchivedTask(task, includePinned: false)
        }

        return activePinnedCount + activeUnpinnedCount + archivedPinnedCount + archivedUnpinnedCount
    }

    func groupedRoutineSections(from displays: [Display]) -> [HomeTaskListSection<Display>] {
        sectionBuilder.groupedRoutineSections(from: filteredTasks(displays))
    }

    var usesTagSectioning: Bool {
        sectionBuilder.configuration.routineListSectioningMode == .tags
    }

    var usesUngroupedSectioning: Bool {
        sectionBuilder.configuration.routineListSectioningMode == .none
    }

    var usesDeadlineDateSectioning: Bool {
        sectionBuilder.configuration.routineListSectioningMode == .deadlineDate
    }

    var separatesDeadlineStatusInTagSections: Bool {
        sectionBuilder.configuration.routineListSectioningMode == .tags
            && sectionBuilder.configuration.separateDeadlineStatusInTagSections
    }

    func filteredDailyRoutineTasks(_ displays: [Display]) -> [Display] {
        sorter.sortedTasks(
            displays.filter { task in
                task.isDailyRoutine && predicate.matchesVisibleTask(task)
            }
        )
    }

    func filteredPlannedTodayTasks(_ displays: [Display]) -> [Display] {
        filteredPlannedTasks(
            displays,
            on: metrics.configuration.referenceDate,
            sortedBy: sorter.plannedTodayTaskSort
        )
    }

    func filteredPlannedTomorrowTasks(_ displays: [Display]) -> [Display] {
        guard let tomorrow = metrics.configuration.calendar.date(
            byAdding: .day,
            value: 1,
            to: metrics.configuration.calendar.startOfDay(for: metrics.configuration.referenceDate)
        ) else {
            return []
        }

        return filteredPlannedTasks(
            displays,
            on: tomorrow,
            sortedBy: sorter.plannedTomorrowTaskSort
        )
    }

    func filteredTrackingTasks(_ displays: [Display]) -> [Display] {
        displays
            .filter { task in
                task.scheduleMode.taskType == .record && predicate.matchesVisibleTask(task)
            }
            .sorted(by: sorter.trackingTaskSort)
    }

    private func filteredPlannedTasks(
        _ displays: [Display],
        on day: Date,
        sortedBy sort: (Display, Display) -> Bool
    ) -> [Display] {
        let calendar = metrics.configuration.calendar
        let isReferenceDay = calendar.isDate(day, inSameDayAs: metrics.configuration.referenceDate)

        return displays
            .filter { task in
                guard !task.isDailyRoutine,
                      matchesUncompletedTodayClaim(task),
                      predicate.matchesVisibleTask(task) else { return false }
                guard !isReferenceDay || !task.isCanceledToday else { return false }
                if let plannedDate = task.plannedDate {
                    return calendar.isDate(
                        plannedDate,
                        inSameDayAs: day
                    )
                }
                return task.isFixedCalendarRoutineScheduled(
                    on: day,
                    calendar: calendar
                )
            }
            .sorted(by: sort)
    }

    func matchesUncompletedTodayClaim(_ task: Display) -> Bool {
        !task.isDoneToday && !task.isCompletedOneOff
    }

    func deadlineBasedSections(from tasks: [Display]) -> [HomeTaskListSection<Display>] {
        sectionBuilder.deadlineBasedSections(from: tasks)
    }

    func regularTaskSort(_ lhs: Display, _ rhs: Display) -> Bool {
        sorter.regularTaskSort(lhs, rhs)
    }

    func archivedTaskSort(_ lhs: Display, _ rhs: Display) -> Bool {
        sorter.archivedTaskSort(lhs, rhs)
    }

    func pinnedTaskSort(_ lhs: Display, _ rhs: Display) -> Bool {
        sorter.pinnedTaskSort(lhs, rhs)
    }

    func dueDateSortResult(_ lhs: Display, _ rhs: Display) -> Bool? {
        sorter.dueDateSortResult(lhs, rhs)
    }

    func regularManualOrderSectionKey(for task: Display) -> String {
        sorter.regularManualOrderSectionKey(for: task)
    }

    func matchesSearch(_ task: Display) -> Bool {
        predicate.matchesSearch(task)
    }

    func matchesFilter(_ task: Display) -> Bool {
        predicate.matchesFilter(task)
    }

    func matchesManualPlaceFilter(_ task: Display) -> Bool {
        predicate.matchesManualPlaceFilter(task)
    }

    func matchesTodoStateFilter(_ task: Display) -> Bool {
        predicate.matchesTodoStateFilter(task)
    }

    func matchesTaskListViewMode(_ task: Display) -> Bool {
        predicate.matchesTaskListViewMode(task)
    }

    func sectionDateForDeadlineGrouping(for task: Display) -> Date? {
        metrics.sectionDateForDeadlineGrouping(for: task)
    }

    func deadlineSectionTitle(for task: Display) -> String {
        metrics.deadlineSectionTitle(for: task)
    }

    func formattedDeadlineSectionTitle(for date: Date) -> String {
        metrics.formattedDeadlineSectionTitle(for: date)
    }

    func isYellowUrgency(_ task: Display) -> Bool {
        metrics.isYellowUrgency(task)
    }

    func dueInDays(for task: Display) -> Int {
        metrics.dueInDays(for: task)
    }

    func overdueDays(for task: Display) -> Int {
        metrics.overdueDays(for: task)
    }

    func hasMissedExactTimedOccurrence(for task: Display) -> Bool {
        metrics.hasMissedExactTimedOccurrence(for: task)
    }

    func daysSinceLastRoutine(_ task: Display) -> Int {
        metrics.daysSinceLastRoutine(task)
    }

    func daysSinceScheduleAnchor(_ task: Display) -> Int {
        metrics.daysSinceScheduleAnchor(task)
    }

    func urgencyLevel(for task: Display) -> Int {
        metrics.urgencyLevel(for: task)
    }
}
