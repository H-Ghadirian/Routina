import ComposableArchitecture
@preconcurrency import AppKit
import SwiftUI

extension HomeTCAView {
    @ViewBuilder
    func platformListOfSortedTasksView(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> some View {
        if let filterDate = dayPlanUnplannedCompletedFilterDate, macHomeDetailMode == .planner {
            macDayPlanUnplannedCompletedTaskList(for: filterDate)
        } else {
            let presentation = macTaskListPresentation(
                routineDisplays: routineDisplays,
                awayRoutineDisplays: awayRoutineDisplays,
                archivedRoutineDisplays: archivedRoutineDisplays
            )

            if let emptyState = presentation.emptyState {
                emptyStateView(
                    title: emptyState.title,
                    message: emptyState.message,
                    systemImage: emptyState.systemImage
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                macTaskSourceList(
                    presentation,
                    allowsPlannerDrag: macHomeDetailMode == .planner
                )
            }
        }
    }

    func platformRoutineRow(for task: HomeFeature.RoutineDisplay, rowNumber: Int) -> some View {
        let metadataText = rowMetadataText(for: task)
        let rowVisibility = taskRowVisibility

        return HStack(alignment: .top, spacing: 10) {
            if rowVisibility.shows(.icon) || rowVisibility.shows(.rowNumber) {
                VStack(spacing: 4) {
                    if rowVisibility.shows(.icon) {
                        taskIcon(for: task)
                    }

                    if rowVisibility.shows(.rowNumber) {
                        Text("\(rowNumber)")
                            .font(.caption2.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .frame(width: 38)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(task.name)
                        .font(.headline)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Spacer(minLength: 8)

                    if rowVisibility.shows(.statusBadge) {
                        statusBadge(for: task)
                    }
                }

                if let metadataText {
                    Text(metadataText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if rowVisibility.shows(.tags), !task.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(task.tags, id: \.self) { tag in
                            sidebarTagChip(tag)
                        }
                    }
                    .lineLimit(1)
                }

                if rowVisibility.shows(.goals), !task.goalTitles.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(task.goalTitles, id: \.self) { goal in
                            Label(goal, systemImage: "target")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func taskIcon(for task: HomeFeature.RoutineDisplay) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(rowIconBackgroundColor(for: task))
            Text(task.emoji)
                .font(.body)
            if task.hasImage {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "photo.fill")
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .padding(3)
                            .routinaGlassPill()
                    }
                }
                .padding(2)
            }
        }
        .frame(width: 34, height: 34)
    }

    private func tagColor(for tag: String) -> Color? {
        guard let normalizedTag = RoutineTag.normalized(tag) else { return nil }
        return Color(routineTagHex: store.tagColors[normalizedTag])
    }

    private func tagTint(for tag: String) -> Color {
        if let color = tagColor(for: tag) {
            return color
        }
        return .secondary
    }

    private func sidebarTagChip(_ tag: String) -> some View {
        let tint = tagTint(for: tag)

        return Text("#\(tag)")
            .font(.caption2.weight(.semibold))
            .foregroundColor(tint)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .routinaGlassPill(tint: tint, tintOpacity: 0.14)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 0.5)
            )
    }

    private func taskDragPreview(for task: HomeFeature.RoutineDisplay, rowNumber: Int) -> some View {
        routineRow(for: task, rowNumber: rowNumber)
            .padding(.trailing, macTaskSourceRowColorBadgeTrailingSpace(for: task))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(macTaskSourceRowBackground(for: task))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        macTaskSourceRowStroke(for: task),
                        lineWidth: macTaskSourceRowStrokeWidth(for: task)
                    )
            )
            .overlay(alignment: .topTrailing) {
                macTaskSourceRowColorBadge(for: task)
            }
            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
    }

    private func macTaskSourceList(
        _ presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        allowsPlannerDrag: Bool
    ) -> some View {
        let visibleTaskIDs = visibleTaskIDs(in: presentation)

        return ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8, pinnedViews: []) {
                    ForEach(presentation.sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            taskListSectionHeader(for: section)

                            if taskListSectionIsExpanded(section) {
                                ForEach(section.taskGroups) { group in
                                    if let groupTitle = group.title {
                                        taskListInnerGroupHeader(groupTitle, count: group.tasks.count, group: group)
                                    }

                                    if taskListGroupIsExpanded(group) {
                                        ForEach(group.tasks, id: \.id) { task in
                                            macTaskSourceRow(
                                                for: task,
                                                rowNumber: visibleRowNumber(for: task, in: presentation),
                                                includeMarkDone: section.includeMarkDone,
                                                moveContext: group.moveContext,
                                                allowsPlannerDrag: allowsPlannerDrag
                                            )
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(10)
            }
            .onAppear {
                handleMacTaskSourceScrollEvent(
                    .listAppeared,
                    with: scrollProxy,
                    visibleTaskIDs: visibleTaskIDs
                )
            }
            .onChange(of: store.selectedTaskID) { _, _ in
                handleMacTaskSourceScrollEvent(
                    .selectionChanged,
                    with: scrollProxy,
                    visibleTaskIDs: visibleTaskIDs
                )
            }
            .onChange(of: visibleTaskIDs) { _, _ in
                handleMacTaskSourceScrollEvent(
                    .visibleTaskIDsChanged,
                    with: scrollProxy,
                    visibleTaskIDs: visibleTaskIDs
                )
            }
            .onChange(of: macSidebarTaskScrollRequest) { _, _ in
                handleMacTaskSourceScrollEvent(
                    .scrollRequestChanged,
                    with: scrollProxy,
                    visibleTaskIDs: visibleTaskIDs
                )
            }
            .focusable()
            .focused($isMacTaskSourceListFocused)
            .focusEffectDisabled()
            .onKeyPress(.upArrow) {
                handleMacTaskSourceListKeyboardNavigation(
                    .previous,
                    visibleTaskIDs: visibleTaskIDs
                )
                return visibleTaskIDs.isEmpty ? .ignored : .handled
            }
            .onKeyPress(.downArrow) {
                handleMacTaskSourceListKeyboardNavigation(
                    .next,
                    visibleTaskIDs: visibleTaskIDs
                )
                return visibleTaskIDs.isEmpty ? .ignored : .handled
            }
        }
    }

    @ViewBuilder
    private func taskListInnerGroupHeader(
        _ title: String,
        count: Int,
        group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> some View {
        if group.isCollapsible {
            Button {
                toggleTaskListGroup(group)
            } label: {
                taskListInnerGroupHeaderLabel(title, count: count, isExpanded: taskListGroupIsExpanded(group))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(taskListGroupIsExpanded(group) ? "Expanded" : "Collapsed")
        } else {
            taskListInnerGroupHeaderLabel(title, count: count, isExpanded: nil)
        }
    }

    private func taskListInnerGroupHeaderLabel(
        _ title: String,
        count: Int,
        isExpanded: Bool?
    ) -> some View {
        HStack(spacing: 5) {
            if let isExpanded {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }

            Text(title)

            Text("\(count)")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 22)
        .padding(.top, 2)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func taskListSectionHeader(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> some View {
        if section.kind.isCollapsible {
            Button {
                toggleTaskListSection(section)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .rotationEffect(.degrees(taskListSectionIsExpanded(section) ? 90 : 0))

                    Text(section.title)

                    Text("\(section.tasks.count)")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.tertiary)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .accessibilityLabel(section.title)
            .accessibilityValue(taskListSectionIsExpanded(section) ? "Expanded" : "Collapsed")
        } else {
            Text(section.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
        }
    }

    private func taskListSectionIsExpanded(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> Bool {
        switch section.kind {
        case .plannedToday:
            return !collapsedTagTaskListSectionIDs.contains(section.id)
        case .daily:
            return !isDailyRoutinesSectionCollapsed
        case .tag, .untagged:
            return !collapsedTagTaskListSectionIDs.contains(section.id)
        case .archived:
            return !isArchivedSectionCollapsed
        case .pinned, .regular, .away:
            return true
        }
    }

    private func toggleTaskListSection(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) {
        guard section.kind.isCollapsible else { return }
        withAnimation(.snappy(duration: 0.2)) {
            switch section.kind {
            case .plannedToday:
                setTagTaskListSection(section, collapsed: taskListSectionIsExpanded(section))
            case .daily:
                isDailyRoutinesSectionCollapsed.toggle()
            case .tag, .untagged:
                setTagTaskListSection(section, collapsed: taskListSectionIsExpanded(section))
            case .archived:
                isArchivedSectionCollapsed.toggle()
            case .pinned, .regular, .away:
                break
            }
        }
    }

    private func taskListGroupIsExpanded(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> Bool {
        guard group.isCollapsible else { return true }
        return !isMacPlanTodayDailyRoutinesGroupCollapsed
    }

    private func toggleTaskListGroup(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) {
        guard group.isCollapsible else { return }
        withAnimation(.snappy(duration: 0.2)) {
            isMacPlanTodayDailyRoutinesGroupCollapsed.toggle()
        }
    }

    private func visibleRowNumber(
        for task: HomeFeature.RoutineDisplay,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    ) -> Int {
        visibleTaskIDs(in: presentation).firstIndex(of: task.taskID).map { $0 + 1 } ?? 1
    }

    private func visibleTaskIDs(
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    ) -> [UUID] {
        presentation.sections.flatMap { section in
            visibleTaskIDs(in: section)
        }
    }

    private func visibleTaskIDs(
        in section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> [UUID] {
        guard taskListSectionIsExpanded(section) else { return [] }
        return section.taskGroups.flatMap { group in
            taskListGroupIsExpanded(group) ? group.tasks.map(\.taskID) : []
        }
    }

    private var collapsedTagTaskListSectionIDs: Set<String> {
        Set(
            collapsedTagTaskListSectionIDsStorage
                .split(separator: "\n")
                .map(String.init)
        )
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

    private func macDayPlanUnplannedCompletedTaskList(for date: Date) -> some View {
        let tasks = dayPlanUnplannedCompletedDisplays(for: date)
        let section = HomeTaskListPresentationSection(
            kind: .regular,
            title: "Timeline on \(date.formatted(date: .abbreviated, time: .omitted))",
            tasks: tasks,
            rowNumberOffset: 0,
            includeMarkDone: false,
            moveContext: nil
        )
        let presentation = HomeTaskListPresentation(
            sections: tasks.isEmpty ? [] : [section],
            hiddenUnavailableTaskCount: 0,
            emptyState: tasks.isEmpty
                ? HomeTaskListEmptyState(
                    title: "All timeline activity is planned",
                    message: "Timeline tasks for this day are already placed in the planner.",
                    systemImage: "clock.arrow.circlepath"
                )
                : nil
        )

        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Label(dayPlanUnplannedCompletedFilterTitle(for: date), systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Button("Clear") {
                    clearDayPlanUnplannedCompletedFilter()
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if let emptyState = presentation.emptyState {
                emptyStateView(
                    title: emptyState.title,
                    message: emptyState.message,
                    systemImage: emptyState.systemImage
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                macTaskSourceList(presentation, allowsPlannerDrag: true)
            }
        }
    }

    @ViewBuilder
    private func macTaskSourceRow(
        for task: HomeFeature.RoutineDisplay,
        rowNumber: Int,
        includeMarkDone: Bool,
        moveContext: HomeTaskListMoveContext?,
        allowsPlannerDrag: Bool
    ) -> some View {
        let row = routineRow(for: task, rowNumber: rowNumber)
            .padding(.trailing, macTaskSourceRowColorBadgeTrailingSpace(for: task))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .routinaGlassCard(
                cornerRadius: 8,
                tint: macTaskSourceRowGlassTint(for: task),
                tintOpacity: macTaskSourceRowGlassOpacity(for: task),
                interactive: true
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        macTaskSourceRowStroke(for: task),
                        lineWidth: macTaskSourceRowStrokeWidth(for: task)
                    )
            )
            .overlay(alignment: .topTrailing) {
                macTaskSourceRowColorBadge(for: task)
            }
            .id(task.taskID)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                selectMacTaskSourceListTask(task.taskID, scrollAnchor: nil)
            }
            .onMacDoubleClick(enabled: allowsPlannerDrag) {
                openDayPlanTaskDetails(task.taskID)
            }
            .contextMenu {
                routineContextMenu(
                    for: task,
                    includeMarkDone: includeMarkDone,
                    moveContext: moveContext
                )
            }

        if allowsPlannerDrag {
            row
                .draggable(task.taskID.uuidString) {
                    taskDragPreview(for: task, rowNumber: rowNumber)
                }
                .help("Drag to place this task on the planner")
        } else {
            row
        }
    }

    private func macTaskSourceRowGlassTint(for task: HomeFeature.RoutineDisplay) -> Color {
        if task.id == store.selectedTaskID {
            return .accentColor
        }
        guard taskRowVisibility.shows(.rowColor) else {
            return .secondary
        }
        return task.color.swiftUIColor ?? .secondary
    }

    private func macTaskSourceRowGlassOpacity(for task: HomeFeature.RoutineDisplay) -> Double {
        if task.id == store.selectedTaskID {
            return 0.16
        }
        guard taskRowVisibility.shows(.rowColor) else {
            return 0.05
        }
        return task.color.swiftUIColor == nil ? 0.05 : 0.10
    }

    private func handleMacTaskSourceListKeyboardNavigation(
        _ direction: MacTaskSourceListKeyboardDirection,
        visibleTaskIDs: [UUID]
    ) {
        guard let taskID = MacTaskSourceListKeyboardNavigation.adjacentTaskID(
            from: store.selectedTaskID,
            direction: direction,
            visibleTaskIDs: visibleTaskIDs
        ) else { return }

        selectMacTaskSourceListTask(taskID, scrollAnchor: .minimalReveal)
    }

    private func selectMacTaskSourceListTask(
        _ taskID: UUID,
        scrollAnchor: MacSidebarTaskScrollRequest.Anchor?
    ) {
        isMacTaskSourceListFocused = true
        if let scrollAnchor {
            macSidebarTaskScrollRequest = MacSidebarTaskScrollRequest(
                taskID: taskID,
                anchor: scrollAnchor
            )
        }
        store.send(.macSidebarSelectionChanged(.task(taskID)))
    }

    private func macTaskSourceRowBackground(for task: HomeFeature.RoutineDisplay) -> Color {
        if store.selectedTaskID == task.taskID {
            return Color.accentColor.opacity(0.18)
        }
        guard taskRowVisibility.shows(.rowColor) else {
            return Color.secondary.opacity(0.08)
        }
        if let color = task.color.swiftUIColor {
            return color.opacity(0.12)
        }
        return Color.secondary.opacity(0.08)
    }

    private func macTaskSourceRowStroke(for task: HomeFeature.RoutineDisplay) -> Color {
        if store.selectedTaskID == task.taskID {
            return Color.accentColor.opacity(0.55)
        }
        guard taskRowVisibility.shows(.rowColor) else {
            return Color.primary.opacity(0.06)
        }
        if let color = task.color.swiftUIColor {
            return color.opacity(0.32)
        }
        return Color.primary.opacity(0.06)
    }

    private func macTaskSourceRowStrokeWidth(for task: HomeFeature.RoutineDisplay) -> CGFloat {
        1
    }

    private func macTaskSourceRowColorBadgeTrailingSpace(for task: HomeFeature.RoutineDisplay) -> CGFloat {
        taskRowVisibility.shows(.colorBadge) && task.color.swiftUIColor != nil ? 15 : 0
    }

    @ViewBuilder
    private func macTaskSourceRowColorBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        if taskRowVisibility.shows(.colorBadge),
           let color = task.color.swiftUIColor {
            HomeTaskRowColorMarkerShape()
                .fill(color)
                .frame(width: 10, height: 18)
                .padding(.trailing, 18)
                .accessibilityHidden(true)
        }
    }

    private func handleMacTaskSourceScrollEvent(
        _ event: MacTaskSourceListScrollEvent,
        with proxy: ScrollViewProxy,
        visibleTaskIDs: [UUID]
    ) {
        guard let taskID = MacTaskSourceListScrollPolicy.scrollTarget(
            for: event,
            selectedTaskID: store.selectedTaskID,
            pendingRequest: macSidebarTaskScrollRequest,
            visibleTaskIDs: visibleTaskIDs
        ) else { return }

        if scrollMacTaskSourceList(
            to: taskID,
            with: proxy,
            visibleTaskIDs: visibleTaskIDs,
            anchor: macSidebarTaskScrollRequest?.unitPointAnchor
        ) {
            macSidebarTaskScrollRequest = nil
        }
    }

    @discardableResult
    private func scrollMacTaskSourceList(
        to taskID: UUID,
        with proxy: ScrollViewProxy,
        visibleTaskIDs: [UUID],
        anchor: UnitPoint?
    ) -> Bool {
        guard visibleTaskIDs.contains(taskID) else { return false }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(taskID, anchor: anchor)
            }
        }
        return true
    }

    func platformDeleteTasks(
        at offsets: IndexSet,
        from sectionTasks: [HomeFeature.RoutineDisplay]
    ) {
        let ids = offsets.compactMap { sectionTasks[$0].taskID }
        store.send(.deleteTasksTapped(ids))
    }

    func platformOpenTask(_ taskID: UUID) {
        store.send(.macSidebarSelectionChanged(.task(taskID)))
    }

    func platformDeleteTask(_ taskID: UUID) {
        store.send(.deleteTasksTapped([taskID]))
    }

    func platformRoutineNavigationRow(
        for task: HomeFeature.RoutineDisplay,
        rowNumber: Int,
        includeMarkDone: Bool,
        moveContext: HomeTaskListMoveContext?
    ) -> some View {
        routineRow(for: task, rowNumber: rowNumber)
            .tag(MacSidebarSelection.task(task.taskID))
            .contentShape(Rectangle())
            .contextMenu {
                routineContextMenu(
                    for: task,
                    includeMarkDone: includeMarkDone,
                    moveContext: moveContext
                )
            }
    }

}

private extension MacSidebarTaskScrollRequest {
    var unitPointAnchor: UnitPoint? {
        switch anchor {
        case .center:
            return .center
        case .minimalReveal:
            return nil
        }
    }
}
