import Foundation

struct HomeTaskListFiltering<Display: HomeTaskListDisplay> {
    static var pinnedManualOrderSectionKey: String {
        HomeTaskListSorter<Display>.pinnedManualOrderSectionKey
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
        sortedTasks(displays).filter(predicate.matchesVisibleTask)
    }

    func filteredAwayTasks(_ displays: [Display]) -> [Display] {
        sortedTasks(displays).filter(predicate.matchesVisibleTask)
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
        let activePinned = sortedTasks(activeDisplays + awayDisplays).filter { task in
            task.isPinned && predicate.matchesVisibleTask(task)
        }
        let archivedPinned = filteredArchivedTasks(archivedDisplays).filter(\.isPinned)

        return (activePinned + archivedPinned).sorted(by: sorter.pinnedTaskSort)
    }

    func groupedRoutineSections(from displays: [Display]) -> [HomeTaskListSection<Display>] {
        sectionBuilder.groupedRoutineSections(from: filteredTasks(displays))
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
