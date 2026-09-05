import Foundation

/// A stable, reducer-owned snapshot for Backlog workspaces. Home intentionally
/// does not build this presentation while its task list scrolls.
struct BacklogTaskListPresentation: Equatable {
    struct FilterCatalog: Equatable {
        let tags: [String]
        let tagCounts: [String: Int]
        let flags: [String]

        static let empty = Self(tags: [], tagCounts: [:], flags: [])
    }

    struct OutsideBacklogResult: Identifiable, Equatable {
        enum RevealDestination: Equatable {
            case planner
            case timeline
        }

        let task: RoutineTask
        let locationTitle: String
        let revealDestination: RevealDestination

        var id: UUID { task.id }
    }

    struct Subsection: Identifiable, Equatable {
        let section: HomeCustomTaskSection
        let tasks: [RoutineTask]

        var id: UUID { section.id }
    }

    struct Section: Identifiable, Equatable {
        let section: HomeCustomTaskSection
        let tasks: [RoutineTask]
        let subsections: [Subsection]

        var id: UUID { section.id }
        var taskCount: Int { tasks.count + subsections.reduce(0) { $0 + $1.tasks.count } }
    }

    let sections: [Section]
    /// Tasks hidden by a Flag remain discoverable even before the person gives
    /// them an explicit Backlog path.
    let hiddenByFlagTasks: [RoutineTask]
    /// Matching tasks that exist, but are not currently owned by Backlog.  They
    /// remain separate from the scoped result count so search never implies
    /// that a Radar or archived task belongs to Backlog.
    let outsideBacklogResults: [OutsideBacklogResult]
    /// Search creation remains duplicate-aware even when a Backlog-only filter
    /// suppresses the matching row from the visible hierarchy.
    let hasAnySearchResult: Bool
    let filterCatalog: FilterCatalog
    let rowPresentationsByTaskID: [UUID: BacklogTaskRowPresentation]
    let rowNumbersByTaskID: [UUID: Int]
    var taskCount: Int {
        sections.reduce(0) { $0 + $1.taskCount } + hiddenByFlagTasks.count
    }
    var isEmpty: Bool {
        sections.isEmpty && hiddenByFlagTasks.isEmpty
    }
    static var empty: Self {
        Self(
            sections: [],
            hiddenByFlagTasks: [],
            outsideBacklogResults: [],
            hasAnySearchResult: false,
            filterCatalog: .empty,
            rowPresentationsByTaskID: [:],
            rowNumbersByTaskID: [:]
        )
    }
    static func make(
        tasks: [RoutineTask],
        customSections: [HomeCustomTaskSection],
        flagRules: [RoutineFlagRule],
        availableFlags: [String] = [],
        completionDatesByTaskID: [UUID: Set<Date>] = [:],
        filters: BacklogFilterState = .default,
        fileAttachmentTaskIDs: Set<UUID> = [],
        searchText: String = "",
        referenceDate: Date,
        calendar: Calendar
    ) -> Self {
        let sections = HomeCustomTaskSectionStorage.sanitized(customSections)
        let relationshipBlockedTaskIDs = HomeDisplayFilterSupport.activeRelationshipBlockedTaskIDs(
            tasks: tasks,
            referenceDate: referenceDate,
            calendar: calendar,
            completionDatesByTaskID: completionDatesByTaskID
        )
        let backlogSections = sections.filter { $0.surface == .backlog }
        let backlogSectionIDs = Set(backlogSections.map(\.id))
        let normalizedSearchQuery = HomeTaskSearchIndex.query(searchText)
        let pathTitlesBySectionID = Dictionary(
            uniqueKeysWithValues: backlogSections.map { section in
                (
                    section.id,
                    HomeCustomTaskSectionStorage.pathTitles(for: section.id, in: backlogSections) ?? [section.title]
                )
            })
        let topLevelSections = HomeCustomTaskSectionStorage.topLevelSections(
            in: backlogSections,
            surface: .backlog
        )
        let automaticSectionIDByTaskID: [UUID: UUID] = Dictionary(
            uniqueKeysWithValues: tasks.compactMap { task in
                // Main task list and Backlog sections own independent automatic
                // rules. A stored Main task list path remains available if the
                // hiding Flag is later removed, but does not block Backlog's
                // presentation-only classification while the task is hidden.
                guard task.customTaskSectionID.map(backlogSectionIDs.contains) != true,
                    isActiveBacklogCandidate(task, referenceDate: referenceDate, calendar: calendar),
                    RoutineFlagRules.hidesFromTaskLists(flags: task.flags, rules: flagRules),
                    let section = topLevelSections.first(where: { section in
                        !section.rules.isEmpty && section.rules.matchesTags(task.tags)
                    })
                else {
                    return nil
                }
                return (task.id, section.id)
            })
        let backlogSectionIDByTaskID: [UUID: UUID] = Dictionary(
            uniqueKeysWithValues: tasks.compactMap { task in
                if let explicitSectionID = task.customTaskSectionID,
                    backlogSectionIDs.contains(explicitSectionID)
                {
                    return (task.id, explicitSectionID)
                }
                guard let automaticSectionID = automaticSectionIDByTaskID[task.id] else {
                    return nil
                }
                return (task.id, automaticSectionID)
            })
        let unassignedHiddenByFlagTasks = tasks.filter { task in
            guard task.customTaskSectionID.map(backlogSectionIDs.contains) != true,
                automaticSectionIDByTaskID[task.id] == nil,
                isActiveBacklogCandidate(task, referenceDate: referenceDate, calendar: calendar)
            else {
                return false
            }
            return RoutineFlagRules.hidesFromTaskLists(flags: task.flags, rules: flagRules)
        }
        let allBacklogTaskIDs = Set(backlogSectionIDByTaskID.keys)
            .union(unassignedHiddenByFlagTasks.map(\.id))
        let allBacklogTasks = tasks.filter { allBacklogTaskIDs.contains($0.id) }
        let filterCatalog = makeFilterCatalog(
            tasks: allBacklogTasks, availableFlags: availableFlags
        )
        let tasksBySectionID = tasks.reduce(into: [UUID: [RoutineTask]]()) { groupedTasks, task in
            guard let sectionID = backlogSectionIDByTaskID[task.id],
                filters.matches(
                    task,
                    fileAttachmentTaskIDs: fileAttachmentTaskIDs,
                    referenceDate: referenceDate,
                    calendar: calendar
                ),
                matchesSearch(
                    task,
                    normalizedQuery: normalizedSearchQuery,
                    pathTitles: pathTitlesBySectionID[sectionID] ?? []
                )
            else {
                return
            }
            groupedTasks[sectionID, default: []].append(task)
        }
        let shouldPruneEmptyHierarchy = normalizedSearchQuery != nil || filters.hasActiveFilters

        let presentationSections = topLevelSections.compactMap { section -> Section? in
            let directTasks = sorted(
                tasksBySectionID[section.id] ?? [],
                order: filters.sortOrder,
                referenceDate: referenceDate,
                calendar: calendar
            )
            let allSubsections = HomeCustomTaskSectionStorage.subsections(
                of: section.id,
                in: backlogSections
            ).map { subsection in
                Subsection(
                    section: subsection,
                    tasks: sorted(
                        tasksBySectionID[subsection.id] ?? [],
                        order: filters.sortOrder,
                        referenceDate: referenceDate,
                        calendar: calendar
                    )
                )
            }
            let subsections =
                shouldPruneEmptyHierarchy
                ? allSubsections.filter { !$0.tasks.isEmpty }
                : allSubsections

            guard
                !shouldPruneEmptyHierarchy
                    || !directTasks.isEmpty
                    || !subsections.isEmpty
            else {
                return nil
            }
            return Section(section: section, tasks: directTasks, subsections: subsections)
        }

        let hiddenByFlagTasks = sorted(
            unassignedHiddenByFlagTasks.filter { task in
                filters.matches(
                    task,
                    fileAttachmentTaskIDs: fileAttachmentTaskIDs,
                    referenceDate: referenceDate,
                    calendar: calendar
                ) && matchesSearch(task, normalizedQuery: normalizedSearchQuery)
            },
            order: filters.sortOrder,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let radarSections = sections.filter { $0.surface == .radar }
        let outsideBacklogResults: [OutsideBacklogResult]
        if normalizedSearchQuery == nil {
            outsideBacklogResults = []
        } else {
            outsideBacklogResults = defaultSorted(
                tasks.filter { task in
                    !allBacklogTaskIDs.contains(task.id)
                        && matchesSearch(
                            task,
                            normalizedQuery: normalizedSearchQuery,
                            pathTitles: task.customTaskSectionID.flatMap {
                                HomeCustomTaskSectionStorage.pathTitles(for: $0, in: radarSections)
                            } ?? []
                        )
                }
            ).map { task in
                OutsideBacklogResult(
                    task: task,
                    locationTitle: outsideBacklogLocationTitle(
                        for: task,
                        radarSections: radarSections,
                        referenceDate: referenceDate,
                        calendar: calendar
                    ),
                    revealDestination: task.isCompletedOneOff ? .timeline : .planner
                )
            }
        }
        let hasFilteredBacklogSearchResult =
            normalizedSearchQuery.map { query in
                allBacklogTasks.contains { task in
                    let sectionID = backlogSectionIDByTaskID[task.id]
                    return matchesSearch(
                        task,
                        normalizedQuery: query,
                        pathTitles: sectionID.flatMap { pathTitlesBySectionID[$0] } ?? []
                    )
                }
            } ?? false

        return BacklogTaskRowPresentationCache.makeList(
            sections: presentationSections,
            hiddenByFlagTasks: hiddenByFlagTasks,
            outsideBacklogResults: outsideBacklogResults,
            hasAnySearchResult: hasFilteredBacklogSearchResult || !outsideBacklogResults.isEmpty,
            filterCatalog: filterCatalog,
            context: BacklogTaskRowPresentationContext(
                flagRules: flagRules,
                relationshipBlockedTaskIDs: relationshipBlockedTaskIDs,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
    }

    private static func makeFilterCatalog(
        tasks: [RoutineTask],
        availableFlags: [String]
    ) -> FilterCatalog {
        let tagCounts = tasks.reduce(into: [String: Int]()) { counts, task in
            for tag in task.tags {
                guard let normalizedTag = RoutineTag.normalized(tag) else { continue }
                counts[normalizedTag, default: 0] += 1
            }
        }
        let tags = tagCounts.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        let flags = RoutineFlag.allFlags(from: [availableFlags] + tasks.map(\.flags))
        return FilterCatalog(tags: tags, tagCounts: tagCounts, flags: flags)
    }

    private static func matchesSearch(
        _ task: RoutineTask,
        normalizedQuery: String?,
        pathTitles: [String] = []
    ) -> Bool {
        guard let normalizedQuery else { return true }
        return HomeTaskSearchIndex.make(
            name: task.name ?? "",
            emoji: task.emoji ?? "",
            taskDescription: task.taskDescription,
            notes: task.notes,
            placeName: task.destinationAddress,
            tags: task.tags + pathTitles,
            flags: task.flags,
            goalTitles: []
        )
        .contains(normalizedQuery)
    }

    private static func isActiveBacklogCandidate(
        _ task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        !task.isArchived(referenceDate: referenceDate, calendar: calendar)
            && !task.isCompletedOneOff
            && !task.isCanceledOneOff
    }

    private static func outsideBacklogLocationTitle(
        for task: RoutineTask,
        radarSections: [HomeCustomTaskSection],
        referenceDate: Date,
        calendar: Calendar
    ) -> String {
        if task.isArchived(referenceDate: referenceDate, calendar: calendar) {
            return "Archived"
        }
        if task.isCompletedOneOff {
            return "Completed"
        }
        if task.isCanceledOneOff {
            return "Canceled"
        }
        if let sectionID = task.customTaskSectionID,
            let pathTitles = HomeCustomTaskSectionStorage.pathTitles(
                for: sectionID,
                in: radarSections
            ),
            !pathTitles.isEmpty
        {
            return (["Main task list"] + pathTitles).joined(separator: " › ")
        }
        return task.isDailyRoutineForTaskList ? "Main task list › Today" : "Main task list › Future"
    }

    private static func sorted(
        _ tasks: [RoutineTask],
        order: BacklogSortOrder,
        referenceDate: Date,
        calendar: Calendar
    ) -> [RoutineTask] {
        switch order {
        case .defaultOrder:
            return defaultSorted(tasks)
        case .dueSoonestFirst, .dueLatestFirst:
            let dueDatesByTaskID = Dictionary(
                uniqueKeysWithValues: tasks.map { task in
                    (
                        task.id,
                        sortableDueDate(for: task, referenceDate: referenceDate, calendar: calendar)
                    )
                })
            return tasks.sorted { lhs, rhs in
                let lhsDueDate = dueDatesByTaskID[lhs.id] ?? nil
                let rhsDueDate = dueDatesByTaskID[rhs.id] ?? nil
                switch (lhsDueDate, rhsDueDate) {
                case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                    return order == .dueSoonestFirst ? lhsDate < rhsDate : lhsDate > rhsDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return defaultSort(lhs, rhs)
                }
            }
        }
    }

    static func sortableDueDate(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> Date? {
        if task.isOneOffTask {
            return task.deadline
        }
        guard task.usesEffectiveRoutineCadence,
            !task.isSoftIntervalRoutine
        else {
            return nil
        }
        let dueDate = RoutineDateMath.upcomingDueDate(
            for: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
        return dueDate == .distantFuture ? nil : dueDate
    }

    private static func defaultSorted(_ tasks: [RoutineTask]) -> [RoutineTask] {
        tasks.sorted(by: defaultSort)
    }

    private static func defaultSort(_ lhs: RoutineTask, _ rhs: RoutineTask) -> Bool {
        if lhs.isPinned != rhs.isPinned {
            return lhs.isPinned && !rhs.isPinned
        }

        let lhsDeadline = lhs.deadline ?? .distantFuture
        let rhsDeadline = rhs.deadline ?? .distantFuture
        if lhsDeadline != rhsDeadline {
            return lhsDeadline < rhsDeadline
        }

        let lhsCreatedAt = lhs.createdAt ?? .distantPast
        let rhsCreatedAt = rhs.createdAt ?? .distantPast
        if lhsCreatedAt != rhsCreatedAt {
            return lhsCreatedAt > rhsCreatedAt
        }

        let lhsName = lhs.name ?? ""
        let rhsName = rhs.name ?? ""
        return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
    }
}
