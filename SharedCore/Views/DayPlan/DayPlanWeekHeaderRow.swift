import SwiftUI

struct DayPlanWeekHeaderRow: View {
    var dates: [Date]
    var selectedDate: Date
    var focusedUnplannedCompletedDate: Date?
    var calendar: Calendar
    var timeColumnWidth: CGFloat
    var showsUnplannedCompletedBadges: Bool
    var unplannedCompletedCount: (Date) -> Int
    var onSelectUnplannedCompletedDate: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("Time")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: timeColumnWidth, height: 56)

            ForEach(dates, id: \.self) { date in
                DayPlanWeekDayHeader(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isFocusedForUnplannedCompleted: focusedUnplannedCompletedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false,
                    isToday: calendar.isDateInToday(date),
                    unplannedCompletedCount: showsUnplannedCompletedBadges ? unplannedCompletedCount(date) : 0,
                    onSelectUnplannedCompleted: {
                        onSelectUnplannedCompletedDate(date)
                    }
                )
            }
        }
        .background(Color.secondary.opacity(0.08))
    }
}
