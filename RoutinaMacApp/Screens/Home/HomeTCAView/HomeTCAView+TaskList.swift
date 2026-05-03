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
        } else {
            macTaskSourceList(
                presentation,
                allowsPlannerDrag: macHomeDetailMode == .planner
            )
        }
    }

    func platformRoutineRow(for task: HomeFeature.RoutineDisplay, rowNumber: Int) -> some View {
        let metadataText = rowMetadataText(for: task)

        return HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 4) {
                taskIcon(for: task)

                Text("\(rowNumber)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(width: 38)

            VStack(alignment: .leading, spacing: 3) {
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
                    HStack(spacing: 6) {
                        ForEach(task.tags, id: \.self) { tag in
                            sidebarTagChip(tag)
                        }
                    }
                    .lineLimit(1)
                }

                if !task.goalTitles.isEmpty {
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
                            .background(.ultraThinMaterial, in: Circle())
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

    private func macTaskSourceList(
        _ presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>,
        allowsPlannerDrag: Bool
    ) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8, pinnedViews: []) {
                ForEach(presentation.sections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)

                        ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                            macTaskSourceRow(
                                for: task,
                                rowNumber: section.rowNumber(forTaskAt: index),
                                includeMarkDone: section.includeMarkDone,
                                moveContext: section.moveContext,
                                allowsPlannerDrag: allowsPlannerDrag
                            )
                        }
                    }
                }
            }
            .padding(10)
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
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
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
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture {
                store.send(.macSidebarSelectionChanged(.task(task.taskID)))
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
                .onDrag({
                    store.send(.macSidebarSelectionChanged(.task(task.taskID)))
                    return NSItemProvider(object: task.taskID.uuidString as NSString)
                }, preview: {
                    taskDragPreview(for: task)
                })
                .help("Drag to place this task on the planner")
        } else {
            row
        }
    }

    private func macTaskSourceRowBackground(for task: HomeFeature.RoutineDisplay) -> Color {
        if store.selectedTaskID == task.taskID {
            return Color.accentColor.opacity(0.18)
        }
        return Color.secondary.opacity(0.08)
    }

    private func macTaskSourceRowStroke(for task: HomeFeature.RoutineDisplay) -> Color {
        if let color = task.color.swiftUIColor {
            return color.opacity(store.selectedTaskID == task.taskID ? 0.95 : 0.72)
        }
        if store.selectedTaskID == task.taskID {
            return Color.accentColor.opacity(0.55)
        }
        return Color.primary.opacity(0.06)
    }

    private func macTaskSourceRowStrokeWidth(for task: HomeFeature.RoutineDisplay) -> CGFloat {
        task.color.swiftUIColor == nil ? 1 : 1.5
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
