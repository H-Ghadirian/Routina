import Foundation

struct HomeTaskListPresentation<Display: HomeTaskListDisplay> {
    struct SectionAccumulator {
        var sections: [HomeTaskListPresentationSection<Display>] = []
        var offset = 0

        mutating func append(_ section: HomeTaskListPresentationSection<Display>) {
            let positionedSection = section.replacingRowNumberOffset(offset)
            sections.append(positionedSection)
            offset += positionedSection.tasks.count
        }
    }

    let sections: [HomeTaskListPresentationSection<Display>]
    let visibleTaskCount: Int
    let hiddenUnavailableTaskCount: Int
    let emptyState: HomeTaskListEmptyState?
    let datePlannedTodayTaskIDs: Set<UUID>
    let searchResultLocationTitlesByTaskID: [UUID: String]

    init(
        sections: [HomeTaskListPresentationSection<Display>],
        hiddenUnavailableTaskCount: Int,
        emptyState: HomeTaskListEmptyState?,
        datePlannedTodayTaskIDs: Set<UUID> = [],
        searchResultLocationTitlesByTaskID: [UUID: String] = [:]
    ) {
        self.sections = sections
        self.visibleTaskCount = sections.reduce(0) { $0 + $1.tasks.count }
        self.hiddenUnavailableTaskCount = hiddenUnavailableTaskCount
        self.emptyState = emptyState
        self.datePlannedTodayTaskIDs = datePlannedTodayTaskIDs
        self.searchResultLocationTitlesByTaskID = searchResultLocationTitlesByTaskID
    }

    func showsPlannedTodayLabel(
        for taskID: UUID,
        in section: HomeTaskListPresentationSection<Display>
    ) -> Bool {
        section.kind != .plannedToday && datePlannedTodayTaskIDs.contains(taskID)
    }

    func searchResultLocationTitle(
        for taskID: UUID,
        in section: HomeTaskListPresentationSection<Display>
    ) -> String? {
        guard section.identityKey == "searchResults" else { return nil }
        return searchResultLocationTitlesByTaskID[taskID]
    }

    func addingSearchFallbackResults(
        from sourceDisplays: [Display],
        filtering: HomeTaskListFiltering<Display>,
        title: String = "Search Results",
        locationTitle: (Display) -> String? = { _ in nil }
    ) -> Self {
        let presentedTaskIDs = Set(sections.flatMap(\.tasks).map(\.taskID))
        let fallbackTasks = filtering.searchFallbackTasks(from: sourceDisplays).filter {
            !presentedTaskIDs.contains($0.taskID)
        }
        guard !fallbackTasks.isEmpty else { return self }

        var resultLocationTitlesByTaskID = searchResultLocationTitlesByTaskID
        for task in fallbackTasks {
            if let locationTitle = locationTitle(task) {
                resultLocationTitlesByTaskID[task.taskID] = locationTitle
            }
        }

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
            datePlannedTodayTaskIDs: datePlannedTodayTaskIDs,
            searchResultLocationTitlesByTaskID: resultLocationTitlesByTaskID
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
            datePlannedTodayTaskIDs: datePlannedTodayTaskIDs,
            searchResultLocationTitlesByTaskID: searchResultLocationTitlesByTaskID
        )
    }

    static func claimTasks(
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

    static func uniqueTasks(_ tasks: [Display]) -> [Display] {
        var seenTaskIDs: Set<UUID> = []
        return tasks.filter { task in
            seenTaskIDs.insert(task.taskID).inserted
        }
    }

    static func claimSections(
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

    static func tagPresentationSections(
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

}
