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

    var body: some View {
        Section(header: Text("Repeat Pattern")) {
            Picker("Repeat Pattern", selection: $recurrenceKind) {
                ForEach(RoutineRecurrenceRule.Kind.allCases, id: \.self) { kind in
                    Text(kind.pickerTitle).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            Text(recurrencePatternDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
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
                Stepper(value: $frequencyValue, in: 1...365) {
                    Text(stepperLabel)
                }
            }
        }
    }

    private var dailyTimeSection: some View {
        Section(header: Text("Time of Day")) {
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
                Text("Every \(TaskFormPresentation.ordinalDay(recurrenceDayOfMonth))")
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
