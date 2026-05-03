import Foundation
import SwiftUI

struct DayPlanBlockCard: View {
    var block: DayPlanBlock
    var tint: Color
    var isSelected: Bool
    var renderedHeight: CGFloat
    var selectedDate: Date
    var calendar: Calendar
    var onSelect: () -> Void
    var onDelete: () -> Void
    var onResizeStarted: () -> Void
    var onResizeChanged: (DayPlanResizeEdge, CGFloat) -> Void
    var onResizeEnded: () -> Void
    var onDragProvider: () -> NSItemProvider

    var body: some View {
        Button(action: onSelect) {
            cardContent
                .padding(contentInsets)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(isSelected ? 0.22 : 0.14))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(tint.opacity(isSelected ? 0.75 : 0.35), lineWidth: isSelected ? 2 : 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
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
        if renderedHeight < 36 {
            EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6)
        } else if renderedHeight < 48 {
            EdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7)
        } else {
            EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        }
    }

    private var rangeText: String {
        let start = DayPlanFormatting.timeText(for: block.startMinute, on: selectedDate, calendar: calendar)
        let end = DayPlanFormatting.timeText(for: block.endMinute, on: selectedDate, calendar: calendar)
        let duration = DayPlanFormatting.durationText(block.durationMinutes)
        return "\(start)-\(end)  \(duration)"
    }
}
