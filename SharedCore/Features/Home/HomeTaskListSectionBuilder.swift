struct HomeTaskListSectionBuilder<Display: HomeTaskListDisplay> {
    static var ungroupedTitle: String { "Tasks" }

    var configuration: HomeTaskListFilteringConfiguration
    var metrics: HomeTaskListMetrics<Display>
    var sorter: HomeTaskListSorter<Display>

    func groupedRoutineSections(from filteredTasks: [Display]) -> [HomeTaskListSection<Display>] {
        switch configuration.routineListSectioningMode {
        case .none:
            return filteredTasks.isEmpty
                ? []
                : [HomeTaskListSection(identityKey: "tasks", title: Self.ungroupedTitle, tasks: filteredTasks)]
        case .tags:
            return configuration.separateDeadlineStatusInTagSections
                ? tagBasedSectionsWithDeadlineStatus(from: filteredTasks)
                : tagBasedSections(from: filteredTasks)
        case .status, .deadlineDate:
            break
        }

        let bucketedTasks = filteredTasks.reduce(into: [HomeTaskListStatusBucket: [Display]]()) { buckets, task in
            buckets[statusBucket(for: task), default: []].append(task)
        }

        let onTrackSections: [HomeTaskListSection<Display>]
        switch configuration.routineListSectioningMode {
        case .none:
            onTrackSections = []
        case .status:
            onTrackSections = [
                HomeTaskListSection(
                    identityKey: HomeTaskListStatusBucket.onTrack.identityKey,
                    title: HomeTaskListStatusBucket.onTrack.title,
                    tasks: bucketedTasks[.onTrack, default: []]
                )
            ]
        case .deadlineDate:
            onTrackSections = deadlineBasedSections(from: bucketedTasks[.onTrack, default: []])
        case .tags:
            onTrackSections = []
        }

        return (
            [
                HomeTaskListSection(
                    identityKey: HomeTaskListStatusBucket.missed.identityKey,
                    title: HomeTaskListStatusBucket.missed.title,
                    tasks: bucketedTasks[.missed, default: []]
                ),
                HomeTaskListSection(
                    identityKey: HomeTaskListStatusBucket.overdue.identityKey,
                    title: HomeTaskListStatusBucket.overdue.title,
                    tasks: bucketedTasks[.overdue, default: []]
                ),
                HomeTaskListSection(
                    identityKey: HomeTaskListStatusBucket.dueSoon.identityKey,
                    title: HomeTaskListStatusBucket.dueSoon.title,
                    tasks: bucketedTasks[.dueSoon, default: []]
                )
            ]
            + onTrackSections
            + [
                HomeTaskListSection(
                    identityKey: HomeTaskListStatusBucket.doneToday.identityKey,
                    title: HomeTaskListStatusBucket.doneToday.title,
                    tasks: bucketedTasks[.doneToday, default: []]
                )
            ]
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
            let identityKey = metrics.deadlineSectionKey(for: task)
            if let lastIndex = sections.indices.last, sections[lastIndex].identityKey == identityKey {
                sections[lastIndex].tasks.append(task)
            } else {
                sections.append(HomeTaskListSection(identityKey: identityKey, title: title, tasks: [task]))
            }
        }

        return sections
    }

    func tagBasedSections(from tasks: [Display]) -> [HomeTaskListSection<Display>] {
        guard !tasks.isEmpty else { return [] }

        var groups: [String: (title: String, tasks: [Display], isUntagged: Bool)] = [:]
        for task in tasks {
            let descriptor = HomeTaskListTagGrouping.descriptor(for: task)
            let key = descriptor.sectionKey
            var group = groups[key] ?? (
                title: descriptor.title,
                tasks: [],
                isUntagged: descriptor.isUntagged
            )
            group.tasks.append(task)
            groups[key] = group
        }

        return groups.map { key, group in
            (identityKey: key, title: group.title, tasks: group.tasks, isUntagged: group.isUntagged)
        }
        .sorted { lhs, rhs in
            if lhs.isUntagged != rhs.isUntagged {
                return !lhs.isUntagged && rhs.isUntagged
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        .map { group in
            HomeTaskListSection(identityKey: group.identityKey, title: group.title, tasks: group.tasks)
        }
    }

    func tagBasedSectionsWithDeadlineStatus(from tasks: [Display]) -> [HomeTaskListSection<Display>] {
        guard !tasks.isEmpty else { return [] }

        let bucketedTasks = tasks.reduce(into: [HomeTaskListStatusBucket: [Display]]()) { buckets, task in
            buckets[statusBucket(for: task), default: []].append(task)
        }

        let leadingStatusSections = [
            HomeTaskListStatusBucket.missed,
            .overdue,
            .dueSoon
        ].compactMap { bucket in
            statusSection(bucket, tasks: bucketedTasks[bucket, default: []])
        }

        let tagSections = tagBasedSections(from: bucketedTasks[.onTrack, default: []])
        let doneTodaySections = statusSection(.doneToday, tasks: bucketedTasks[.doneToday, default: []])
            .map { [$0] } ?? []

        return leadingStatusSections
            + tagSections
            + doneTodaySections
    }

    private func statusSection(
        _ bucket: HomeTaskListStatusBucket,
        tasks: [Display]
    ) -> HomeTaskListSection<Display>? {
        guard !tasks.isEmpty else { return nil }
        return HomeTaskListSection(
            identityKey: bucket.identityKey,
            title: bucket.title,
            tasks: tasks
        )
    }

    private func statusBucket(for task: Display) -> HomeTaskListStatusBucket {
        if metrics.hasMissedExactTimedOccurrence(for: task) {
            return .missed
        }
        if metrics.overdueDays(for: task) > 0 {
            return .overdue
        }
        if task.isDoneToday {
            return .doneToday
        }
        if metrics.urgencyLevel(for: task) > 0 || metrics.isYellowUrgency(task) {
            return .dueSoon
        }
        return .onTrack
    }
}

private enum HomeTaskListStatusBucket: CaseIterable, Hashable {
    case missed
    case overdue
    case dueSoon
    case onTrack
    case doneToday

    var identityKey: String {
        switch self {
        case .missed:
            return "missed"
        case .overdue:
            return "overdue"
        case .dueSoon:
            return "dueSoon"
        case .onTrack:
            return "onTrack"
        case .doneToday:
            return "doneToday"
        }
    }

    var title: String {
        switch self {
        case .missed:
            return "Missed"
        case .overdue:
            return "Overdue"
        case .dueSoon:
            return "Due Soon"
        case .onTrack:
            return "On Track"
        case .doneToday:
            return "Done Today"
        }
    }
}
