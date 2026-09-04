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
        let deduplicatedTaskGroups = Self.deduplicatedTaskGroups(
            taskGroups ?? [
                HomeTaskListPresentationTaskGroup(
                    kind: kind,
                    title: nil,
                    tasks: tasks,
                    moveContext: moveContext,
                    isCollapsible: false
                )
            ])
        let resolvedTaskGroups =
            separatesUserCompletedTasks
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
            let followingInsertionIndex =
                canonicalIDs
                .dropFirst(canonicalIndex + 1)
                .lazy
                .compactMap { result.firstIndex(of: $0) }
                .first
            if let insertionIndex = followingInsertionIndex {
                result.insert(sectionID, at: insertionIndex)
                continue
            }

            let precedingInsertionIndex = canonicalIDs[..<canonicalIndex]
                .reversed()
                .lazy
                .compactMap { result.firstIndex(of: $0) }
                .first
            if let precedingIndex = precedingInsertionIndex {
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
