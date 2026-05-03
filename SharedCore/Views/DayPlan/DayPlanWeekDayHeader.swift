import SwiftUI

struct DayPlanWeekDayHeader: View {
    var date: Date
    var isSelected: Bool
    var isToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(date.formatted(.dateTime.day()))
                .font(.title3.weight(.semibold))
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .padding(.horizontal, isToday ? 8 : 0)
                .padding(.vertical, isToday ? 3 : 0)
                .background {
                    if isToday {
                        Capsule()
                            .fill(Color.accentColor)
                    }
                }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.horizontal, 10)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 1)
        }
    }
}
