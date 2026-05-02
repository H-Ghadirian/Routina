import ComposableArchitecture
import SwiftUI

extension HomeTCAView {
    @ViewBuilder
    func platformListOfSortedTasksView(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> some View {
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
        } else if macHomeDetailMode == .planner {
            plannerTaskSourceList(presentation)
        } else {
            List(selection: macSidebarSelectionBinding) {
                ForEach(presentation.sections) { section in
                    Section(section.title) {
                        ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                            routineNavigationRow(
                                for: task,
                                rowNumber: section.rowNumber(forTaskAt: index),
                                includeMarkDone: section.includeMarkDone,
                                moveContext: section.moveContext
                            )
                        }
                        .onDelete { offsets in
                            deleteTasks(at: offsets, from: section.tasks)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationDestination(for: UUID.self) { taskID in
                taskDetailDestination(taskID: taskID)
            }
        }
    }

    func platformRoutineRow(for task: HomeFeature.RoutineDisplay, rowNumber: Int) -> some View {
        let metadataText = rowMetadataText(for: task)

        return HStack(alignment: .center, spacing: 12) {
            Text("\(rowNumber)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: sidebarRowNumberMinWidth, alignment: .trailing)

            if let color = task.color.swiftUIColor {
                Capsule(style: .continuous)
                    .fill(color)
                    .frame(width: 3, height: 28)
                    .accessibilityHidden(true)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(rowIconBackgroundColor(for: task))
                Text(task.emoji)
                    .font(.title3)
                if task.hasImage {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "photo.fill")
                                .font(.caption2)
                                .foregroundStyle(.primary)
                                .padding(4)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
                    .padding(2)
                }
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(task.name)
                        .font(.headline)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Spacer(minLength: 8)

                    statusBadge(for: task)
                }

                if let metadataText {
                    Text(metadataText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !task.tags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(task.tags, id: \.self) { tag in
                            sidebarTagChip(tag)
                        }
                    }
                    .lineLimit(1)
                }

                if !task.goalTitles.isEmpty {
                    HStack(spacing: 8) {
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

            Image(systemName: "line.3.horizontal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 30)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }

    private func tagColor(for tag: String) -> Color? {
        Color(routineTagHex: RoutineTagColors.colorHex(for: tag, in: appSettingsClient.tagColors()))
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
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.14))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 0.5)
            )
    }

    private func taskDragPreview(for task: HomeFeature.RoutineDisplay) -> some View {
        HStack(spacing: 8) {
            Text(task.emoji)
                .font(.body)

            Text(task.name)
                .font(.body.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThickMaterial)
        )
    }

    private func plannerTaskSourceList(
        _ presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    ) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10, pinnedViews: []) {
                ForEach(presentation.sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)

                        ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                            plannerTaskSourceRow(
                                for: task,
                                rowNumber: section.rowNumber(forTaskAt: index),
                                includeMarkDone: section.includeMarkDone,
                                moveContext: section.moveContext
                            )
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    private func plannerTaskSourceRow(
        for task: HomeFeature.RoutineDisplay,
        rowNumber: Int,
        includeMarkDone: Bool,
        moveContext: HomeTaskListMoveContext?
    ) -> some View {
        routineRow(for: task, rowNumber: rowNumber)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(plannerTaskSourceRowBackground(for: task))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(plannerTaskSourceRowStroke(for: task), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                store.send(.macSidebarSelectionChanged(.task(task.taskID)))
            }
            .draggable(task.taskID.uuidString) {
                taskDragPreview(for: task)
            }
            .contextMenu {
                routineContextMenu(
                    for: task,
                    includeMarkDone: includeMarkDone,
                    moveContext: moveContext
                )
            }
            .help("Drag to place this task on the planner")
    }

    private func plannerTaskSourceRowBackground(for task: HomeFeature.RoutineDisplay) -> Color {
        if store.selectedTaskID == task.taskID {
            return Color.accentColor.opacity(0.18)
        }
        return Color.secondary.opacity(0.08)
    }

    private func plannerTaskSourceRowStroke(for task: HomeFeature.RoutineDisplay) -> Color {
        if store.selectedTaskID == task.taskID {
            return Color.accentColor.opacity(0.55)
        }
        return Color.primary.opacity(0.06)
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
