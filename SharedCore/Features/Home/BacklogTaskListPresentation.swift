import Foundation

/// A stable, reducer-owned snapshot for the Mac Backlog window.  The main
/// sidebar intentionally does not build this presentation while it scrolls.
struct BacklogTaskListPresentation: Equatable {
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

    var taskCount: Int {
        sections.reduce(0) { $0 + $1.taskCount } + hiddenByFlagTasks.count
    }

    var isEmpty: Bool {
        sections.isEmpty && hiddenByFlagTasks.isEmpty
    }

    static var empty: Self {
        Self(sections: [], hiddenByFlagTasks: [])
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
        let tasksBySectionID = Dictionary(grouping: tasks.filter { task in
            guard let sectionID = task.customTaskSectionID,
                  backlogSectionIDs.contains(sectionID) else {
                return false
            }
            return matchesSearch(
                task,
                normalizedQuery: normalizedSearchQuery,
                pathTitles: pathTitlesBySectionID[sectionID] ?? []
            )
        }) { $0.customTaskSectionID! }

        let topLevelSections = HomeCustomTaskSectionStorage.topLevelSections(
            in: backlogSections,
            surface: .backlog
        )
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
                  isActiveBacklogCandidate(task, referenceDate: referenceDate, calendar: calendar)
            else {
                return false
            }
            return RoutineFlagRules.hidesFromTaskLists(flags: task.flags, rules: flagRules)
                && matchesSearch(task, normalizedQuery: normalizedSearchQuery)
        })

        return Self(sections: presentationSections, hiddenByFlagTasks: hiddenByFlagTasks)
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
