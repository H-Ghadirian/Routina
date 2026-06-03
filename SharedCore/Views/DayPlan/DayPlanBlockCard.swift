import Foundation
import SwiftUI

struct DayPlanBlockCard: View {
    enum Style: Equatable {
        case manual
        case automatic(RoutineLogKind)
        case event
        case liveFocus
        case sprintFocus(isActive: Bool, isAllocated: Bool)
        case sleep
        case away
    }

    var block: DayPlanBlock
    var tint: Color
    var style: Style = .manual
    var displayDurationMinutes: Int? = nil
    var isSelected: Bool
    var renderedHeight: CGFloat
    var selectedDate: Date
    var calendar: Calendar
    var onSelect: () -> Void
    var onOpenDetails: () -> Void
    var onDelete: () -> Void
    var onConfirmAutomatic: (() -> Void)? = nil
    var onHideAutomatic: (() -> Void)? = nil
    var onResizeStarted: () -> Void
    var onResizeChanged: (DayPlanResizeEdge, CGFloat) -> Void
    var onResizeEnded: () -> Void
    var onDragProvider: () -> NSItemProvider

    var body: some View {
        if isAutomatic {
            automaticCard
        } else if isLiveFocus {
            liveFocusCard
        } else if isSprintFocus {
            sprintFocusCard
        } else if isEvent {
            eventCard
        } else if isSleep {
            sleepCard
        } else if isAway {
            awayCard
        } else {
            manualCard
        }
    }

    private var baseCard: some View {
        cardContent
            .padding(contentInsets)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(fillOpacity))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        tint.opacity(strokeOpacity),
                        style: StrokeStyle(lineWidth: strokeWidth, dash: strokeDash)
                    )
            }
            .overlay(alignment: .leading) {
                if showsActivityStripe {
                    DayPlanActivityStripe(tint: tint, isLiveFocus: isLiveFocus)
                        .frame(width: 9)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if renderedHeight >= 28 {
                    if let automaticKind {
                        Image(systemName: automaticIconName(for: automaticKind))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(tint)
                            .padding(4)
                    } else if let statusIconName {
                        Image(systemName: statusIconName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(tint)
                            .padding(4)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityAddTraits(.isButton)
    }

    private var manualCard: some View {
        baseCard
            .onTapGesture(count: 2) {
                onOpenDetails()
            }
            .onTapGesture {
                onSelect()
            }
            .onDrag(onDragProvider)
            .overlay(alignment: .top) {
                DayPlanResizeHandle(
                    edge: .top,
                    isSelected: isSelected,
                    onResizeStarted: onResizeStarted,
                    onResizeChanged: onResizeChanged,
                    onResizeEnded: onResizeEnded
                )
            }
            .overlay(alignment: .bottom) {
                DayPlanResizeHandle(
                    edge: .bottom,
                    isSelected: isSelected,
                    onResizeStarted: onResizeStarted,
                    onResizeChanged: onResizeChanged,
                    onResizeEnded: onResizeEnded
                )
            }
            .contextMenu {
                Button("Delete", role: .destructive, action: onDelete)
            }
    }

    private var automaticCard: some View {
        baseCard
            .onTapGesture {
                onOpenDetails()
            }
            .onDrag(onDragProvider)
            .contextMenu {
                if let onConfirmAutomatic {
                    Button {
                        onConfirmAutomatic()
                    } label: {
                        Label("Confirm in Planner", systemImage: "checkmark.circle")
                    }
                }
                if let onHideAutomatic {
                    Button {
                        onHideAutomatic()
                    } label: {
                        Label("Hide from Planner", systemImage: "eye.slash")
                    }
                }
            }
            .help(automaticHelpText)
    }

    private var liveFocusCard: some View {
        baseCard
            .onTapGesture {
                onOpenDetails()
            }
            .help("Focus timer in progress")
    }

    private var sprintFocusCard: some View {
        baseCard
            .onTapGesture {
                if sprintFocusIsAllocated {
                    onOpenDetails()
                }
            }
            .help(sprintFocusHelpText)
    }

    private var eventCard: some View {
        baseCard
            .onTapGesture {
                onOpenDetails()
            }
            .help("Event")
    }

    private var sleepCard: some View {
        baseCard
            .help("Sleep time is blocked")
    }

    private var awayCard: some View {
        baseCard
            .help("Away time is blocked")
    }

    @ViewBuilder
    private var cardContent: some View {
        if renderedHeight < 36 {
            HStack(spacing: 5) {
                miniIcon

                Text(block.titleSnapshot)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text("\(effectiveDurationMinutes)m")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        } else if renderedHeight < 48 {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    miniIcon

                    Text(block.titleSnapshot)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }

                Text(rangeText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                DayPlanTaskAvatar(emoji: block.emojiSnapshot, tint: tint)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(block.titleSnapshot)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(rangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Spacer(minLength: 6)
            }
        }
    }

    private var miniIcon: some View {
        Group {
            if let emoji = CalendarTaskImportSupport.displayEmoji(for: block.emojiSnapshot) {
                Text(emoji)
            } else {
                Image(systemName: "checkmark")
                    .foregroundStyle(tint)
            }
        }
        .font(.caption2.weight(.semibold))
        .frame(width: 13, height: 13)
        .lineLimit(1)
    }

    private var contentInsets: EdgeInsets {
        let activityLeadingPadding: CGFloat = showsActivityStripe ? 8 : 0
        let statusTrailingPadding: CGFloat = showsStatusIcon ? 18 : 0

        if renderedHeight < 36 {
            return EdgeInsets(
                top: 1,
                leading: 6 + activityLeadingPadding,
                bottom: 1,
                trailing: 6 + statusTrailingPadding
            )
        } else if renderedHeight < 48 {
            return EdgeInsets(
                top: 2,
                leading: 7 + activityLeadingPadding,
                bottom: 2,
                trailing: 7 + statusTrailingPadding
            )
        } else {
            return EdgeInsets(
                top: 8,
                leading: 8 + activityLeadingPadding,
                bottom: 8,
                trailing: 8 + statusTrailingPadding
            )
        }
    }

    private var isAutomatic: Bool {
        automaticKind != nil
    }

    private var isLiveFocus: Bool {
        if case .liveFocus = style {
            return true
        }
        return false
    }

    private var isEvent: Bool {
        if case .event = style {
            return true
        }
        return false
    }

    private var isSprintFocus: Bool {
        if case .sprintFocus = style {
            return true
        }
        return false
    }

    private var isSleep: Bool {
        if case .sleep = style {
            return true
        }
        return false
    }

    private var isAway: Bool {
        if case .away = style {
            return true
        }
        return false
    }

    private var automaticKind: RoutineLogKind? {
        if case let .automatic(kind) = style {
            return kind
        }
        return nil
    }

    private var showsActivityStripe: Bool {
        isAutomatic || isLiveFocus || isSprintFocus || isEvent || isSleep || isAway
    }

    private var showsStatusIcon: Bool {
        renderedHeight >= 28 && (isAutomatic || isLiveFocus || isSprintFocus || isEvent || isSleep || isAway)
    }

    private var fillOpacity: Double {
        if isAutomatic {
            return 0.08
        }
        if isLiveFocus {
            return 0.2
        }
        if isSprintFocus {
            return sprintFocusIsActive ? 0.2 : 0.16
        }
        if isEvent {
            return 0.12
        }
        if isSleep {
            return isSelected ? 0.24 : 0.16
        }
        if isAway {
            return 0.16
        }
        return isSelected ? 0.22 : 0.14
    }

    private var strokeOpacity: Double {
        if isAutomatic {
            return 0.72
        }
        if isLiveFocus {
            return 0.85
        }
        if isSprintFocus {
            return sprintFocusIsActive ? 0.85 : 0.78
        }
        if isEvent {
            return 0.78
        }
        if isSleep {
            return isSelected ? 0.95 : 0.78
        }
        if isAway {
            return 0.78
        }
        return isSelected ? 0.75 : 0.35
    }

    private var strokeWidth: CGFloat {
        if isAutomatic {
            return 1.5
        }
        if isLiveFocus {
            return 2
        }
        if isSprintFocus {
            return sprintFocusIsActive ? 2 : 1.5
        }
        if isEvent {
            return 1.5
        }
        if isSleep {
            return isSelected ? 2.5 : 1.5
        }
        if isAway {
            return 1.5
        }
        return isSelected ? 2 : 1
    }

    private var strokeDash: [CGFloat] {
        isAutomatic ? [5, 4] : []
    }

    private var statusIconName: String? {
        if isLiveFocus {
            return "timer.circle.fill"
        }
        if isSprintFocus {
            if sprintFocusIsActive {
                return "timer.circle.fill"
            }
            return sprintFocusIsAllocated ? "checkmark.circle.fill" : "flag.checkered"
        }
        if isEvent {
            return "calendar"
        }
        if isSleep {
            return "bed.double.fill"
        }
        if isAway {
            return "lock.shield.fill"
        }
        return nil
    }

    private var sprintFocusIsActive: Bool {
        if case let .sprintFocus(isActive, _) = style {
            return isActive
        }
        return false
    }

    private var sprintFocusIsAllocated: Bool {
        if case let .sprintFocus(_, isAllocated) = style {
            return isAllocated
        }
        return false
    }

    private var sprintFocusHelpText: String {
        if sprintFocusIsActive {
            return sprintFocusIsAllocated ? "Allocated board focus in progress" : "Board focus timer in progress"
        }
        return sprintFocusIsAllocated ? "Allocated board focus time" : "Board focus time is blocked"
    }

    private func automaticIconName(for kind: RoutineLogKind) -> String {
        switch kind {
        case .completed:
            return "checkmark.circle.fill"
        case .missed:
            return "exclamationmark.triangle.fill"
        case .canceled:
            return "xmark.circle.fill"
        }
    }

    private var automaticHelpText: String {
        guard let automaticKind else { return "Automatically shown from timeline activity" }
        switch automaticKind {
        case .completed:
            return "Automatically shown from completed timeline activity"
        case .missed:
            return "Automatically shown from missed timeline activity"
        case .canceled:
            return "Automatically shown from canceled timeline activity"
        }
    }

    private var effectiveDurationMinutes: Int {
        displayDurationMinutes ?? block.durationMinutes
    }

    private var effectiveEndMinute: Int {
        min(DayPlanBlock.minutesPerDay, block.startMinute + effectiveDurationMinutes)
    }

    private var rangeText: String {
        let start = DayPlanFormatting.timeText(for: block.startMinute, on: selectedDate, calendar: calendar)
        let end = DayPlanFormatting.timeText(for: effectiveEndMinute, on: selectedDate, calendar: calendar)
        let duration = DayPlanFormatting.durationText(effectiveDurationMinutes)
        return "\(start)-\(end)  \(duration)"
    }
}

private struct DayPlanActivityStripe: View {
    var tint: Color
    var isLiveFocus: Bool

    var body: some View {
        Rectangle()
            .fill(tint.opacity(isLiveFocus ? 0.22 : 0.14))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(tint.opacity(isLiveFocus ? 0.9 : 0.70))
                    .frame(width: isLiveFocus ? 3 : 2)
            }
    }
}
