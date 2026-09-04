import Foundation

extension HomeTaskListPresentation {
    static func sidebarCustomTaskSections(
        from sections: [HomeCustomTaskSection],
        displays: [Display],
        filtering: HomeTaskListFiltering<Display>,
        claimedTaskIDs: inout Set<UUID>
    ) -> [SidebarCustomTaskSection] {
        let topLevelSections = HomeCustomTaskSectionStorage.topLevelSections(
            in: sections,
            surface: .radar
        )
        return topLevelSections.compactMap { section in
            var taskGroups: [HomeTaskListPresentationTaskGroup<Display>] = []
            var allTasks: [Display] = []

            let subsections = HomeCustomTaskSectionStorage.subsections(of: section.id, in: sections)
            for subsection in subsections {
                let tasks = claimTasks(
                    filtering.filteredCustomTaskSectionTasks(displays, section: subsection),
                    claimedTaskIDs: &claimedTaskIDs
                )
                guard !tasks.isEmpty else { continue }
                allTasks.append(contentsOf: tasks)
                taskGroups.append(
                    HomeTaskListPresentationTaskGroup(
                        kind: .custom,
                        identityKey: HomeCustomTaskSectionStorage.manualOrderSectionKey(for: subsection.id),
                        title: subsection.title,
                        tasks: tasks,
                        moveContext: HomeTaskListMoveContext(
                            sectionKey: HomeTaskListFiltering<Display>.customManualOrderSectionKey(
                                for: subsection.id
                            ),
                            orderedTaskIDs: tasks.map(\.taskID)
                        ),
                        isCollapsible: true
                    )
                )
            }

            let parentTasks = claimTasks(
                filtering.filteredCustomTaskSectionTasks(displays, section: section),
                claimedTaskIDs: &claimedTaskIDs
            )
            if !parentTasks.isEmpty {
                allTasks.insert(contentsOf: parentTasks, at: 0)
                taskGroups.insert(
                    HomeTaskListPresentationTaskGroup(
                        kind: .custom,
                        identityKey: HomeCustomTaskSectionStorage.manualOrderSectionKey(for: section.id),
                        title: nil,
                        tasks: parentTasks,
                        moveContext: HomeTaskListMoveContext(
                            sectionKey: HomeTaskListFiltering<Display>.customManualOrderSectionKey(
                                for: section.id
                            ),
                            orderedTaskIDs: parentTasks.map(\.taskID)
                        ),
                        isCollapsible: false
                    ),
                    at: 0
                )
            }

            guard !allTasks.isEmpty || section.isPaused else { return nil }
            return SidebarCustomTaskSection(
                section: section,
                tasks: allTasks,
                taskGroups: taskGroups
            )
        }
    }

    static func sidebarPlanTodayTaskGroups(
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
                    title: separateDailyRoutinesInTaskList ? "Daily repeating tasks" : nil,
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

    static func sidebarFutureSection(
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

    static func sidebarFutureGroupKind(
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

    static func sidebarFutureTagTaskKindGroups(
        from section: HomeTaskListSection<Display>,
        parentKind: HomeTaskListPresentationSectionKind,
        separateTodosAndRoutinesInTagSections: Bool
    ) -> [HomeTaskListPresentationTaskGroup<Display>] {
        guard separateTodosAndRoutinesInTagSections,
            parentKind == .tag || parentKind == .untagged
        else {
            return []
        }

        let todos = section.tasks.filter(\.isOneOffTask)
        let routines = section.tasks.filter { !$0.isOneOffTask }
        let childGroupCount = [todos, routines].filter { !$0.isEmpty }.count
        guard childGroupCount > 1 else { return [] }

        return [
            HomeTaskListPresentationTaskGroup(
                kind: .regular,
                identityKey: "\(section.identityKey):todos",
                title: "One-time tasks",
                tasks: todos,
                moveContext: nil,
                isCollapsible: true
            ),
            HomeTaskListPresentationTaskGroup(
                kind: .regular,
                identityKey: "\(section.identityKey):routines",
                title: "Repeating tasks",
                tasks: routines,
                moveContext: nil,
                isCollapsible: true
            ),
        ].filter { !$0.tasks.isEmpty }
    }

    static func isDeadlineStatusSection(_ section: HomeTaskListSection<Display>) -> Bool {
        switch section.identityKey {
        case "missed", "overdue", "dueSoon", "doneToday":
            return true
        default:
            return false
        }
    }

}
