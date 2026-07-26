import SwiftUI

struct UnifiedRecurrenceEditor: View {
    @Binding var draft: RoutineRecurrenceDraft
    let supportsNoSchedule: Bool
    let supportsItemRunout: Bool
    let weekdayOptions: [(id: Int, name: String)]

    @State private var showsMoreOptions = false
    @State private var referenceDate = Date()

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            cadenceControl

            if draft.cadence == .scheduled || draft.cadence == .afterCompletion {
                frequencyControl
                intervalControl

                if draft.cadence == .scheduled {
                    schedulePatternControls
                    moreOptions
                }
            }

            Label(draft.composerSummary(calendar: calendar), systemImage: summarySystemImage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Recurrence summary")
        }
        .onAppear {
            if draft.requiresFixedScheduleDetails {
                draft = draft.settingFixedScheduleDetailsEnabled(
                    true,
                    now: referenceDate,
                    calendar: calendar
                )
            }
            showsMoreOptions = draft.usesFixedScheduleDetails
        }
        .onChange(of: draft.requiresFixedScheduleDetails) { _, isRequired in
            if isRequired {
                showsMoreOptions = true
            }
        }
    }

    private var cadenceControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Repeat behavior")
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Repeat behavior",
                options: cadenceOptions,
                selection: draft.cadence,
                onSelect: selectCadence,
                minimumSegmentWidth: 110,
                horizontalPadding: 10,
                fillsAvailableWidth: true,
                maximumSegmentsPerRow: 2
            ) { cadence in
                Text(cadenceTitle(cadence))
            }
        }
    }

    private var frequencyControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel(draft.cadence == .afterCompletion ? "Wait" : "Frequency")
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Repeat frequency",
                options: frequencyOptions,
                selection: draft.frequency,
                onSelect: selectFrequency,
                minimumSegmentWidth: 80,
                horizontalPadding: 9,
                fillsAvailableWidth: true,
                maximumSegmentsPerRow: 3
            ) { frequency in
                Text(frequencyTitle(frequency))
            }
        }
    }

    private var intervalControl: some View {
        Stepper(
            value: Binding(
                get: { draft.interval },
                set: {
                    draft = draft.settingInterval(
                        $0,
                        now: referenceDate,
                        calendar: calendar
                    )
                }
            ),
            in: intervalBounds
        ) {
            Text(everyLabel)
        }
    }

    @ViewBuilder
    private var schedulePatternControls: some View {
        switch draft.frequency {
        case .hourly, .daily:
            EmptyView()

        case .weekly:
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("On")
                RecurrenceWeekdaySelectionControl(
                    selectedWeekdays: weekdaysBinding,
                    options: weekdayOptions
                )
            }

        case .monthly:
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("On")
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Monthly pattern",
                    options: RoutineAdvancedRecurrenceRule.MonthlyPattern.allCases,
                    selection: monthlyPatternBinding,
                    fillsAvailableWidth: true
                ) { pattern in
                    Text(pattern.rawValue)
                }

                if draft.monthlyPattern == .dayOfMonth {
                    RecurrenceMonthDaySelectionControl(selectedDays: monthDaysBinding)
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

        case .yearly:
            VStack(alignment: .leading, spacing: 12) {
                fieldLabel("Months")
                RecurrenceMonthSelectionControl(
                    selectedMonths: monthsOfYearBinding,
                    calendar: calendar
                )
                fieldLabel("Dates")
                RecurrenceMonthDaySelectionControl(selectedDays: monthDaysBinding)
            }
        }
    }

    private var moreOptions: some View {
        DisclosureGroup(isExpanded: $showsMoreOptions) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Use fixed schedule details", isOn: fixedDetailsBinding)
                    .disabled(draft.requiresFixedScheduleDetails)

                if draft.requiresFixedScheduleDetails {
                    Text(requiredDetailsExplanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if draft.usesFixedScheduleDetails {
                    fixedScheduleControls
                }
            }
            .padding(.top, 10)
        } label: {
            Label("More schedule options", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
    }

    private var fixedScheduleControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            DatePicker(
                "Start",
                selection: startDateBinding,
                displayedComponents: [.date, .hourAndMinute]
            )

            Picker("Time zone", selection: timeZoneBinding) {
                ForEach(timeZoneIdentifiers, id: \.self) { identifier in
                    Text(timeZoneTitle(identifier)).tag(identifier)
                }
            }
            .pickerStyle(.menu)

            fixedFrequencyControls
            endControls
        }
    }

    @ViewBuilder
    private var fixedFrequencyControls: some View {
        switch draft.frequency {
        case .hourly:
            hourlyControls
        case .daily:
            occurrenceTimeControls(allowsAdding: true)
        case .weekly, .monthly, .yearly:
            occurrenceTimeControls(allowsAdding: false)
        }
    }

    private var hourlyControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Hourly schedule",
                options: RoutineAdvancedRecurrenceRule.HourlyMode.allCases,
                selection: valueBinding(\.hourlyMode),
                minimumSegmentWidth: 112,
                horizontalPadding: 10,
                fillsAvailableWidth: true
            ) { mode in
                Text(mode.displayTitle)
            }

            if draft.hourlyMode == .dailyWindow {
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

    private func occurrenceTimeControls(allowsAdding: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            fieldLabel(allowsAdding ? "Times" : "Time")

            ForEach(Array(draft.occurrenceTimes.enumerated()), id: \.offset) { index, _ in
                HStack(spacing: 8) {
                    DatePicker(
                        allowsAdding ? "Time \(index + 1)" : "At",
                        selection: indexedTimeBinding(index),
                        displayedComponents: .hourAndMinute
                    )
                    if draft.occurrenceTimes.count > 1 {
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

            if allowsAdding {
                Button {
                    addTime()
                } label: {
                    Label("Add another time", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var endControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("End", selection: endModeBinding) {
                ForEach(RoutineAdvancedRecurrenceRule.EndMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            switch draft.endMode {
            case .never:
                EmptyView()
            case .onDate:
                DatePicker("End date", selection: valueBinding(\.endDate), displayedComponents: .date)
            case .afterCount:
                Stepper(value: valueBinding(\.occurrenceCount), in: 1...10_000) {
                    Text("\(draft.occurrenceCount) occurrences")
                }
            }
        }
    }

    private var cadenceOptions: [RoutineRecurrenceDraft.Cadence] {
        var options: [RoutineRecurrenceDraft.Cadence] = []
        if supportsNoSchedule {
            options.append(.none)
        }
        options.append(contentsOf: [.afterCompletion, .scheduled])
        if supportsItemRunout {
            options.append(.itemRunout)
        }
        return options
    }

    private var frequencyOptions: [RoutineAdvancedRecurrenceRule.Frequency] {
        if draft.cadence == .afterCompletion {
            return [.daily, .weekly, .monthly]
        }
        return RoutineAdvancedRecurrenceRule.Frequency.allCases
    }

    private var intervalBounds: ClosedRange<Int> {
        draft.frequency == .hourly ? 1...168 : 1...365
    }

    private var everyLabel: String {
        let unit = draft.frequency.unitName(for: draft.interval)
        if draft.cadence == .afterCompletion {
            return "Repeat \(draft.interval) \(unit) after completion"
        }
        return "Every \(draft.interval) \(unit)"
    }

    private var requiredDetailsExplanation: String {
        switch draft.frequency {
        case .hourly:
            return "Hourly schedules need a fixed start to establish their first occurrence."
        case .yearly:
            return "Yearly schedules need a fixed start and time zone."
        case .daily, .weekly, .monthly:
            if draft.occurrenceTimes.count > 1 {
                return "Multiple times require fixed schedule details."
            }
            if draft.endMode != .never {
                return "An ending condition requires fixed schedule details."
            }
            if draft.monthlyPattern == .ordinalWeekday {
                return "A weekday position requires fixed schedule details."
            }
            return "Every-N schedules need a fixed start so the interval has a stable anchor."
        }
    }

    private var fixedDetailsBinding: Binding<Bool> {
        Binding(
            get: { draft.usesFixedScheduleDetails },
            set: {
                draft = draft.settingFixedScheduleDetailsEnabled(
                    $0,
                    now: referenceDate,
                    calendar: calendar
                )
            }
        )
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { draft.startDate ?? referenceDate },
            set: { value in
                updateDraft { $0.startDate = value }
            }
        )
    }

    private var timeZoneBinding: Binding<String> {
        Binding(
            get: { draft.timeZoneIdentifier ?? calendar.timeZone.identifier },
            set: { value in
                updateDraft { $0.timeZoneIdentifier = value }
            }
        )
    }

    private var monthlyPatternBinding: Binding<RoutineAdvancedRecurrenceRule.MonthlyPattern> {
        Binding(
            get: { draft.monthlyPattern },
            set: { value in
                updateDraft { $0.monthlyPattern = value }
            }
        )
    }

    private var endModeBinding: Binding<RoutineAdvancedRecurrenceRule.EndMode> {
        Binding(
            get: { draft.endMode },
            set: { value in
                updateDraft { $0.endMode = value }
            }
        )
    }

    private var weekdaysBinding: Binding<[Int]> {
        Binding(
            get: {
                draft.weekdays.isEmpty
                    ? [calendar.component(.weekday, from: draft.startDate ?? referenceDate)]
                    : draft.weekdays
            },
            set: { value in
                updateDraft { $0.weekdays = value }
            }
        )
    }

    private var monthDaysBinding: Binding<[Int]> {
        Binding(
            get: {
                draft.monthDays.isEmpty
                    ? [calendar.component(.day, from: draft.startDate ?? referenceDate)]
                    : draft.monthDays
            },
            set: { value in
                updateDraft { $0.monthDays = value }
            }
        )
    }

    private var monthsOfYearBinding: Binding<[Int]> {
        Binding(
            get: {
                draft.monthsOfYear.isEmpty
                    ? [calendar.component(.month, from: draft.startDate ?? referenceDate)]
                    : draft.monthsOfYear
            },
            set: { value in
                updateDraft { $0.monthsOfYear = value }
            }
        )
    }

    private func valueBinding<Value>(
        _ keyPath: WritableKeyPath<RoutineRecurrenceDraft, Value>
    ) -> Binding<Value> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { value in
                updateDraft { $0[keyPath: keyPath] = value }
            }
        )
    }

    private func timeBinding(
        _ keyPath: WritableKeyPath<RoutineRecurrenceDraft, RoutineTimeOfDay>
    ) -> Binding<Date> {
        Binding(
            get: {
                draft[keyPath: keyPath].date(
                    on: draft.startDate ?? referenceDate,
                    calendar: calendar
                )
            },
            set: { value in
                updateDraft {
                    $0[keyPath: keyPath] = RoutineTimeOfDay.from(value, calendar: calendar)
                }
            }
        )
    }

    private func indexedTimeBinding(_ index: Int) -> Binding<Date> {
        Binding(
            get: {
                guard draft.occurrenceTimes.indices.contains(index) else {
                    return draft.startDate ?? referenceDate
                }
                return draft.occurrenceTimes[index].date(
                    on: draft.startDate ?? referenceDate,
                    calendar: calendar
                )
            },
            set: { value in
                updateDraft { updated in
                    guard updated.occurrenceTimes.indices.contains(index) else { return }
                    updated.occurrenceTimes[index] = RoutineTimeOfDay.from(value, calendar: calendar)
                }
            }
        )
    }

    private func selectCadence(_ cadence: RoutineRecurrenceDraft.Cadence) {
        draft = draft.selectingCadence(
            cadence,
            now: referenceDate,
            calendar: calendar
        )
    }

    private func selectFrequency(_ frequency: RoutineAdvancedRecurrenceRule.Frequency) {
        draft = draft.selectingFrequency(
            frequency,
            now: referenceDate,
            calendar: calendar
        )
    }

    private func addTime() {
        updateDraft { updated in
            let last = updated.occurrenceTimes.last
                ?? RoutineTimeOfDay.from(updated.startDate ?? referenceDate, calendar: calendar)
            updated.occurrenceTimes.append(last.addingMinutes(60))
        }
    }

    private func removeTime(at index: Int) {
        updateDraft { updated in
            guard updated.occurrenceTimes.count > 1,
                  updated.occurrenceTimes.indices.contains(index)
            else { return }
            updated.occurrenceTimes.remove(at: index)
        }
    }

    private func updateDraft(_ update: (inout RoutineRecurrenceDraft) -> Void) {
        var updated = draft
        update(&updated)
        if updated.requiresFixedScheduleDetails {
            updated = updated.settingFixedScheduleDetailsEnabled(
                true,
                now: referenceDate,
                calendar: calendar
            )
        }
        draft = updated.normalized()
    }

    private func cadenceTitle(_ cadence: RoutineRecurrenceDraft.Cadence) -> String {
        switch cadence {
        case .none: return "No schedule"
        case .itemRunout: return "Item runout"
        case .afterCompletion: return "After done"
        case .scheduled: return "On schedule"
        }
    }

    private func frequencyTitle(_ frequency: RoutineAdvancedRecurrenceRule.Frequency) -> String {
        switch frequency {
        case .hourly: return "Hour"
        case .daily: return "Day"
        case .weekly: return "Week"
        case .monthly: return "Month"
        case .yearly: return "Year"
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var summarySystemImage: String {
        switch draft.cadence {
        case .none: return "arrow.trianglehead.2.clockwise.rotate.90.slash"
        case .itemRunout: return "checklist"
        case .afterCompletion: return "arrow.clockwise"
        case .scheduled: return "calendar.badge.clock"
        }
    }

    private var timeZoneIdentifiers: [String] {
        let selected = draft.timeZoneIdentifier ?? calendar.timeZone.identifier
        return Array(Set([selected, calendar.timeZone.identifier] + TimeZone.knownTimeZoneIdentifiers))
            .sorted()
    }

    private func timeZoneTitle(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: " ")
    }
}

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
            HStack(spacing: 12) {
                Text("Schedule")
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Hourly schedule",
                    options: RoutineAdvancedRecurrenceRule.HourlyMode.allCases,
                    selection: valueBinding(\.hourlyMode),
                    minimumSegmentWidth: 96,
                    horizontalPadding: 10,
                    fillsAvailableWidth: true
                ) { mode in
                    Text(mode.displayTitle)
                }
            }

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
            RecurrenceWeekdaySelectionControl(
                selectedWeekdays: advancedWeekdaysBinding,
                options: weekdayOptions
            )
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
                RecurrenceMonthDaySelectionControl(selectedDays: advancedMonthDaysBinding)
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

    private var primaryMonthDayBinding: Binding<Int> {
        Binding(
            get: { rule.monthDays.first ?? calendar.component(.day, from: rule.startDate) },
            set: { value in
                rule.monthDays = [min(max(value, 1), 31)]
            }
        )
    }

    private var advancedWeekdaysBinding: Binding<[Int]> {
        Binding(
            get: {
                let selectedWeekdays = Array(Set(rule.weekdays.filter((1...7).contains))).sorted()
                return selectedWeekdays.isEmpty
                    ? [calendar.component(.weekday, from: rule.startDate)]
                    : selectedWeekdays
            },
            set: { weekdays in
                updateRule { updatedRule in
                    updatedRule.weekdays = weekdays
                }
            }
        )
    }

    private var advancedMonthDaysBinding: Binding<[Int]> {
        Binding(
            get: {
                let selectedDays = Array(Set(rule.monthDays.filter((1...31).contains))).sorted()
                return selectedDays.isEmpty
                    ? [calendar.component(.day, from: rule.startDate)]
                    : selectedDays
            },
            set: { days in
                updateRule { updatedRule in
                    updatedRule.monthDays = days
                }
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
                updateRule { updatedRule in
                    updatedRule[keyPath: keyPath] = value
                }
            }
        )
    }

    private func timeBinding(
        _ keyPath: WritableKeyPath<RoutineAdvancedRecurrenceRule, RoutineTimeOfDay>
    ) -> Binding<Date> {
        Binding(
            get: { rule[keyPath: keyPath].date(on: rule.startDate, calendar: calendar) },
            set: { value in
                updateRule { updatedRule in
                    updatedRule[keyPath: keyPath] = RoutineTimeOfDay.from(value, calendar: calendar)
                }
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
                updateRule { updatedRule in
                    guard updatedRule.timesOfDay.indices.contains(index) else { return }
                    updatedRule.timesOfDay[index] = RoutineTimeOfDay.from(value, calendar: calendar)
                }
            }
        )
    }

    private func addTime() {
        updateRule { updatedRule in
            let last = updatedRule.timesOfDay.last
                ?? RoutineTimeOfDay.from(updatedRule.startDate, calendar: calendar)
            updatedRule.timesOfDay.append(last.addingMinutes(60))
        }
    }

    private func removeTime(at index: Int) {
        guard rule.timesOfDay.count > 1, rule.timesOfDay.indices.contains(index) else { return }
        updateRule { updatedRule in
            guard updatedRule.timesOfDay.count > 1,
                  updatedRule.timesOfDay.indices.contains(index)
            else { return }
            updatedRule.timesOfDay.remove(at: index)
        }
    }

    private func updateRule(
        _ update: (inout RoutineAdvancedRecurrenceRule) -> Void
    ) {
        var updatedRule = rule
        update(&updatedRule)
        rule = updatedRule.normalized(calendar: calendar)
    }
}
