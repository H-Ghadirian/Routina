import AppKit
import SwiftUI

extension HomeTCAView {
    func taskListSectionIsExpanded(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> Bool {
        if isMacSearchSidebarRevealActive {
            return true
        }

        switch section.kind {
        case .plannedToday, .plannedTomorrow, .custom:
            return !collapsedTagTaskListSectionIDs.contains(section.id)
        case .daily:
            return !isDailyRoutinesSectionCollapsed
        case .future:
            return !isMacFutureTasksSectionCollapsed
        case .tag, .untagged:
            return !collapsedTagTaskListSectionIDs.contains(section.id)
        case .archived:
            return !isArchivedSectionCollapsed
        case .pinned, .regular, .deadlineDate, .away:
            return true
        }
    }

    func toggleTaskListSection(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) {
        guard section.kind.isCollapsible else { return }
        let isCurrentlyExpanded = taskListSectionIsExpanded(section)
        preserveMacTaskSourceListScrollPosition {
            switch section.kind {
            case .plannedToday, .plannedTomorrow, .custom:
                setTagTaskListSection(section, collapsed: isCurrentlyExpanded)
            case .daily:
                isDailyRoutinesSectionCollapsed.toggle()
            case .future:
                isMacFutureTasksSectionCollapsed.toggle()
            case .tag, .untagged:
                setTagTaskListSection(section, collapsed: isCurrentlyExpanded)
            case .archived:
                isArchivedSectionCollapsed.toggle()
            case .pinned, .regular, .deadlineDate, .away:
                break
            }
        }
    }

    private func preserveMacTaskSourceListScrollPosition(_ update: () -> Void) {
        guard let scrollView = macTaskSourceListScrollViewReference.scrollView else {
            update()
            return
        }

        macTaskSourceListScrollViewReference.startPreservingScrollPosition(in: scrollView)
        let animation: Animation? =
            MacTaskSourceListScrollPreservation
                .animatesUserDrivenDisclosureChanges
            ? .easeInOut(duration: 0.24)
            : nil
        withTransaction(Transaction(animation: animation)) {
            update()
        }

        scrollView.layoutSubtreeIfNeeded()
        scrollView.documentView?.layoutSubtreeIfNeeded()
        macTaskSourceListScrollViewReference.restorePreservedScrollPosition()
        DispatchQueue.main.async {
            scrollView.layoutSubtreeIfNeeded()
            scrollView.documentView?.layoutSubtreeIfNeeded()
            macTaskSourceListScrollViewReference.restorePreservedScrollPosition()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                macTaskSourceListScrollViewReference.restorePreservedScrollPosition()
                macTaskSourceListScrollViewReference.stopPreservingScrollPosition()
            }
        }
    }

    func taskListGroupIsExpanded(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> Bool {
        guard group.isCollapsible else { return true }
        if isMacSearchSidebarRevealActive {
            return true
        }
        if group.isCollapsedByDefault {
            return collapsedTagTaskListSectionIDs.contains(taskListGroupExpandedOverrideID(group))
        }

        switch group.kind {
        case .daily:
            return !isMacPlanTodayDailyRoutinesGroupCollapsed
        case .custom, .deadlineDate, .tag, .untagged, .regular:
            return !collapsedTagTaskListSectionIDs.contains(taskListGroupCollapseID(group))
        case .plannedToday, .plannedTomorrow, .future, .pinned, .away, .archived:
            return true
        }
    }

    func toggleTaskListGroup(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) {
        guard group.isCollapsible else { return }
        let isCurrentlyExpanded = taskListGroupIsExpanded(group)
        preserveMacTaskSourceListScrollPosition {
            if group.isCollapsedByDefault {
                setDefaultCollapsedTaskListGroup(group, expanded: !isCurrentlyExpanded)
                return
            }

            switch group.kind {
            case .daily:
                isMacPlanTodayDailyRoutinesGroupCollapsed.toggle()
            case .custom, .deadlineDate, .tag, .untagged, .regular:
                setTagTaskListGroup(group, collapsed: isCurrentlyExpanded)
            case .plannedToday, .plannedTomorrow, .future, .pinned, .away, .archived:
                break
            }
        }
    }

    func expandAllFutureTaskListSubsections(
        in section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) {
        setAllFutureTaskListSubsections(in: section, collapsed: false)
    }

    func collapseAllFutureTaskListSubsections(
        in section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) {
        setAllFutureTaskListSubsections(in: section, collapsed: true)
    }

    private func setAllFutureTaskListSubsections(
        in section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        collapsed: Bool
    ) {
        let groups = futureTaskListSubsections(in: section)
        guard section.kind == .future, !groups.isEmpty else { return }

        preserveMacTaskSourceListScrollPosition {
            isMacFutureTasksSectionCollapsed = false
            var ids = collapsedTagTaskListSectionIDs
            for group in groups {
                if group.isCollapsedByDefault {
                    let id = taskListGroupExpandedOverrideID(group)
                    if collapsed {
                        ids.remove(id)
                    } else {
                        ids.insert(id)
                    }
                } else {
                    let id = taskListGroupCollapseID(group)
                    if collapsed {
                        ids.insert(id)
                    } else {
                        ids.remove(id)
                    }
                }
            }
            collapsedTagTaskListSectionIDsStorage = ids.sorted().joined(separator: "\n")
        }
    }

    private func futureTaskListSubsections(
        in section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> [HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>] {
        section.taskGroups.flatMap(taskListCollapsibleGroups)
    }

    private func taskListCollapsibleGroups(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> [HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>] {
        let currentGroups = group.isCollapsible ? [group] : []
        return currentGroups + group.childGroups.flatMap(taskListCollapsibleGroups)
    }

    func visibleTaskIDs(
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        collapsedTagIDs: Set<String>
    ) -> [UUID] {
        presentation.sections.flatMap { section in
            visibleTaskIDs(in: section, collapsedTagIDs: collapsedTagIDs)
        }
    }

    func visibleTaskIDs(
        in section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        collapsedTagIDs: Set<String>
    ) -> [UUID] {
        guard taskListSectionIsExpanded(section, collapsedTagIDs: collapsedTagIDs) else { return [] }
        return section.taskGroups.flatMap { group in
            visibleTaskIDs(in: group, collapsedTagIDs: collapsedTagIDs)
        }
    }

    func visibleTaskIDs(
        in group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        collapsedTagIDs: Set<String>
    ) -> [UUID] {
        guard taskListGroupIsExpanded(group, collapsedTagIDs: collapsedTagIDs) else { return [] }
        guard !group.childGroups.isEmpty else {
            return group.tasks.map(\.taskID)
        }
        return group.childGroups.flatMap { childGroup in
            visibleTaskIDs(in: childGroup, collapsedTagIDs: collapsedTagIDs)
        }
    }

    func macVisibleTaskSourceListTaskIDs() -> [UUID] {
        let presentation = macTaskListPresentation(
            routineDisplays: store.routineDisplays,
            awayRoutineDisplays: store.awayRoutineDisplays,
            archivedRoutineDisplays: store.archivedRoutineDisplays
        )
        return visibleTaskIDs(
            in: presentation,
            collapsedTagIDs: collapsedTagTaskListSectionIDs
        )
    }

    func revealMacTaskSourceListTask(_ taskID: UUID) -> MacSidebarTaskScrollDestination? {
        let presentation = macTaskListPresentation(
            routineDisplays: store.routineDisplays,
            awayRoutineDisplays: store.awayRoutineDisplays,
            archivedRoutineDisplays: store.archivedRoutineDisplays
        )

        guard let location = macTaskSourceListLocation(of: taskID, in: presentation) else {
            return nil
        }

        expandMacTaskSourceListLocation(location)
        return MacSidebarTaskScrollDestination(
            sectionID: location.section.id,
            groupIDs: location.groups.map(\.id)
        )
    }

    func macTaskSourceListSidebarLocation(_ taskID: UUID) -> TaskDetailSidebarLocation? {
        guard let location = macTaskListPresentationCache.sidebarLocation(for: taskID) else {
            return nil
        }

        let sectionTitle = macTaskSourceListSidebarSectionTitle(
            location: location
        )

        return TaskDetailSidebarLocation(
            titles: [sectionTitle] + location.groupTitles
        )
    }

    private func macTaskSourceListSidebarSectionTitle(
        location: HomeMacTaskListSidebarLocationSnapshot
    ) -> String {
        guard location.sectionIdentityKey == "hiddenByFlagRule" else {
            return location.sectionTitle
        }

        let hidingFlags = RoutineFlagRules.flagsHidingFromTaskLists(
            location.taskFlags,
            rules: store.flagRules
        )
        guard !hidingFlags.isEmpty else { return location.sectionTitle }

        let noun = hidingFlags.count == 1 ? "Flag" : "Flags"
        return "Hidden by \(noun): \(hidingFlags.joined(separator: ", "))"
    }

    private func macTaskSourceListLocation(
        of taskID: UUID,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    ) -> MacTaskSourceListTaskLocation? {
        for section in presentation.sections where section.tasks.contains(where: { $0.taskID == taskID }) {
            return MacTaskSourceListTaskLocation(
                section: section,
                groups: macTaskSourceListGroupPath(to: taskID, in: section.taskGroups) ?? []
            )
        }

        return nil
    }

    private func macTaskSourceListGroupPath(
        to taskID: UUID,
        in groups: [HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>]
    ) -> [HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>]? {
        for group in groups where group.tasks.contains(where: { $0.taskID == taskID }) {
            if let childPath = macTaskSourceListGroupPath(to: taskID, in: group.childGroups) {
                return [group] + childPath
            }

            return [group]
        }

        return nil
    }

    private func expandMacTaskSourceListLocation(_ location: MacTaskSourceListTaskLocation) {
        guard !isMacSearchSidebarRevealActive else { return }

        withTransaction(Transaction(animation: nil)) {
            expandTaskListSection(location.section)
            location.groups.forEach(expandTaskListGroup)
        }
    }

    private func expandTaskListSection(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) {
        guard section.kind.isCollapsible else { return }

        switch section.kind {
        case .plannedToday, .plannedTomorrow, .custom, .tag, .untagged:
            setTagTaskListSection(section, collapsed: false)
        case .daily:
            isDailyRoutinesSectionCollapsed = false
        case .future:
            isMacFutureTasksSectionCollapsed = false
        case .archived:
            isArchivedSectionCollapsed = false
        case .pinned, .regular, .deadlineDate, .away:
            break
        }
    }

    private func expandTaskListGroup(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) {
        guard group.isCollapsible else { return }

        if group.isCollapsedByDefault {
            setDefaultCollapsedTaskListGroup(group, expanded: true)
            return
        }

        switch group.kind {
        case .daily:
            isMacPlanTodayDailyRoutinesGroupCollapsed = false
        case .custom, .deadlineDate, .tag, .untagged, .regular:
            setTagTaskListGroup(group, collapsed: false)
        case .plannedToday, .plannedTomorrow, .future, .pinned, .away, .archived:
            break
        }
    }

    func taskListSectionIsExpanded(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        collapsedTagIDs: Set<String>
    ) -> Bool {
        if isMacSearchSidebarRevealActive {
            return true
        }

        switch section.kind {
        case .plannedToday, .plannedTomorrow, .custom, .tag, .untagged:
            return !collapsedTagIDs.contains(section.id)
        case .daily:
            return !isDailyRoutinesSectionCollapsed
        case .future:
            return !isMacFutureTasksSectionCollapsed
        case .archived:
            return !isArchivedSectionCollapsed
        case .pinned, .regular, .deadlineDate, .away:
            return true
        }
    }

    func taskListGroupIsExpanded(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        collapsedTagIDs: Set<String>
    ) -> Bool {
        guard group.isCollapsible else { return true }
        if isMacSearchSidebarRevealActive {
            return true
        }
        if group.isCollapsedByDefault {
            return collapsedTagIDs.contains(taskListGroupExpandedOverrideID(group))
        }

        switch group.kind {
        case .daily:
            return !isMacPlanTodayDailyRoutinesGroupCollapsed
        case .custom, .deadlineDate, .tag, .untagged, .regular:
            return !collapsedTagIDs.contains(taskListGroupCollapseID(group))
        case .plannedToday, .plannedTomorrow, .future, .pinned, .away, .archived:
            return true
        }
    }

    func rowNumbersByTaskID(for visibleTaskIDs: [UUID]) -> [UUID: Int] {
        var rowNumbers: [UUID: Int] = [:]
        rowNumbers.reserveCapacity(visibleTaskIDs.count)
        for (index, taskID) in visibleTaskIDs.enumerated() where rowNumbers[taskID] == nil {
            rowNumbers[taskID] = index + 1
        }
        return rowNumbers
    }

    var collapsedTagTaskListSectionIDs: Set<String> {
        collapsedTagTaskListSectionIDsCache.ids(for: collapsedTagTaskListSectionIDsStorage)
    }

    private func setTagTaskListSection(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        collapsed: Bool
    ) {
        var ids = collapsedTagTaskListSectionIDs
        if collapsed {
            ids.insert(section.id)
        } else {
            ids.remove(section.id)
        }
        collapsedTagTaskListSectionIDsStorage = ids.sorted().joined(separator: "\n")
    }

    private func taskListGroupCollapseID(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> String {
        "group:\(group.id)"
    }

    private func taskListGroupExpandedOverrideID(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> String {
        "expandedGroup:\(group.id)"
    }

    private func setTagTaskListGroup(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        collapsed: Bool
    ) {
        var ids = collapsedTagTaskListSectionIDs
        let id = taskListGroupCollapseID(group)
        if collapsed {
            ids.insert(id)
        } else {
            ids.remove(id)
        }
        collapsedTagTaskListSectionIDsStorage = ids.sorted().joined(separator: "\n")
    }

    private func setDefaultCollapsedTaskListGroup(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        expanded: Bool
    ) {
        var ids = collapsedTagTaskListSectionIDs
        let id = taskListGroupExpandedOverrideID(group)
        if expanded {
            ids.insert(id)
        } else {
            ids.remove(id)
        }
        collapsedTagTaskListSectionIDsStorage = ids.sorted().joined(separator: "\n")
    }

}
