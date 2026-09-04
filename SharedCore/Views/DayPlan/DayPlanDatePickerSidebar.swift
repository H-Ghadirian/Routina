import SwiftUI

struct DayPlanDatePickerSidebar: View {
    @Binding var selectedDate: Date
    let summaryTitle: String
    let blocksCount: Int
    let plannedMinutes: Int
    let calendar: Calendar
    var activityDates: [Date] = []
    var showsActivityAvailability = false
    let onDismiss: () -> Void

    @State private var displayedMonthStart: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            DayPlanSidebarDateGrid(
                selectedDate: $selectedDate,
                displayedMonthStart: displayedMonthStartBinding,
                calendar: calendar,
                activityDayStarts: activityDayStarts,
                showsActivityAvailability: showsActivityAvailability
            )

            Button {
                selectedDate = calendar.startOfDay(for: Date())
            } label: {
                Label("Today", systemImage: "location.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            syncDisplayedMonthToSelectedDate(force: true)
        }
        .onChange(of: selectedDate) { _, _ in
            syncDisplayedMonthToSelectedDate()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "calendar")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Go to date")
                    .font(.headline.weight(.semibold))
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Close")
            .contentShape(Circle())
        }
    }

    private var summaryText: String {
        "\(summaryTitle) - \(blocksCount) blocks, \(DayPlanFormatting.durationText(plannedMinutes)) planned"
    }

    private var activityDayStarts: Set<Date> {
        DayPlanSidebarDateAvailability.dayStarts(for: activityDates, calendar: calendar)
    }

    private var displayedMonthStartBinding: Binding<Date> {
        Binding(
            get: {
                displayedMonthStart ?? calendar.dayPlanMonthStart(for: selectedDate)
            },
            set: { newValue in
                displayedMonthStart = calendar.dayPlanMonthStart(for: newValue)
            }
        )
    }

    private func syncDisplayedMonthToSelectedDate(force: Bool = false) {
        let selectedMonthStart = calendar.dayPlanMonthStart(for: selectedDate)
        guard
            force
                || displayedMonthStart.map({
                    !calendar.isDate($0, equalTo: selectedMonthStart, toGranularity: .month)
                }) ?? true
        else {
            return
        }
        displayedMonthStart = selectedMonthStart
    }
}

private struct DayPlanSidebarDateGrid: View {
    @Binding var selectedDate: Date
    @Binding var displayedMonthStart: Date
    let calendar: Calendar
    let activityDayStarts: Set<Date>
    let showsActivityAvailability: Bool

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 32), spacing: 8), count: 7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            monthHeader
            weekdayHeader

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(days) { day in
                    dayCell(day)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var monthHeader: some View {
        HStack(spacing: 8) {
            Text(displayedMonthStart.formatted(.dateTime.month(.wide).year()))
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .monospacedDigit()

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                monthNavigationButton(
                    systemName: "chevron.left",
                    accessibilityLabel: "Previous month"
                ) {
                    moveMonth(by: -1)
                }
                monthNavigationButton(
                    systemName: "chevron.right",
                    accessibilityLabel: "Next month"
                ) {
                    moveMonth(by: 1)
                }
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 8) {
            ForEach(Array(calendar.orderedShortStandaloneWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func monthNavigationButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.subheadline.weight(.bold))
                .frame(width: 32, height: 32)
                .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(accessibilityLabel)
    }

    private func dayCell(_ day: DayPlanSidebarCalendarDay) -> some View {
        let isSelected = calendar.isDate(day.date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day.date)
        let hasActivity =
            showsActivityAvailability
            && DayPlanSidebarDateAvailability.contains(day.date, in: activityDayStarts, calendar: calendar)

        return Button {
            selectedDate = calendar.startOfDay(for: day.date)
            displayedMonthStart = calendar.dayPlanMonthStart(for: day.date)
        } label: {
            Text(day.date.formatted(.dateTime.day()))
                .font(.headline.weight(isSelected ? .bold : .semibold))
                .monospacedDigit()
                .foregroundStyle(
                    foregroundStyle(
                        isSelected: isSelected,
                        isInDisplayedMonth: day.isInDisplayedMonth,
                        hasActivity: hasActivity
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            backgroundColor(
                                isSelected: isSelected,
                                isToday: isToday,
                                hasActivity: hasActivity
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(
                            borderColor(
                                isSelected: isSelected,
                                isToday: isToday,
                                hasActivity: hasActivity
                            ),
                            lineWidth: hasActivity && !isSelected ? 1.4 : 1
                        )
                }
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
        .accessibilityValue(accessibilityValue(isSelected: isSelected, hasActivity: hasActivity))
    }

    private var days: [DayPlanSidebarCalendarDay] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonthStart),
            let firstGridDate = calendar.date(
                byAdding: .day,
                value: -leadingEmptyDays(from: monthInterval.start),
                to: monthInterval.start
            )
        else {
            return []
        }

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstGridDate) else {
                return nil
            }
            return DayPlanSidebarCalendarDay(
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: displayedMonthStart, toGranularity: .month)
            )
        }
    }

    private func leadingEmptyDays(from firstDayOfMonth: Date) -> Int {
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        return (firstWeekday - calendar.firstWeekday + 7) % 7
    }

    private func moveMonth(by offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonthStart) else {
            return
        }
        displayedMonthStart = calendar.dayPlanMonthStart(for: newMonth)
    }

    private func foregroundStyle(
        isSelected: Bool,
        isInDisplayedMonth: Bool,
        hasActivity: Bool
    ) -> Color {
        if isSelected {
            return .white
        }
        if showsActivityAvailability && !hasActivity {
            return isInDisplayedMonth ? .secondary.opacity(0.52) : .secondary.opacity(0.32)
        }
        if !isInDisplayedMonth {
            return .secondary.opacity(hasActivity ? 0.72 : 0.58)
        }
        return .primary
    }

    private func backgroundColor(isSelected: Bool, isToday: Bool, hasActivity: Bool) -> Color {
        if isSelected {
            return .accentColor
        }
        if hasActivity {
            return Color.accentColor.opacity(0.07)
        }
        if isToday {
            return showsActivityAvailability ? Color.secondary.opacity(0.08) : Color.accentColor.opacity(0.13)
        }
        return Color.clear
    }

    private func borderColor(isSelected: Bool, isToday: Bool, hasActivity: Bool) -> Color {
        if isSelected {
            return .clear
        }
        if hasActivity {
            return Color.accentColor.opacity(0.72)
        }
        if isToday {
            return showsActivityAvailability ? Color.secondary.opacity(0.34) : Color.accentColor.opacity(0.58)
        }
        return .clear
    }

    private func accessibilityValue(isSelected: Bool, hasActivity: Bool) -> String {
        var values: [String] = []
        if isSelected {
            values.append("Selected")
        }
        if showsActivityAvailability {
            values.append(hasActivity ? "Timeline activity available" : "No timeline activity")
        }
        return values.joined(separator: ", ")
    }
}

private struct DayPlanSidebarCalendarDay: Identifiable {
    let date: Date
    let isInDisplayedMonth: Bool

    var id: Date { date }
}

private extension Calendar {
    func dayPlanMonthStart(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }
}
