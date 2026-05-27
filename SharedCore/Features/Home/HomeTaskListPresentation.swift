import Foundation

struct HomeTaskListMoveContext: Equatable {
    let sectionKey: String
    let orderedTaskIDs: [UUID]
}

enum HomeTaskListPresentationSectionKind: String, Equatable {
    case pinned
    case daily
    case regular
    case tag
    case untagged
    case away
    case archived
}

extension HomeTaskListPresentationSectionKind {
    var isCollapsible: Bool {
        switch self {
        case .daily, .tag, .untagged, .archived:
            return true
        case .pinned, .regular, .away:
            return false
        }
    }
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
        showArchivedTasks: Bool = true,
        taskListKind: HomeFilterTaskListKind
    ) -> Self {
        let visibleArchivedDisplays = showArchivedTasks ? archivedRoutineDisplays : []
        let pinnedTasks = filtering.filteredPinnedTasks(
            activeDisplays: routineDisplays,
            awayDisplays: hideUnavailableRoutines ? [] : awayRoutineDisplays,
            archivedDisplays: visibleArchivedDisplays
        )
        let pinnedTaskIDs = Set(pinnedTasks.map(\.taskID))
        let unpinnedRoutineDisplays = routineDisplays.filter { !pinnedTaskIDs.contains($0.taskID) }
        let awayTasks = filtering.filteredAwayTasks(
            awayRoutineDisplays.filter { !pinnedTaskIDs.contains($0.taskID) }
        )
        let archivedTasks = showArchivedTasks
            ? filtering.filteredArchivedTasks(
                archivedRoutineDisplays.filter { !pinnedTaskIDs.contains($0.taskID) }
            )
            : []

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
                    moveContext: nil
                )
            )
            offset += pinnedTasks.count
        }

        if filtering.usesTagSectioning {
            presentationSections += tagPresentationSections(
                from: filtering.groupedRoutineSections(from: unpinnedRoutineDisplays),
                offset: &offset,
                includeMarkDone: true,
                moveContext: { _ in nil }
            )
        } else if filtering.usesUngroupedSectioning {
            for section in filtering.groupedRoutineSections(from: unpinnedRoutineDisplays) {
                presentationSections.append(
                    HomeTaskListPresentationSection(
                        kind: .regular,
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
            let dailyTasks = filtering.filteredDailyRoutineTasks(unpinnedRoutineDisplays)
            let regularSections = filtering.groupedRoutineSections(
                from: unpinnedRoutineDisplays.filter { !$0.isDailyRoutine }
            )

            if !dailyTasks.isEmpty {
                presentationSections.append(
                    HomeTaskListPresentationSection(
                        kind: .daily,
                        title: "Daily Routines",
                        tasks: dailyTasks,
                        rowNumberOffset: offset,
                        includeMarkDone: true,
                        moveContext: nil
                    )
                )
                offset += dailyTasks.count
            }

            presentationSections += regularSections.map { section in
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
        showArchivedTasks: Bool = true,
        emptyState: HomeTaskListEmptyState
    ) -> Self {
        let visibleArchivedDisplays = showArchivedTasks ? archivedRoutineDisplays : []
        let pinnedTasks = filtering.filteredPinnedTasks(
            activeDisplays: routineDisplays,
            awayDisplays: awayRoutineDisplays,
            archivedDisplays: visibleArchivedDisplays
        )
        let unpinnedActiveDisplays = (routineDisplays + awayRoutineDisplays).filter { !$0.isPinned }
        let archivedTasks = filtering.filteredArchivedTasks(visibleArchivedDisplays, includePinned: false)

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

        if filtering.usesTagSectioning {
            presentationSections += tagPresentationSections(
                from: filtering.groupedRoutineSections(from: unpinnedActiveDisplays),
                offset: &offset,
                includeMarkDone: true,
                moveContext: { section in
                    HomeTaskListMoveContext(
                        sectionKey: section.tasks.first.map { filtering.regularManualOrderSectionKey(for: $0) }
                            ?? HomeTaskListTagGrouping.sectionKey(for: nil),
                        orderedTaskIDs: section.tasks.map(\.taskID)
                    )
                }
            )
        } else if filtering.usesUngroupedSectioning {
            for section in filtering.groupedRoutineSections(from: unpinnedActiveDisplays) {
                presentationSections.append(
                    HomeTaskListPresentationSection(
                        kind: .regular,
                        title: section.title,
                        tasks: section.tasks,
                        rowNumberOffset: offset,
                        includeMarkDone: true,
                        moveContext: HomeTaskListMoveContext(
                            sectionKey: HomeTaskListFiltering<Display>.ungroupedManualOrderSectionKey,
                            orderedTaskIDs: section.tasks.map(\.taskID)
                        )
                    )
                )
                offset += section.tasks.count
            }
        } else {
            let dailyTasks = filtering.filteredDailyRoutineTasks(unpinnedActiveDisplays)
            let regularSections = filtering.groupedRoutineSections(
                from: unpinnedActiveDisplays.filter { !$0.isDailyRoutine }
            )

            if !dailyTasks.isEmpty {
                presentationSections.append(
                    HomeTaskListPresentationSection(
                        kind: .daily,
                        title: "Daily Routines",
                        tasks: dailyTasks,
                        rowNumberOffset: offset,
                        includeMarkDone: true,
                        moveContext: HomeTaskListMoveContext(
                            sectionKey: HomeTaskListFiltering<Display>.dailyManualOrderSectionKey,
                            orderedTaskIDs: dailyTasks.map(\.taskID)
                        )
                    )
                )
                offset += dailyTasks.count
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
