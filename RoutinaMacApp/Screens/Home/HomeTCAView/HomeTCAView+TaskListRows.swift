import ComposableArchitecture
import AppKit
import SwiftUI

extension HomeTCAView {
    func macDayPlanUnplannedCompletedTaskList(for date: Date) -> some View {
        let tasks = dayPlanUnplannedCompletedDisplays(for: date)
        let section = HomeTaskListPresentationSection(
            kind: .regular,
            title: "Timeline on \(date.formatted(date: .abbreviated, time: .omitted))",
            tasks: tasks,
            rowNumberOffset: 0,
            includeMarkDone: false,
            separatesUserCompletedTasks: false,
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
    func macTaskSourceRow(
        for task: HomeFeature.RoutineDisplay,
        rowNumber: Int,
        includeMarkDone: Bool,
        moveContext: HomeTaskListMoveContext?,
        metadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay>,
        rowVisibility: HomeTaskRowVisibility,
        showsPlannedTodayLabel: Bool,
        searchResultLocationTitle: String?,
        allowsPlannerDrag: Bool
    ) -> some View {
        let row = platformRoutineRow(
            for: task,
            rowNumber: rowNumber,
            metadataPresenter: metadataPresenter,
            rowVisibility: rowVisibility,
            showsPlannedTodayLabel: showsPlannedTodayLabel,
            searchResultLocationTitle: searchResultLocationTitle
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
        .overlay(alignment: .trailing) {
            assumedDoneHoverActions(
                for: task,
                isVisible: hoveredAssumedDoneTaskID == task.taskID
            )
            .padding(.trailing, 12)
        }
        .id(task.taskID)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { isHovered in
            hoveredAssumedDoneTaskID = isHovered && task.isAssumedDoneToday ? task.taskID : nil
        }
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

    func handleMacTaskSourceListKeyboardNavigation(
        _ direction: MacTaskSourceListKeyboardDirection,
        visibleTaskIDs: [UUID]
    ) {
        guard
            let taskID = MacTaskSourceListKeyboardNavigation.adjacentTaskID(
                from: store.selectedTaskID,
                direction: direction,
                visibleTaskIDs: visibleTaskIDs
            )
        else { return }

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
        if rowVisibility.shows(.colorBadge) {
            if let color = task.color.swiftUIColor {
                HomeTaskRowColorMarkerShape()
                    .fill(color)
                    .frame(width: 10, height: 18)
                    .padding(.trailing, 18)
                    .accessibilityHidden(true)
            }
        }
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
