import ComposableArchitecture
import AppKit
import SwiftUI

extension HomeTCAView {
    @ViewBuilder
    func taskListSectionView(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        collapsedTagIDs: Set<String>,
        rowNumbersByTaskID: [UUID: Int],
        metadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay>,
        rowVisibility: HomeTaskRowVisibility,
        allowsPlannerDrag: Bool
    ) -> some View {
        let isExpanded = taskListSectionIsExpanded(section, collapsedTagIDs: collapsedTagIDs)

        if section.kind.isCollapsible {
            if taskListSectionUsesContinuousSurface(section) {
                VStack(alignment: .leading, spacing: isExpanded ? 8 : 0) {
                    taskListCollapsibleSectionHeader(
                        for: section,
                        isExpanded: isExpanded,
                        in: presentation
                    )

                    if isExpanded {
                        taskListSectionTaskGroups(
                            for: section,
                            in: presentation,
                            collapsedTagIDs: collapsedTagIDs,
                            rowNumbersByTaskID: rowNumbersByTaskID,
                            metadataPresenter: metadataPresenter,
                            rowVisibility: rowVisibility,
                            allowsPlannerDrag: allowsPlannerDrag
                        )
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                        .transition(taskListSearchRestoreTransition)
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
                    taskListCollapsibleSectionHeader(
                        for: section,
                        isExpanded: isExpanded,
                        in: presentation
                    )
                    .padding(.bottom, isExpanded ? 6 : 0)

                    if isExpanded {
                        taskListSectionTaskGroups(
                            for: section,
                            in: presentation,
                            collapsedTagIDs: collapsedTagIDs,
                            rowNumbersByTaskID: rowNumbersByTaskID,
                            metadataPresenter: metadataPresenter,
                            rowVisibility: rowVisibility,
                            allowsPlannerDrag: allowsPlannerDrag
                        )
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .transition(taskListSearchRestoreTransition)
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
                taskListSectionHeader(for: section, in: presentation)

                if isExpanded {
                    taskListSectionTaskGroups(
                        for: section,
                        in: presentation,
                        collapsedTagIDs: collapsedTagIDs,
                        rowNumbersByTaskID: rowNumbersByTaskID,
                        metadataPresenter: metadataPresenter,
                        rowVisibility: rowVisibility,
                        allowsPlannerDrag: allowsPlannerDrag
                    )
                }
            }
        }
    }

    func moveMacTaskListSection(
        _ sectionID: String,
        by offset: Int,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    ) {
        let visibleIDs = presentation.sections
            .filter(\.kind.isMacSidebarReorderable)
            .map(\.id)
        guard
            HomeMacTaskListSectionOrder.canMove(
                sectionID,
                by: offset,
                visibleIDs: visibleIDs
            )
        else { return }

        let preferredIDs = HomeMacTaskListSectionOrder.decoded(
            from: macHomeTaskListSectionOrderRawValue
        )
        let updatedIDs = HomeMacTaskListSectionOrder.moving(
            sectionID,
            by: offset,
            preferredIDs: preferredIDs,
            visibleIDs: visibleIDs
        )

        withAnimation(.easeInOut(duration: 0.2)) {
            macHomeTaskListSectionOrderRawValue = HomeMacTaskListSectionOrder.encoded(updatedIDs)
        }
    }

    private func taskListSectionUsesContinuousSurface(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> Bool {
        section.kind == .plannedToday || section.kind == .plannedTomorrow || section.kind == .custom
            || section.kind == .future || section.kind == .archived
    }

    func taskListTopLevelSectionSpacing(
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
        case .plannedToday, .plannedTomorrow, .custom, .future, .archived:
            return 0
        case .daily, .tag, .untagged, .pinned, .regular, .deadlineDate, .away:
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

    @ViewBuilder
    private func taskListCollapsibleSectionHeader(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        isExpanded: Bool,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    ) -> some View {
        let header = taskListCollapsibleSectionHeaderButton(
            for: section,
            isExpanded: isExpanded
        )

        if taskListSectionHasContextMenu(section) {
            header
                .routinaMacContextMenu {
                    taskListSectionNativeContextMenu(for: section, in: presentation)
                }
        } else {
            header
        }
    }

    private func taskListCollapsibleSectionHeaderButton(
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
    }

    @ViewBuilder
    private func taskListSectionTaskGroups(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        collapsedTagIDs: Set<String>,
        rowNumbersByTaskID: [UUID: Int],
        metadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay>,
        rowVisibility: HomeTaskRowVisibility,
        allowsPlannerDrag: Bool
    ) -> some View {
        let taskGroups = section.taskGroups
        LazyVStack(alignment: .leading, spacing: taskListGroupStackSpacing(for: section)) {
            ForEach(taskGroups) { group in
                Group {
                    if taskListGroupUsesSectionSurface(group) {
                        VStack(alignment: .leading, spacing: 0) {
                            if let groupTitle = group.title {
                                let isExpanded = taskListGroupIsExpanded(group, collapsedTagIDs: collapsedTagIDs)
                                taskListInnerGroupHeader(
                                    groupTitle,
                                    count: group.tasks.count,
                                    group: group,
                                    collapsedTagIDs: collapsedTagIDs
                                )
                                .padding(.bottom, isExpanded ? 6 : 0)
                            }

                            if taskListGroupIsExpanded(group, collapsedTagIDs: collapsedTagIDs) {
                                taskListGroupContent(
                                    group,
                                    section: section,
                                    in: presentation,
                                    collapsedTagIDs: collapsedTagIDs,
                                    rowNumbersByTaskID: rowNumbersByTaskID,
                                    metadataPresenter: metadataPresenter,
                                    rowVisibility: rowVisibility,
                                    allowsPlannerDrag: allowsPlannerDrag
                                )
                                .padding(.horizontal, 8)
                                .padding(.bottom, 8)
                                .transition(taskListSearchRestoreTransition)
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
                            taskListInnerGroupHeader(
                                groupTitle,
                                count: group.tasks.count,
                                group: group,
                                collapsedTagIDs: collapsedTagIDs
                            )
                        }

                        if taskListGroupIsExpanded(group, collapsedTagIDs: collapsedTagIDs) {
                            taskListGroupContent(
                                group,
                                section: section,
                                in: presentation,
                                collapsedTagIDs: collapsedTagIDs,
                                rowNumbersByTaskID: rowNumbersByTaskID,
                                metadataPresenter: metadataPresenter,
                                rowVisibility: rowVisibility,
                                allowsPlannerDrag: allowsPlannerDrag
                            )
                        }
                    }
                }
                .id(
                    MacTaskSourceListScrollAnchor.group(
                        sectionID: section.id,
                        groupID: group.id
                    )
                )
            }
        }
    }

    private func taskListGroupStackSpacing(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> CGFloat {
        guard section.taskGroups.count > 1 else { return 0 }
        let containsOnlyUncollapsibleUntitledGroups = section.taskGroups.allSatisfy {
            $0.title == nil && !$0.isCollapsible
        }
        if section.kind == .plannedToday && containsOnlyUncollapsibleUntitledGroups {
            return taskListTaskRowSpacing()
        }
        return 8
    }

    @ViewBuilder
    private func taskListGroupContent(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        collapsedTagIDs: Set<String>,
        rowNumbersByTaskID: [UUID: Int],
        metadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay>,
        rowVisibility: HomeTaskRowVisibility,
        allowsPlannerDrag: Bool
    ) -> some View {
        if group.childGroups.isEmpty {
            taskListGroupRows(
                group,
                section: section,
                in: presentation,
                rowNumbersByTaskID: rowNumbersByTaskID,
                metadataPresenter: metadataPresenter,
                rowVisibility: rowVisibility,
                allowsPlannerDrag: allowsPlannerDrag
            )
        } else {
            taskListChildGroups(
                for: group,
                section: section,
                in: presentation,
                collapsedTagIDs: collapsedTagIDs,
                rowNumbersByTaskID: rowNumbersByTaskID,
                metadataPresenter: metadataPresenter,
                rowVisibility: rowVisibility,
                allowsPlannerDrag: allowsPlannerDrag
            )
        }
    }

    @ViewBuilder
    private func taskListChildGroups(
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        collapsedTagIDs: Set<String>,
        rowNumbersByTaskID: [UUID: Int],
        metadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay>,
        rowVisibility: HomeTaskRowVisibility,
        allowsPlannerDrag: Bool
    ) -> some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(group.childGroups) { childGroup in
                VStack(alignment: .leading, spacing: 5) {
                    if let title = childGroup.title {
                        taskListInnerGroupHeader(
                            title,
                            count: childGroup.tasks.count,
                            group: childGroup,
                            collapsedTagIDs: collapsedTagIDs
                        )
                    }

                    if taskListGroupIsExpanded(childGroup, collapsedTagIDs: collapsedTagIDs) {
                        taskListGroupRows(
                            childGroup,
                            section: section,
                            in: presentation,
                            rowNumbersByTaskID: rowNumbersByTaskID,
                            metadataPresenter: metadataPresenter,
                            rowVisibility: rowVisibility,
                            allowsPlannerDrag: allowsPlannerDrag
                        )
                        .transition(taskListSearchRestoreTransition)
                    }
                }
                .id(
                    MacTaskSourceListScrollAnchor.group(
                        sectionID: section.id,
                        groupID: childGroup.id
                    )
                )
            }
        }
    }

    @ViewBuilder
    private func taskListGroupRows(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        rowNumbersByTaskID: [UUID: Int],
        metadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay>,
        rowVisibility: HomeTaskRowVisibility,
        allowsPlannerDrag: Bool
    ) -> some View {
        LazyVStack(alignment: .leading, spacing: taskListTaskRowSpacing()) {
            ForEach(group.tasks, id: \.id) { task in
                macTaskSourceRow(
                    for: task,
                    rowNumber: rowNumbersByTaskID[task.taskID] ?? 1,
                    includeMarkDone: section.includeMarkDone,
                    moveContext: group.moveContext
                        ?? (group.usesSectionMoveContext ? section.moveContext : nil),
                    metadataPresenter: metadataPresenter,
                    rowVisibility: rowVisibility,
                    showsPlannedTodayLabel: presentation.showsPlannedTodayLabel(
                        for: task.taskID,
                        in: section
                    ),
                    searchResultLocationTitle: presentation.searchResultLocationTitle(
                        for: task.taskID,
                        in: section
                    ),
                    allowsPlannerDrag: allowsPlannerDrag
                )
            }
        }
    }

    private func taskListTaskRowSpacing() -> CGFloat {
        5
    }

    private var taskListSearchRestoreTransition: AnyTransition {
        isMacSearchSidebarRestoreInProgress
            ? .identity
            : .opacity.combined(with: .move(edge: .top))
    }

    var macTaskSourceListScrollContainerIdentity: MacTaskSourceListScrollContainerIdentity {
        isMacSearchSidebarRevealActive
            ? .searchReveal
            : .normal(macSearchSidebarRestoreScrollRequestID)
    }

    func taskListGroupUsesSectionSurface(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> Bool {
        group.title != nil
            && (group.kind == .custom
                || group.kind == .tag
                || group.kind == .untagged
                || group.kind == .deadlineDate)
    }

}
