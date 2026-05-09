import Foundation
import SwiftUI

struct DayPlanBlockCard: View {
    enum Style: Equatable {
        case manual
        case automatic(RoutineLogKind)
    }

    var block: DayPlanBlock
    var tint: Color
    var style: Style = .manual
    var isSelected: Bool
    var renderedHeight: CGFloat
    var selectedDate: Date
    var calendar: Calendar
    var onSelect: () -> Void
    var onOpenDetails: () -> Void
    var onDelete: () -> Void
    var onResizeStarted: () -> Void
    var onResizeChanged: (DayPlanResizeEdge, CGFloat) -> Void
    var onResizeEnded: () -> Void
    var onDragProvider: () -> NSItemProvider

    var body: some View {
        if isAutomatic {
            automaticCard
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
                if isAutomatic {
                    DayPlanAutomaticActivityStripe(tint: tint)
                        .frame(width: 9)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if let automaticKind, renderedHeight >= 28 {
                    Image(systemName: automaticIconName(for: automaticKind))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(4)
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
            .help(automaticHelpText)
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

                Text("\(block.durationMinutes)m")
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
        let automaticLeadingPadding: CGFloat = isAutomatic ? 8 : 0
        let automaticTrailingPadding: CGFloat = isAutomatic && renderedHeight >= 28 ? 18 : 0

        if renderedHeight < 36 {
            return EdgeInsets(
                top: 1,
                leading: 6 + automaticLeadingPadding,
                bottom: 1,
                trailing: 6 + automaticTrailingPadding
            )
        } else if renderedHeight < 48 {
            return EdgeInsets(
                top: 2,
                leading: 7 + automaticLeadingPadding,
                bottom: 2,
                trailing: 7 + automaticTrailingPadding
            )
        } else {
            return EdgeInsets(
                top: 8,
                leading: 8 + automaticLeadingPadding,
                bottom: 8,
                trailing: 8 + automaticTrailingPadding
            )
        }
    }

    private var isAutomatic: Bool {
        automaticKind != nil
    }

    private var automaticKind: RoutineLogKind? {
        if case let .automatic(kind) = style {
            return kind
        }
        return nil
    }

    private var fillOpacity: Double {
        isAutomatic ? 0.08 : (isSelected ? 0.22 : 0.14)
    }

    private var strokeOpacity: Double {
        isAutomatic ? 0.72 : (isSelected ? 0.75 : 0.35)
    }

    private var strokeWidth: CGFloat {
        isAutomatic ? 1.5 : (isSelected ? 2 : 1)
    }

    private var strokeDash: [CGFloat] {
        isAutomatic ? [5, 4] : []
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

    private var rangeText: String {
        let start = DayPlanFormatting.timeText(for: block.startMinute, on: selectedDate, calendar: calendar)
        let end = DayPlanFormatting.timeText(for: block.endMinute, on: selectedDate, calendar: calendar)
        let duration = DayPlanFormatting.durationText(block.durationMinutes)
        return "\(start)-\(end)  \(duration)"
    }
}

private struct DayPlanAutomaticActivityStripe: View {
    var tint: Color

    var body: some View {
        Rectangle()
            .fill(tint.opacity(0.14))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(tint.opacity(0.70))
                    .frame(width: 2)
            }
    }
}
