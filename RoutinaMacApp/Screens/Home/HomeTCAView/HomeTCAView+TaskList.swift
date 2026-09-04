import ComposableArchitecture
import AppKit
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
                let searchCreateAction: (() -> Void)? =
                    canCreateTaskFromToolbarSearch
                    ? { openAddTaskFromToolbarSearch(searchTextBinding.wrappedValue) }
                    : nil

                emptyStateView(
                    title: emptyState.title,
                    message: emptyState.message,
                    systemImage: emptyState.systemImage,
                    actionTitle: "Create task",
                    action: searchCreateAction
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
        rowVisibility suppliedRowVisibility: HomeTaskRowVisibility? = nil,
        showsPlannedTodayLabel: Bool = false,
        searchResultLocationTitle: String? = nil
    ) -> some View {
        let metadataText = metadataPresenter.rowMetadataText(for: task)
        let rowVisibility = suppliedRowVisibility ?? taskRowVisibility
        let statusBadgeStyle =
            rowVisibility.shows(.statusBadge)
            ? taskListStatusBadgeStyle(for: task, metadataPresenter: metadataPresenter)
            : nil
        let secondaryLabels = taskListRowLabelItems(
            for: task,
            showsTags: rowVisibility.shows(.tags),
            showsFlags: rowVisibility.shows(.flags),
            showsGoals: isGoalsTabEnabled && rowVisibility.shows(.goals),
            showsPlannedTodayLabel: showsPlannedTodayLabel
        )
        let showsSecondaryLabels =
            statusBadgeStyle != nil
            || !secondaryLabels.isEmpty

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
                Text(task.name)
                    .font(.headline)
                    .lineLimit(rowVisibility.allowsMultilineTitles ? nil : 1)
                    .fixedSize(
                        horizontal: false,
                        vertical: rowVisibility.allowsMultilineTitles
                    )
                    .layoutPriority(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let searchResultLocationTitle {
                    Label(searchResultLocationTitle, systemImage: "folder.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if showsSecondaryLabels {
                    HomeMacTaskRowSecondaryLabels(
                        labels: secondaryLabels,
                        statusBadgeStyle: statusBadgeStyle,
                        allowsMultilineDetails: rowVisibility.allowsMultilineDetails,
                        tagTint: tagTint(for:)
                    )
                }

                if let metadataText {
                    Text(metadataText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    func assumedDoneHoverActions(
        for task: HomeFeature.RoutineDisplay,
        isVisible: Bool
    ) -> some View {
        if task.isAssumedDoneToday {
            HStack(spacing: 6) {
                assumedDoneHoverButton(
                    systemImage: "checkmark",
                    tint: .green,
                    accessibilityLabel: "I did it"
                ) {
                    confirmAssumedTaskDone(task.taskID)
                }

                assumedDoneHoverButton(
                    systemImage: "xmark",
                    tint: .red,
                    accessibilityLabel: "I didn't do it"
                ) {
                    markAssumedTaskMissed(task.taskID)
                }
            }
            .padding(4)
            .routinaGlassPill(tint: .secondary, tintOpacity: 0.12)
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(isVisible)
            .animation(.easeInOut(duration: 0.12), value: isVisible)
        }
    }

    private func assumedDoneHoverButton(
        systemImage: String,
        tint: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(tint, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .help(accessibilityLabel)
        .contentShape(Circle())
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

    func tagTint(for tag: String) -> Color {
        if let color = tagColor(for: tag) {
            return color
        }
        return .secondary
    }

    private func taskListRowLabelItems(
        for task: HomeFeature.RoutineDisplay,
        showsTags: Bool,
        showsFlags: Bool,
        showsGoals: Bool,
        showsPlannedTodayLabel: Bool
    ) -> [HomeMacTaskRowSecondaryLabel] {
        var labels: [HomeMacTaskRowSecondaryLabel] = []
        if showsPlannedTodayLabel {
            labels.append(.plannedToday)
        }
        if showsTags {
            labels.append(contentsOf: task.tags.map(HomeMacTaskRowSecondaryLabel.tag))
        }
        if showsFlags {
            labels.append(contentsOf: task.flags.map(HomeMacTaskRowSecondaryLabel.flag))
        }
        if showsGoals {
            labels.append(contentsOf: task.goalTitles.map(HomeMacTaskRowSecondaryLabel.goal))
        }
        return labels
    }

    func macTaskSourceList(
        _ presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        allowsPlannerDrag: Bool
    ) -> some View {
        let collapsedTagIDs = collapsedTagTaskListSectionIDs
        let visibleTaskIDs = visibleTaskIDs(in: presentation, collapsedTagIDs: collapsedTagIDs)
        let rowNumbersByTaskID = rowNumbersByTaskID(for: visibleTaskIDs)
        let metadataPresenter = routineMetadataPresenter
        let rowVisibility = taskRowVisibility

        return ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    Color.clear
                        .frame(height: 1)
                        .id(MacTaskSourceListScrollAnchor.top)

                    ForEach(presentation.sections) { section in
                        taskListSectionView(
                            for: section,
                            in: presentation,
                            collapsedTagIDs: collapsedTagIDs,
                            rowNumbersByTaskID: rowNumbersByTaskID,
                            metadataPresenter: metadataPresenter,
                            rowVisibility: rowVisibility,
                            allowsPlannerDrag: allowsPlannerDrag
                        )
                        .padding(.top, taskListTopLevelSectionSpacing(before: section, in: presentation))
                        .id(MacTaskSourceListScrollAnchor.section(section.id))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .background(
                    ZStack {
                        MacTaskSourceListScrollResetView(
                            requestID: macSearchSidebarRestoreScrollRequestID
                        )
                        MacTaskSourceListScrollViewResolver(
                            reference: macTaskSourceListScrollViewReference
                        )
                    }
                )
            }
            .id(macTaskSourceListScrollContainerIdentity)
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
            .onChange(of: macSearchSidebarRestoreScrollRequestID) { _, _ in
                restoreMacTaskSourceListTopPosition(with: scrollProxy)
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

}
