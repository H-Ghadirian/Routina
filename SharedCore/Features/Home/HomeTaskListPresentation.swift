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
    let usesSectionMoveContext: Bool
    let isCollapsible: Bool
    let isCollapsedByDefault: Bool
    let childGroups: [HomeTaskListPresentationTaskGroup<Display>]
    private let taskIndicesByID: [UUID: Int]

    init(
        kind: HomeTaskListPresentationSectionKind,
        identityKey: String? = nil,
        title: String?,
        tasks: [Display],
        moveContext: HomeTaskListMoveContext?,
        usesSectionMoveContext: Bool = true,
        isCollapsible: Bool,
        isCollapsedByDefault: Bool = false,
        childGroups: [HomeTaskListPresentationTaskGroup<Display>] = []
    ) {
        self.kind = kind
        self.identityKey = identityKey
        self.title = title
        self.tasks = tasks
        self.moveContext = moveContext
        self.usesSectionMoveContext = usesSectionMoveContext
        self.isCollapsible = isCollapsible
        self.isCollapsedByDefault = isCollapsedByDefault
        self.childGroups = childGroups
        self.taskIndicesByID = Dictionary(
            uniqueKeysWithValues: tasks.enumerated().map { ($0.element.taskID, $0.offset) }
        )
    }

    var id: String {
        identityKey ?? moveContext?.sectionKey ?? title ?? "primary"
    }

    func taskIndex(for taskID: UUID) -> Int? {
        taskIndicesByID[taskID]
    }
}

enum HomeTaskListPresentationSectionKind: String, Equatable {
    case pinned
    case plannedToday
    case plannedTomorrow
    case custom
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
        case .plannedToday, .plannedTomorrow, .custom, .daily, .future, .tag, .untagged, .archived:
            return true
        case .pinned, .regular, .deadlineDate, .away:
            return false
        }
    }

    var isMacSidebarReorderable: Bool {
        switch self {
        case .pinned, .plannedToday, .plannedTomorrow, .custom, .future, .archived:
            return true
        case .daily, .regular, .deadlineDate, .tag, .untagged, .away:
            return false
        }
    }

    var isMacSidebarMoveMenuEligible: Bool {
        isMacSidebarReorderable && self != .plannedToday && self != .plannedTomorrow
    }
}

struct HomeTaskListPresentationSection<Display: HomeTaskListDisplay>: Identifiable {
    let kind: HomeTaskListPresentationSectionKind
    let identityKey: String
    let title: String
    let rowNumberOffset: Int
    let includeMarkDone: Bool
    let separatesUserCompletedTasks: Bool
    let colorHex: String?
    let isPaused: Bool
    let moveContext: HomeTaskListMoveContext?
    let taskGroups: [HomeTaskListPresentationTaskGroup<Display>]
    let tasks: [Display]
    private let taskIndicesByID: [UUID: Int]

    init(
        kind: HomeTaskListPresentationSectionKind,
        identityKey: String? = nil,
        title: String,
        tasks: [Display],
        rowNumberOffset: Int,
        includeMarkDone: Bool,
        separatesUserCompletedTasks: Bool = true,
        colorHex: String? = nil,
        isPaused: Bool = false,
        moveContext: HomeTaskListMoveContext?,
        taskGroups: [HomeTaskListPresentationTaskGroup<Display>]? = nil
    ) {
        self.kind = kind
        let resolvedIdentityKey = identityKey ?? moveContext?.sectionKey ?? title
        self.identityKey = resolvedIdentityKey
        self.title = title
        self.rowNumberOffset = rowNumberOffset
        self.includeMarkDone = includeMarkDone
        self.separatesUserCompletedTasks = separatesUserCompletedTasks
        self.colorHex = colorHex
        self.isPaused = isPaused
        self.moveContext = moveContext
        let deduplicatedTaskGroups = Self.deduplicatedTaskGroups(taskGroups ?? [
            HomeTaskListPresentationTaskGroup(
                kind: kind,
                title: nil,
                tasks: tasks,
                moveContext: moveContext,
                isCollapsible: false
            )
        ])
        let resolvedTaskGroups = separatesUserCompletedTasks
            ? Self.separatingUserCompletedTasks(
                from: deduplicatedTaskGroups,
                completedGroupIdentityKey: "completed:\(kind.rawValue):\(resolvedIdentityKey)"
            )
            : deduplicatedTaskGroups
        let resolvedTasks = resolvedTaskGroups.flatMap(\.tasks)
        self.taskGroups = resolvedTaskGroups
        self.tasks = resolvedTasks
        self.taskIndicesByID = Dictionary(
            uniqueKeysWithValues: resolvedTasks.enumerated().map { ($0.element.taskID, $0.offset) }
        )
    }

    var id: String {
        "\(kind.rawValue):\(identityKey)"
    }

    func rowNumber(forTaskAt index: Int) -> Int {
        rowNumberOffset + index + 1
    }

    func taskIndex(for taskID: UUID) -> Int? {
        taskIndicesByID[taskID]
    }

    func replacingRowNumberOffset(_ rowNumberOffset: Int) -> Self {
        HomeTaskListPresentationSection(
            kind: kind,
            identityKey: identityKey,
            title: title,
            tasks: tasks,
            rowNumberOffset: rowNumberOffset,
            includeMarkDone: includeMarkDone,
            separatesUserCompletedTasks: separatesUserCompletedTasks,
            colorHex: colorHex,
            isPaused: isPaused,
            moveContext: moveContext,
            taskGroups: taskGroups
        )
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
                    usesSectionMoveContext: existingGroup.usesSectionMoveContext && group.usesSectionMoveContext,
                    isCollapsible: existingGroup.isCollapsible || group.isCollapsible,
                    isCollapsedByDefault: existingGroup.isCollapsedByDefault || group.isCollapsedByDefault,
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
                        usesSectionMoveContext: group.usesSectionMoveContext,
                        isCollapsible: group.isCollapsible,
                        isCollapsedByDefault: group.isCollapsedByDefault,
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
                usesSectionMoveContext: childGroup.usesSectionMoveContext,
                isCollapsible: childGroup.isCollapsible,
                isCollapsedByDefault: childGroup.isCollapsedByDefault,
                childGroups: Self.childGroups(
                    childGroup.childGroups,
                    limitedTo: Set(uniqueTasks.map(\.taskID))
                )
            )
        }
    }

    private static func separatingUserCompletedTasks(
        from taskGroups: [HomeTaskListPresentationTaskGroup<Display>],
        completedGroupIdentityKey: String
    ) -> [HomeTaskListPresentationTaskGroup<Display>] {
        let completedTasks = taskGroups.flatMap(\.tasks).filter(\.isCompletedByUser)
        guard !completedTasks.isEmpty else { return taskGroups }

        var activeTaskGroups: [HomeTaskListPresentationTaskGroup<Display>] = []
        for group in taskGroups {
            if let activeGroup = removingUserCompletedTasks(from: group) {
                activeTaskGroups.append(activeGroup)
            }
        }
        let completedGroup = HomeTaskListPresentationTaskGroup(
            kind: .regular,
            identityKey: completedGroupIdentityKey,
            title: "Completed",
            tasks: completedTasks,
            moveContext: nil,
            usesSectionMoveContext: false,
            isCollapsible: true,
            isCollapsedByDefault: true
        )
        return activeTaskGroups + [completedGroup]
    }

    private static func removingUserCompletedTasks(
        from group: HomeTaskListPresentationTaskGroup<Display>
    ) -> HomeTaskListPresentationTaskGroup<Display>? {
        let activeTasks = group.tasks.filter { !$0.isCompletedByUser }
        guard !activeTasks.isEmpty else { return nil }

        var activeChildGroups: [HomeTaskListPresentationTaskGroup<Display>] = []
        for childGroup in group.childGroups {
            if let activeChildGroup = removingUserCompletedTasks(from: childGroup) {
                activeChildGroups.append(activeChildGroup)
            }
        }

        return HomeTaskListPresentationTaskGroup(
            kind: group.kind,
            identityKey: group.identityKey,
            title: group.title,
            tasks: activeTasks,
            moveContext: moveContext(group.moveContext, orderedBy: activeTasks),
            usesSectionMoveContext: group.usesSectionMoveContext,
            isCollapsible: group.isCollapsible,
            isCollapsedByDefault: group.isCollapsedByDefault,
            childGroups: activeChildGroups
        )
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

enum HomeMacTaskListSectionOrder {
    enum Placement {
        case before
        case after
    }

    static func decoded(from rawValue: String) -> [String] {
        uniqueIDs(
            rawValue
                .split(whereSeparator: \.isNewline)
                .map(String.init)
        )
    }

    static func encoded(_ sectionIDs: [String]) -> String {
        uniqueIDs(sectionIDs).joined(separator: "\n")
    }

    static func visibleSectionIDs(
        preferredIDs: [String],
        defaultIDs: [String]
    ) -> [String] {
        let availableIDs = uniqueIDs(defaultIDs)
        let availableIDSet = Set(availableIDs)
        return resolvedIDs(
            preferredIDs: preferredIDs,
            defaultIDs: availableIDs
        ).filter(availableIDSet.contains)
    }

    static func moving(
        _ sourceID: String,
        relativeTo targetID: String,
        placement: Placement,
        preferredIDs: [String],
        visibleIDs: [String]
    ) -> [String] {
        guard sourceID != targetID,
              visibleIDs.contains(sourceID),
              visibleIDs.contains(targetID)
        else {
            return resolvedIDs(preferredIDs: preferredIDs, defaultIDs: visibleIDs)
        }

        var result = resolvedIDs(preferredIDs: preferredIDs, defaultIDs: visibleIDs)
        result.removeAll { $0 == sourceID }
        guard let targetIndex = result.firstIndex(of: targetID) else {
            return result
        }

        let insertionIndex = placement == .before ? targetIndex : targetIndex + 1
        result.insert(sourceID, at: insertionIndex)
        return result
    }

    static func canMove(
        _ sectionID: String,
        by offset: Int,
        visibleIDs: [String]
    ) -> Bool {
        guard let currentIndex = visibleIDs.firstIndex(of: sectionID) else { return false }
        return visibleIDs.indices.contains(currentIndex + offset)
    }

    static func moving(
        _ sectionID: String,
        by offset: Int,
        preferredIDs: [String],
        visibleIDs: [String]
    ) -> [String] {
        guard canMove(sectionID, by: offset, visibleIDs: visibleIDs),
              let currentIndex = visibleIDs.firstIndex(of: sectionID)
        else {
            return resolvedIDs(preferredIDs: preferredIDs, defaultIDs: visibleIDs)
        }

        let targetID = visibleIDs[currentIndex + offset]
        return moving(
            sectionID,
            relativeTo: targetID,
            placement: offset < 0 ? .before : .after,
            preferredIDs: preferredIDs,
            visibleIDs: visibleIDs
        )
    }

    private static func resolvedIDs(
        preferredIDs: [String],
        defaultIDs: [String]
    ) -> [String] {
        let canonicalIDs = uniqueIDs(defaultIDs)
        var result = uniqueIDs(preferredIDs)
        guard !result.isEmpty else { return canonicalIDs }

        for (canonicalIndex, sectionID) in canonicalIDs.enumerated()
        where !result.contains(sectionID) {
            let followingID = canonicalIDs
                .dropFirst(canonicalIndex + 1)
                .first(where: result.contains)
            if let followingID,
               let insertionIndex = result.firstIndex(of: followingID) {
                result.insert(sectionID, at: insertionIndex)
                continue
            }

            let precedingID = canonicalIDs[..<canonicalIndex]
                .reversed()
                .first(where: result.contains)
            if let precedingID,
               let precedingIndex = result.firstIndex(of: precedingID) {
                result.insert(sectionID, at: precedingIndex + 1)
            } else {
                result.append(sectionID)
            }
        }

        return result
    }

    private static func uniqueIDs(_ sectionIDs: [String]) -> [String] {
        var seenIDs: Set<String> = []
        return sectionIDs.compactMap { sectionID in
            let trimmedID = sectionID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedID.isEmpty, seenIDs.insert(trimmedID).inserted else {
                return nil
            }
            return trimmedID
        }
    }
}

struct HomeTaskListEmptyState: Equatable {
    let title: String
    let message: String
    let systemImage: String
}

struct HomeTaskListPresentation<Display: HomeTaskListDisplay> {
    let sections: [HomeTaskListPresentationSection<Display>]
    let visibleTaskCount: Int
    let hiddenUnavailableTaskCount: Int
    let emptyState: HomeTaskListEmptyState?
    let datePlannedTodayTaskIDs: Set<UUID>

    init(
        sections: [HomeTaskListPresentationSection<Display>],
        hiddenUnavailableTaskCount: Int,
        emptyState: HomeTaskListEmptyState?,
        datePlannedTodayTaskIDs: Set<UUID> = []
    ) {
        self.sections = sections
        self.visibleTaskCount = sections.reduce(0) { $0 + $1.tasks.count }
        self.hiddenUnavailableTaskCount = hiddenUnavailableTaskCount
        self.emptyState = emptyState
        self.datePlannedTodayTaskIDs = datePlannedTodayTaskIDs
    }

    func showsPlannedTodayLabel(
        for taskID: UUID,
        in section: HomeTaskListPresentationSection<Display>
    ) -> Bool {
        section.kind != .plannedToday && datePlannedTodayTaskIDs.contains(taskID)
    }

    func addingSearchFallbackResults(
        from sourceDisplays: [Display],
        filtering: HomeTaskListFiltering<Display>,
        title: String = "Search Results"
    ) -> Self {
        let presentedTaskIDs = Set(sections.flatMap(\.tasks).map(\.taskID))
        let fallbackTasks = filtering.searchFallbackTasks(from: sourceDisplays).filter {
            !presentedTaskIDs.contains($0.taskID)
        }
        guard !fallbackTasks.isEmpty else { return self }

        let section = HomeTaskListPresentationSection(
            kind: .regular,
            identityKey: "searchResults",
            title: title,
            tasks: fallbackTasks,
            rowNumberOffset: visibleTaskCount,
            includeMarkDone: false,
            moveContext: nil
        )

        return HomeTaskListPresentation(
            sections: sections + [section],
            hiddenUnavailableTaskCount: hiddenUnavailableTaskCount,
            emptyState: nil,
            datePlannedTodayTaskIDs: datePlannedTodayTaskIDs
        )
    }

    func appendingFlagRuleRevealResults(
        from sourceDisplays: [Display],
        filtering: HomeTaskListFiltering<Display>,
        title: String = "Hidden by flag"
    ) -> Self {
        let presentedTaskIDs = Set(sections.flatMap(\.tasks).map(\.taskID))
        let revealedTasks = filtering.flagRuleRevealTasks(from: sourceDisplays).filter {
            !presentedTaskIDs.contains($0.taskID)
        }
        guard !revealedTasks.isEmpty else { return self }

        let section = HomeTaskListPresentationSection(
            kind: .regular,
            identityKey: "hiddenByFlagRule",
            title: title,
            tasks: revealedTasks,
            rowNumberOffset: visibleTaskCount,
            includeMarkDone: false,
            moveContext: nil
        )

        return HomeTaskListPresentation(
            sections: sections + [section],
            hiddenUnavailableTaskCount: hiddenUnavailableTaskCount,
            emptyState: nil,
            datePlannedTodayTaskIDs: datePlannedTodayTaskIDs
        )
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

    private static func uniqueTasks(_ tasks: [Display]) -> [Display] {
        var seenTaskIDs: Set<UUID> = []
        return tasks.filter { task in
            seenTaskIDs.insert(task.taskID).inserted
        }
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
        let plannedTodayTasks = uniqueTasks(
            filtering.filteredPlannedTodayTasks(routineDisplays)
        )
        let dailyTasks = claimTasks(
            filtering.filteredDailyRoutineTasks(unpinnedRoutineDisplays),
            claimedTaskIDs: &claimedTaskIDs
        )
        let nonDailyRoutineDisplays = unpinnedRoutineDisplays.filter {
            RoutineTaskPlanningSupport.supportsStoredPlanning(
                scheduleMode: $0.scheduleMode,
                cadenceEnabled: $0.cadenceEnabled,
                isDailyRoutine: $0.isDailyRoutine
            ) && !claimedTaskIDs.contains($0.taskID)
        }
        let regularSections = claimSections(
            filtering.groupedRoutineSections(from: nonDailyRoutineDisplays),
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
        customSections: [HomeCustomTaskSection] = [],
        sectionOrderIDs: [String] = [],
        separateTodosAndRoutinesInTagSections: Bool = false,
        emptyState: HomeTaskListEmptyState
    ) -> Self {
        let sanitizedCustomSections = HomeCustomTaskSectionStorage.sanitized(customSections)
        let backlogSectionIDs = Set(
            sanitizedCustomSections
                .filter { $0.surface == .backlog }
                .map(\.id)
        )
        let isAssignedToBacklog: (Display) -> Bool = { display in
            display.customTaskSectionID.map(backlogSectionIDs.contains) ?? false
        }
        let sidebarRoutineDisplays = routineDisplays.filter { !isAssignedToBacklog($0) }
        let sidebarAwayDisplays = awayRoutineDisplays.filter { !isAssignedToBacklog($0) }
        let sidebarArchivedDisplays = archivedRoutineDisplays.filter { !isAssignedToBacklog($0) }
        let visibleArchivedDisplays = showArchivedTasks ? sidebarArchivedDisplays : []
        let activeDisplays = sidebarRoutineDisplays + sidebarAwayDisplays
        var claimedTaskIDs: Set<UUID> = []
        let pinnedTasks = claimTasks(
            filtering.filteredPinnedTasks(
                activeDisplays: sidebarRoutineDisplays,
                awayDisplays: sidebarAwayDisplays,
                archivedDisplays: visibleArchivedDisplays
            ),
            claimedTaskIDs: &claimedTaskIDs
        )
        let plannedTodayTasks = uniqueTasks(
            filtering.filteredPlannedTodayTasks(activeDisplays)
        )
        let datePlannedTodayTaskIDs = Set(
            plannedTodayTasks.lazy
                .filter { $0.plannedDate != nil }
                .map(\.taskID)
        )
        let plannedTomorrowTasks = showTomorrowSection
            ? uniqueTasks(filtering.filteredPlannedTomorrowTasks(activeDisplays))
            : []
        let dailyTasks = uniqueTasks(
            filtering.filteredDailyRoutineTasks(activeDisplays)
                .filter { filtering.matchesUncompletedTodayClaim($0) }
        )
        let unpinnedActiveDisplays = activeDisplays.filter {
            !$0.isPinned && !claimedTaskIDs.contains($0.taskID)
        }
        let customTaskSections = sidebarCustomTaskSections(
            from: sanitizedCustomSections,
            displays: unpinnedActiveDisplays,
            filtering: filtering,
            claimedTaskIDs: &claimedTaskIDs
        )
        let activeDisplaysAfterCustomClaim = unpinnedActiveDisplays.filter {
            !claimedTaskIDs.contains($0.taskID)
        }
        _ = claimTasks(
            dailyTasks,
            claimedTaskIDs: &claimedTaskIDs
        )
        let nonDailyActiveDisplays = activeDisplaysAfterCustomClaim.filter {
            RoutineTaskPlanningSupport.supportsStoredPlanning(
                scheduleMode: $0.scheduleMode,
                cadenceEnabled: $0.cadenceEnabled,
                isDailyRoutine: $0.isDailyRoutine
            ) && !claimedTaskIDs.contains($0.taskID)
        }
        let regularSections = claimSections(
            filtering.groupedRoutineSections(from: nonDailyActiveDisplays),
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

        for customTaskSection in customTaskSections {
            presentationSections.append(
                HomeTaskListPresentationSection(
                    kind: .custom,
                    identityKey: HomeCustomTaskSectionStorage.manualOrderSectionKey(for: customTaskSection.section.id),
                    title: customTaskSection.section.title,
                    tasks: customTaskSection.tasks,
                    rowNumberOffset: offset,
                    includeMarkDone: true,
                    colorHex: customTaskSection.section.colorHex,
                    isPaused: customTaskSection.section.isPaused,
                    moveContext: HomeTaskListMoveContext(
                        sectionKey: HomeTaskListFiltering<Display>.customManualOrderSectionKey(
                            for: customTaskSection.section.id
                        ),
                        orderedTaskIDs: customTaskSection.tasks.map(\.taskID)
                    ),
                    taskGroups: customTaskSection.taskGroups
                )
            )
            offset += customTaskSection.tasks.count
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

        let reorderableSections = presentationSections.filter(\.kind.isMacSidebarReorderable)
        let reorderableIDs = Set(reorderableSections.map(\.id))
        let orderedReorderableIDs = HomeMacTaskListSectionOrder.visibleSectionIDs(
            preferredIDs: sectionOrderIDs,
            defaultIDs: reorderableSections.map(\.id)
        )
        let reorderableSectionsByID = Dictionary(
            uniqueKeysWithValues: reorderableSections.map { ($0.id, $0) }
        )
        var orderedSections = orderedReorderableIDs.compactMap { reorderableSectionsByID[$0] }
        orderedSections += presentationSections.filter { !reorderableIDs.contains($0.id) }

        var reorderedOffset = 0
        presentationSections = orderedSections.map { section in
            defer { reorderedOffset += section.tasks.count }
            return section.replacingRowNumberOffset(reorderedOffset)
        }

        return HomeTaskListPresentation(
            sections: presentationSections,
            hiddenUnavailableTaskCount: 0,
            emptyState: presentationSections.isEmpty ? emptyState : nil,
            datePlannedTodayTaskIDs: datePlannedTodayTaskIDs
        )
    }

    private struct SidebarCustomTaskSection {
        let section: HomeCustomTaskSection
        let tasks: [Display]
        let taskGroups: [HomeTaskListPresentationTaskGroup<Display>]
    }

    private static func sidebarCustomTaskSections(
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
        let routines = section.tasks.filter { !$0.isOneOffTask }
        let childGroupCount = [todos, routines].filter { !$0.isEmpty }.count
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

    static func iOSEmptyState(
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
        }
    }
}

struct HomeIOSPresentationSnapshotResult: @unchecked Sendable {
    let presentation: HomeTaskListPresentation<HomeRoutineDisplay>
    let searchTaskCreationText: String?
}

struct HomeIOSPresentationSnapshotRequest: @unchecked Sendable {
    private var filteringConfiguration: HomeTaskListFilteringConfiguration
    private let taskListMode: HomeTaskListMode
    private let routineDisplays: [HomeRoutineDisplay]
    private let awayRoutineDisplays: [HomeRoutineDisplay]
    private let archivedRoutineDisplays: [HomeRoutineDisplay]
    private let hideUnavailableRoutines: Bool
    private let showArchivedTasks: Bool

    init(
        filteringConfiguration: HomeTaskListFilteringConfiguration,
        taskListMode: HomeTaskListMode,
        routineDisplays: [HomeRoutineDisplay],
        awayRoutineDisplays: [HomeRoutineDisplay],
        archivedRoutineDisplays: [HomeRoutineDisplay],
        hideUnavailableRoutines: Bool,
        showArchivedTasks: Bool
    ) {
        self.filteringConfiguration = filteringConfiguration
        self.taskListMode = taskListMode
        self.routineDisplays = routineDisplays
        self.awayRoutineDisplays = awayRoutineDisplays
        self.archivedRoutineDisplays = archivedRoutineDisplays
        self.hideUnavailableRoutines = hideUnavailableRoutines
        self.showArchivedTasks = showArchivedTasks
    }

    var requiresMainActorBuild: Bool {
        filteringConfiguration.taskListViewMode == .actionable
    }

    func preparedForDetachedBuild() -> Self {
        var request = self
        // SwiftData models stay actor-bound. The all-items view mode never
        // consults this legacy relationship collection while filtering.
        request.filteringConfiguration.routineTasks = []
        return request
    }

    func build() -> HomeIOSPresentationSnapshotResult? {
        guard !Task.isCancelled else { return nil }

        let taskListMode = taskListMode
        let filtering = HomeTaskListFiltering<HomeRoutineDisplay>(
            configuration: filteringConfiguration,
            matchesCurrentTaskListMode: { display in
                switch taskListMode {
                case .all:
                    return true
                case .routines:
                    return display.scheduleMode.taskType == .routine
                case .todos:
                    return display.isOneOffTask
                }
            }
        )
        let searchSeed = filteringConfiguration.searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let allTaskSearchSourceDisplays = searchSeed.isEmpty
            ? []
            : sourceDisplays(includingArchivedTasks: true)

        if !searchSeed.isEmpty {
            let containsKnownTask = allTaskSearchSourceDisplays.contains(
                where: filtering.matchesSearch
            )
            guard !Task.isCancelled else { return nil }

            if !containsKnownTask {
                return HomeIOSPresentationSnapshotResult(
                    presentation: HomeTaskListPresentation(
                        sections: [],
                        hiddenUnavailableTaskCount: 0,
                        emptyState: HomeTaskListPresentation<HomeRoutineDisplay>.iOSEmptyState(
                            isEmpty: true,
                            hiddenUnavailableTaskCount: 0,
                            taskListKind: filterTaskListKind
                        )
                    ),
                    searchTaskCreationText: searchSeed
                )
            }
        }

        let searchSourceDisplays = showArchivedTasks && !allTaskSearchSourceDisplays.isEmpty
            ? allTaskSearchSourceDisplays
            : sourceDisplays(includingArchivedTasks: showArchivedTasks)

        guard !Task.isCancelled else { return nil }
        let presentation = HomeTaskListPresentation.iOS(
            filtering: filtering,
            routineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays,
            hideUnavailableRoutines: hideUnavailableRoutines,
            showArchivedTasks: showArchivedTasks,
            taskListKind: filterTaskListKind
        )
        .appendingFlagRuleRevealResults(
            from: searchSourceDisplays,
            filtering: filtering
        )

        guard !Task.isCancelled else { return nil }
        guard !Task.isCancelled else { return nil }
        return HomeIOSPresentationSnapshotResult(
            presentation: presentation,
            searchTaskCreationText: nil
        )
    }

    private func sourceDisplays(
        includingArchivedTasks: Bool
    ) -> [HomeRoutineDisplay] {
        var seenTaskIDs: Set<UUID> = []
        var displays: [HomeRoutineDisplay] = []
        displays.reserveCapacity(
            routineDisplays.count
                + awayRoutineDisplays.count
                + (includingArchivedTasks ? archivedRoutineDisplays.count : 0)
        )

        func appendUnique(_ source: [HomeRoutineDisplay]) -> Bool {
            for display in source {
                guard !Task.isCancelled else { return false }
                if seenTaskIDs.insert(display.taskID).inserted {
                    displays.append(display)
                }
            }
            return true
        }

        guard appendUnique(routineDisplays), appendUnique(awayRoutineDisplays) else { return [] }
        if includingArchivedTasks {
            guard appendUnique(archivedRoutineDisplays) else { return [] }
        }

        return displays
    }

    private var filterTaskListKind: HomeFilterTaskListKind {
        switch taskListMode {
        case .all:
            return .all
        case .routines:
            return .routines
        case .todos:
            return .todos
        }
    }
}
