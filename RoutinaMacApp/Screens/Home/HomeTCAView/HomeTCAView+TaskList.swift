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
        platformRoutineRow(
            for: task,
            rowNumber: rowNumber,
            metadataPresenter: routineMetadataPresenter
        )
    }

    func platformRoutineRow(
        for task: HomeFeature.RoutineDisplay,
        rowNumber: Int,
        rowVisibility: HomeTaskRowVisibility
    ) -> some View {
        platformRoutineRow(
            for: task,
            rowNumber: rowNumber,
            metadataPresenter: routineMetadataPresenter,
            rowVisibility: rowVisibility
        )
    }

    func platformRoutineRow(
        for task: HomeFeature.RoutineDisplay,
        rowNumber: Int,
        metadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay>,
        rowVisibility suppliedRowVisibility: HomeTaskRowVisibility? = nil
    ) -> some View {
        let metadataText = metadataPresenter.rowMetadataText(for: task)
        let rowVisibility = suppliedRowVisibility ?? taskRowVisibility

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
                        statusBadge(for: task, metadataPresenter: metadataPresenter)
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

    private func macTaskSourceList(
        _ presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        allowsPlannerDrag: Bool
    ) -> some View {
        let visibleTaskIDs = visibleTaskIDs(in: presentation)
        let metadataPresenter = routineMetadataPresenter
        let rowVisibility = taskRowVisibility

        return ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    ForEach(presentation.sections) { section in
                        taskListSectionView(
                            for: section,
                            in: presentation,
                            metadataPresenter: metadataPresenter,
                            rowVisibility: rowVisibility,
                            allowsPlannerDrag: allowsPlannerDrag
                        )
                        .padding(.top, taskListTopLevelSectionSpacing(before: section, in: presentation))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
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
        metadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay>,
        rowVisibility: HomeTaskRowVisibility,
        allowsPlannerDrag: Bool
    ) -> some View {
        let isExpanded = taskListSectionIsExpanded(section)

        if section.kind.isCollapsible {
            if taskListSectionUsesContinuousSurface(section) {
                VStack(alignment: .leading, spacing: isExpanded ? 8 : 0) {
                    taskListCollapsibleSectionHeader(for: section, isExpanded: isExpanded)

                    if isExpanded {
                        taskListSectionTaskGroups(
                            for: section,
                            in: presentation,
                            metadataPresenter: metadataPresenter,
                            rowVisibility: rowVisibility,
                            allowsPlannerDrag: allowsPlannerDrag
                        )
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .routinaGlassCard(
                    cornerRadius: taskListTopLevelSectionCornerRadius(for: section),
                    tint: taskListSectionHeaderTint(for: section),
                    tintOpacity: taskListSectionHeaderTintOpacity(for: section, isExpanded: isExpanded),
                    interactive: true
                )
                .overlay(alignment: .top) {
                    taskListTopLevelSectionHorizontalRule(for: section, isExpanded: isExpanded)
                }
                .overlay(alignment: .bottom) {
                    taskListTopLevelSectionHorizontalRule(for: section, isExpanded: isExpanded)
                }
                .clipped()
                .padding(.horizontal, -10)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    taskListCollapsibleSectionHeader(for: section, isExpanded: isExpanded)
                        .padding(.bottom, isExpanded ? 6 : 0)

                    if isExpanded {
                        taskListSectionTaskGroups(
                            for: section,
                            in: presentation,
                            metadataPresenter: metadataPresenter,
                            rowVisibility: rowVisibility,
                            allowsPlannerDrag: allowsPlannerDrag
                        )
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
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
                .clipped()
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                taskListSectionHeader(for: section)

                if isExpanded {
                    taskListSectionTaskGroups(
                        for: section,
                        in: presentation,
                        metadataPresenter: metadataPresenter,
                        rowVisibility: rowVisibility,
                        allowsPlannerDrag: allowsPlannerDrag
                    )
                }
            }
        }
    }

    private func taskListSectionUsesContinuousSurface(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> Bool {
        section.kind == .plannedToday || section.kind == .future
    }

    private func taskListTopLevelSectionSpacing(
        before section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    ) -> CGFloat {
        guard let index = presentation.sections.firstIndex(where: { $0.id == section.id }), index > 0 else {
            return 0
        }

        let previous = presentation.sections[index - 1]
        if taskListSectionUsesContinuousSurface(previous), taskListSectionUsesContinuousSurface(section) {
            return 0
        }
        return 8
    }

    private func taskListTopLevelSectionCornerRadius(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> CGFloat {
        switch section.kind {
        case .plannedToday, .future:
            return 0
        case .daily, .tag, .untagged, .archived, .pinned, .regular, .deadlineDate, .away:
            return 8
        }
    }

    private func taskListTopLevelSectionHorizontalRule(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        isExpanded: Bool
    ) -> some View {
        Rectangle()
            .fill(
                taskListSectionHeaderTint(for: section).opacity(
                    taskListSectionHeaderStrokeOpacity(for: section, isExpanded: isExpanded)
                )
            )
            .frame(height: 0.75)
    }

    private func taskListCollapsibleSectionHeader(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        isExpanded: Bool
    ) -> some View {
        Button {
            toggleTaskListSection(section)
        } label: {
            taskListSectionHeaderContent(for: section, isExpanded: isExpanded)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.title)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .contextMenu {
            taskListSectionContextMenu(for: section)
        }
    }

    @ViewBuilder
    private func taskListSectionTaskGroups(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        metadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay>,
        rowVisibility: HomeTaskRowVisibility,
        allowsPlannerDrag: Bool
    ) -> some View {
        let taskGroups = section.taskGroups
        VStack(alignment: .leading, spacing: taskListGroupStackSpacing(for: section)) {
            ForEach(taskGroups) { group in
                if taskListGroupUsesSectionSurface(group) {
                    VStack(alignment: .leading, spacing: 0) {
                        if let groupTitle = group.title {
                            taskListInnerGroupHeader(groupTitle, count: group.tasks.count, group: group)
                                .padding(.bottom, taskListGroupIsExpanded(group) ? 6 : 0)
                        }

                        if taskListGroupIsExpanded(group) {
                            taskListGroupRows(
                                group,
                                section: section,
                                in: presentation,
                                metadataPresenter: metadataPresenter,
                                rowVisibility: rowVisibility,
                                allowsPlannerDrag: allowsPlannerDrag
                            )
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .routinaGlassCard(
                        cornerRadius: 8,
                        tint: taskListGroupHeaderTint(for: group),
                        tintOpacity: taskListGroupHeaderTintOpacity(for: group),
                        interactive: true
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                taskListGroupHeaderTint(for: group).opacity(
                                    taskListGroupHeaderStrokeOpacity(for: group)
                                ),
                                lineWidth: 0.75
                            )
                    )
                    .clipped()
                } else {
                    if let groupTitle = group.title {
                        taskListInnerGroupHeader(groupTitle, count: group.tasks.count, group: group)
                    }

                    if taskListGroupIsExpanded(group) {
                        taskListGroupRows(
                            group,
                            section: section,
                            in: presentation,
                            metadataPresenter: metadataPresenter,
                            rowVisibility: rowVisibility,
                            allowsPlannerDrag: allowsPlannerDrag
                        )
                    }
                }
            }
        }
        .id(taskListTaskGroupsRenderIdentity(taskGroups))
    }

    private func taskListGroupStackSpacing(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> CGFloat {
        guard section.taskGroups.count > 1 else { return 0 }
        if section.kind == .plannedToday,
           section.taskGroups.allSatisfy({ $0.title == nil && !$0.isCollapsible }) {
            return taskListTaskRowSpacing()
        }
        return 8
    }

    @ViewBuilder
    private func taskListGroupRows(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        metadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay>,
        rowVisibility: HomeTaskRowVisibility,
        allowsPlannerDrag: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: taskListTaskRowSpacing()) {
            ForEach(group.tasks, id: \.id) { task in
                macTaskSourceRow(
                    for: task,
                    rowNumber: visibleRowNumber(for: task, in: presentation),
                    includeMarkDone: section.includeMarkDone,
                    moveContext: group.moveContext,
                    metadataPresenter: metadataPresenter,
                    rowVisibility: rowVisibility,
                    allowsPlannerDrag: allowsPlannerDrag
                )
            }
        }
    }

    private func taskListTaskRowSpacing() -> CGFloat {
        5
    }

    private func taskListTaskGroupsRenderIdentity(
        _ groups: [HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>]
    ) -> String {
        groups.map { group in
            let taskIDs = group.tasks.map(\.taskID.uuidString).joined(separator: ",")
            return "\(group.id):\(taskIDs)"
        }
        .joined(separator: "|")
    }

    private func taskListGroupUsesSectionSurface(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> Bool {
        group.title != nil && (group.kind == .tag || group.kind == .untagged || group.kind == .deadlineDate)
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
                if taskListGroupUsesSectionSurface(group) {
                    taskListInnerGroupSectionHeaderContent(
                        title,
                        count: count,
                        group: group,
                        isExpanded: taskListGroupIsExpanded(group)
                    )
                } else {
                    taskListInnerGroupHeaderLabel(title, count: count, isExpanded: taskListGroupIsExpanded(group))
                }
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

    private func taskListInnerGroupSectionHeaderContent(
        _ title: String,
        count: Int,
        group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        isExpanded: Bool
    ) -> some View {
        let tint = taskListGroupHeaderTint(for: group)

        return HStack(spacing: 7) {
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 12)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))

            Image(systemName: taskListGroupHeaderIcon(for: group))
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
                .background(
                    Circle()
                        .fill(tint.opacity(0.16))
                )

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 6)

            Text(count.formatted())
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .routinaGlassPill(tint: tint, tintOpacity: 0.16)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
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

    private func taskListSectionHeader(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> some View {
        Text(section.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
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
        isExpanded _: Bool
    ) -> Double {
        switch section.kind {
        case .tag:
            return 0.12
        case .future:
            return 0.07
        case .plannedToday, .daily:
            return 0.08
        case .untagged, .archived:
            return 0.06
        case .pinned, .regular, .deadlineDate, .away:
            return 0.07
        }
    }

    private func taskListSectionHeaderStrokeOpacity(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        isExpanded _: Bool
    ) -> Double {
        switch section.kind {
        case .tag:
            return 0.30
        case .future:
            return 0.20
        case .plannedToday, .daily:
            return 0.22
        case .untagged, .archived:
            return 0.18
        case .pinned, .regular, .deadlineDate, .away:
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
        case .future:
            return "calendar"
        case .tag:
            return "tag.fill"
        case .untagged:
            return "tag.slash"
        case .archived:
            return "archivebox.fill"
        case .pinned:
            return "pin.fill"
        case .regular, .deadlineDate, .away:
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
        case .future:
            return .secondary
        case .tag:
            if let tag = taskListSectionHeaderTagName(for: section) {
                return tagTint(for: tag)
            }
            return .accentColor
        case .untagged, .archived:
            return .secondary
        case .pinned:
            return .orange
        case .regular, .deadlineDate, .away:
            return .secondary
        }
    }

    private func taskListGroupHeaderTintOpacity(
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> Double {
        switch group.kind {
        case .tag:
            return 0.12
        case .untagged:
            return 0.06
        case .plannedToday, .daily, .future, .regular, .deadlineDate, .pinned, .away, .archived:
            return 0.07
        }
    }

    private func taskListGroupHeaderStrokeOpacity(
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> Double {
        switch group.kind {
        case .tag:
            return 0.30
        case .untagged:
            return 0.18
        case .plannedToday, .daily, .future, .regular, .deadlineDate, .pinned, .away, .archived:
            return 0.22
        }
    }

    private func taskListGroupHeaderIcon(
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> String {
        switch group.kind {
        case .tag:
            return "tag.fill"
        case .untagged:
            return "tag.slash"
        case .daily:
            return "arrow.triangle.2.circlepath"
        case .plannedToday:
            return "checklist"
        case .future:
            return "calendar"
        case .archived:
            return "archivebox.fill"
        case .pinned:
            return "pin.fill"
        case .regular, .away:
            return "list.bullet"
        case .deadlineDate:
            return "calendar"
        }
    }

    private func taskListGroupHeaderTint(
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> Color {
        switch group.kind {
        case .tag:
            if let tag = taskListGroupHeaderTagName(for: group) {
                return tagTint(for: tag)
            }
            return .accentColor
        case .daily:
            return .teal
        case .plannedToday:
            return .accentColor
        case .untagged, .future, .regular, .deadlineDate, .away, .archived:
            return .secondary
        case .pinned:
            return .orange
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

    private func taskListGroupHeaderTagName(
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> String? {
        if let firstTag = group.tasks.compactMap(\.taskListPrimaryTag).first {
            return firstTag
        }
        guard let title = group.title, title.hasPrefix("#") else { return nil }
        return String(title.dropFirst())
    }

    @ViewBuilder
    private func taskListSectionContextMenu(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> some View {
        let showsFutureSubsectionActions = section.kind == .future && section.taskGroups.contains { $0.isCollapsible }

        if showsFutureSubsectionActions {
            Button {
                expandAllFutureTaskListSubsections(in: section)
            } label: {
                Label("Expand All", systemImage: "chevron.down.2")
            }

            Button {
                collapseAllFutureTaskListSubsections(in: section)
            } label: {
                Label("Collapse All Subsections", systemImage: "chevron.right.2")
            }
        }

        if showsFutureSubsectionActions, areMacHomeSectionFocusTimersEnabled, section.canStartFocusTimer {
            Divider()
        }

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
            taskDetailPanePlacement = nil
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
            taskDetailPanePlacement = nil
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

    private func toggleTaskListSection(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) {
        guard section.kind.isCollapsible else { return }
        withAnimation(.easeInOut(duration: 0.24)) {
            switch section.kind {
            case .plannedToday:
                setTagTaskListSection(section, collapsed: taskListSectionIsExpanded(section))
            case .daily:
                isDailyRoutinesSectionCollapsed.toggle()
            case .future:
                isMacFutureTasksSectionCollapsed.toggle()
            case .tag, .untagged:
                setTagTaskListSection(section, collapsed: taskListSectionIsExpanded(section))
            case .archived:
                isArchivedSectionCollapsed.toggle()
            case .pinned, .regular, .deadlineDate, .away:
                break
            }
        }
    }

    private func taskListGroupIsExpanded(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> Bool {
        guard group.isCollapsible else { return true }
        switch group.kind {
        case .daily:
            return !isMacPlanTodayDailyRoutinesGroupCollapsed
        case .deadlineDate, .tag, .untagged:
            return !collapsedTagTaskListSectionIDs.contains(taskListGroupCollapseID(group))
        case .plannedToday, .future, .regular, .pinned, .away, .archived:
            return true
        }
    }

    private func toggleTaskListGroup(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) {
        guard group.isCollapsible else { return }
        withAnimation(.easeInOut(duration: 0.24)) {
            switch group.kind {
            case .daily:
                isMacPlanTodayDailyRoutinesGroupCollapsed.toggle()
            case .deadlineDate, .tag, .untagged:
                setTagTaskListGroup(group, collapsed: taskListGroupIsExpanded(group))
            case .plannedToday, .future, .regular, .pinned, .away, .archived:
                break
            }
        }
    }

    private func expandAllFutureTaskListSubsections(
        in section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) {
        setAllFutureTaskListSubsections(in: section, collapsed: false)
    }

    private func collapseAllFutureTaskListSubsections(
        in section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) {
        setAllFutureTaskListSubsections(in: section, collapsed: true)
    }

    private func setAllFutureTaskListSubsections(
        in section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        collapsed: Bool
    ) {
        let subsectionIDs = futureTaskListSubsectionCollapseIDs(in: section)
        guard section.kind == .future, !subsectionIDs.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.24)) {
            isMacFutureTasksSectionCollapsed = false
            var ids = collapsedTagTaskListSectionIDs
            if collapsed {
                ids.formUnion(subsectionIDs)
            } else {
                ids.subtract(subsectionIDs)
            }
            collapsedTagTaskListSectionIDsStorage = ids.sorted().joined(separator: "\n")
        }
    }

    private func futureTaskListSubsectionCollapseIDs(
        in section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> Set<String> {
        Set(
            section.taskGroups
                .filter(\.isCollapsible)
                .map(taskListGroupCollapseID)
        )
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

    private func taskListGroupCollapseID(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> String {
        "group:\(group.id)"
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
        metadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay>,
        rowVisibility: HomeTaskRowVisibility,
        allowsPlannerDrag: Bool
    ) -> some View {
        let row = platformRoutineRow(
            for: task,
            rowNumber: rowNumber,
            metadataPresenter: metadataPresenter,
            rowVisibility: rowVisibility
        )
            .padding(.trailing, macTaskSourceRowColorBadgeTrailingSpace(for: task, rowVisibility: rowVisibility))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .routinaGlassCard(
                cornerRadius: 8,
                tint: macTaskSourceRowGlassTint(for: task, rowVisibility: rowVisibility),
                tintOpacity: macTaskSourceRowGlassOpacity(for: task, rowVisibility: rowVisibility),
                interactive: true
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        macTaskSourceRowStroke(for: task, rowVisibility: rowVisibility),
                        lineWidth: macTaskSourceRowStrokeWidth(for: task)
                    )
            )
            .overlay(alignment: .topTrailing) {
                macTaskSourceRowColorBadge(for: task, rowVisibility: rowVisibility)
            }
            .id(task.taskID)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                selectMacTaskSourceListTask(task.taskID, scrollAnchor: nil)
            }
            .onMacDoubleClick {
                openMacTaskDetails(
                    task.taskID,
                    presentation: .fullDetail,
                    scrollAnchor: nil
                )
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
                .draggable(task.taskID.uuidString)
                .help("Drag to place this task on the planner")
        } else {
            row
        }
    }

    private func macTaskSourceRowGlassTint(
        for task: HomeFeature.RoutineDisplay,
        rowVisibility: HomeTaskRowVisibility
    ) -> Color {
        if task.id == store.selectedTaskID {
            return .accentColor
        }
        guard rowVisibility.shows(.rowColor) else {
            return .secondary
        }
        return task.color.swiftUIColor ?? .secondary
    }

    private func macTaskSourceRowGlassOpacity(
        for task: HomeFeature.RoutineDisplay,
        rowVisibility: HomeTaskRowVisibility
    ) -> Double {
        if task.id == store.selectedTaskID {
            return 0.16
        }
        guard rowVisibility.shows(.rowColor) else {
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
        openMacTaskDetails(
            taskID,
            presentation: .listSelection,
            scrollAnchor: scrollAnchor
        )
    }

    private func macTaskSourceRowBackground(
        for task: HomeFeature.RoutineDisplay,
        rowVisibility: HomeTaskRowVisibility
    ) -> Color {
        if store.selectedTaskID == task.taskID {
            return Color.accentColor.opacity(0.18)
        }
        guard rowVisibility.shows(.rowColor) else {
            return Color.secondary.opacity(0.08)
        }
        if let color = task.color.swiftUIColor {
            return color.opacity(0.12)
        }
        return Color.secondary.opacity(0.08)
    }

    private func macTaskSourceRowStroke(
        for task: HomeFeature.RoutineDisplay,
        rowVisibility: HomeTaskRowVisibility
    ) -> Color {
        if store.selectedTaskID == task.taskID {
            return Color.accentColor.opacity(0.55)
        }
        guard rowVisibility.shows(.rowColor) else {
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

    private func macTaskSourceRowColorBadgeTrailingSpace(
        for task: HomeFeature.RoutineDisplay,
        rowVisibility: HomeTaskRowVisibility
    ) -> CGFloat {
        rowVisibility.shows(.colorBadge) && task.color.swiftUIColor != nil ? 15 : 0
    }

    @ViewBuilder
    private func macTaskSourceRowColorBadge(
        for task: HomeFeature.RoutineDisplay,
        rowVisibility: HomeTaskRowVisibility
    ) -> some View {
        if rowVisibility.shows(.colorBadge),
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
        macHomeDetailMode = .details
        taskDetailPanePlacement = nil
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
        let rowVisibility = taskRowVisibility

        return platformRoutineRow(for: task, rowNumber: rowNumber, rowVisibility: rowVisibility)
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
        case .plannedToday, .daily, .future, .tag, .untagged, .regular, .deadlineDate, .pinned:
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
