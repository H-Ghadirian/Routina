import SwiftUI

struct AdvancedRecurrenceEditor: View {
    @Binding var rule: RoutineAdvancedRecurrenceRule
    let weekdayOptions: [(id: Int, name: String)]

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DatePicker(
                "Start",
                selection: valueBinding(\.startDate),
                displayedComponents: [.date, .hourAndMinute]
            )

            Picker("Repeat", selection: valueBinding(\.frequency)) {
                ForEach(RoutineAdvancedRecurrenceRule.Frequency.allCases) { frequency in
                    Text(frequency.rawValue).tag(frequency)
                }
            }

            Stepper(value: valueBinding(\.interval), in: intervalBounds) {
                Text(everyLabel)
            }

            frequencySpecificControls

            endControls

            Text(rule.summary(calendar: calendar))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Recurrence summary")
        }
    }

    @ViewBuilder
    private var frequencySpecificControls: some View {
        switch rule.frequency {
        case .hourly:
            hourlyControls
        case .daily:
            dailyControls
        case .weekly:
            weeklyControls
        case .monthly:
            monthlyControls
        case .yearly:
            yearlyControls
        }
    }

    private var hourlyControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Schedule", selection: valueBinding(\.hourlyMode)) {
                ForEach(RoutineAdvancedRecurrenceRule.HourlyMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if rule.hourlyMode == .dailyWindow {
                HStack(spacing: 16) {
                    DatePicker(
                        "From",
                        selection: timeBinding(\.dailyWindowStart),
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "To",
                        selection: timeBinding(\.dailyWindowEnd),
                        displayedComponents: .hourAndMinute
                    )
                }
            }
        }
    }

    private var dailyControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Times")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(rule.timesOfDay.enumerated()), id: \.offset) { index, _ in
                HStack(spacing: 8) {
                    DatePicker(
                        "Time \(index + 1)",
                        selection: indexedTimeBinding(index),
                        displayedComponents: .hourAndMinute
                    )
                    if rule.timesOfDay.count > 1 {
                        Button {
                            removeTime(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove time \(index + 1)")
                    }
                }
            }

            Button {
                addTime()
            } label: {
                Label("Add time", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var weeklyControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("On")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: weekdayColumns, alignment: .leading, spacing: 8) {
                ForEach(weekdayOptions, id: \.id) { option in
                    Toggle(option.name, isOn: weekdayBinding(option.id))
                        .toggleStyle(.button)
                }
            }
        }
    }

    private var monthlyControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("On", selection: valueBinding(\.monthlyPattern)) {
                ForEach(RoutineAdvancedRecurrenceRule.MonthlyPattern.allCases) { pattern in
                    Text(pattern.rawValue).tag(pattern)
                }
            }
            .pickerStyle(.segmented)

            if rule.monthlyPattern == .dayOfMonth {
                Stepper(value: primaryMonthDayBinding, in: 1...31) {
                    Text("Day \(rule.monthDays.first ?? 1)")
                }
            } else {
                HStack(spacing: 12) {
                    Picker("Position", selection: valueBinding(\.weekdayOrdinal)) {
                        ForEach(RoutineAdvancedRecurrenceRule.WeekdayOrdinal.allCases) { ordinal in
                            Text(ordinal.title).tag(ordinal)
                        }
                    }
                    Picker("Weekday", selection: valueBinding(\.ordinalWeekday)) {
                        ForEach(weekdayOptions, id: \.id) { option in
                            Text(option.name).tag(option.id)
                        }
                    }
                }
            }
        }
    }

    private var yearlyControls: some View {
        HStack(spacing: 12) {
            Picker("Month", selection: primaryMonthBinding) {
                ForEach(Array(calendar.monthSymbols.enumerated()), id: \.offset) { index, month in
                    Text(month).tag(index + 1)
                }
            }
            Stepper(value: primaryMonthDayBinding, in: 1...31) {
                Text("Day \(rule.monthDays.first ?? 1)")
            }
        }
    }

    private var endControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("End", selection: valueBinding(\.endMode)) {
                ForEach(RoutineAdvancedRecurrenceRule.EndMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            switch rule.endMode {
            case .never:
                EmptyView()
            case .onDate:
                DatePicker("End date", selection: valueBinding(\.endDate), displayedComponents: .date)
            case .afterCount:
                Stepper(value: valueBinding(\.occurrenceCount), in: 1...10_000) {
                    Text("\(rule.occurrenceCount) occurrences")
                }
            }
        }
    }

    private var everyLabel: String {
        "Every \(rule.interval) \(rule.frequency.unitName(for: rule.interval))"
    }

    private var intervalBounds: ClosedRange<Int> {
        rule.frequency == .hourly ? 1...168 : 1...365
    }

    private var weekdayColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 84), spacing: 8)]
    }

    private var primaryMonthDayBinding: Binding<Int> {
        Binding(
            get: { rule.monthDays.first ?? calendar.component(.day, from: rule.startDate) },
            set: { value in
                rule.monthDays = [min(max(value, 1), 31)]
            }
        )
    }

    private var primaryMonthBinding: Binding<Int> {
        Binding(
            get: { rule.monthsOfYear.first ?? calendar.component(.month, from: rule.startDate) },
            set: { value in
                rule.monthsOfYear = [min(max(value, 1), 12)]
            }
        )
    }

    private func valueBinding<Value>(
        _ keyPath: WritableKeyPath<RoutineAdvancedRecurrenceRule, Value>
    ) -> Binding<Value> {
        Binding(
            get: { rule[keyPath: keyPath] },
            set: { value in
                rule[keyPath: keyPath] = value
                rule = rule.normalized(calendar: calendar)
            }
        )
    }

    private func timeBinding(
        _ keyPath: WritableKeyPath<RoutineAdvancedRecurrenceRule, RoutineTimeOfDay>
    ) -> Binding<Date> {
        Binding(
            get: { rule[keyPath: keyPath].date(on: rule.startDate, calendar: calendar) },
            set: { value in
                rule[keyPath: keyPath] = RoutineTimeOfDay.from(value, calendar: calendar)
                rule = rule.normalized(calendar: calendar)
            }
        )
    }

    private func indexedTimeBinding(_ index: Int) -> Binding<Date> {
        Binding(
            get: {
                guard rule.timesOfDay.indices.contains(index) else { return rule.startDate }
                return rule.timesOfDay[index].date(on: rule.startDate, calendar: calendar)
            },
            set: { value in
                guard rule.timesOfDay.indices.contains(index) else { return }
                rule.timesOfDay[index] = RoutineTimeOfDay.from(value, calendar: calendar)
                rule = rule.normalized(calendar: calendar)
            }
        )
    }

    private func weekdayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { rule.weekdays.contains(weekday) },
            set: { isSelected in
                var selected = Set(rule.weekdays)
                if isSelected {
                    selected.insert(weekday)
                } else if selected.count > 1 {
                    selected.remove(weekday)
                }
                rule.weekdays = selected.sorted()
                rule = rule.normalized(calendar: calendar)
            }
        )
    }

    private func addTime() {
        let last = rule.timesOfDay.last ?? RoutineTimeOfDay.from(rule.startDate, calendar: calendar)
        rule.timesOfDay.append(last.addingMinutes(60))
        rule = rule.normalized(calendar: calendar)
    }

    private func removeTime(at index: Int) {
        guard rule.timesOfDay.count > 1, rule.timesOfDay.indices.contains(index) else { return }
        rule.timesOfDay.remove(at: index)
        rule = rule.normalized(calendar: calendar)
    }
}
