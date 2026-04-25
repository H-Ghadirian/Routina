import Foundation

struct HomeTaskListMoveContext: Equatable {
    let sectionKey: String
    let orderedTaskIDs: [UUID]
}

enum HomeTaskListPresentationSectionKind: String, Equatable {
    case pinned
    case regular
    case away
    case archived
}

struct HomeTaskListPresentationSection<Display: HomeTaskListDisplay>: Identifiable {
    let kind: HomeTaskListPresentationSectionKind
    let title: String
    var tasks: [Display]
    let rowNumberOffset: Int
    let includeMarkDone: Bool
    let moveContext: HomeTaskListMoveContext?

    var id: String {
        "\(kind.rawValue):\(title)"
    }

    func rowNumber(forTaskAt index: Int) -> Int {
        rowNumberOffset + index + 1
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

    static func iOS(
        filtering: HomeTaskListFiltering<Display>,
        routineDisplays: [Display],
        awayRoutineDisplays: [Display],
        archivedRoutineDisplays: [Display],
        hideUnavailableRoutines: Bool,
        taskListKind: HomeFilterTaskListKind
    ) -> Self {
        let regularSections = filtering.groupedRoutineSections(from: routineDisplays)
        let awayTasks = filtering.filteredAwayTasks(awayRoutineDisplays)
        let archivedTasks = filtering.filteredArchivedTasks(archivedRoutineDisplays)

        var offset = 0
        var presentationSections = regularSections.map { section in
            defer { offset += section.tasks.count }
            return HomeTaskListPresentationSection(
                kind: .regular,
                title: section.title,
                tasks: section.tasks,
                rowNumberOffset: offset,
                includeMarkDone: true,
                moveContext: nil
            )
        }

        if !hideUnavailableRoutines && !awayTasks.isEmpty {
            presentationSections.append(
                HomeTaskListPresentationSection(
                    kind: .away,
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
        emptyState: HomeTaskListEmptyState
    ) -> Self {
        let pinnedTasks = filtering.filteredPinnedTasks(
            activeDisplays: routineDisplays,
            awayDisplays: awayRoutineDisplays,
            archivedDisplays: archivedRoutineDisplays
        )
        let regularSections = filtering.groupedRoutineSections(
            from: (routineDisplays + awayRoutineDisplays).filter { !$0.isPinned }
        )
        let archivedTasks = filtering.filteredArchivedTasks(archivedRoutineDisplays, includePinned: false)

        var offset = 0
        var presentationSections: [HomeTaskListPresentationSection<Display>] = []

        if !pinnedTasks.isEmpty {
            presentationSections.append(
                HomeTaskListPresentationSection(
                    kind: .pinned,
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

        for section in regularSections {
            presentationSections.append(
                HomeTaskListPresentationSection(
                    kind: .regular,
                    title: section.title,
                    tasks: section.tasks,
                    rowNumberOffset: offset,
                    includeMarkDone: true,
                    moveContext: HomeTaskListMoveContext(
                        sectionKey: section.tasks.first.map { filtering.regularManualOrderSectionKey(for: $0) } ?? "onTrack",
                        orderedTaskIDs: section.tasks.map(\.taskID)
                    )
                )
            )
            offset += section.tasks.count
        }

        if !archivedTasks.isEmpty {
            presentationSections.append(
                HomeTaskListPresentationSection(
                    kind: .archived,
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

    private static func iOSEmptyState(
        isEmpty: Bool,
        hiddenUnavailableTaskCount: Int,
        taskListKind: HomeFilterTaskListKind
    ) -> HomeTaskListEmptyState? {
        guard isEmpty else { return nil }

        if hiddenUnavailableTaskCount > 0 {
            return HomeTaskListEmptyState(
                title: "No routines available here",
                message: "\(hiddenUnavailableTaskCount) routines are hidden because you are away from their saved place.",
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
