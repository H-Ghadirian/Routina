import SwiftUI

struct TaskFormIOSDeadlineSection: View {
    let model: TaskFormModel
    let persianDeadlineText: String?

    var body: some View {
        Section(header: Text("Deadline")) {
            Toggle("Set deadline", isOn: model.deadlineEnabled)
            if model.deadlineEnabled.wrappedValue {
                DatePicker(
                    "Deadline",
                    selection: model.deadline,
                    displayedComponents: model.isAllDay.wrappedValue ? .date : [.date, .hourAndMinute]
                )
                if let persianDeadlineText {
                    Text(persianDeadlineText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct TaskFormIOSReminderSection: View {
    let model: TaskFormModel

    var body: some View {
        Section(header: Text("Reminder")) {
            Toggle("Set reminder", isOn: model.reminderEnabled)
            if model.reminderEnabled.wrappedValue {
                if let reminderEventDate = model.reminderEventDate {
                    Picker("When", selection: model.reminderLeadMinutes) {
                        Text("Custom time").tag(Optional<Int>.none)
                        ForEach(TaskFormReminderLeadTime.allCases) { option in
                            Text(option.title).tag(Optional(option.rawValue))
                        }
                    }

                    Text("Event: \(reminderEventDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DatePicker(
                    model.reminderEventDate == nil ? "Reminder" : "Custom time",
                    selection: model.reminderAt
                )
            }
            Text(model.reminderEventDate == nil
                ? "Send one notification at an exact date and time."
                : "Choose a lead time before the event, or set a custom notification time.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TaskFormIOSImportanceUrgencySection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        Section(header: Text("Importance & Urgency")) {
            ImportanceUrgencyMatrixPicker(importance: model.importance, urgency: model.urgency)
            Text(presentation.importanceUrgencyDescription(includesDerivedPriority: true))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TaskFormIOSPressureSection: View {
    let model: TaskFormModel

    var body: some View {
        Section(header: Text("Pressure")) {
            Picker("Pressure", selection: model.pressure) {
                ForEach(RoutineTaskPressure.allCases, id: \.self) { pressure in
                    Text(pressure.title).tag(pressure)
                }
            }
            .pickerStyle(.segmented)
            Text("Use this for tasks that keep occupying your mind, even when they are not the most urgent.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TaskFormIOSScheduleTypeSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        Section(header: Text("Schedule Behavior")) {
            Picker("Schedule Behavior", selection: model.scheduleBehavior) {
                ForEach(RoutineScheduleBehavior.allCases) { behavior in
                    Text(behavior.rawValue).tag(behavior)
                }
            }
            .pickerStyle(.segmented)
            TaskFormIOSScheduleBehaviorHint(
                behavior: model.scheduleBehavior.wrappedValue,
                description: presentation.scheduleBehaviorDescription
            )
        }

        Section(header: Text("Routine Finish")) {
            Picker("How it finishes", selection: model.routineFinishMode) {
                ForEach(RoutineFinishMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text(presentation.routineFinishDescription).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct TaskFormIOSScheduleBehaviorHint: View {
    let behavior: RoutineScheduleBehavior
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(behavior.rowPreviewBadges) { badge in
                    TaskFormIOSScheduleBehaviorPreviewBadge(badge: badge)
                }
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct TaskFormIOSScheduleBehaviorPreviewBadge: View {
    let badge: RoutineScheduleBehaviorPreviewBadge

    var body: some View {
        Label(badge.title, systemImage: badge.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .routinaGlassPill(tint: tint, tintOpacity: tintOpacity)
    }

    private var tint: Color {
        switch badge.style {
        case .due: return .orange
        case .overdue: return .red
        case .ready: return .secondary
        case .gentle: return .teal
        }
    }

    private var tintOpacity: Double {
        switch badge.style {
        case .ready: return 0.10
        default: return 0.14
        }
    }
}

struct TaskFormIOSStepsSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        Section(header: Text("Steps")) {
            HStack(spacing: 10) {
                TextField("Wash clothes", text: model.stepDraft)
                    .onSubmit { model.onAddStep() }
                Button("Add") { model.onAddStep() }
                    .disabled(RoutineStep.normalizedTitle(model.stepDraft.wrappedValue) == nil)
            }
            if model.routineSteps.isEmpty {
                Label("No steps yet", systemImage: "list.bullet")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(model.routineSteps.enumerated()), id: \.element.id) { index, step in
                        HStack(spacing: 10) {
                            Text("\(index + 1).")
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                .frame(width: 22, alignment: .leading)
                            Text(step.title).frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 6) {
                                Button { model.onMoveStepUp(step.id) } label: {
                                    Image(systemName: "arrow.up")
                                }
                                .buttonStyle(.borderless).disabled(index == 0)
                                Button { model.onMoveStepDown(step.id) } label: {
                                    Image(systemName: "arrow.down")
                                }
                                .buttonStyle(.borderless).disabled(index == model.routineSteps.count - 1)
                                Button(role: .destructive) { model.onRemoveStep(step.id) } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            Text(presentation.stepsSectionDescription).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct TaskFormIOSChecklistSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        Section(header: Text("Checklist Items")) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Bread", text: model.checklistItemDraftTitle)
                    .onSubmit { model.onAddChecklistItem() }
                if model.scheduleMode.wrappedValue.isChecklistDrivenMode {
                    Stepper(value: model.checklistItemDraftInterval, in: 1...365) {
                        Text(TaskFormPresentation.checklistIntervalLabel(for: model.checklistItemDraftInterval.wrappedValue))
                    }
                }
                Button("Add Item") { model.onAddChecklistItem() }
                    .disabled(RoutineChecklistItem.normalizedTitle(model.checklistItemDraftTitle.wrappedValue) == nil)
            }
            if model.routineChecklistItems.isEmpty {
                Label("No checklist items yet", systemImage: "checklist")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(model.routineChecklistItems) { item in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).frame(maxWidth: .infinity, alignment: .leading)
                                if model.scheduleMode.wrappedValue.isChecklistDrivenMode {
                                    Text(TaskFormPresentation.checklistIntervalLabel(for: item.intervalDays))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Button(role: .destructive) { model.onRemoveChecklistItem(item.id) } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            Text(presentation.checklistSectionDescription(includesDerivedChecklistDueDetail: false))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TaskFormIOSPlaceSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation
    let onManagePlaces: () -> Void

    var body: some View {
        Section(header: Text("Place")) {
            Picker("Place", selection: model.selectedPlaceID) {
                Text("Anywhere").tag(Optional<UUID>.none)
                ForEach(model.availablePlaces) { place in
                    Text(place.name).tag(Optional(place.id))
                }
            }
            Button {
                onManagePlaces()
            } label: {
                Label("Manage Places", systemImage: "map")
            }
            Text(presentation.placeSelectionDescription).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct TaskFormIOSRepeatPatternSections: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        if presentation.showsChecklistTimingControls {
            checklistTimingSection
        }

        if presentation.showsRepeatControls {
            if model.scheduleMode.wrappedValue.isSoftIntervalRoutine {
                softReminderSection
            } else {
                repeatPatternSection
                recurrenceSpecificSections
            }
        }

        if model.taskType.wrappedValue == .routine {
            assumedDoneSection
        }
    }

    private var checklistTimingSection: some View {
        Section(header: Text("Checklist Cadence")) {
            Picker("Checklist Cadence", selection: model.checklistTimingMode) {
                ForEach(ChecklistTimingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            Text(presentation.checklistTimingDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var softReminderSection: some View {
        Section(header: Text("Gentle Reminder")) {
            frequencyUnitPicker

            Stepper(value: model.frequencyValue, in: 1...365) {
                Text("Highlight again after \(TaskFormPresentation.stepperLabel(unit: model.frequencyUnit.wrappedValue, value: model.frequencyValue.wrappedValue).lowercased())")
            }

            Text("This routine stays visible and never becomes overdue. Routina will gently nudge it again after this much time has passed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var repeatPatternSection: some View {
        Section(header: Text("Cadence")) {
            Picker("Cadence", selection: model.recurrenceKind) {
                ForEach(RoutineRecurrenceRule.Kind.allCases, id: \.self) { kind in
                    Text(kind.pickerTitle).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            Text(presentation.recurrencePatternDescription).font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var recurrenceSpecificSections: some View {
        switch model.recurrenceKind.wrappedValue {
        case .intervalDays:
            Section(header: Text("Frequency")) {
                frequencyUnitPicker
            }
            Section(header: Text("Repeat")) {
                Stepper(value: model.frequencyValue, in: 1...365) {
                    Text(TaskFormPresentation.stepperLabel(unit: model.frequencyUnit.wrappedValue, value: model.frequencyValue.wrappedValue))
                }
            }

        case .dailyTime:
            Section(header: Text("Availability")) {
                Picker("Availability", selection: dailyTimingModeBinding) {
                    Text(TaskFormTimingMode.exact.rawValue).tag(TaskFormTimingMode.exact)
                    Text(TaskFormTimingMode.range.rawValue).tag(TaskFormTimingMode.range)
                }
                .pickerStyle(.segmented)
                if model.recurrenceHasTimeRange.wrappedValue {
                    timeRangePickers
                } else {
                    DatePicker("Time", selection: model.recurrenceTimeOfDay, displayedComponents: .hourAndMinute)
                }
                Text(
                    presentation.dailyRecurrenceTimeHelpText(
                        exactTimeText: exactTimeText,
                        timeRangeText: timeRangeText
                    )
                )
                    .font(.caption).foregroundStyle(.secondary)
            }

        case .weekly:
            Section(header: Text("Weekday")) {
                Picker("Weekday", selection: model.recurrenceWeekday) {
                    ForEach(presentation.weekdayOptions, id: \.id) { option in
                        Text(option.name).tag(option.id)
                    }
                }
                Text(presentation.weeklyRecurrenceSummary)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(header: Text("Availability")) {
                timingModePicker
                if model.recurrenceHasExplicitTime.wrappedValue {
                    DatePicker("Time", selection: model.recurrenceTimeOfDay, displayedComponents: .hourAndMinute)
                } else if model.recurrenceHasTimeRange.wrappedValue {
                    timeRangePickers
                }
                Text(
                    presentation.weeklyRecurrenceTimeHelpText(
                        explicitTimeText: exactTimeText,
                        timeRangeText: timeRangeText
                    )
                )
                    .font(.caption).foregroundStyle(.secondary)
            }

        case .monthlyDay:
            Section(header: Text("Day of Month")) {
                Stepper(value: model.recurrenceDayOfMonth, in: 1...31) {
                    Text("Every \(TaskFormPresentation.ordinalDay(model.recurrenceDayOfMonth.wrappedValue))")
                }
                Text(presentation.monthlyRecurrenceSummary)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(header: Text("Availability")) {
                timingModePicker
                if model.recurrenceHasExplicitTime.wrappedValue {
                    DatePicker("Time", selection: model.recurrenceTimeOfDay, displayedComponents: .hourAndMinute)
                } else if model.recurrenceHasTimeRange.wrappedValue {
                    timeRangePickers
                }
                Text(
                    presentation.monthlyRecurrenceTimeHelpText(
                        explicitTimeText: exactTimeText,
                        timeRangeText: timeRangeText
                    )
                )
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var timingModePicker: some View {
        Picker("Availability", selection: timingModeBinding) {
            ForEach(TaskFormTimingMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    private var timeRangePickers: some View {
        VStack(spacing: 8) {
            DatePicker("Starts", selection: model.recurrenceTimeRangeStart, displayedComponents: .hourAndMinute)
            DatePicker("Ends", selection: model.recurrenceTimeRangeEnd, displayedComponents: .hourAndMinute)
        }
    }

    private var exactTimeText: String {
        model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened)
    }

    private var timeRangeText: String {
        "\(model.recurrenceTimeRangeStart.wrappedValue.formatted(date: .omitted, time: .shortened)) to \(model.recurrenceTimeRangeEnd.wrappedValue.formatted(date: .omitted, time: .shortened))"
    }

    private var timingModeBinding: Binding<TaskFormTimingMode> {
        Binding(
            get: {
                if model.recurrenceHasTimeRange.wrappedValue {
                    return .range
                }
                if model.recurrenceHasExplicitTime.wrappedValue {
                    return .exact
                }
                return .none
            },
            set: { mode in
                model.recurrenceHasExplicitTime.wrappedValue = mode == .exact
                model.recurrenceHasTimeRange.wrappedValue = mode == .range
            }
        )
    }

    private var dailyTimingModeBinding: Binding<TaskFormTimingMode> {
        Binding(
            get: {
                model.recurrenceHasTimeRange.wrappedValue ? .range : .exact
            },
            set: { mode in
                model.recurrenceHasTimeRange.wrappedValue = mode == .range
                model.recurrenceHasExplicitTime.wrappedValue = mode != .range
            }
        )
    }

    private var frequencyUnitPicker: some View {
        Picker("Frequency", selection: model.frequencyUnit) {
            ForEach(TaskFormFrequencyUnit.allCases, id: \.self) { unit in
                Text(unit.rawValue).tag(unit)
            }
        }
        .pickerStyle(.segmented)
    }

    private var assumedDoneSection: some View {
        Section(header: Text("Assumed Done")) {
            Toggle("Assume done automatically", isOn: model.autoAssumeDailyDone)
                .disabled(!model.canAutoAssumeDailyDone)
            Text(presentation.autoAssumeDailyDoneHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
