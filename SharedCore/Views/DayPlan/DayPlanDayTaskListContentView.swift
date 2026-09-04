import SwiftUI
import UniformTypeIdentifiers

struct DayPlanDayTaskListContentView: View {
    let items: [DayPlanDayTaskListItem]
    let taskTint: (UUID) -> Color
    let date: Date
    let calendar: Calendar
    let isTaskOpenable: (UUID) -> Bool
    let onOpenTaskDetails: (DayPlanDayTaskListItem, Date) -> Void
    var onCompletePlannedDayTask: ((DayPlanDayTaskListItem, Date) -> Void)?
    let onConfirmAssumedDayTask: (DayPlanDayTaskListItem, Date) -> Void
    let onMarkAssumedDayTaskMissed: (DayPlanDayTaskListItem, Date) -> Void
    var onDragProvider: ((DayPlanDayTaskListItem) -> NSItemProvider)?
    var availableRowWidth: CGFloat?
    var sectionSpacing: CGFloat = 14
    var plannedTasksSectionCollapsed: Binding<Bool>?
    var assumedDoneSectionCollapsed: Binding<Bool>?
    var confirmedAssumedDoneSectionCollapsed: Binding<Bool>?
    var doneSectionCollapsed: Binding<Bool>?
    var separatesConfirmedAssumedDone = false
    @AppStorage(
        UserDefaultStringValueKey.appSettingDayPlanCalendarListRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) private var rowHiddenFieldsRawValue = ""

    var body: some View {
        LazyVStack(alignment: .leading, spacing: sectionSpacing) {
            ForEach(displayedSections, id: \.self) { section in
                let sectionItems = items(in: section)
                if !sectionItems.isEmpty {
                    DayPlanDayTaskListContentSectionView(
                        title: section.title,
                        count: sectionItems.count,
                        items: sectionItems,
                        taskTint: taskTint,
                        date: date,
                        calendar: calendar,
                        isTaskOpenable: isTaskOpenable,
                        onOpenTaskDetails: onOpenTaskDetails,
                        onCompletePlannedDayTask: onCompletePlannedDayTask,
                        onConfirmAssumedDayTask: onConfirmAssumedDayTask,
                        onMarkAssumedDayTaskMissed: onMarkAssumedDayTaskMissed,
                        onDragProvider: onDragProvider,
                        availableRowWidth: availableRowWidth,
                        rowVisibility: rowVisibility,
                        isCollapsed: collapsedState(for: section)
                    )
                }
            }
        }
    }

    private func items(in section: DayPlanDayTaskListItem.Section) -> [DayPlanDayTaskListItem] {
        items.filter { displayedSection(for: $0) == section }
    }

    private var displayedSections: [DayPlanDayTaskListItem.Section] {
        separatesConfirmedAssumedDone
            ? DayPlanDayTaskListItem.Section.allCases
            : [.planned, .assumedDone, .done]
    }

    private func displayedSection(
        for item: DayPlanDayTaskListItem
    ) -> DayPlanDayTaskListItem.Section {
        if !separatesConfirmedAssumedDone && item.section == .confirmedAssumedDone {
            return .done
        }
        return item.section
    }

    private var rowVisibility: DayPlanCalendarListRowVisibility {
        DayPlanCalendarListRowVisibility(storageRawValue: rowHiddenFieldsRawValue)
    }

    private func collapsedState(
        for section: DayPlanDayTaskListItem.Section
    ) -> Binding<Bool>? {
        switch section {
        case .planned:
            plannedTasksSectionCollapsed
        case .assumedDone:
            assumedDoneSectionCollapsed
        case .confirmedAssumedDone:
            confirmedAssumedDoneSectionCollapsed
        case .done:
            doneSectionCollapsed
        }
    }
}

private struct DayPlanDayTaskListContentSectionView: View {
    let title: String
    let count: Int
    let items: [DayPlanDayTaskListItem]
    let taskTint: (UUID) -> Color
    let date: Date
    let calendar: Calendar
    let isTaskOpenable: (UUID) -> Bool
    let onOpenTaskDetails: (DayPlanDayTaskListItem, Date) -> Void
    let onCompletePlannedDayTask: ((DayPlanDayTaskListItem, Date) -> Void)?
    let onConfirmAssumedDayTask: (DayPlanDayTaskListItem, Date) -> Void
    let onMarkAssumedDayTaskMissed: (DayPlanDayTaskListItem, Date) -> Void
    let onDragProvider: ((DayPlanDayTaskListItem) -> NSItemProvider)?
    let availableRowWidth: CGFloat?
    let rowVisibility: DayPlanCalendarListRowVisibility
    let isCollapsed: Binding<Bool>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let isCollapsed {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isCollapsed.wrappedValue.toggle()
                    }
                } label: {
                    sectionHeader(isCollapsed: isCollapsed.wrappedValue)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel("\(title), \(count) tasks")
                .accessibilityValue(isCollapsed.wrappedValue ? "Collapsed" : "Expanded")
            } else {
                sectionHeader(isCollapsed: nil)
            }

            if isCollapsed?.wrappedValue != true {
                ForEach(items) { item in
                    DayPlanDayTaskListContentRow(
                        item: item,
                        tint: taskTint(item.taskID),
                        date: date,
                        calendar: calendar,
                        isOpenable: isTaskOpenable(item.taskID),
                        onOpenTaskDetails: onOpenTaskDetails,
                        onCompletePlannedDayTask: onCompletePlannedDayTask,
                        onConfirmAssumedDayTask: onConfirmAssumedDayTask,
                        onMarkAssumedDayTaskMissed: onMarkAssumedDayTaskMissed,
                        onDragProvider: onDragProvider,
                        availableRowWidth: availableRowWidth,
                        rowVisibility: rowVisibility
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(isCollapsed: Bool?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let isCollapsed {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                    .frame(width: 10)
            }

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("\(count)")
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DayPlanDayTaskListContentRow: View {
    let item: DayPlanDayTaskListItem
    let tint: Color
    let date: Date
    let calendar: Calendar
    let isOpenable: Bool
    let onOpenTaskDetails: (DayPlanDayTaskListItem, Date) -> Void
    let onCompletePlannedDayTask: ((DayPlanDayTaskListItem, Date) -> Void)?
    let onConfirmAssumedDayTask: (DayPlanDayTaskListItem, Date) -> Void
    let onMarkAssumedDayTaskMissed: (DayPlanDayTaskListItem, Date) -> Void
    let onDragProvider: ((DayPlanDayTaskListItem) -> NSItemProvider)?
    let availableRowWidth: CGFloat?
    let rowVisibility: DayPlanCalendarListRowVisibility

    @State private var isHovered = false

    var body: some View {
        Group {
            if isOpenable && !hasInlineActions {
                Button {
                    onOpenTaskDetails(item, date)
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .help("Open \(item.title)")
                .onHover { isHovered = $0 }
            } else {
                rowContent
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onTapGesture {
                        if isOpenable {
                            onOpenTaskDetails(item, date)
                        }
                    }
                    .help(isOpenable ? "Open \(item.title)" : "")
                    .onHover { isHovered = $0 }
            }
        }
        .dayPlanDayTaskDrag(dragProvider)
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 10) {
            if showsAvatar {
                DayPlanTaskAvatar(emoji: item.emoji, tint: tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if rowVisibility.shows(.placement) {
                    Label(placementText, systemImage: placementSystemImage)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Spacer(minLength: 6)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassCard(
            cornerRadius: 8,
            tint: rowVisibility.shows(.rowColor) ? tint : .secondary,
            tintOpacity: rowVisibility.shows(.rowColor) ? 0.08 : 0.05,
            interactive: isOpenable
        )
        .overlay(alignment: .trailing) {
            if hasInlineActions {
                inlineResolutionActions
                    .padding(.trailing, 8)
            }
        }
    }

    private var hasInlineActions: Bool {
        if item.section == .assumedDone {
            return true
        }
        return item.section == .planned
            && item.plannedCompletionDate != nil
            && onCompletePlannedDayTask != nil
    }

    private var showsAvatar: Bool {
        rowVisibility.shows(.icon)
            && DayPlanWeekCalendarSizing.showsDayTaskListAvatar(rowWidth: availableRowWidth)
    }

    private var dragProvider: (() -> NSItemProvider)? {
        guard item.taskID != FocusSession.unassignedTaskID else { return nil }
        guard let onDragProvider else { return nil }
        return {
            onDragProvider(item)
        }
    }

    @ViewBuilder
    private var inlineResolutionActions: some View {
        if item.section == .planned {
            resolutionActionsContainer {
                resolutionButton(
                    systemImage: "checkmark",
                    tint: .green,
                    accessibilityLabel: "Mark done"
                ) {
                    onCompletePlannedDayTask?(item, date)
                }
            }
        } else {
            resolutionActionsContainer {
                HStack(spacing: 5) {
                    resolutionButton(
                        systemImage: "checkmark",
                        tint: .green,
                        accessibilityLabel: "I did it"
                    ) {
                        onConfirmAssumedDayTask(item, date)
                    }

                    resolutionButton(
                        systemImage: "xmark",
                        tint: .red,
                        accessibilityLabel: "I didn't do it"
                    ) {
                        onMarkAssumedDayTaskMissed(item, date)
                    }
                }
            }
        }
    }

    private func resolutionActionsContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 5) {
            content()
        }
        .padding(4)
        .routinaGlassPill(tint: .secondary, tintOpacity: 0.12)
        .opacity(isHovered ? 1 : 0)
        .allowsHitTesting(isHovered)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private func resolutionButton(
        systemImage: String,
        tint: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(tint, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .help(accessibilityLabel)
        .contentShape(Circle())
    }

    private var placementText: String {
        switch item.placement {
        case .anyTime:
            return "Any time"
        case .allDay:
            return "All day"
        case let .durationOnly(durationMinutes):
            return "No specific time · \(DayPlanFormatting.durationText(durationMinutes))"
        case let .timed(startMinute, durationMinutes):
            let endMinute = startMinute + durationMinutes
            let startText = DayPlanFormatting.timeText(for: startMinute, on: date, calendar: calendar)
            let endText = DayPlanFormatting.timeText(for: endMinute, on: date, calendar: calendar)
            return "\(startText) - \(endText), \(DayPlanFormatting.durationText(durationMinutes))"
        }
    }

    private var placementSystemImage: String {
        switch item.placement {
        case .anyTime:
            return "clock.badge.questionmark"
        case .allDay:
            return "sun.max"
        case .durationOnly:
            return "clock.badge.questionmark"
        case .timed:
            return "clock"
        }
    }
}

private extension View {
    @ViewBuilder
    func dayPlanDayTaskDrag(_ provider: (() -> NSItemProvider)?) -> some View {
        if let provider {
            onDrag(provider)
        } else {
            self
        }
    }
}
