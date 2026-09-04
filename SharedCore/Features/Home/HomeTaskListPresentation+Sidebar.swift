import Foundation

extension HomeTaskListPresentation {
    struct SidebarCustomTaskSection {
        let section: HomeCustomTaskSection
        let tasks: [Display]
        let taskGroups: [HomeTaskListPresentationTaskGroup<Display>]
    }

    private struct SidebarSectionSource {
        let pinnedTasks: [Display]
        let plannedTodayTasks: [Display]
        let datePlannedTodayTaskIDs: Set<UUID>
        let plannedTomorrowTasks: [Display]
        let dailyTasks: [Display]
        let customTaskSections: [SidebarCustomTaskSection]
        let regularSections: [HomeTaskListSection<Display>]
        let archivedTasks: [Display]
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
        let source = sidebarSectionSource(
            filtering: filtering,
            routineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays,
            showArchivedTasks: showArchivedTasks,
            showTomorrowSection: showTomorrowSection,
            customSections: customSections
        )
        var accumulator = SectionAccumulator()
        appendSidebarLeadingSections(
            from: source,
            separateDailyRoutinesInTaskList: separateDailyRoutinesInTaskList,
            to: &accumulator
        )
        appendSidebarCustomSections(source.customTaskSections, to: &accumulator)
        appendSidebarFutureSection(
            source.regularSections,
            filtering: filtering,
            separateTodosAndRoutinesInTagSections: separateTodosAndRoutinesInTagSections,
            to: &accumulator
        )
        appendSidebarArchivedSection(source.archivedTasks, to: &accumulator)

        let sections = orderedSidebarSections(
            accumulator.sections,
            sectionOrderIDs: sectionOrderIDs
        )
        return HomeTaskListPresentation(
            sections: sections,
            hiddenUnavailableTaskCount: 0,
            emptyState: sections.isEmpty ? emptyState : nil,
            datePlannedTodayTaskIDs: source.datePlannedTodayTaskIDs
        )
    }

    private static func sidebarSectionSource(
        filtering: HomeTaskListFiltering<Display>,
        routineDisplays: [Display],
        awayRoutineDisplays: [Display],
        archivedRoutineDisplays: [Display],
        showArchivedTasks: Bool,
        showTomorrowSection: Bool,
        customSections: [HomeCustomTaskSection]
    ) -> SidebarSectionSource {
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
        let plannedTomorrowTasks =
            showTomorrowSection
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
        _ = claimTasks(dailyTasks, claimedTaskIDs: &claimedTaskIDs)
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

        return SidebarSectionSource(
            pinnedTasks: pinnedTasks,
            plannedTodayTasks: plannedTodayTasks,
            datePlannedTodayTaskIDs: datePlannedTodayTaskIDs,
            plannedTomorrowTasks: plannedTomorrowTasks,
            dailyTasks: dailyTasks,
            customTaskSections: customTaskSections,
            regularSections: regularSections,
            archivedTasks: archivedTasks
        )
    }

    private static func appendSidebarLeadingSections(
        from source: SidebarSectionSource,
        separateDailyRoutinesInTaskList: Bool,
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
                    moveContext: HomeTaskListMoveContext(
                        sectionKey: HomeTaskListFiltering<Display>.pinnedManualOrderSectionKey,
                        orderedTaskIDs: source.pinnedTasks.map(\.taskID)
                    )
                )
            )
        }

        let todayGroups = sidebarPlanTodayTaskGroups(
            plannedTodayTasks: source.plannedTodayTasks,
            dailyTasks: source.dailyTasks,
            separateDailyRoutinesInTaskList: separateDailyRoutinesInTaskList
        )
        let todayTasks = todayGroups.flatMap(\.tasks)
        if !todayTasks.isEmpty {
            accumulator.append(
                HomeTaskListPresentationSection(
                    kind: .plannedToday,
                    identityKey: "plannedToday",
                    title: "Today",
                    tasks: todayTasks,
                    rowNumberOffset: 0,
                    includeMarkDone: true,
                    moveContext: nil,
                    taskGroups: todayGroups
                )
            )
        }

        if !source.plannedTomorrowTasks.isEmpty {
            accumulator.append(
                HomeTaskListPresentationSection(
                    kind: .plannedTomorrow,
                    identityKey: "plannedTomorrow",
                    title: "Tomorrow",
                    tasks: source.plannedTomorrowTasks,
                    rowNumberOffset: 0,
                    includeMarkDone: true,
                    moveContext: HomeTaskListMoveContext(
                        sectionKey: HomeTaskListFiltering<Display>.plannedTomorrowManualOrderSectionKey,
                        orderedTaskIDs: source.plannedTomorrowTasks.map(\.taskID)
                    )
                )
            )
        }
    }

    private static func appendSidebarCustomSections(
        _ customTaskSections: [SidebarCustomTaskSection],
        to accumulator: inout SectionAccumulator
    ) {
        for customTaskSection in customTaskSections {
            accumulator.append(
                HomeTaskListPresentationSection(
                    kind: .custom,
                    identityKey: HomeCustomTaskSectionStorage.manualOrderSectionKey(
                        for: customTaskSection.section.id
                    ),
                    title: customTaskSection.section.title,
                    tasks: customTaskSection.tasks,
                    rowNumberOffset: 0,
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
        }
    }

    private static func appendSidebarFutureSection(
        _ regularSections: [HomeTaskListSection<Display>],
        filtering: HomeTaskListFiltering<Display>,
        separateTodosAndRoutinesInTagSections: Bool,
        to accumulator: inout SectionAccumulator
    ) {
        let futureSection: HomeTaskListPresentationSection<Display>?
        if filtering.usesTagSectioning {
            let separatesDeadlineStatus = filtering.separatesDeadlineStatusInTagSections
            futureSection = sidebarFutureSection(
                from: regularSections,
                offset: &accumulator.offset,
                showsGroupTitles: true,
                usesDeadlineDateSectioning: separatesDeadlineStatus,
                separateTodosAndRoutinesInTagSections: separateTodosAndRoutinesInTagSections,
                moveContext: { section in
                    HomeTaskListMoveContext(
                        sectionKey: separatesDeadlineStatus && isDeadlineStatusSection(section)
                            ? section.identityKey
                            : section.tasks.first.map { filtering.regularManualOrderSectionKey(for: $0) }
                                ?? HomeTaskListTagGrouping.sectionKey(for: nil),
                        orderedTaskIDs: section.tasks.map(\.taskID)
                    )
                }
            )
        } else if filtering.usesUngroupedSectioning {
            futureSection = sidebarFutureSection(
                from: regularSections,
                offset: &accumulator.offset,
                showsGroupTitles: false,
                usesDeadlineDateSectioning: false,
                separateTodosAndRoutinesInTagSections: false,
                moveContext: { section in
                    HomeTaskListMoveContext(
                        sectionKey: HomeTaskListFiltering<Display>.ungroupedManualOrderSectionKey,
                        orderedTaskIDs: section.tasks.map(\.taskID)
                    )
                }
            )
        } else {
            futureSection = sidebarFutureSection(
                from: regularSections,
                offset: &accumulator.offset,
                showsGroupTitles: true,
                usesDeadlineDateSectioning: filtering.usesDeadlineDateSectioning,
                separateTodosAndRoutinesInTagSections: false,
                moveContext: { section in
                    HomeTaskListMoveContext(
                        sectionKey: section.tasks.first.map {
                            filtering.regularManualOrderSectionKey(for: $0)
                        } ?? "onTrack",
                        orderedTaskIDs: section.tasks.map(\.taskID)
                    )
                }
            )
        }

        if let futureSection {
            accumulator.sections.append(futureSection)
        }
    }

    private static func appendSidebarArchivedSection(
        _ archivedTasks: [Display],
        to accumulator: inout SectionAccumulator
    ) {
        guard !archivedTasks.isEmpty else { return }
        accumulator.append(
            HomeTaskListPresentationSection(
                kind: .archived,
                identityKey: "archived",
                title: "Archived",
                tasks: archivedTasks,
                rowNumberOffset: 0,
                includeMarkDone: true,
                moveContext: HomeTaskListMoveContext(
                    sectionKey: HomeTaskListFiltering<Display>.archivedManualOrderSectionKey,
                    orderedTaskIDs: archivedTasks.map(\.taskID)
                )
            )
        )
    }

    private static func orderedSidebarSections(
        _ sections: [HomeTaskListPresentationSection<Display>],
        sectionOrderIDs: [String]
    ) -> [HomeTaskListPresentationSection<Display>] {
        let reorderableSections = sections.filter(\.kind.isMacSidebarReorderable)
        let reorderableIDs = Set(reorderableSections.map(\.id))
        let orderedReorderableIDs = HomeMacTaskListSectionOrder.visibleSectionIDs(
            preferredIDs: sectionOrderIDs,
            defaultIDs: reorderableSections.map(\.id)
        )
        let reorderableSectionsByID = Dictionary(
            uniqueKeysWithValues: reorderableSections.map { ($0.id, $0) }
        )
        var orderedSections = orderedReorderableIDs.compactMap { reorderableSectionsByID[$0] }
        orderedSections += sections.filter { !reorderableIDs.contains($0.id) }

        var accumulator = SectionAccumulator()
        for section in orderedSections {
            accumulator.append(section)
        }
        return accumulator.sections
    }
}
