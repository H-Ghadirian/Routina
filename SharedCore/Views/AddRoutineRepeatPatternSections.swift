import SwiftUI

struct AddRoutineRepeatPatternSections: View {
    @Binding var recurrenceKind: RoutineRecurrenceRule.Kind
    @Binding var frequency: AddRoutineFeature.Frequency
    @Binding var frequencyValue: Int
    @Binding var recurrenceTime: Date
    @Binding var recurrenceWeekday: Int
    @Binding var recurrenceDayOfMonth: Int
    @Binding var recurrenceWeekdays: [Int]
    @Binding var recurrenceDaysOfMonth: [Int]
    let recurrencePatternDescription: String
    let dailyTimeSummary: String
    let weeklyRecurrenceSummary: String
    let monthlyRecurrenceSummary: String
    let weekdayOptions: [(id: Int, name: String)]
    var frequencyValueBounds: ClosedRange<Int> = TaskFormRecurrenceConstraints.defaultFrequencyValueBounds

    var body: some View {
        Section(header: Text("Repeat Type")) {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Repeat Type",
                options: RoutineRepeatBasis.allCases,
                selection: repeatBasisBinding,
                fillsAvailableWidth: true
            ) { basis in
                Text(basis.rawValue)
            }

            Text(recurrencePatternDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if recurrenceKind.repeatBasis == .calendar {
            Section(header: Text("Calendar Pattern")) {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Calendar Pattern",
                    options: RoutineRecurrenceRule.Kind.calendarCases,
                    selection: calendarRecurrenceKindBinding,
                    fillsAvailableWidth: true
                ) { kind in
                    Text(kind.pickerTitle)
                }
            }
        }

        switch recurrenceKind {
        case .intervalDays:
            intervalSections

        case .dailyTime:
            dailyTimeSection

        case .weekly:
            weeklySection

        case .monthlyDay:
            monthlyDaySection
        }
    }

    private var repeatBasisBinding: Binding<RoutineRepeatBasis> {
        Binding(
            get: {
                recurrenceKind.repeatBasis
            },
            set: { basis in
                recurrenceKind = recurrenceKind.replacingRepeatBasis(basis)
            }
        )
    }

    private var calendarRecurrenceKindBinding: Binding<RoutineRecurrenceRule.Kind> {
        Binding(
            get: {
                RoutineRecurrenceRule.Kind.calendarCases.contains(recurrenceKind) ? recurrenceKind : .weekly
            },
            set: { kind in
                guard RoutineRecurrenceRule.Kind.calendarCases.contains(kind) else { return }
                recurrenceKind = kind
            }
        )
    }

    private var intervalSections: some View {
        Group {
            Section(header: Text("Frequency")) {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Frequency",
                    options: AddRoutineFeature.Frequency.allCases,
                    selection: $frequency,
                    fillsAvailableWidth: true
                ) { frequency in
                    Text(frequency.rawValue)
                }
            }

            Section(header: Text("Repeat")) {
                Stepper(value: $frequencyValue, in: frequencyValueBounds) {
                    Text(stepperLabel)
                }
            }
        }
    }

    private var dailyTimeSection: some View {
        Section(header: Text("Availability")) {
            DatePicker(
                "Time",
                selection: $recurrenceTime,
                displayedComponents: .hourAndMinute
            )

            Text(dailyTimeSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var weeklySection: some View {
        Section(header: Text("Weekday")) {
            LazyVGrid(columns: weekdayGridColumns, alignment: .leading, spacing: 8) {
                ForEach(weekdayOptions, id: \.id) { option in
                    Toggle(option.name, isOn: weekdaySelectionBinding(for: option.id))
                        .toggleStyle(.button)
                }
            }

            Text(weeklyRecurrenceSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var monthlyDaySection: some View {
        Section(header: Text("Day of Month")) {
            LazyVGrid(columns: monthDayGridColumns, alignment: .leading, spacing: 8) {
                ForEach(1...31, id: \.self) { day in
                    Toggle(isOn: monthDaySelectionBinding(for: day)) {
                        Text("\(day)")
                            .frame(maxWidth: .infinity)
                    }
                    .toggleStyle(.button)
                    .accessibilityLabel(TaskFormPresentation.monthDayControlLabel(for: day))
                }
            }

            Text(monthlyRecurrenceSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var stepperLabel: String {
        let unit: TaskFormFrequencyUnit
        switch frequency {
        case .day:
            unit = .day
        case .week:
            unit = .week
        case .month:
            unit = .month
        }
        return TaskFormPresentation.stepperLabel(unit: unit, value: frequencyValue)
    }

    private var weekdayGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 96), spacing: 8)]
    }

    private var monthDayGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 44), spacing: 8)]
    }

    private func weekdaySelectionBinding(for weekday: Int) -> Binding<Bool> {
        Binding(
            get: { recurrenceWeekdays.contains(weekday) },
            set: { isSelected in
                let updatedSelection = updatedSelection(
                    value: weekday,
                    isSelected: isSelected,
                    selection: recurrenceWeekdays
                )
                recurrenceWeekdays = updatedSelection
            }
        )
    }

    private func monthDaySelectionBinding(for day: Int) -> Binding<Bool> {
        Binding(
            get: { recurrenceDaysOfMonth.contains(day) },
            set: { isSelected in
                let updatedSelection = updatedSelection(
                    value: day,
                    isSelected: isSelected,
                    selection: recurrenceDaysOfMonth
                )
                recurrenceDaysOfMonth = updatedSelection
            }
        )
    }

    private func updatedSelection(
        value: Int,
        isSelected: Bool,
        selection: [Int]
    ) -> [Int] {
        var selectedValues = Set(selection)
        if isSelected {
            selectedValues.insert(value)
        } else {
            guard selectedValues.count > 1 else { return selection.sorted() }
            selectedValues.remove(value)
        }
        return selectedValues.sorted()
    }
}
