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
    var isHighlighted: Bool = false
    var renderedHeight: CGFloat
    var contentLayoutHeight: CGFloat? = nil
    var showsResizeHandles: Bool = true
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
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(neutralFillOpacity))
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(fillOpacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        tint.opacity(strokeOpacity),
                        style: StrokeStyle(lineWidth: strokeWidth, dash: strokeDash)
                    )
            }
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.95), lineWidth: 3)
                        .shadow(color: Color.accentColor.opacity(0.45), radius: 6)
                }
            }
            .overlay(alignment: .leading) {
                if showsActivityStripe {
                    DayPlanActivityStripe(tint: tint, isLiveFocus: isLiveFocus)
                        .frame(width: 9)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if layoutHeight >= 28 {
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
                if showsResizeHandles {
                    DayPlanResizeHandle(
                        edge: .top,
                        isSelected: isSelected,
                        onResizeStarted: onResizeStarted,
                        onResizeChanged: onResizeChanged,
                        onResizeEnded: onResizeEnded
                    )
                }
            }
            .overlay(alignment: .bottom) {
                if showsResizeHandles {
                    DayPlanResizeHandle(
                        edge: .bottom,
                        isSelected: isSelected,
                        onResizeStarted: onResizeStarted,
                        onResizeChanged: onResizeChanged,
                        onResizeEnded: onResizeEnded
                    )
                }
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

    private var cardContent: some View {
        DayPlanBlockCardContent(
            block: block,
            tint: tint,
            displayDurationMinutes: displayDurationMinutes,
            layoutHeight: layoutHeight,
            selectedDate: selectedDate,
            calendar: calendar
        )
    }

    private var contentInsets: EdgeInsets {
        let activityLeadingPadding: CGFloat = showsActivityStripe ? 8 : 0
        let statusTrailingPadding: CGFloat = showsStatusIcon ? 18 : 0

        if layoutHeight < 36 {
            return EdgeInsets(
                top: 1,
                leading: 6 + activityLeadingPadding,
                bottom: 1,
                trailing: 6 + statusTrailingPadding
            )
        } else if layoutHeight < 48 {
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
        true
    }

    private var showsStatusIcon: Bool {
        layoutHeight >= 28 && (isAutomatic || isLiveFocus || isSprintFocus || isEvent || isSleep || isAway)
    }

    private var layoutHeight: CGFloat {
        contentLayoutHeight ?? renderedHeight
    }

    private var fillOpacity: Double {
        if isAutomatic {
            return 0.035
        }
        if isLiveFocus {
            return 0.08
        }
        if isSprintFocus {
            return sprintFocusIsActive ? 0.08 : 0.06
        }
        if isEvent {
            return 0.035
        }
        if isSleep {
            return isSelected ? 0.07 : 0.045
        }
        if isAway {
            return 0.045
        }
        return isSelected ? 0.075 : 0.045
    }

    private var neutralFillOpacity: Double {
        if isSelected || isHighlighted {
            return 0.105
        }
        if isLiveFocus || isSprintFocus || isSleep || isAway {
            return 0.085
        }
        return 0.07
    }

    private var strokeOpacity: Double {
        if isAutomatic {
            return 0.55
        }
        if isLiveFocus {
            return 0.75
        }
        if isSprintFocus {
            return sprintFocusIsActive ? 0.75 : 0.62
        }
        if isEvent {
            return 0.50
        }
        if isSleep {
            return isSelected ? 0.72 : 0.56
        }
        if isAway {
            return 0.52
        }
        return isSelected ? 0.66 : 0.28
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
        case .fulfilled:
            return "checkmark.circle"
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
        case .fulfilled:
            return "Automatically shown from linked task fulfillment"
        case .missed:
            return "Automatically shown from missed timeline activity"
        case .canceled:
            return "Automatically shown from canceled timeline activity"
        }
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
