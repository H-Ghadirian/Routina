import SwiftUI

struct TaskFormMacSectionCard<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassPanel(cornerRadius: 14, tint: .secondary, tintOpacity: 0.06)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
        )
    }
}

struct TaskFormMacControlBlock<Content: View>: View {
    let title: String
    var caption: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content
            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TaskFormMacInfoPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.secondary.opacity(0.10)))
    }
}

struct TaskFormMacIdentityCard<NameField: View>: View {
    let model: TaskFormModel
    let previewScheduleModeTitle: String?
    let previewPlaceSummary: String?
    @ViewBuilder let nameField: NameField

    var body: some View {
        TaskFormMacSectionCard(title: "Identity") {
            VStack(alignment: .leading, spacing: 18) {
                if model.autofocusName {
                    HStack(alignment: .top, spacing: 16) {
                        Text(model.emoji.wrappedValue)
                            .font(.system(size: 30))
                            .frame(width: 60, height: 60)
                            .background(Circle().fill(Color.accentColor.opacity(0.16)))

                        VStack(alignment: .leading, spacing: 10) {
                            nameField
                            validationMessage
                            previewPills
                        }

                        Spacer(minLength: 0)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        nameField
                        validationMessage
                    }
                }

                TaskFormMacControlBlock(title: "") {
                    emojiPickerRow
                }
            }
        }
    }

    @ViewBuilder
    private var validationMessage: some View {
        if let message = model.nameValidationMessage {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var previewPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let previewScheduleModeTitle {
                    TaskFormMacInfoPill(title: previewScheduleModeTitle, systemImage: "repeat")
                }
                if let previewPlaceSummary {
                    TaskFormMacInfoPill(title: previewPlaceSummary, systemImage: "mappin.and.ellipse")
                }
            }
        }
    }

    private var emojiPickerRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button("More Emoji") {
                        model.isEmojiPickerPresented.wrappedValue = true
                    }
                    .buttonStyle(.bordered)

                    ForEach(Array(model.emojiOptions.prefix(8)), id: \.self) { emoji in
                        Button {
                            model.emoji.wrappedValue = emoji
                        } label: {
                            Text(emoji)
                                .font(.title3)
                                .frame(width: 34, height: 34)
                                .routinaGlassPill(
                                    tint: model.emoji.wrappedValue == emoji ? .accentColor : .secondary,
                                    tintOpacity: model.emoji.wrappedValue == emoji ? 0.20 : 0.08,
                                    interactive: true
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct TaskFormMacBehaviorCard<ChecklistComposer: View, ChecklistItemsContent: View>: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation
    let persianDeadlineText: String?
    @ViewBuilder let checklistItemComposer: ChecklistComposer
    @ViewBuilder let checklistItemsContent: ChecklistItemsContent

    var body: some View {
        TaskFormMacSectionCard(title: "Scheduling") {
            VStack(alignment: .leading, spacing: 18) {
                taskTypeControl
                routineScheduleControls
                repeatControls
                todoDeadlineControl
                reminderControl
            }
        }
    }

    private var taskTypeControl: some View {
        TaskFormMacControlBlock(title: "Kind", caption: presentation.taskTypeDescription) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Kind", selection: model.taskType) {
                    Text("Routine").tag(RoutineTaskType.routine)
                    Text("Todo").tag(RoutineTaskType.todo)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
    }

    @ViewBuilder
    private var routineScheduleControls: some View {
        if model.taskType.wrappedValue == .routine {
            TaskFormMacControlBlock(title: "Routine schedule", caption: presentation.scheduleBehaviorDescription) {
                HStack(spacing: 0) {
                    Picker("Routine Schedule", selection: model.scheduleBehavior) {
                        ForEach(RoutineScheduleBehavior.allCases) { behavior in
                            Text(behavior.rawValue).tag(behavior)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                    Spacer(minLength: 0)
                }
            }

            TaskFormMacControlBlock(title: "Routine type", caption: presentation.routineFormatDescription) {
                HStack(spacing: 0) {
                    Picker("Routine Type", selection: model.routineFormat) {
                        ForEach(RoutineFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                    Spacer(minLength: 0)
                }
            }

            if !presentation.isStepBasedMode {
                TaskFormMacControlBlock(title: "Checklist") {
                    VStack(alignment: .leading, spacing: 12) {
                        checklistItemComposer
                        checklistItemsContent
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var repeatControls: some View {
        if presentation.showsRepeatControls {
            if model.scheduleMode.wrappedValue.isSoftIntervalRoutine {
                softReminderControl
            } else {
                repeatPatternControls
            }
            assumedDoneControl
        }
    }

    private var softReminderControl: some View {
        TaskFormMacControlBlock(title: "Soft reminder") {
            VStack(alignment: .leading, spacing: 12) {
                frequencyStepper(prefix: "Highlight again after")

                Text("This routine stays visible and never becomes overdue. The app will just give it a softer nudge after this much time has passed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var repeatPatternControls: some View {
        TaskFormMacControlBlock(title: "Cadence") {
            HStack(spacing: 0) {
                Picker("Cadence", selection: model.recurrenceKind) {
                    ForEach(RoutineRecurrenceRule.Kind.allCases, id: \.self) { kind in
                        Text(kind.pickerTitle).tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
                Spacer(minLength: 0)
            }
        }

        switch model.recurrenceKind.wrappedValue {
        case .intervalDays:
            TaskFormMacControlBlock(title: "Repeat") {
                frequencyStepper(prefix: "Every")
            }
        case .dailyTime:
            recurrenceTimePicker
        case .weekly:
            weeklyControls
        case .monthlyDay:
            monthlyControls
        }
    }

    private func frequencyStepper(prefix: String) -> some View {
        HStack(spacing: 10) {
            Text(prefix)
                .foregroundStyle(.secondary)

            Stepper(value: model.frequencyValue, in: 1...365) {
                Text("\(model.frequencyValue.wrappedValue)")
                    .font(.body.monospacedDigit())
                    .frame(minWidth: 28, alignment: .trailing)
            }
            .fixedSize()

            Picker("Unit", selection: model.frequencyUnit) {
                ForEach(TaskFormFrequencyUnit.allCases, id: \.self) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 220)

            Spacer(minLength: 0)
        }
    }

    private var recurrenceTimePicker: some View {
        TaskFormMacControlBlock(title: "Availability") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Availability", selection: dailyTimingModeBinding) {
                    Text(TaskFormTimingMode.exact.rawValue).tag(TaskFormTimingMode.exact)
                    Text(TaskFormTimingMode.range.rawValue).tag(TaskFormTimingMode.range)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()

                if model.recurrenceHasTimeRange.wrappedValue {
                    timeRangePickers
                } else {
                    DatePicker(
                        "Time",
                        selection: model.recurrenceTimeOfDay,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
                Text(
                    presentation.dailyRecurrenceTimeHelpText(
                        exactTimeText: exactTimeText,
                        timeRangeText: timeRangeText
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var weeklyControls: some View {
        VStack(alignment: .leading, spacing: 18) {
            TaskFormMacControlBlock(title: "Weekday") {
                Picker("Weekday", selection: model.recurrenceWeekday) {
                    ForEach(presentation.weekdayOptions, id: \.id) { option in
                        Text(option.name).tag(option.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            TaskFormMacControlBlock(title: "Availability") {
                recurrenceExplicitTimeControls(
                    helpText: presentation.weeklyRecurrenceTimeHelpText(
                        explicitTimeText: exactTimeText,
                        timeRangeText: timeRangeText
                    )
                )
            }
        }
    }

    private var monthlyControls: some View {
        VStack(alignment: .leading, spacing: 18) {
            TaskFormMacControlBlock(title: "Month day") {
                Stepper(value: model.recurrenceDayOfMonth, in: 1...31) {
                    Text(TaskFormPresentation.ordinalDay(model.recurrenceDayOfMonth.wrappedValue))
                        .frame(minWidth: 40, alignment: .leading)
                }
                .fixedSize()
            }

            TaskFormMacControlBlock(title: "Availability") {
                recurrenceExplicitTimeControls(
                    helpText: presentation.monthlyRecurrenceTimeHelpText(
                        explicitTimeText: exactTimeText,
                        timeRangeText: timeRangeText
                    )
                )
            }
        }
    }

    private func recurrenceExplicitTimeControls(helpText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Availability", selection: timingModeBinding) {
                ForEach(TaskFormTimingMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()

            if model.recurrenceHasExplicitTime.wrappedValue {
                DatePicker(
                    "Time",
                    selection: model.recurrenceTimeOfDay,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
            } else if model.recurrenceHasTimeRange.wrappedValue {
                timeRangePickers
            }
            Text(helpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var timeRangePickers: some View {
        HStack(spacing: 12) {
            DatePicker(
                "Starts",
                selection: model.recurrenceTimeRangeStart,
                displayedComponents: .hourAndMinute
            )
            .fixedSize()

            DatePicker(
                "Ends",
                selection: model.recurrenceTimeRangeEnd,
                displayedComponents: .hourAndMinute
            )
            .fixedSize()
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

    private var assumedDoneControl: some View {
        TaskFormMacControlBlock(
            title: "Assumed done",
            caption: presentation.autoAssumeDailyDoneHelpText
        ) {
            Toggle("Assume done automatically", isOn: model.autoAssumeDailyDone)
                .disabled(!model.canAutoAssumeDailyDone)
        }
    }

    @ViewBuilder
    private var todoDeadlineControl: some View {
        if model.taskType.wrappedValue == .todo {
            TaskFormMacControlBlock(title: "Deadline") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Set deadline", isOn: model.deadlineEnabled)
                    if model.deadlineEnabled.wrappedValue {
                        DatePicker("Deadline", selection: model.deadline)
                            .labelsHidden()
                        if let persianDeadlineText {
                            Text(persianDeadlineText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var reminderControl: some View {
        TaskFormMacControlBlock(
            title: "Reminder",
            caption: model.reminderEventDate == nil
                ? "Send one notification at an exact date and time."
                : "Choose a lead time before the event, or set a custom notification time."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Set reminder", isOn: model.reminderEnabled)
                if model.reminderEnabled.wrappedValue {
                    if let reminderEventDate = model.reminderEventDate {
                        Picker("When", selection: model.reminderLeadMinutes) {
                            Text("Custom time").tag(Optional<Int>.none)
                            ForEach(TaskFormReminderLeadTime.allCases) { option in
                                Text(option.title).tag(Optional(option.rawValue))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180)

                        Text("Event: \(reminderEventDate.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    DatePicker(
                        model.reminderEventDate == nil ? "Reminder" : "Custom time",
                        selection: model.reminderAt
                    )
                    .labelsHidden()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TaskFormMacDangerZoneCard: View {
    let pauseResumeAction: (() -> Void)?
    let pauseResumeTitle: String?
    let pauseResumeDescription: String?
    let pauseResumeTint: Color?
    let onDelete: (() -> Void)?

    var body: some View {
        TaskFormMacSectionCard(title: "Danger Zone") {
            VStack(alignment: .leading, spacing: 10) {
                if let pauseResumeAction, let pauseResumeTitle {
                    Button(pauseResumeTitle) { pauseResumeAction() }
                        .buttonStyle(.bordered)
                        .tint(pauseResumeTint)

                    if let pauseResumeDescription {
                        Text(pauseResumeDescription)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    Divider()
                }

                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Text("Delete Task")
                    }
                    .buttonStyle(.borderless)

                    Text("This action cannot be undone.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
