import SwiftUI

struct AddRoutineRepeatPatternSections: View {
    @Binding var recurrenceKind: RoutineRecurrenceRule.Kind
    @Binding var frequency: AddRoutineFeature.Frequency
    @Binding var frequencyValue: Int
    @Binding var recurrenceTime: Date
    @Binding var recurrenceWeekday: Int
    @Binding var recurrenceDayOfMonth: Int
    let recurrencePatternDescription: String
    let dailyTimeSummary: String
    let weeklyRecurrenceSummary: String
    let monthlyRecurrenceSummary: String
    let weekdayOptions: [(id: Int, name: String)]
    var frequencyValueBounds: ClosedRange<Int> = TaskFormRecurrenceConstraints.defaultFrequencyValueBounds

    var body: some View {
        Section(header: Text("Repeat Type")) {
            Picker("Repeat Type", selection: repeatBasisBinding) {
                ForEach(RoutineRepeatBasis.allCases) { basis in
                    Text(basis.rawValue).tag(basis)
                }
            }
            .pickerStyle(.segmented)

            Text(recurrencePatternDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if recurrenceKind.repeatBasis == .calendar {
            Section(header: Text("Calendar Pattern")) {
                Picker("Calendar Pattern", selection: calendarRecurrenceKindBinding) {
                    ForEach(RoutineRecurrenceRule.Kind.calendarCases, id: \.self) { kind in
                        Text(kind.pickerTitle).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
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
                Picker("Frequency", selection: $frequency) {
                    ForEach(AddRoutineFeature.Frequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
                .pickerStyle(.segmented)
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
            Picker("Weekday", selection: $recurrenceWeekday) {
                ForEach(weekdayOptions, id: \.id) { option in
                    Text(option.name).tag(option.id)
                }
            }

            Text(weeklyRecurrenceSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var monthlyDaySection: some View {
        Section(header: Text("Day of Month")) {
            Stepper(value: $recurrenceDayOfMonth, in: 1...31) {
                Text(TaskFormPresentation.monthDayRepeatLabel(for: recurrenceDayOfMonth))
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
}
