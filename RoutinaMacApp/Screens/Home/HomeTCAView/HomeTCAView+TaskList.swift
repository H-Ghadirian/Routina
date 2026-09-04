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
        let showsSecondaryLabels =
            statusBadgeStyle != nil
            || showsPlannedTodayLabel
            || rowVisibility.shows(.tags) && !task.tags.isEmpty
            || rowVisibility.shows(.flags) && !task.flags.isEmpty
            || isGoalsTabEnabled && rowVisibility.shows(.goals) && !task.goalTitles.isEmpty

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
                    HStack(alignment: .center, spacing: 6) {
                        taskListRowLabels(
                            for: task,
                            showsTags: rowVisibility.shows(.tags),
                            showsFlags: rowVisibility.shows(.flags),
                            showsGoals: isGoalsTabEnabled && rowVisibility.shows(.goals),
                            showsPlannedTodayLabel: showsPlannedTodayLabel
                        )

                        Spacer(minLength: 6)

                        if let statusBadgeStyle {
                            HomeStatusBadgeView(style: statusBadgeStyle)
                        }
                    }
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

    private func sidebarFlagChip(_ flag: String) -> some View {
        Label(flag, systemImage: "flag.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.orange)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .routinaGlassPill(tint: .orange, tintOpacity: 0.14)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.orange.opacity(0.28), lineWidth: 0.5)
            )
    }

    private func taskListRowLabels(
        for task: HomeFeature.RoutineDisplay,
        showsTags: Bool,
        showsFlags: Bool,
        showsGoals: Bool,
        showsPlannedTodayLabel: Bool
    ) -> some View {
        HStack(spacing: 6) {
            if showsPlannedTodayLabel {
                Label("Planned today", systemImage: "calendar")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .routinaGlassPill(tint: .accentColor, tintOpacity: 0.14)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.accentColor.opacity(0.30), lineWidth: 0.5)
                    )
                    .accessibilityLabel("Planned for today")
            }

            if showsTags {
                ForEach(task.tags, id: \.self) { tag in
                    sidebarTagChip(tag)
                }
            }

            if showsFlags {
                ForEach(task.flags, id: \.self) { flag in
                    sidebarFlagChip(flag)
                }
            }

            if showsGoals {
                ForEach(task.goalTitles, id: \.self) { goal in
                    Label(goal, systemImage: "target")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .lineLimit(1)
        .frame(minHeight: 20, alignment: .leading)
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
