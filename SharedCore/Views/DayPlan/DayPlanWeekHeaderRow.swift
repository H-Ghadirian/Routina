import SwiftUI

struct DayPlanWeekHeaderRow: View {
    var dates: [Date]
    var selectedDate: Date
    var focusedUnplannedCompletedDate: Date?
    var focusedPlannedTasksDate: Date?
    var calendar: Calendar
    var timeColumnWidth: CGFloat
    var timeHeaderTitle = "Time"
    var showsDayTaskButtons = true
    var showsUnplannedCompletedBadges: Bool
    var showsHourSpacingControls = false
    var canDecreaseHourSpacing = false
    var canIncreaseHourSpacing = false
    var hourSpacingAccessibilityValue = ""
    var dayTaskCounts: (Date) -> DayPlanDayTaskCounts
    var unplannedCompletedCount: (Date) -> Int
    var onDecreaseHourSpacing: () -> Void = {}
    var onIncreaseHourSpacing: () -> Void = {}
    var onSelectPlannedTasksDate: (Date) -> Void
    var onSelectUnplannedCompletedDate: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            timeHeaderCell

            ForEach(dates, id: \.self) { date in
                DayPlanWeekDayHeader(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isFocusedForUnplannedCompleted: focusedUnplannedCompletedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false,
                    isFocusedForPlannedTasks: focusedPlannedTasksDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false,
                    isToday: calendar.isDateInToday(date),
                    showsDayTaskButton: showsDayTaskButtons,
                    dayTaskCounts: dayTaskCounts(date),
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

    private var timeHeaderCell: some View {
        HStack(alignment: .center, spacing: showsHourSpacingControls ? 4 : 0) {
            Text(timeHeaderTitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            if showsHourSpacingControls {
                VStack(spacing: 4) {
                    hourSpacingButton(
                        systemName: "minus.magnifyingglass",
                        accessibilityLabel: "Decrease day hour spacing",
                        help: "Decrease hour spacing",
                        isEnabled: canDecreaseHourSpacing,
                        action: onDecreaseHourSpacing
                    )

                    hourSpacingButton(
                        systemName: "plus.magnifyingglass",
                        accessibilityLabel: "Increase day hour spacing",
                        help: "Increase hour spacing",
                        isEnabled: canIncreaseHourSpacing,
                        action: onIncreaseHourSpacing
                    )
                }
            }
        }
        .padding(.horizontal, showsHourSpacingControls ? 5 : 0)
        .frame(width: timeColumnWidth, height: 64)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(showsHourSpacingControls ? "Time and day hour spacing" : timeHeaderTitle)
        .accessibilityValue(showsHourSpacingControls ? hourSpacingAccessibilityValue : "")
    }

    private func hourSpacingButton(
        systemName: String,
        accessibilityLabel: String,
        help: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isEnabled ? Color.secondary : Color.secondary.opacity(0.45))
                .frame(width: 22, height: 22)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(isEnabled ? 0.08 : 0.045))
                }
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
        .help(help)
    }
}
