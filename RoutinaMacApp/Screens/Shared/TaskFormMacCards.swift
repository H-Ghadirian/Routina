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

private struct TaskFormMacScheduleBehaviorHint: View {
    let behavior: RoutineScheduleBehavior
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(behavior.rowPreviewBadges) { badge in
                    TaskFormMacScheduleBehaviorPreviewBadge(badge: badge)
                }
            }

            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct TaskFormMacScheduleBehaviorPreviewBadge: View {
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

struct TaskFormMacIdentityCard<NameField: View>: View {
    let model: TaskFormModel
    let previewScheduleModeTitle: String?
    let previewPlaceSummary: String?
    let smartNameDraft: RoutinaQuickAddDraft?
    let smartNameCalendar: Calendar
    let onApplySmartName: (() -> Void)?
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
                            smartNamePreview
                            previewPills
                        }

                        Spacer(minLength: 0)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        nameField
                        validationMessage
                        smartNamePreview
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

    @ViewBuilder
    private var smartNamePreview: some View {
        if let smartNameDraft {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Label("Detected from title", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    if let onApplySmartName {
                        Button {
                            onApplySmartName()
                        } label: {
                            Label("Apply", systemImage: "checkmark")
                        }
                        .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(smartNameRows(for: smartNameDraft)) { row in
                        smartNameRow(row)
                    }
                }
            }
            .padding(10)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.16), lineWidth: 1)
            )
        }
    }

    private func smartNameRows(for draft: RoutinaQuickAddDraft) -> [SmartNameRow] {
        var rows = [
            SmartNameRow(title: "Task", value: draft.name, systemImage: "textformat")
        ]

        if draft.scheduleMode != .oneOff {
            rows.append(SmartNameRow(
                title: draft.scheduleMode.isSoftIntervalRoutine ? "Gentle routine" : "Repeats",
                value: draft.recurrenceRule.displayText(calendar: smartNameCalendar),
                systemImage: "calendar"
            ))
        } else if let deadline = draft.deadline {
            rows.append(SmartNameRow(
                title: "Due",
                value: deadline.formatted(date: .abbreviated, time: .shortened),
                systemImage: "calendar"
            ))
        }

        if !draft.tags.isEmpty {
            rows.append(SmartNameRow(
                title: "Tags",
                value: draft.tags.map { "#\($0)" }.joined(separator: " "),
                systemImage: "tag"
            ))
        }

        if let placeName = draft.placeName {
            rows.append(SmartNameRow(
                title: "Place",
                value: "@\(placeName)",
                systemImage: "mappin.and.ellipse"
            ))
        }

        if draft.importance != .level2 || draft.urgency != .level2 {
            rows.append(SmartNameRow(
                title: "Priority",
                value: "\(draft.importance.title) / \(draft.urgency.title)",
                systemImage: "exclamationmark.triangle"
            ))
        }

        if let estimatedDurationMinutes = draft.estimatedDurationMinutes {
            rows.append(SmartNameRow(
                title: "Focus",
                value: "\(estimatedDurationMinutes)m",
                systemImage: "timer"
            ))
        }

        return rows
    }

    private func smartNameRow(_ row: SmartNameRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: row.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)

            Text(row.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 86, alignment: .leading)

            Text(row.value)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
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

    private struct SmartNameRow: Identifiable {
        let title: String
        let value: String
        let systemImage: String

        var id: String { "\(title):\(value)" }
    }
}

struct TaskFormMacBehaviorCard: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation
    let persianDeadlineText: String?

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
            TaskFormMacControlBlock(title: "Schedule behavior") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 0) {
                        Picker("Schedule Behavior", selection: model.scheduleBehavior) {
                            ForEach(RoutineScheduleBehavior.allCases) { behavior in
                                Text(behavior.rawValue).tag(behavior)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .fixedSize()
                        Spacer(minLength: 0)
                    }

                    TaskFormMacScheduleBehaviorHint(
                        behavior: model.scheduleBehavior.wrappedValue,
                        description: presentation.scheduleBehaviorDescription
                    )
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
        TaskFormMacControlBlock(title: "Gentle reminder") {
            VStack(alignment: .leading, spacing: 12) {
                frequencyStepper(prefix: "Highlight again after")

                Text("This routine stays visible and never becomes overdue. Routina will gently nudge it again after this much time has passed.")
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
                        Toggle("All Day", isOn: model.isAllDay)
                        DatePicker(
                            "Deadline",
                            selection: model.deadline,
                            displayedComponents: model.isAllDay.wrappedValue ? .date : [.date, .hourAndMinute]
                        )
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
