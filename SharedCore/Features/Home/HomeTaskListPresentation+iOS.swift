import Foundation

extension HomeTaskListPresentation {
    private struct IOSSectionSource {
        let pinnedTasks: [Display]
        let plannedTodayTasks: [Display]
        let dailyTasks: [Display]
        let regularSections: [HomeTaskListSection<Display>]
        let awayTasks: [Display]
        let archivedTasks: [Display]
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
        let source = iOSSectionSource(
            filtering: filtering,
            routineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays,
            hideUnavailableRoutines: hideUnavailableRoutines,
            showArchivedTasks: showArchivedTasks
        )
        var accumulator = SectionAccumulator()
        appendIOSLeadingSections(from: source, to: &accumulator)
        appendIOSRegularSections(from: source.regularSections, filtering: filtering, to: &accumulator)
        appendIOSUnavailableSections(
            from: source,
            hideUnavailableRoutines: hideUnavailableRoutines,
            to: &accumulator
        )

        let hiddenUnavailableTaskCount = hideUnavailableRoutines ? source.awayTasks.count : 0
        return HomeTaskListPresentation(
            sections: accumulator.sections,
            hiddenUnavailableTaskCount: hiddenUnavailableTaskCount,
            emptyState: iOSEmptyState(
                isEmpty: accumulator.sections.isEmpty,
                hiddenUnavailableTaskCount: hiddenUnavailableTaskCount,
                taskListKind: taskListKind
            )
        )
    }

    private static func iOSSectionSource(
        filtering: HomeTaskListFiltering<Display>,
        routineDisplays: [Display],
        awayRoutineDisplays: [Display],
        archivedRoutineDisplays: [Display],
        hideUnavailableRoutines: Bool,
        showArchivedTasks: Bool
    ) -> IOSSectionSource {
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
        let archivedTasks =
            showArchivedTasks
            ? claimTasks(
                filtering.filteredArchivedTasks(
                    archivedRoutineDisplays.filter { !claimedTaskIDs.contains($0.taskID) }
                ),
                claimedTaskIDs: &claimedTaskIDs
            )
            : []

        return IOSSectionSource(
            pinnedTasks: pinnedTasks,
            plannedTodayTasks: plannedTodayTasks,
            dailyTasks: dailyTasks,
            regularSections: regularSections,
            awayTasks: awayTasks,
            archivedTasks: archivedTasks
        )
    }

    private static func appendIOSLeadingSections(
        from source: IOSSectionSource,
        to accumulator: inout SectionAccumulator
    ) {
        if !source.pinnedTasks.isEmpty {
            accumulator.append(
                HomeTaskListPresentationSection(
                    kind: .pinned,
                    identityKey: "pinned",
                    title: "Pinned",
                    tasks: source.pinnedTasks,
                    rowNumberOffset: 0,
                    includeMarkDone: true,
                    moveContext: nil
                )
            )
        }

        if !source.plannedTodayTasks.isEmpty {
            accumulator.append(
                HomeTaskListPresentationSection(
                    kind: .plannedToday,
                    identityKey: "plannedToday",
                    title: "Today",
                    tasks: source.plannedTodayTasks,
                    rowNumberOffset: 0,
                    includeMarkDone: true,
                    moveContext: HomeTaskListMoveContext(
                        sectionKey: HomeTaskListFiltering<Display>.plannedTodayManualOrderSectionKey,
                        orderedTaskIDs: source.plannedTodayTasks.map(\.taskID)
                    )
                )
            )
        }

        if !source.dailyTasks.isEmpty {
            accumulator.append(
                HomeTaskListPresentationSection(
                    kind: .daily,
                    identityKey: "daily",
                    title: "Daily repeating tasks",
                    tasks: source.dailyTasks,
                    rowNumberOffset: 0,
                    includeMarkDone: true,
                    moveContext: nil
                )
            )
        }
    }

    private static func appendIOSRegularSections(
        from regularSections: [HomeTaskListSection<Display>],
        filtering: HomeTaskListFiltering<Display>,
        to accumulator: inout SectionAccumulator
    ) {
        if filtering.usesTagSectioning {
            accumulator.sections += tagPresentationSections(
                from: regularSections,
                offset: &accumulator.offset,
                includeMarkDone: true,
                moveContext: { _ in nil }
            )
        } else if filtering.usesUngroupedSectioning {
            for section in regularSections {
                accumulator.append(
                    HomeTaskListPresentationSection(
                        kind: .regular,
                        identityKey: section.identityKey,
                        title: section.title,
                        tasks: section.tasks,
                        rowNumberOffset: 0,
                        includeMarkDone: true,
                        moveContext: nil
                    )
                )
            }
        } else {
            for section in regularSections {
                accumulator.append(
                    HomeTaskListPresentationSection(
                        kind: .regular,
                        identityKey: section.identityKey,
                        title: section.title,
                        tasks: section.tasks,
                        rowNumberOffset: 0,
                        includeMarkDone: true,
                        moveContext: nil
                    )
                )
            }
        }
    }

    private static func appendIOSUnavailableSections(
        from source: IOSSectionSource,
        hideUnavailableRoutines: Bool,
        to accumulator: inout SectionAccumulator
    ) {
        if !hideUnavailableRoutines && !source.awayTasks.isEmpty {
            accumulator.append(
                HomeTaskListPresentationSection(
                    kind: .away,
                    identityKey: "away",
                    title: "Not Here Right Now",
                    tasks: source.awayTasks,
                    rowNumberOffset: 0,
                    includeMarkDone: false,
                    moveContext: nil
                )
            )
        }

        if !source.archivedTasks.isEmpty {
            accumulator.append(
                HomeTaskListPresentationSection(
                    kind: .archived,
                    identityKey: "archived",
                    title: "Archived",
                    tasks: source.archivedTasks,
                    rowNumberOffset: 0,
                    includeMarkDone: true,
                    moveContext: nil
                )
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
                title: "No repeating tasks available here",
                message: hiddenUnavailableTaskCount == 1
                    ? "1 repeating task is hidden because you are away from its matching place."
                    : "\(hiddenUnavailableTaskCount) repeating tasks are hidden because you are away from their matching places.",
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
            return "No matching repeating tasks"
        case .todos:
            return "No matching one-time tasks"
        }
    }
}
