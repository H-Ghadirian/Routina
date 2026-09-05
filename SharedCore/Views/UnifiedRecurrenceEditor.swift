import SwiftUI

enum UnifiedRecurrenceEditorLayout: Equatable {
    case compact
    case desktop

    var fillsSegmentedControlWidth: Bool {
        self == .compact
    }

    var cadenceMaximumSegmentsPerRow: Int? {
        self == .compact ? 2 : nil
    }

    var frequencyMaximumSegmentsPerRow: Int? {
        self == .compact ? 3 : nil
    }

    var fixedDetailsMaximumWidth: CGFloat? {
        self == .desktop ? 520 : nil
    }

    var weekdayMinimumCellWidth: CGFloat {
        self == .desktop ? 96 : 88
    }

    var weekdayMaximumWidth: CGFloat {
        self == .desktop ? 740 : 680
    }
}

enum UnifiedRecurrenceSummaryPolicy {
    static func showsSummary(for cadence: RoutineRecurrenceDraft.Cadence) -> Bool {
        cadence != .afterCompletion
    }
}

struct UnifiedRecurrenceEditor: View {
    @Binding var draft: RoutineRecurrenceDraft
    let supportsNoSchedule: Bool
    let supportsItemRunout: Bool
    let weekdayOptions: [(id: Int, name: String)]
    var layout: UnifiedRecurrenceEditorLayout = .compact

    @State var showsMoreOptions = false
    @State var referenceDate = Date()

    let calendar = Calendar.current

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

            if UnifiedRecurrenceSummaryPolicy.showsSummary(for: draft.cadence) {
                Label(draft.composerSummary(calendar: calendar), systemImage: summarySystemImage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Recurrence summary")
            }
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
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Repeat behavior",
            options: cadenceOptions,
            selection: draft.cadence,
            onSelect: selectCadence,
            minimumSegmentWidth: 110,
            horizontalPadding: 10,
            fillsAvailableWidth: layout.fillsSegmentedControlWidth,
            maximumSegmentsPerRow: layout.cadenceMaximumSegmentsPerRow
        ) { cadence in
            Text(cadenceTitle(cadence))
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
                fillsAvailableWidth: layout.fillsSegmentedControlWidth,
                maximumSegmentsPerRow: layout.frequencyMaximumSegmentsPerRow
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
                    options: weekdayOptions,
                    minimumCellWidth: layout.weekdayMinimumCellWidth,
                    maximumWidth: layout.weekdayMaximumWidth
                )
            }

        case .monthly:
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("On")
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Monthly pattern",
                    options: RoutineAdvancedRecurrenceRule.MonthlyPattern.allCases,
                    selection: monthlyPatternBinding,
                    fillsAvailableWidth: layout.fillsSegmentedControlWidth
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
                fixedScheduleModeRow

                if draft.requiresFixedScheduleDetails {
                    Text(requiredDetailsExplanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if draft.usesFixedScheduleDetails {
                    Divider()
                    fixedScheduleControls
                }
            }
            .padding(14)
            .frame(maxWidth: layout.fixedDetailsMaximumWidth, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
        } label: {
            HStack(spacing: 12) {
                Label("More schedule options", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))

                if layout == .desktop {
                    Spacer(minLength: 12)

                    Text(
                        TaskFormFixedSchedulePresentation.summary(
                            for: draft,
                            calendar: calendar
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var fixedScheduleModeRow: some View {
        if draft.requiresFixedScheduleDetails {
            HStack(spacing: 12) {
                Text("Fixed schedule")
                    .font(.body)

                Spacer(minLength: 12)

                Text("Required")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.10))
                    )
            }
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
        } else {
            Toggle(isOn: fixedDetailsBinding) {
                Text("Fixed schedule")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .toggleStyle(.switch)
            .controlSize(layout == .desktop ? .mini : .regular)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var fixedScheduleControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            if inlinesSingleOccurrenceTime {
                HStack(spacing: 18) {
                    fixedStartControl
                    singleOccurrenceTimeControl
                }
                .fixedSize(horizontal: true, vertical: false)
            } else {
                fixedStartControl
            }

            RecurrenceTimeZoneField(selection: timeZoneBinding)

            if !inlinesSingleOccurrenceTime {
                fixedFrequencyControls
            }
            endControls
        }
    }

    private var fixedStartControl: some View {
        DatePicker(
            "Starts",
            selection: startDateBinding,
            displayedComponents: fixedStartComponents
        )
    }

    private var singleOccurrenceTimeControl: some View {
        DatePicker(
            "At",
            selection: indexedTimeBinding(0),
            displayedComponents: .hourAndMinute
        )
    }

    private var inlinesSingleOccurrenceTime: Bool {
        TaskFormFixedSchedulePresentation.inlinesSingleOccurrenceTime(
            isDesktop: layout == .desktop,
            frequency: draft.frequency,
            occurrenceTimeCount: draft.occurrenceTimes.count
        )
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

    var fixedStartComponents: DatePickerComponents {
        TaskFormFixedSchedulePresentation.startIncludesTime(
            frequency: draft.frequency,
            availabilityUsesWindow: draft.availability.usesWindow
        )
            ? [.date, .hourAndMinute]
            : .date
    }

    private var hourlyControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Hourly schedule",
                options: RoutineAdvancedRecurrenceRule.HourlyMode.allCases,
                selection: valueBinding(\.hourlyMode),
                minimumSegmentWidth: 112,
                horizontalPadding: 10,
                fillsAvailableWidth: layout.fillsSegmentedControlWidth
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
}
