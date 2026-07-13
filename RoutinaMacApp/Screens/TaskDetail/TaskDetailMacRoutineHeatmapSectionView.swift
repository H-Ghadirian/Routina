import SwiftUI

struct TaskDetailMacRoutineHeatmapSectionView: View {
    let task: RoutineTask
    let logs: [RoutineLog]
    let referenceDate: Date
    let background: Color
    let stroke: Color
    var calendar: Calendar = .current

    private var weeks: [TaskDetailMacRoutineHeatmapWeek] {
        TaskDetailMacRoutineHeatmapPresentation.weeks(
            logs: logs,
            task: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    private var completedDayCount: Int {
        TaskDetailMacRoutineHeatmapPresentation.completedDayCount(
            logs: logs,
            task: task,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    var body: some View {
        TaskDetailSectionCardView(background: background, stroke: stroke) {
            VStack(alignment: .leading, spacing: 12) {
                header

                TaskDetailMacRoutineHeatmapGridView(
                    weeks: weeks,
                    calendar: calendar
                )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label("Done heatmap", systemImage: "square.grid.3x3.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Text(summaryText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var summaryText: String {
        completedDayCount == 1
            ? "1 done day in the last year"
            : "\(completedDayCount.formatted()) done days in the last year"
    }
}

struct TaskDetailMacRoutineHeatmapWeek: Identifiable, Equatable {
    let weekStart: Date
    let days: [TaskDetailMacRoutineHeatmapDay?]

    var id: Date { weekStart }
}

struct TaskDetailMacRoutineHeatmapDay: Identifiable, Equatable {
    let date: Date
    let isDone: Bool

    var id: Date { date }
}

enum TaskDetailMacRoutineHeatmapPresentation {
    static let visibleDayCount = 365

    static func doneDates(
        logs: [RoutineLog],
        task: RoutineTask,
        calendar: Calendar = .current
    ) -> Set<Date> {
        Set(
            TaskDetailCalendarPresentation.doneDates(
                from: logs,
                task: task,
                calendar: calendar
            )
            .map { calendar.startOfDay(for: $0) }
        )
    }

    static func completedDayCount(
        logs: [RoutineLog],
        task: RoutineTask,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let range = visibleDayRange(referenceDate: referenceDate, calendar: calendar)
        return doneDates(logs: logs, task: task, calendar: calendar)
            .filter { day in day >= range.start && day <= range.end }
            .count
    }

    static func weeks(
        logs: [RoutineLog],
        task: RoutineTask,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [TaskDetailMacRoutineHeatmapWeek] {
        weeks(
            doneDates: doneDates(logs: logs, task: task, calendar: calendar),
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    static func weeks(
        doneDates: Set<Date>,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [TaskDetailMacRoutineHeatmapWeek] {
        let range = visibleDayRange(referenceDate: referenceDate, calendar: calendar)
        let normalizedDoneDates = Set(doneDates.map { calendar.startOfDay(for: $0) })
        var result: [TaskDetailMacRoutineHeatmapWeek] = []
        var weekStart = startOfWeek(containing: range.start, calendar: calendar)

        while weekStart <= range.end {
            let days = (0..<7).map { offset -> TaskDetailMacRoutineHeatmapDay? in
                guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                    return nil
                }
                let normalizedDay = calendar.startOfDay(for: day)
                guard normalizedDay >= range.start && normalizedDay <= range.end else {
                    return nil
                }
                return TaskDetailMacRoutineHeatmapDay(
                    date: normalizedDay,
                    isDone: normalizedDoneDates.contains(normalizedDay)
                )
            }

            result.append(TaskDetailMacRoutineHeatmapWeek(weekStart: weekStart, days: days))

            guard let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
                break
            }
            weekStart = nextWeekStart
        }

        return result
    }

    static func visibleDayRange(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let end = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(
            byAdding: .day,
            value: -(visibleDayCount - 1),
            to: end
        ) ?? end
        return (start, end)
    }

    static func startOfWeek(
        containing date: Date,
        calendar: Calendar = .current
    ) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -leadingDays, to: day) ?? day
    }
}

private struct TaskDetailMacRoutineHeatmapGridView: View {
    let weeks: [TaskDetailMacRoutineHeatmapWeek]
    let calendar: Calendar

    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 4
    private let weekdayLabelWidth: CGFloat = 28

    var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 6) {
                monthHeader
                dayGrid
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var monthHeader: some View {
        HStack(alignment: .top, spacing: cellSpacing) {
            Color.clear
                .frame(width: weekdayLabelWidth, height: 12)

            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(Array(weeks.enumerated()), id: \.element.id) { index, week in
                    Text(monthLabel(for: week, at: index))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(width: cellSize, alignment: .leading)
                }
            }
        }
    }

    private var dayGrid: some View {
        HStack(alignment: .top, spacing: cellSpacing) {
            weekdayLabels

            HStack(alignment: .top, spacing: cellSpacing) {
                ForEach(weeks) { week in
                    VStack(spacing: cellSpacing) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            dayCell(week.days[dayIndex])
                        }
                    }
                }
            }
        }
    }

    private var weekdayLabels: some View {
        let symbols = calendar.orderedShortStandaloneWeekdaySymbols

        return VStack(alignment: .trailing, spacing: cellSpacing) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { index, symbol in
                Text(index == 0 || index == 2 || index == 4 ? symbol : "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: weekdayLabelWidth, height: cellSize, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: TaskDetailMacRoutineHeatmapDay?) -> some View {
        if let day {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(day.isDone ? TaskDetailStatusPalette.done : Color.secondary.opacity(0.13))
                .frame(width: cellSize, height: cellSize)
                .help(helpText(for: day))
                .accessibilityLabel(helpText(for: day))
        } else {
            Color.clear
                .frame(width: cellSize, height: cellSize)
                .accessibilityHidden(true)
        }
    }

    private func monthLabel(
        for week: TaskDetailMacRoutineHeatmapWeek,
        at index: Int
    ) -> String {
        let visibleDays = week.days.compactMap { $0?.date }
        guard !visibleDays.isEmpty else { return "" }
        if index == 0 {
            return visibleDays[0].formatted(.dateTime.month(.abbreviated))
        }
        let containsFirstOfMonth = visibleDays.contains {
            calendar.component(.day, from: $0) == 1
        }
        return containsFirstOfMonth
            ? visibleDays.first(where: { calendar.component(.day, from: $0) == 1 })?
                .formatted(.dateTime.month(.abbreviated)) ?? ""
            : ""
    }

    private func helpText(for day: TaskDetailMacRoutineHeatmapDay) -> String {
        let prefix = day.isDone ? "Done" : "No done"
        return "\(prefix) on \(day.date.formatted(date: .abbreviated, time: .omitted))"
    }
}
