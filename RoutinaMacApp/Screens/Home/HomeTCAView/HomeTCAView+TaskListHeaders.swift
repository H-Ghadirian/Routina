import ComposableArchitecture
import AppKit
import SwiftUI

extension HomeTCAView {
    @ViewBuilder
    func taskListInnerGroupHeader(
        _ title: String,
        count: Int,
        group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        collapsedTagIDs: Set<String>
    ) -> some View {
        if group.isCollapsible {
            let isExpanded = taskListGroupIsExpanded(group, collapsedTagIDs: collapsedTagIDs)
            let header = Button {
                toggleTaskListGroup(group)
            } label: {
                if taskListGroupUsesSectionSurface(group) {
                    taskListInnerGroupSectionHeaderContent(
                        title,
                        count: count,
                        group: group,
                        isExpanded: isExpanded
                    )
                } else {
                    taskListInnerGroupHeaderLabel(title, count: count, isExpanded: isExpanded)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if taskListGroupHasContextMenu(group) {
                header
                    .routinaMacContextMenu {
                        taskListGroupNativeContextMenu(for: group)
                    }
            } else {
                header
            }
        } else {
            let header = taskListInnerGroupHeaderLabel(title, count: count, isExpanded: nil)

            if taskListGroupHasContextMenu(group) {
                header
                    .routinaMacContextMenu {
                        taskListGroupNativeContextMenu(for: group)
                    }
            } else {
                header
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

    @ViewBuilder
    func taskListSectionHeader(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    ) -> some View {
        let header = HStack(spacing: 6) {
            Text(section.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)

        if taskListSectionHasContextMenu(section) {
            header
                .routinaMacContextMenu {
                    taskListSectionNativeContextMenu(for: section, in: presentation)
                }
        } else {
            header
        }
    }

    func taskListSectionHeaderContent(
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

            if section.isPaused {
                Text("Paused")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .routinaGlassPill(tint: .teal, tintOpacity: 0.14)
            }

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

    func taskListSectionHeaderTintOpacity(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        isExpanded _: Bool
    ) -> Double {
        switch section.kind {
        case .tag:
            return 0.12
        case .custom, .future:
            return 0.07
        case .plannedToday, .plannedTomorrow, .daily:
            return 0.08
        case .untagged, .archived:
            return 0.06
        case .pinned, .regular, .deadlineDate, .away:
            return 0.07
        }
    }

    func taskListSectionHeaderStrokeOpacity(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        isExpanded _: Bool
    ) -> Double {
        switch section.kind {
        case .tag:
            return 0.30
        case .custom, .future:
            return 0.20
        case .plannedToday, .plannedTomorrow, .daily:
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
        case .plannedTomorrow:
            return "calendar.badge.clock"
        case .custom:
            return "rectangle.stack.fill"
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

    func taskListSectionHeaderTint(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> Color {
        switch section.kind {
        case .plannedToday:
            return .accentColor
        case .plannedTomorrow:
            return .blue
        case .custom:
            return Color(routineTagHex: section.colorHex) ?? .secondary
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

    func taskListGroupHeaderTintOpacity(
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> Double {
        switch group.kind {
        case .tag:
            return 0.12
        case .untagged:
            return 0.06
        case .plannedToday, .plannedTomorrow, .custom, .daily, .future, .regular, .deadlineDate, .pinned, .away, .archived:
            return 0.07
        }
    }

    func taskListGroupHeaderStrokeOpacity(
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> Double {
        switch group.kind {
        case .tag:
            return 0.30
        case .untagged:
            return 0.18
        case .plannedToday, .plannedTomorrow, .custom, .daily, .future, .regular, .deadlineDate, .pinned, .away, .archived:
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
        case .plannedTomorrow:
            return "calendar.badge.clock"
        case .custom:
            return "rectangle.stack.fill"
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

    func taskListGroupHeaderTint(
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
        case .plannedTomorrow:
            return .blue
        case .custom:
            return .secondary
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

}
