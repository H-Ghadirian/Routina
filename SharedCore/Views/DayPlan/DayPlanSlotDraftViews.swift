import SwiftUI

struct DayPlanSlotSidebarPresentation {
    static let width: CGFloat = 400
}

struct DayPlanSelectedSlotDraft: Equatable {
    var date: Date
    var startMinute: Int
    var durationMinutes: Int
}

struct DayPlanSlotDraftBlock: View {
    var date: Date
    var startMinute: Int
    var durationMinutes: Int
    var renderedHeight: CGFloat
    var calendar: Calendar
    var onResizeStarted: () -> Void
    var onResizeChanged: (DayPlanResizeEdge, CGFloat) -> Void
    var onResizeEnded: () -> Void

    private var tint: Color {
        .accentColor
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(tint.opacity(0.88))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Block")
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                    Label(intervalText, systemImage: "clock")
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .overlay(alignment: .top) {
                resizeHandle(edge: .top)
            }
            .overlay(alignment: .bottom) {
                resizeHandle(edge: .bottom)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(.white.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: tint.opacity(0.28), radius: 10, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityLabel("New block, \(intervalText)")
    }

    private var intervalText: String {
        guard
            let startDate = calendar.date(
                byAdding: .minute,
                value: startMinute,
                to: calendar.startOfDay(for: date)
            ),
            let endDate = calendar.date(byAdding: .minute, value: durationMinutes, to: startDate)
        else {
            return
                "\(DayPlanFormatting.timeText(for: startMinute, on: date, calendar: calendar)) - \(DayPlanFormatting.timeText(for: startMinute + durationMinutes, on: date, calendar: calendar))"
        }

        let startText = startDate.formatted(date: .omitted, time: .shortened)
        let endText: String
        if calendar.isDate(endDate, inSameDayAs: startDate) {
            endText = endDate.formatted(date: .omitted, time: .shortened)
        } else {
            endText = endDate.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        }
        return "\(startText) - \(endText)"
    }

    private func resizeHandle(edge: DayPlanResizeEdge) -> some View {
        DayPlanResizeHandle(
            edge: edge,
            isSelected: true,
            hitHeight: resizeHandleHitHeight,
            outwardOverlap: resizeHandleHitHeight >= 16 ? 6 : 0,
            onResizeStarted: onResizeStarted,
            onResizeChanged: onResizeChanged,
            onResizeEnded: onResizeEnded
        )
    }

    private var resizeHandleHitHeight: CGFloat {
        let preferredHitHeight: CGFloat = 16
        let minimumMoveDragArea: CGFloat = 8
        guard renderedHeight < preferredHitHeight * 2 + minimumMoveDragArea else {
            return preferredHitHeight
        }

        return max(5, (renderedHeight - minimumMoveDragArea) / 2)
    }
}

struct DayPlanResizeSession: Equatable {
    let blockID: DayPlanBlock.ID
    let startMinute: Int
    let durationMinutes: Int
    let contentLayoutHeight: CGFloat
}
