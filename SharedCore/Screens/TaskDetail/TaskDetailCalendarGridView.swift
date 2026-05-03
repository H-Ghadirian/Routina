import SwiftUI

struct TaskDetailCalendarGridView: View {
    let displayedMonthStart: Date
    let doneDates: Set<Date>
    let assumedDates: Set<Date>
    let dueDate: Date?
    let createdAt: Date?
    let pausedAt: Date?
    let isOrangeUrgencyToday: Bool
    let selectedDate: Date
    let onSelectDate: (Date) -> Void
    var calendar: Calendar = .current

    var body: some View {
        let days = calendar.daysInMonthGrid(for: displayedMonthStart)
        let weekdaySymbols = calendar.orderedShortStandaloneWeekdaySymbols

        VStack(spacing: 6) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(
                            day: day,
                            isSelected: calendar.isDate(day, inSameDayAs: selectedDate)
                        )
                    } else {
                        Color.clear
                            .frame(height: 28)
                    }
                }
            }
        }
    }

    private func dayCell(day: Date, isSelected: Bool) -> some View {
        let presentation = TaskDetailCalendarPresentation.dayPresentation(
            day: day,
            doneDates: doneDates,
            assumedDates: assumedDates,
            dueDate: dueDate,
            createdAt: createdAt,
            pausedAt: pausedAt,
            isOrangeUrgencyToday: isOrangeUrgencyToday,
            calendar: calendar
        )

        return Button {
            onSelectDate(day)
        } label: {
            Text(day.formatted(.dateTime.day()))
                .font(.subheadline)
                .foregroundColor(presentation.foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(Circle().fill(presentation.backgroundColor))
                .overlay(
                    Circle()
                        .stroke(
                            TaskDetailCalendarPresentation.selectionStrokeColor(
                                isSelected: isSelected,
                                isToday: presentation.isToday,
                                isHighlightedDay: presentation.isHighlightedDay
                            ),
                            lineWidth: isSelected ? 3 : 2
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
