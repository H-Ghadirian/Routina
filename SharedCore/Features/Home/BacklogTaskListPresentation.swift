import Foundation

/// A stable, reducer-owned snapshot for Backlog workspaces. Home intentionally
/// does not build this presentation while its task list scrolls.
struct BacklogTaskListPresentation: Equatable {
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

    var taskCount: Int {
        sections.reduce(0) { $0 + $1.taskCount } + hiddenByFlagTasks.count
    }

    var isEmpty: Bool {
        sections.isEmpty && hiddenByFlagTasks.isEmpty
    }

    static var empty: Self {
        Self(sections: [], hiddenByFlagTasks: [], outsideBacklogResults: [])
    }

    static func make(
        tasks: [RoutineTask],
        customSections: [HomeCustomTaskSection],
        flagRules: [RoutineFlagRule],
        searchText: String = "",
        referenceDate: Date,
        calendar: Calendar
    ) -> Self {
        let sections = HomeCustomTaskSectionStorage.sanitized(customSections)
        let backlogSections = sections.filter { $0.surface == .backlog }
        let backlogSectionIDs = Set(backlogSections.map(\.id))
        let normalizedSearchQuery = HomeTaskSearchIndex.query(searchText)
        let pathTitlesBySectionID = Dictionary(uniqueKeysWithValues: backlogSections.map { section in
            (
                section.id,
                HomeCustomTaskSectionStorage.pathTitles(for: section.id, in: backlogSections) ?? [section.title]
            )
        })
        let topLevelSections = HomeCustomTaskSectionStorage.topLevelSections(
            in: backlogSections,
            surface: .backlog
        )
        let automaticSectionIDByTaskID: [UUID: UUID] = Dictionary(uniqueKeysWithValues: tasks.compactMap { task in
            // Main task list and Backlog sections own independent automatic
            // rules. A stored Main task list path remains available if the
            // hiding Flag is later removed, but does not block Backlog's
            // presentation-only classification while the task is hidden.
            guard task.customTaskSectionID.map(backlogSectionIDs.contains) != true,
                  isActiveBacklogCandidate(task, referenceDate: referenceDate, calendar: calendar),
                  RoutineFlagRules.hidesFromTaskLists(flags: task.flags, rules: flagRules),
                  let section = topLevelSections.first(where: { section in
                      !section.rules.isEmpty && section.rules.matchesTags(task.tags)
                  }) else {
                return nil
            }
            return (task.id, section.id)
        })
        let backlogSectionIDByTaskID: [UUID: UUID] = Dictionary(uniqueKeysWithValues: tasks.compactMap { task in
            if let explicitSectionID = task.customTaskSectionID,
               backlogSectionIDs.contains(explicitSectionID) {
                return (task.id, explicitSectionID)
            }
            guard let automaticSectionID = automaticSectionIDByTaskID[task.id] else {
                return nil
            }
            return (task.id, automaticSectionID)
        })
        let tasksBySectionID: [UUID: [RoutineTask]] = Dictionary(grouping: tasks.filter { task in
            guard let sectionID = backlogSectionIDByTaskID[task.id] else {
                return false
            }
            return matchesSearch(
                task,
                normalizedQuery: normalizedSearchQuery,
                pathTitles: pathTitlesBySectionID[sectionID] ?? []
            )
        }) { backlogSectionIDByTaskID[$0.id]! }

        let presentationSections = topLevelSections.compactMap { section -> Section? in
            let directTasks = sorted(tasksBySectionID[section.id] ?? [])
            let allSubsections = HomeCustomTaskSectionStorage.subsections(
                of: section.id,
                in: backlogSections
            ).map { subsection in
                Subsection(
                    section: subsection,
                    tasks: sorted(tasksBySectionID[subsection.id] ?? [])
                )
            }
            let subsections = normalizedSearchQuery == nil
                ? allSubsections
                : allSubsections.filter { !$0.tasks.isEmpty }

            guard normalizedSearchQuery == nil
                    || !directTasks.isEmpty
                    || !subsections.isEmpty else {
                return nil
            }
            return Section(section: section, tasks: directTasks, subsections: subsections)
        }

        let hiddenByFlagTasks = sorted(tasks.filter { task in
            guard task.customTaskSectionID.map(backlogSectionIDs.contains) != true,
                  automaticSectionIDByTaskID[task.id] == nil,
                  isActiveBacklogCandidate(task, referenceDate: referenceDate, calendar: calendar)
            else {
                return false
            }
            return RoutineFlagRules.hidesFromTaskLists(flags: task.flags, rules: flagRules)
                && matchesSearch(task, normalizedQuery: normalizedSearchQuery)
        })

        let backlogTaskIDs = Set(
            tasksBySectionID.values.flatMap { $0.map(\.id) }
                + hiddenByFlagTasks.map(\.id)
        )
        let radarSections = sections.filter { $0.surface == .radar }
        let outsideBacklogResults: [OutsideBacklogResult]
        if normalizedSearchQuery == nil {
            outsideBacklogResults = []
        } else {
            outsideBacklogResults = sorted(tasks.filter { task in
                !backlogTaskIDs.contains(task.id)
                    && matchesSearch(
                        task,
                        normalizedQuery: normalizedSearchQuery,
                        pathTitles: task.customTaskSectionID.flatMap {
                            HomeCustomTaskSectionStorage.pathTitles(for: $0, in: radarSections)
                        } ?? []
                    )
            }).map { task in
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

        return Self(
            sections: presentationSections,
            hiddenByFlagTasks: hiddenByFlagTasks,
            outsideBacklogResults: outsideBacklogResults
        )
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
           !pathTitles.isEmpty {
            return (["Main task list"] + pathTitles).joined(separator: " › ")
        }
        return task.isDailyRoutineForTaskList ? "Main task list › Today" : "Main task list › Future"
    }

    private static func sorted(_ tasks: [RoutineTask]) -> [RoutineTask] {
        tasks.sorted { lhs, rhs in
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
}
