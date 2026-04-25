struct HomeTaskListSectionBuilder<Display: HomeTaskListDisplay> {
    var configuration: HomeTaskListFilteringConfiguration
    var metrics: HomeTaskListMetrics<Display>
    var sorter: HomeTaskListSorter<Display>

    func groupedRoutineSections(from filteredTasks: [Display]) -> [HomeTaskListSection<Display>] {
        let overdue = filteredTasks.filter { metrics.overdueDays(for: $0) > 0 }
        let dueSoon = filteredTasks.filter {
            !$0.isDoneToday
                && metrics.overdueDays(for: $0) == 0
                && (metrics.urgencyLevel(for: $0) > 0 || metrics.isYellowUrgency($0))
        }
        let onTrack = filteredTasks.filter {
            !$0.isDoneToday
                && metrics.overdueDays(for: $0) == 0
                && metrics.urgencyLevel(for: $0) == 0
                && !metrics.isYellowUrgency($0)
        }
        let doneToday = filteredTasks.filter(\.isDoneToday)

        let onTrackSections: [HomeTaskListSection<Display>]
        switch configuration.routineListSectioningMode {
        case .status:
            onTrackSections = [HomeTaskListSection(title: "On Track", tasks: onTrack)]
        case .deadlineDate:
            onTrackSections = deadlineBasedSections(from: onTrack)
        }

        return (
            [
                HomeTaskListSection(title: "Overdue", tasks: overdue),
                HomeTaskListSection(title: "Due Soon", tasks: dueSoon)
            ]
            + onTrackSections
            + [HomeTaskListSection(title: "Done Today", tasks: doneToday)]
        )
        .filter { !$0.tasks.isEmpty }
    }

    func deadlineBasedSections(from tasks: [Display]) -> [HomeTaskListSection<Display>] {
        guard !tasks.isEmpty else { return [] }

        let sorted = tasks.sorted { lhs, rhs in
            let lhsDate = metrics.sectionDateForDeadlineGrouping(for: lhs) ?? .distantFuture
            let rhsDate = metrics.sectionDateForDeadlineGrouping(for: rhs) ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return sorter.regularTaskSort(lhs, rhs)
        }

        var sections: [HomeTaskListSection<Display>] = []
        for task in sorted {
            let title = metrics.deadlineSectionTitle(for: task)
            if let lastIndex = sections.indices.last, sections[lastIndex].title == title {
                sections[lastIndex].tasks.append(task)
            } else {
                sections.append(HomeTaskListSection(title: title, tasks: [task]))
            }
        }

        return sections
    }
}
