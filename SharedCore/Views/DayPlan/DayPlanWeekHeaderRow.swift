import SwiftUI

struct DayPlanWeekHeaderRow: View {
    var dates: [Date]
    var selectedDate: Date
    var focusedUnplannedCompletedDate: Date?
    var focusedPlannedTasksDate: Date?
    var calendar: Calendar
    var timeColumnWidth: CGFloat
    var showsUnplannedCompletedBadges: Bool
    var plannedTaskCount: (Date) -> Int
    var unplannedCompletedCount: (Date) -> Int
    var onSelectPlannedTasksDate: (Date) -> Void
    var onSelectUnplannedCompletedDate: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("Time")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: timeColumnWidth, height: 64)

            ForEach(dates, id: \.self) { date in
                DayPlanWeekDayHeader(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isFocusedForUnplannedCompleted: focusedUnplannedCompletedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false,
                    isFocusedForPlannedTasks: focusedPlannedTasksDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false,
                    isToday: calendar.isDateInToday(date),
                    plannedTaskCount: plannedTaskCount(date),
                    unplannedCompletedCount: showsUnplannedCompletedBadges ? unplannedCompletedCount(date) : 0,
                    onSelectPlannedTasks: {
                        onSelectPlannedTasksDate(date)
                    },
                    onSelectUnplannedCompleted: {
                        onSelectUnplannedCompletedDate(date)
                    }
                )
            }
        }
        .routinaGlassCard(cornerRadius: 0, tint: .secondary, tintOpacity: 0.08)
    }
}
