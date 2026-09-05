import Foundation
import SwiftUI

struct DayPlanBlockCardContent: View {
    let block: DayPlanBlock
    let tint: Color
    let displayDurationMinutes: Int?
    let layoutHeight: CGFloat
    let selectedDate: Date
    let calendar: Calendar

    @ViewBuilder
    var body: some View {
        if layoutHeight < 36 {
            tinyContent
        } else if layoutHeight < 48 {
            shortContent
        } else if layoutHeight < 74 {
            compactContent
        } else {
            largeContent
        }
    }

    private var tinyContent: some View {
        // Preserve the original leading icon position while progressively
        // removing lower-priority fields when the card cannot fit them.
        ViewThatFits(in: .horizontal) {
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
            .fixedSize(horizontal: true, vertical: false)

            HStack(spacing: 5) {
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
            .fixedSize(horizontal: true, vertical: false)

            titleOnlyContent(font: .caption2.weight(.semibold))
        }
    }

    private var shortContent: some View {
        ViewThatFits(in: .horizontal) {
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
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 1) {
                Text(block.titleSnapshot)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Text(rangeText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)

            titleOnlyContent(font: .caption.weight(.semibold))
        }
    }

    private var compactContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 6) {
                miniIcon
                    .padding(.top, 1)

                textStack(
                    titleFont: .caption.weight(.semibold),
                    rangeFont: .caption2
                )

                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: true, vertical: false)

            textStack(
                titleFont: .caption.weight(.semibold),
                rangeFont: .caption2
            )
            .fixedSize(horizontal: true, vertical: false)

            titleOnlyContent(font: .caption.weight(.semibold), lineLimit: 2)
        }
    }

    private var largeContent: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 8) {
                DayPlanTaskAvatar(emoji: block.emojiSnapshot, tint: tint)
                    .frame(width: 28, height: 28)

                textStack(
                    titleFont: .subheadline.weight(.semibold),
                    rangeFont: .caption
                )

                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: true, vertical: false)

            textStack(
                titleFont: .subheadline.weight(.semibold),
                rangeFont: .caption
            )
            .fixedSize(horizontal: true, vertical: false)

            titleOnlyContent(font: .subheadline.weight(.semibold), lineLimit: 2)
        }
    }

    private func titleOnlyContent(font: Font, lineLimit: Int = 1) -> some View {
        Text(block.titleSnapshot)
            .font(font)
            .foregroundStyle(.primary)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.82)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func textStack(titleFont: Font, rangeFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(block.titleSnapshot)
                .font(titleFont)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)

            Text(rangeText)
                .font(rangeFont)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
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

    private var effectiveDurationMinutes: Int {
        displayDurationMinutes ?? block.durationMinutes
    }

    private var effectiveEndMinute: Int {
        min(DayPlanBlock.minutesPerDay, block.startMinute + effectiveDurationMinutes)
    }

    private var rangeText: String {
        let start = DayPlanFormatting.timeText(
            for: block.startMinute,
            on: selectedDate,
            calendar: calendar
        )
        let end = DayPlanFormatting.timeText(
            for: effectiveEndMinute,
            on: selectedDate,
            calendar: calendar
        )
        let duration = DayPlanFormatting.durationText(effectiveDurationMinutes)
        return "\(start)-\(end)  \(duration)"
    }
}
