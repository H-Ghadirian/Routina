import Foundation

struct HomeTaskListMoveContext: Equatable {
    let sectionKey: String
    let orderedTaskIDs: [UUID]
}

struct HomeTaskListPresentationTaskGroup<Display: HomeTaskListDisplay>: Identifiable {
    let kind: HomeTaskListPresentationSectionKind
    let identityKey: String?
    let title: String?
    let tasks: [Display]
    let moveContext: HomeTaskListMoveContext?
    let isCollapsible: Bool
    let childGroups: [HomeTaskListPresentationTaskGroup<Display>]

    init(
        kind: HomeTaskListPresentationSectionKind,
        identityKey: String? = nil,
        title: String?,
        tasks: [Display],
        moveContext: HomeTaskListMoveContext?,
        isCollapsible: Bool,
        childGroups: [HomeTaskListPresentationTaskGroup<Display>] = []
    ) {
        self.kind = kind
        self.identityKey = identityKey
        self.title = title
        self.tasks = tasks
        self.moveContext = moveContext
        self.isCollapsible = isCollapsible
        self.childGroups = childGroups
    }

    var id: String {
        identityKey ?? moveContext?.sectionKey ?? title ?? "primary"
    }
}

enum HomeTaskListPresentationSectionKind: String, Equatable {
    case pinned
    case plannedToday
    case plannedTomorrow
    case daily
    case future
    case regular
    case deadlineDate
    case tag
    case untagged
    case away
    case archived
}

extension HomeTaskListPresentationSectionKind {
    var isCollapsible: Bool {
        switch self {
        case .plannedToday, .plannedTomorrow, .daily, .future, .tag, .untagged, .archived:
            return true
        case .pinned, .regular, .deadlineDate, .away:
            return false
        }
    }
}

struct HomeTaskListPresentationSection<Display: HomeTaskListDisplay>: Identifiable {
    let kind: HomeTaskListPresentationSectionKind
    let identityKey: String
    let title: String
    let rowNumberOffset: Int
    let includeMarkDone: Bool
    let moveContext: HomeTaskListMoveContext?
    let taskGroups: [HomeTaskListPresentationTaskGroup<Display>]

    init(
        kind: HomeTaskListPresentationSectionKind,
        identityKey: String? = nil,
        title: String,
        tasks: [Display],
        rowNumberOffset: Int,
        includeMarkDone: Bool,
        moveContext: HomeTaskListMoveContext?,
        taskGroups: [HomeTaskListPresentationTaskGroup<Display>]? = nil
    ) {
        self.kind = kind
        self.identityKey = identityKey ?? moveContext?.sectionKey ?? title
        self.title = title
        self.rowNumberOffset = rowNumberOffset
        self.includeMarkDone = includeMarkDone
        self.moveContext = moveContext
        self.taskGroups = Self.deduplicatedTaskGroups(taskGroups ?? [
            HomeTaskListPresentationTaskGroup(
                kind: kind,
                title: nil,
                tasks: tasks,
                moveContext: moveContext,
                isCollapsible: false
            )
        ])
    }

    var id: String {
        "\(kind.rawValue):\(identityKey)"
    }

    var tasks: [Display] {
        taskGroups.flatMap(\.tasks)
    }

    func rowNumber(forTaskAt index: Int) -> Int {
        rowNumberOffset + index + 1
    }

    private static func deduplicatedTaskGroups(
        _ taskGroups: [HomeTaskListPresentationTaskGroup<Display>]
    ) -> [HomeTaskListPresentationTaskGroup<Display>] {
        var groups: [HomeTaskListPresentationTaskGroup<Display>] = []
        var groupIndicesByID: [String: Int] = [:]
        var seenTaskIDs: Set<UUID> = []

        for group in taskGroups {
            let uniqueTasks = group.tasks.filter { task in
                seenTaskIDs.insert(task.taskID).inserted
            }
            guard !uniqueTasks.isEmpty else { continue }
            let uniqueTaskIDs = Set(uniqueTasks.map(\.taskID))
            let uniqueChildGroups = childGroups(group.childGroups, limitedTo: uniqueTaskIDs)

            if let existingIndex = groupIndicesByID[group.id] {
                let existingGroup = groups[existingIndex]
                let mergedTasks = existingGroup.tasks + uniqueTasks
                groups[existingIndex] = HomeTaskListPresentationTaskGroup(
                    kind: existingGroup.kind,
                    identityKey: existingGroup.identityKey,
                    title: existingGroup.title,
                    tasks: mergedTasks,
                    moveContext: Self.moveContext(existingGroup.moveContext, orderedBy: mergedTasks),
                    isCollapsible: existingGroup.isCollapsible || group.isCollapsible,
                    childGroups: deduplicatedTaskGroups(existingGroup.childGroups + uniqueChildGroups)
                )
            } else {
                groupIndicesByID[group.id] = groups.count
                groups.append(
                    HomeTaskListPresentationTaskGroup(
                        kind: group.kind,
                        identityKey: group.identityKey,
                        title: group.title,
                        tasks: uniqueTasks,
                        moveContext: Self.moveContext(group.moveContext, orderedBy: uniqueTasks),
                        isCollapsible: group.isCollapsible,
                        childGroups: uniqueChildGroups
                    )
                )
            }
        }

        return groups
    }

    private static func childGroups(
        _ childGroups: [HomeTaskListPresentationTaskGroup<Display>],
        limitedTo taskIDs: Set<UUID>
    ) -> [HomeTaskListPresentationTaskGroup<Display>] {
        childGroups.compactMap { childGroup in
            let uniqueTasks = childGroup.tasks.filter { taskIDs.contains($0.taskID) }
            guard !uniqueTasks.isEmpty else { return nil }
            return HomeTaskListPresentationTaskGroup(
                kind: childGroup.kind,
                identityKey: childGroup.identityKey,
                title: childGroup.title,
                tasks: uniqueTasks,
                moveContext: Self.moveContext(childGroup.moveContext, orderedBy: uniqueTasks),
                isCollapsible: childGroup.isCollapsible,
                childGroups: Self.childGroups(
                    childGroup.childGroups,
                    limitedTo: Set(uniqueTasks.map(\.taskID))
                )
            )
        }
    }

    private static func moveContext(
        _ moveContext: HomeTaskListMoveContext?,
        orderedBy tasks: [Display]
    ) -> HomeTaskListMoveContext? {
        guard let moveContext else { return nil }
        return HomeTaskListMoveContext(
            sectionKey: moveContext.sectionKey,
            orderedTaskIDs: tasks.map(\.taskID)
        )
    }
}

struct HomeTaskListEmptyState: Equatable {
    let title: String
    let message: String
    let systemImage: String
}

struct HomeTaskListPresentation<Display: HomeTaskListDisplay> {
    let sections: [HomeTaskListPresentationSection<Display>]
    let hiddenUnavailableTaskCount: Int
    let emptyState: HomeTaskListEmptyState?

    var visibleTaskCount: Int {
        sections.reduce(0) { $0 + $1.tasks.count }
    }

    private static func claimTasks(
        _ tasks: [Display],
        claimedTaskIDs: inout Set<UUID>
    ) -> [Display] {
        var claimedTasks: [Display] = []
        for task in tasks where !claimedTaskIDs.contains(task.taskID) {
            claimedTaskIDs.insert(task.taskID)
            claimedTasks.append(task)
        }
        return claimedTasks
    }

    private static func claimSections(
        _ sections: [HomeTaskListSection<Display>],
        claimedTaskIDs: inout Set<UUID>
    ) -> [HomeTaskListSection<Display>] {
        sections.compactMap { section in
            let tasks = claimTasks(section.tasks, claimedTaskIDs: &claimedTaskIDs)
            guard !tasks.isEmpty else { return nil }
            return HomeTaskListSection(
                identityKey: section.identityKey,
                title: section.title,
                tasks: tasks
            )
        }
    }

    static func iOS(
        filtering: HomeTaskListFiltering<Display>,
        routineDisplays: [Display],
        awayRoutineDisplays: [Display],
        archivedRoutineDisplays: [Display],
        hideUnavailableRoutines: Bool,
        showArchivedTasks: Bool = true,
        taskListKind: HomeFilterTaskListKind
    ) -> Self {
        let visibleArchivedDisplays = showArchivedTasks ? archivedRoutineDisplays : []
        var claimedTaskIDs: Set<UUID> = []
        let pinnedTasks = claimTasks(
            filtering.filteredPinnedTasks(
                activeDisplays: routineDisplays,
                awayDisplays: hideUnavailableRoutines ? [] : awayRoutineDisplays,
                archivedDisplays: visibleArchivedDisplays
            ),
            claimedTaskIDs: &claimedTaskIDs
        )
        let unpinnedRoutineDisplays = routineDisplays.filter {
            !$0.isPinned && !claimedTaskIDs.contains($0.taskID)
        }
        let plannedTodayTasks = claimTasks(
            filtering.filteredPlannedTodayTasks(unpinnedRoutineDisplays),
            claimedTaskIDs: &claimedTaskIDs
        )
        let unplannedRoutineDisplays = unpinnedRoutineDisplays.filter {
            !claimedTaskIDs.contains($0.taskID)
        }
        let dailyTasks = claimTasks(
            filtering.filteredDailyRoutineTasks(unplannedRoutineDisplays),
            claimedTaskIDs: &claimedTaskIDs
        )
        let nonDailyUnplannedRoutineDisplays = unplannedRoutineDisplays.filter {
            !$0.isDailyRoutine && !claimedTaskIDs.contains($0.taskID)
        }
        let regularSections = claimSections(
            filtering.groupedRoutineSections(from: nonDailyUnplannedRoutineDisplays),
            claimedTaskIDs: &claimedTaskIDs
        )
        let awayTasks = claimTasks(
            filtering.filteredAwayTasks(
                awayRoutineDisplays.filter {
                    !$0.isPinned && !claimedTaskIDs.contains($0.taskID)
                }
            ),
            claimedTaskIDs: &claimedTaskIDs
        )
        let archivedTasks = showArchivedTasks
            ? claimTasks(
                filtering.filteredArchivedTasks(
                    archivedRoutineDisplays.filter { !claimedTaskIDs.contains($0.taskID) }
                ),
                claimedTaskIDs: &claimedTaskIDs
            )
            : []

        var offset = 0
        var presentationSections: [HomeTaskListPresentationSection<Display>] = []

        if !pinnedTasks.isEmpty {
            presentationSections.append(
                HomeTaskListPresentationSection(
                    kind: .pinned,
                    identityKey: "pinned",
                    title: "Pinned",
                    tasks: pinnedTasks,
                    rowNumberOffset: offset,
                    includeMarkDone: true,
                    moveContext: nil
                )
            )
            offset += pinnedTasks.count
        }

        if !plannedTodayTasks.isEmpty {
            presentationSections.append(
                HomeTaskListPresentationSection(
                    kind: .plannedToday,
                    identityKey: "plannedToday",
                    title: "Today",
                    tasks: plannedTodayTasks,
                    rowNumberOffset: offset,
                    includeMarkDone: true,
                    moveContext: HomeTaskListMoveContext(
                        sectionKey: HomeTaskListFiltering<Display>.plannedTodayManualOrderSectionKey,
                        orderedTaskIDs: plannedTodayTasks.map(\.taskID)
                    )
                )
            )
            offset += plannedTodayTasks.count
        }

        if !dailyTasks.isEmpty {
            presentationSections.append(
                HomeTaskListPresentationSection(
                    kind: .daily,
                    identityKey: "daily",
                    title: "Daily Routines",
                    tasks: dailyTasks,
                    rowNumberOffset: offset,
                    includeMarkDone: true,
                    moveContext: nil
                )
            )
            offset += dailyTasks.count
        }

        if filtering.usesTagSectioning {
            presentationSections += tagPresentationSections(
                from: regularSections,
                offset: &offset,
                includeMarkDone: true,
                moveContext: { _ in nil }
            )
        } else if filtering.usesUngroupedSectioning {
            for section in regularSections {
                presentationSections.append(
                    HomeTaskListPresentationSection(
                        kind: .regular,
                        identityKey: section.identityKey,
                        title: section.title,
                        tasks: section.tasks,
                        rowNumberOffset: offset,
                        includeMarkDone: true,
                        moveContext: nil
                    )
                )
                offset += section.tasks.count
            }
        } else {
            presentationSections += regularSections.map { section in
                defer { offset += section.tasks.count }
                return HomeTaskListPresentationSection(
                    kind: .regular,
                    identityKey: section.identityKey,
                    title: section.title,
                    tasks: section.tasks,
                    rowNumberOffset: offset,
                    includeMarkDone: true,
                    moveContext: nil
                )
            }
        }

        if !hideUnavailableRoutines && !awayTasks.isEmpty {
            presentationSections.append(
                HomeTaskListPresentationSection(
                    kind: .away,
                    identityKey: "away",
                    title: "Not Here Right Now",
                    tasks: awayTasks,
                    rowNumberOffset: offset,
                    includeMarkDone: false,
                    moveContext: nil
                )
            )
            offset += awayTasks.count
        }

        if !archivedTasks.isEmpty {
            presentationSections.append(
                HomeTaskListPresentationSection(
                    kind: .archived,
                    identityKey: "archived",
                    title: "Archived",
                    tasks: archivedTasks,
                    rowNumberOffset: offset,
                    includeMarkDone: true,
                    moveContext: nil
                )
            )
        }

        let hiddenUnavailableTaskCount = hideUnavailableRoutines ? awayTasks.count : 0
        return HomeTaskListPresentation(
            sections: presentationSections,
            hiddenUnavailableTaskCount: hiddenUnavailableTaskCount,
            emptyState: iOSEmptyState(
                isEmpty: presentationSections.isEmpty,
                hiddenUnavailableTaskCount: hiddenUnavailableTaskCount,
                taskListKind: taskListKind
            )
        )
    }

    static func sidebar(
        filtering: HomeTaskListFiltering<Display>,
        routineDisplays: [Display],
        awayRoutineDisplays: [Display],
        archivedRoutineDisplays: [Display],
        showArchivedTasks: Bool = true,
        separateDailyRoutinesInTaskList: Bool = false,
        showTomorrowSection: Bool = false,
        separateTodosAndRoutinesInTagSections: Bool = false,
        emptyState: HomeTaskListEmptyState
    ) -> Self {
        let visibleArchivedDisplays = showArchivedTasks ? archivedRoutineDisplays : []
        var claimedTaskIDs: Set<UUID> = []
        let pinnedTasks = claimTasks(
            filtering.filteredPinnedTasks(
                activeDisplays: routineDisplays,
                awayDisplays: awayRoutineDisplays,
                archivedDisplays: visibleArchivedDisplays
            ),
            claimedTaskIDs: &claimedTaskIDs
        )
        let unpinnedActiveDisplays = (routineDisplays + awayRoutineDisplays).filter {
            !$0.isPinned && !claimedTaskIDs.contains($0.taskID)
        }
        let plannedTodayTasks = claimTasks(
            filtering.filteredPlannedTodayTasks(unpinnedActiveDisplays),
            claimedTaskIDs: &claimedTaskIDs
        )
        let activeDisplaysAfterTodayClaim = unpinnedActiveDisplays.filter {
            !claimedTaskIDs.contains($0.taskID)
        }
        let plannedTomorrowTasks = showTomorrowSection
            ? claimTasks(
                filtering.filteredPlannedTomorrowTasks(activeDisplaysAfterTodayClaim),
                claimedTaskIDs: &claimedTaskIDs
            )
            : []
        let unplannedActiveDisplays = activeDisplaysAfterTodayClaim.filter {
            !claimedTaskIDs.contains($0.taskID)
        }
        let dailyTasks = claimTasks(
            filtering.filteredDailyRoutineTasks(unplannedActiveDisplays)
                .filter { filtering.matchesUncompletedTodayClaim($0) },
            claimedTaskIDs: &claimedTaskIDs
        )
        let nonDailyUnplannedActiveDisplays = unplannedActiveDisplays.filter {
            !$0.isDailyRoutine && !claimedTaskIDs.contains($0.taskID)
        }
        let regularSections = claimSections(
            filtering.groupedRoutineSections(from: nonDailyUnplannedActiveDisplays),
            claimedTaskIDs: &claimedTaskIDs
        )
        let archivedTasks = claimTasks(
            filtering.filteredArchivedTasks(
                visibleArchivedDisplays.filter { !claimedTaskIDs.contains($0.taskID) },
                includePinned: false
            ),
            claimedTaskIDs: &claimedTaskIDs
        )

        var offset = 0
        var presentationSections: [HomeTaskListPresentationSection<Display>] = []

        if !pinnedTasks.isEmpty {
            presentationSections.append(
                HomeTaskListPresentationSection(
                    kind: .pinned,
                    identityKey: "pinned",
                    title: "Pinned",
                    tasks: pinnedTasks,
                    rowNumberOffset: offset,
                    includeMarkDone: true,
                    moveContext: HomeTaskListMoveContext(
                        sectionKey: HomeTaskListFiltering<Display>.pinnedManualOrderSectionKey,
                        orderedTaskIDs: pinnedTasks.map(\.taskID)
                    )
                )
            )
            offset += pinnedTasks.count
        }

        let planTodayTaskGroups = sidebarPlanTodayTaskGroups(
            plannedTodayTasks: plannedTodayTasks,
            dailyTasks: dailyTasks,
            separateDailyRoutinesInTaskList: separateDailyRoutinesInTaskList
        )
        let planTodayTasks = planTodayTaskGroups.flatMap(\.tasks)

        if !planTodayTasks.isEmpty {
            presentationSections.append(
                HomeTaskListPresentationSection(
                    kind: .plannedToday,
                    identityKey: "plannedToday",
                    title: "Today",
                    tasks: planTodayTasks,
                    rowNumberOffset: offset,
                    includeMarkDone: true,
                    moveContext: nil,
                    taskGroups: planTodayTaskGroups
                )
            )
            offset += planTodayTasks.count
        }

        if !plannedTomorrowTasks.isEmpty {
            presentationSections.append(
                HomeTaskListPresentationSection(
                    kind: .plannedTomorrow,
                    identityKey: "plannedTomorrow",
                    title: "Tomorrow",
                    tasks: plannedTomorrowTasks,
                    rowNumberOffset: offset,
                    includeMarkDone: true,
                    moveContext: HomeTaskListMoveContext(
                        sectionKey: HomeTaskListFiltering<Display>.plannedTomorrowManualOrderSectionKey,
                        orderedTaskIDs: plannedTomorrowTasks.map(\.taskID)
                    )
                )
            )
            offset += plannedTomorrowTasks.count
        }

        if filtering.usesTagSectioning {
            let separatesDeadlineStatusInTagSections = filtering.separatesDeadlineStatusInTagSections
            if let futureSection = sidebarFutureSection(
                from: regularSections,
                offset: &offset,
                showsGroupTitles: true,
                usesDeadlineDateSectioning: separatesDeadlineStatusInTagSections,
                separateTodosAndRoutinesInTagSections: separateTodosAndRoutinesInTagSections,
                moveContext: { section in
                    HomeTaskListMoveContext(
                        sectionKey: separatesDeadlineStatusInTagSections
                            && isDeadlineStatusSection(section)
                            ? section.identityKey
                            : section.tasks.first.map { filtering.regularManualOrderSectionKey(for: $0) }
                                ?? HomeTaskListTagGrouping.sectionKey(for: nil),
                        orderedTaskIDs: section.tasks.map(\.taskID)
                    )
                }
            ) {
                presentationSections.append(futureSection)
            }
        } else if filtering.usesUngroupedSectioning {
            if let futureSection = sidebarFutureSection(
                from: regularSections,
                offset: &offset,
                showsGroupTitles: false,
                usesDeadlineDateSectioning: false,
                separateTodosAndRoutinesInTagSections: false,
                moveContext: { section in
                    HomeTaskListMoveContext(
                        sectionKey: HomeTaskListFiltering<Display>.ungroupedManualOrderSectionKey,
                        orderedTaskIDs: section.tasks.map(\.taskID)
                    )
                }
            ) {
                presentationSections.append(futureSection)
            }
        } else {
            if let futureSection = sidebarFutureSection(
                from: regularSections,
                offset: &offset,
                showsGroupTitles: true,
                usesDeadlineDateSectioning: filtering.usesDeadlineDateSectioning,
                separateTodosAndRoutinesInTagSections: false,
                moveContext: { section in
                    HomeTaskListMoveContext(
                        sectionKey: section.tasks.first.map { filtering.regularManualOrderSectionKey(for: $0) } ?? "onTrack",
                        orderedTaskIDs: section.tasks.map(\.taskID)
                    )
                }
            ) {
                presentationSections.append(futureSection)
            }
        }

        if !archivedTasks.isEmpty {
            presentationSections.append(
                HomeTaskListPresentationSection(
                    kind: .archived,
                    identityKey: "archived",
                    title: "Archived",
                    tasks: archivedTasks,
                    rowNumberOffset: offset,
                    includeMarkDone: true,
                    moveContext: HomeTaskListMoveContext(
                        sectionKey: HomeTaskListFiltering<Display>.archivedManualOrderSectionKey,
                        orderedTaskIDs: archivedTasks.map(\.taskID)
                    )
                )
            )
        }

        return HomeTaskListPresentation(
            sections: presentationSections,
            hiddenUnavailableTaskCount: 0,
            emptyState: presentationSections.isEmpty ? emptyState : nil
        )
    }

    private static func sidebarPlanTodayTaskGroups(
        plannedTodayTasks: [Display],
        dailyTasks: [Display],
        separateDailyRoutinesInTaskList: Bool
    ) -> [HomeTaskListPresentationTaskGroup<Display>] {
        var groups: [HomeTaskListPresentationTaskGroup<Display>] = []

        if !plannedTodayTasks.isEmpty {
            groups.append(
                HomeTaskListPresentationTaskGroup(
                    kind: .plannedToday,
                    title: nil,
                    tasks: plannedTodayTasks,
                    moveContext: HomeTaskListMoveContext(
                        sectionKey: HomeTaskListFiltering<Display>.plannedTodayManualOrderSectionKey,
                        orderedTaskIDs: plannedTodayTasks.map(\.taskID)
                    ),
                    isCollapsible: false
                )
            )
        }

        if !dailyTasks.isEmpty {
            groups.append(
                HomeTaskListPresentationTaskGroup(
                    kind: .daily,
                    title: separateDailyRoutinesInTaskList ? "Daily Routines" : nil,
                    tasks: dailyTasks,
                    moveContext: HomeTaskListMoveContext(
                        sectionKey: HomeTaskListFiltering<Display>.dailyManualOrderSectionKey,
                        orderedTaskIDs: dailyTasks.map(\.taskID)
                    ),
                    isCollapsible: separateDailyRoutinesInTaskList
                )
            )
        }

        return groups
    }

    private static func sidebarFutureSection(
        from regularSections: [HomeTaskListSection<Display>],
        offset: inout Int,
        showsGroupTitles: Bool,
        usesDeadlineDateSectioning: Bool,
        separateTodosAndRoutinesInTagSections: Bool,
        moveContext: (HomeTaskListSection<Display>) -> HomeTaskListMoveContext?
    ) -> HomeTaskListPresentationSection<Display>? {
        let taskGroups = regularSections.map { section in
            let kind = sidebarFutureGroupKind(
                for: section,
                showsGroupTitles: showsGroupTitles,
                usesDeadlineDateSectioning: usesDeadlineDateSectioning
            )
            let childGroups = sidebarFutureTagTaskKindGroups(
                from: section,
                parentKind: kind,
                separateTodosAndRoutinesInTagSections: separateTodosAndRoutinesInTagSections
            )
            return HomeTaskListPresentationTaskGroup(
                kind: kind,
                title: showsGroupTitles ? section.title : nil,
                tasks: section.tasks,
                moveContext: moveContext(section),
                isCollapsible: kind == .tag || kind == .untagged || kind == .deadlineDate,
                childGroups: childGroups
            )
        }
        let tasks = taskGroups.flatMap(\.tasks)
        guard !tasks.isEmpty else { return nil }

        defer { offset += tasks.count }
        return HomeTaskListPresentationSection(
            kind: .future,
            identityKey: "future",
            title: "Future",
            tasks: tasks,
            rowNumberOffset: offset,
            includeMarkDone: true,
            moveContext: nil,
            taskGroups: taskGroups
        )
    }

    private static func sidebarFutureGroupKind(
        for section: HomeTaskListSection<Display>,
        showsGroupTitles: Bool,
        usesDeadlineDateSectioning: Bool
    ) -> HomeTaskListPresentationSectionKind {
        guard showsGroupTitles else { return .regular }
        if HomeTaskListTagGrouping.isUntaggedTitle(section.title) {
            return .untagged
        }
        if section.title.hasPrefix("#") {
            return .tag
        }
        if usesDeadlineDateSectioning {
            return .deadlineDate
        }
        if section.identityKey.hasPrefix("deadline:") {
            return .deadlineDate
        }
        return .regular
    }

    private static func sidebarFutureTagTaskKindGroups(
        from section: HomeTaskListSection<Display>,
        parentKind: HomeTaskListPresentationSectionKind,
        separateTodosAndRoutinesInTagSections: Bool
    ) -> [HomeTaskListPresentationTaskGroup<Display>] {
        guard separateTodosAndRoutinesInTagSections,
              parentKind == .tag || parentKind == .untagged else {
            return []
        }

        let todos = section.tasks.filter(\.isOneOffTask)
        let routines = section.tasks.filter { !$0.isOneOffTask && $0.scheduleMode.taskType == .routine }
        let records = section.tasks.filter { $0.scheduleMode.taskType == .record }
        let childGroupCount = [todos, routines, records].filter { !$0.isEmpty }.count
        guard childGroupCount > 1 else { return [] }

        return [
            HomeTaskListPresentationTaskGroup(
                kind: .regular,
                identityKey: "\(section.identityKey):todos",
                title: "Todos",
                tasks: todos,
                moveContext: nil,
                isCollapsible: true
            ),
            HomeTaskListPresentationTaskGroup(
                kind: .regular,
                identityKey: "\(section.identityKey):routines",
                title: "Routines",
                tasks: routines,
                moveContext: nil,
                isCollapsible: true
            ),
            HomeTaskListPresentationTaskGroup(
                kind: .regular,
                identityKey: "\(section.identityKey):records",
                title: "Records",
                tasks: records,
                moveContext: nil,
                isCollapsible: true
            )
        ].filter { !$0.tasks.isEmpty }
    }

    private static func isDeadlineStatusSection(_ section: HomeTaskListSection<Display>) -> Bool {
        switch section.identityKey {
        case "missed", "overdue", "dueSoon", "doneToday":
            return true
        default:
            return false
        }
    }

    private static func tagPresentationSections(
        from tagSections: [HomeTaskListSection<Display>],
        offset: inout Int,
        includeMarkDone: Bool,
        moveContext: (HomeTaskListSection<Display>) -> HomeTaskListMoveContext?
    ) -> [HomeTaskListPresentationSection<Display>] {
        tagSections.map { section in
            defer { offset += section.tasks.count }
            return HomeTaskListPresentationSection(
                kind: HomeTaskListTagGrouping.isUntaggedTitle(section.title) ? .untagged : .tag,
                identityKey: section.identityKey,
                title: section.title,
                tasks: section.tasks,
                rowNumberOffset: offset,
                includeMarkDone: includeMarkDone,
                moveContext: moveContext(section)
            )
        }
    }

    private static func iOSEmptyState(
        isEmpty: Bool,
        hiddenUnavailableTaskCount: Int,
        taskListKind: HomeFilterTaskListKind
    ) -> HomeTaskListEmptyState? {
        guard isEmpty else { return nil }

        if hiddenUnavailableTaskCount > 0 {
            return HomeTaskListEmptyState(
                title: "No routines available here",
                message: "\(hiddenUnavailableTaskCount) routines are hidden because you are away from their matching places.",
                systemImage: "location.slash"
            )
        }

        return HomeTaskListEmptyState(
            title: noMatchingTitle(for: taskListKind),
            message: "Try a different search or switch back to another filter.",
            systemImage: "magnifyingglass"
        )
    }

    private static func noMatchingTitle(for taskListKind: HomeFilterTaskListKind) -> String {
        switch taskListKind {
        case .all:
            return "No matching tasks"
        case .routines:
            return "No matching routines"
        case .todos:
            return "No matching todos"
        case .records:
            return "No matching records"
        }
    }
}
