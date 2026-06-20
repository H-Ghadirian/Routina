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

                if rowVisibility.shows(.tags) {
                    tagRow(for: task)
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

    private func tagRow(for task: HomeFeature.RoutineDisplay) -> some View {
        HStack(spacing: 6) {
            ForEach(task.tags, id: \.self) { tag in
                sidebarTagChip(tag)
            }
        }
        .lineLimit(1)
        .frame(minHeight: 20, alignment: .leading)
        .accessibilityHidden(task.tags.isEmpty)
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
                        taskListSectionView(
                            for: section,
                            in: presentation,
                            allowsPlannerDrag: allowsPlannerDrag
                        )
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
    private func taskListSectionView(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        allowsPlannerDrag: Bool
    ) -> some View {
        let isExpanded = taskListSectionIsExpanded(section)

        if section.kind.isCollapsible && isExpanded {
            VStack(alignment: .leading, spacing: 0) {
                taskListExpandedSectionHeader(for: section)
                    .padding(.bottom, 6)

                taskListSectionTaskGroups(
                    for: section,
                    in: presentation,
                    allowsPlannerDrag: allowsPlannerDrag
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .padding(4)
            .routinaGlassCard(
                cornerRadius: 8,
                tint: taskListSectionHeaderTint(for: section),
                tintOpacity: taskListSectionHeaderTintOpacity(for: section, isExpanded: true),
                interactive: true
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        taskListSectionHeaderTint(for: section).opacity(
                            taskListSectionHeaderStrokeOpacity(for: section, isExpanded: true)
                        ),
                        lineWidth: 0.75
                    )
            )
        } else {
            VStack(alignment: .leading, spacing: 6) {
                taskListSectionHeader(for: section)

                if isExpanded {
                    taskListSectionTaskGroups(
                        for: section,
                        in: presentation,
                        allowsPlannerDrag: allowsPlannerDrag
                    )
                }
            }
        }
    }

    private func taskListExpandedSectionHeader(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> some View {
        Button {
            toggleTaskListSection(section)
        } label: {
            taskListSectionHeaderContent(for: section, isExpanded: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.title)
        .accessibilityValue("Expanded")
        .contextMenu {
            taskListSectionFocusContextMenu(for: section)
        }
    }

    @ViewBuilder
    private func taskListSectionTaskGroups(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        allowsPlannerDrag: Bool
    ) -> some View {
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
            .contextMenu {
                taskListGroupFocusContextMenu(for: group)
            }
        } else {
            taskListInnerGroupHeaderLabel(title, count: count, isExpanded: nil)
                .contextMenu {
                    taskListGroupFocusContextMenu(for: group)
                }
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
            let isExpanded = taskListSectionIsExpanded(section)

            Button {
                toggleTaskListSection(section)
            } label: {
                taskListSectionHeaderLabel(for: section, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(section.title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .contextMenu {
                taskListSectionFocusContextMenu(for: section)
            }
        } else {
            Text(section.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
        }
    }

    private func taskListSectionHeaderLabel(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        isExpanded: Bool
    ) -> some View {
        taskListSectionHeaderContent(for: section, isExpanded: isExpanded)
            .routinaGlassCard(
                cornerRadius: 8,
                tint: taskListSectionHeaderTint(for: section),
                tintOpacity: taskListSectionHeaderTintOpacity(for: section, isExpanded: isExpanded),
                interactive: true
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        taskListSectionHeaderTint(for: section).opacity(
                            taskListSectionHeaderStrokeOpacity(for: section, isExpanded: isExpanded)
                        ),
                        lineWidth: 0.75
                    )
            )
    }

    private func taskListSectionHeaderContent(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        isExpanded: Bool
    ) -> some View {
        let tint = taskListSectionHeaderTint(for: section)

        return HStack(spacing: 7) {
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 12)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))

            Image(systemName: taskListSectionHeaderIcon(for: section))
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
                .background(
                    Circle()
                        .fill(tint.opacity(0.16))
                )

            Text(section.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 6)

            Text(section.tasks.count.formatted())
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .routinaGlassPill(tint: tint, tintOpacity: 0.16)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func taskListSectionHeaderTintOpacity(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        isExpanded: Bool
    ) -> Double {
        switch section.kind {
        case .tag:
            return isExpanded ? 0.17 : 0.12
        case .plannedToday, .daily:
            return isExpanded ? 0.12 : 0.08
        case .untagged, .archived:
            return isExpanded ? 0.10 : 0.06
        case .pinned, .regular, .away:
            return 0.07
        }
    }

    private func taskListSectionHeaderStrokeOpacity(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        isExpanded: Bool
    ) -> Double {
        switch section.kind {
        case .tag:
            return isExpanded ? 0.42 : 0.30
        case .plannedToday, .daily:
            return isExpanded ? 0.34 : 0.22
        case .untagged, .archived:
            return isExpanded ? 0.24 : 0.18
        case .pinned, .regular, .away:
            return 0.22
        }
    }

    private func taskListSectionHeaderIcon(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> String {
        switch section.kind {
        case .plannedToday:
            return "checklist"
        case .daily:
            return "arrow.triangle.2.circlepath"
        case .tag:
            return "tag.fill"
        case .untagged:
            return "tag.slash"
        case .archived:
            return "archivebox.fill"
        case .pinned:
            return "pin.fill"
        case .regular, .away:
            return "list.bullet"
        }
    }

    private func taskListSectionHeaderTint(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> Color {
        switch section.kind {
        case .plannedToday:
            return .accentColor
        case .daily:
            return .teal
        case .tag:
            if let tag = taskListSectionHeaderTagName(for: section) {
                return tagTint(for: tag)
            }
            return .accentColor
        case .untagged, .archived:
            return .secondary
        case .pinned:
            return .orange
        case .regular, .away:
            return .secondary
        }
    }

    private func taskListSectionHeaderTagName(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> String? {
        if let firstTag = section.tasks.compactMap(\.taskListPrimaryTag).first {
            return firstTag
        }
        guard section.title.hasPrefix("#") else { return nil }
        return String(section.title.dropFirst())
    }

    @ViewBuilder
    private func taskListSectionFocusContextMenu(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> some View {
        if areMacHomeSectionFocusTimersEnabled, section.canStartFocusTimer {
            Section("Focus Timer") {
                taskListSectionFocusContextMenuItems(for: section)
            }
        }
    }

    @ViewBuilder
    private func taskListGroupFocusContextMenu(
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> some View {
        if areMacHomeSectionFocusTimersEnabled, group.canStartFocusTimer {
            Section("Focus Timer") {
                taskListGroupFocusContextMenuItems(for: group)
            }
        }
    }

    @ViewBuilder
    private func taskListSectionFocusContextMenuItems(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> some View {
        if section.canStartFocusTimer {
            Button {
                startFocusFromTaskListSection(section, duration: 0)
            } label: {
                Label("Count up", systemImage: "stopwatch")
            }

            Divider()

            ForEach(planFocusDurationOptions, id: \.self) { duration in
                Button(FocusSessionFormatting.compactDurationText(seconds: duration)) {
                    startFocusFromTaskListSection(section, duration: duration)
                }
            }
        }
    }

    @ViewBuilder
    private func taskListGroupFocusContextMenuItems(
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> some View {
        if group.canStartFocusTimer {
            Button {
                startFocusFromTaskListGroup(group, duration: 0)
            } label: {
                Label("Count up", systemImage: "stopwatch")
            }

            Divider()

            ForEach(planFocusDurationOptions, id: \.self) { duration in
                Button(FocusSessionFormatting.compactDurationText(seconds: duration)) {
                    startFocusFromTaskListGroup(group, duration: duration)
                }
            }
        }
    }

    private var planFocusDurationOptions: [TimeInterval] {
        [
            15 * 60,
            25 * 60,
            45 * 60,
            60 * 60,
            90 * 60,
        ]
    }

    private func startFocusFromTaskListSection(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        duration: TimeInterval
    ) {
        guard areMacHomeSectionFocusTimersEnabled, section.canStartFocusTimer else { return }

        do {
            _ = try FocusSessionSupport.startUnassignedFocus(
                plannedDurationSeconds: duration,
                context: modelContext
            )
            macHomeDetailMode = .planner
        } catch {
            NSLog("Failed to start section focus: \(error.localizedDescription)")
        }
    }

    private func startFocusFromTaskListGroup(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        duration: TimeInterval
    ) {
        guard areMacHomeSectionFocusTimersEnabled, group.canStartFocusTimer else { return }

        do {
            _ = try FocusSessionSupport.startUnassignedFocus(
                plannedDurationSeconds: duration,
                context: modelContext
            )
            macHomeDetailMode = .planner
        } catch {
            NSLog("Failed to start group focus: \(error.localizedDescription)")
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
            .routinaMacContextMenu {
                routineNativeContextMenu(
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
            .routinaMacContextMenu {
                routineNativeContextMenu(
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

private extension HomeTaskListPresentationSection where Display == HomeFeature.RoutineDisplay {
    var canStartFocusTimer: Bool {
        guard !tasks.isEmpty else { return false }
        switch kind {
        case .plannedToday, .daily, .tag, .untagged, .regular, .pinned:
            return true
        case .away, .archived:
            return false
        }
    }
}

private extension HomeTaskListPresentationTaskGroup where Display == HomeFeature.RoutineDisplay {
    var canStartFocusTimer: Bool {
        !tasks.isEmpty
    }
}
