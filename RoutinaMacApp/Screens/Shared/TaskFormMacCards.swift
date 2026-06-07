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

struct TaskFormMacToggleBlock<Content: View>: View {
    let title: String
    var caption: String?
    @Binding var isOn: Bool
    var isDisabled = false
    @ViewBuilder let content: Content

    init(
        title: String,
        isOn: Binding<Bool>,
        caption: String? = nil,
        isDisabled: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.caption = caption
        self._isOn = isOn
        self.isDisabled = isDisabled
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(.body.weight(.medium))
            }
            .disabled(isDisabled)

            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isOn {
                content
                    .padding(.top, 2)
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
    let previewPlaceSummary: String?
    let smartNameDraft: RoutinaQuickAddDraft?
    let smartNameCalendar: Calendar
    let onApplySmartName: (() -> Void)?
    @ViewBuilder let nameField: NameField

    var body: some View {
        TaskFormMacSectionCard(title: "Identity") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    selectedEmojiButton

                    VStack(alignment: .leading, spacing: 8) {
                        nameField
                        validationMessage
                        smartNamePreview
                        previewPills
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                emojiPickerRow
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

    @ViewBuilder
    private var previewPills: some View {
        if !previewPillItems.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(previewPillItems) { item in
                        TaskFormMacInfoPill(title: item.title, systemImage: item.systemImage)
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(height: 28)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var previewPillItems: [PreviewPillItem] {
        var items: [PreviewPillItem] = []
        if let previewPlaceSummary {
            items.append(PreviewPillItem(title: previewPlaceSummary, systemImage: "mappin.and.ellipse"))
        }
        return items
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
                        .help("Apply detected details with Tab")
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
            SmartNameRow(
                title: draft.scheduleMode == .oneOff ? "Task" : "Routine",
                value: draft.name,
                systemImage: "textformat"
            )
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

    private var selectedEmojiButton: some View {
        Button {
            model.isEmojiPickerPresented.wrappedValue = true
        } label: {
            Text(model.emoji.wrappedValue)
                .font(.system(size: 30))
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor.opacity(0.16)))
                .overlay(
                    Circle()
                        .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
                )
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(Color.accentColor))
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
                        .accessibilityHidden(true)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help("Choose emoji")
        .accessibilityLabel("Choose task emoji")
    }

    private var emojiPickerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Color.clear
                .frame(width: 56, height: 1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(model.emojiOptions.prefix(12)), id: \.self) { emoji in
                        quickEmojiButton(emoji)
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(height: 34)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func quickEmojiButton(_ emoji: String) -> some View {
        Button {
            model.emoji.wrappedValue = emoji
        } label: {
            Text(emoji)
                .font(.title3)
                .frame(width: 32, height: 32)
                .routinaGlassPill(
                    tint: model.emoji.wrappedValue == emoji ? .accentColor : .secondary,
                    tintOpacity: model.emoji.wrappedValue == emoji ? 0.20 : 0.08,
                    interactive: true
                )
                .overlay(
                    Circle()
                        .stroke(
                            model.emoji.wrappedValue == emoji ? Color.accentColor.opacity(0.42) : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help("Use \(emoji)")
        .accessibilityLabel("Use \(emoji) emoji")
    }

    private struct PreviewPillItem: Identifiable {
        let title: String
        let systemImage: String

        var id: String { "\(title):\(systemImage)" }
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
            ViewThatFits(in: .horizontal) {
                wideSchedulingLayout
                compactSchedulingLayout
            }
            .frame(minHeight: schedulingContentMinHeight, alignment: .topLeading)
        }
    }

    private var schedulingContentMinHeight: CGFloat {
        switch model.taskType.wrappedValue {
        case .todo:
            return 180
        case .routine:
            if model.scheduleMode.wrappedValue.isChecklistDrivenMode {
                return 240
            }
            if model.scheduleMode.wrappedValue.isSoftIntervalRoutine {
                return 340
            }
            return 320
        }
    }

    private var wideSchedulingLayout: some View {
        HStack(alignment: .top, spacing: 28) {
            schedulingMainColumn
                .frame(maxWidth: 760, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            schedulingSupportColumn
                .frame(width: 420, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactSchedulingLayout: some View {
        VStack(alignment: .leading, spacing: 18) {
            schedulingMainColumn
            Divider()
            schedulingSupportColumn
        }
        .frame(maxWidth: 820, alignment: .leading)
    }

    private var schedulingMainColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            scheduleBasicsControls

            if model.taskType.wrappedValue == .routine {
                Divider()
                routineScheduleControls
                routineCadenceControls
            }
        }
    }

    private var schedulingSupportColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.taskType.wrappedValue == .routine {
                scheduleResultPreview

                if showsAssumedDoneControl {
                    assumedDoneControl
                }
            }

            reminderControl

            if model.taskType.wrappedValue == .todo {
                todoDeadlineControl
            }
        }
    }

    @ViewBuilder
    private var scheduleBasicsControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            taskTypeControl
            if showsAvailabilityControl {
                availabilityControl
            }
        }
    }

    private var taskTypeControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Task type", selection: model.taskType) {
                Text("Routine").tag(RoutineTaskType.routine)
                Text("Todo").tag(RoutineTaskType.todo)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()

            Text(presentation.taskTypeDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var showsAvailabilityControl: Bool {
        switch model.taskType.wrappedValue {
        case .todo:
            return true
        case .routine:
            return presentation.showsRepeatControls
        }
    }

    @ViewBuilder
    private var routineScheduleControls: some View {
        if model.taskType.wrappedValue == .routine {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 22) {
                    scheduleBehaviorControl
                        .frame(width: 260, alignment: .leading)
                    routineFormatControl
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 18) {
                    scheduleBehaviorControl
                    routineFormatControl
                }
            }
        }
    }

    private var scheduleBehaviorControl: some View {
        TaskFormMacControlBlock(title: "Due style") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Due style", selection: model.scheduleBehavior) {
                    ForEach(RoutineScheduleBehavior.allCases) { behavior in
                        Text(behavior.rawValue).tag(behavior)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()

                Text(presentation.scheduleBehaviorDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var routineFormatControl: some View {
        TaskFormMacControlBlock(title: "Completion") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Completion", selection: model.routineFinishMode) {
                    ForEach(RoutineFinishMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()

                Text(presentation.routineFinishDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var routineCadenceControls: some View {
        VStack(alignment: .leading, spacing: 18) {
            if presentation.showsChecklistTimingControls {
                checklistTimingControl
            }

            if presentation.showsRepeatControls {
                repeatPatternControls
            }
        }
    }

    private var checklistTimingControl: some View {
        TaskFormMacControlBlock(title: "Checklist cadence") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Checklist cadence", selection: model.checklistTimingMode) {
                    ForEach(ChecklistTimingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()

                Text(presentation.checklistTimingDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var scheduleResultPreview: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Row badge preview")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TaskFormMacScheduleBehaviorHint(
                behavior: model.scheduleBehavior.wrappedValue,
                description: model.scheduleBehavior.wrappedValue.rowPreviewDescription
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(schedulePreviewTint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(schedulePreviewTint.opacity(0.18), lineWidth: 1)
        )
    }

    private var schedulePreviewTint: Color {
        model.scheduleBehavior.wrappedValue == .soft ? .teal : .orange
    }

    @ViewBuilder
    private var repeatPatternControls: some View {
        TaskFormMacControlBlock(title: "Repeat type") {
            HStack(spacing: 0) {
                Picker("Repeat type", selection: model.repeatBasis) {
                    ForEach(RoutineRepeatBasis.allCases) { basis in
                        Text(basis.rawValue).tag(basis)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
                Spacer(minLength: 0)
            }
        }

        if model.repeatBasis.wrappedValue == .calendar {
            calendarPatternControl
        }

        switch model.recurrenceKind.wrappedValue {
        case .intervalDays:
            TaskFormMacControlBlock(title: "Repeat") {
                frequencyStepper(prefix: intervalFrequencyPrefix)
            }
        case .dailyTime:
            EmptyView()
        case .weekly:
            weeklyControls
        case .monthlyDay:
            monthlyControls
        }
    }

    private var intervalFrequencyPrefix: String {
        model.scheduleBehavior.wrappedValue == .soft ? "Nudge every" : "Every"
    }

    private var calendarPatternControl: some View {
        TaskFormMacControlBlock(title: "Calendar pattern") {
            HStack(spacing: 0) {
                Picker("Calendar pattern", selection: model.calendarRecurrenceKind) {
                    ForEach(RoutineRecurrenceRule.Kind.calendarCases, id: \.self) { kind in
                        Text(kind.pickerTitle).tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
                Spacer(minLength: 0)
            }
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

    private var availabilityControl: some View {
        TaskFormMacControlBlock(title: "Availability") {
            recurrenceExplicitTimeControls(helpText: availabilityHelpText)
        }
    }

    private var weeklyControls: some View {
        weeklyDayControl
    }

    private var weeklyDayControl: some View {
        TaskFormMacControlBlock(title: "Weekday") {
            Picker("Weekday", selection: model.recurrenceWeekday) {
                ForEach(presentation.weekdayOptions, id: \.id) { option in
                    Text(option.name).tag(option.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var monthlyControls: some View {
        monthlyDayControl
    }

    private var monthlyDayControl: some View {
        TaskFormMacControlBlock(title: "Month day") {
            Stepper(value: model.recurrenceDayOfMonth, in: 1...31) {
                Text("Day \(model.recurrenceDayOfMonth.wrappedValue) of each month")
                    .frame(minWidth: 180, alignment: .leading)
            }
            .fixedSize()
        }
    }

    private func recurrenceExplicitTimeControls(helpText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Availability", selection: timingModeBinding) {
                ForEach(TaskFormTimingMode.cases(for: model.taskType.wrappedValue)) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()

            if currentTimingMode == .exact {
                DatePicker(
                    "Time",
                    selection: model.recurrenceTimeOfDay,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
            } else if currentTimingMode == .range {
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

    private var availabilityHelpText: String {
        presentation.availabilityControlHelpText(isAllDay: model.isAllDay.wrappedValue)
    }

    private var timingModeBinding: Binding<TaskFormTimingMode> {
        Binding(
            get: {
                if model.isAllDay.wrappedValue {
                    return .allDay
                }
                if model.recurrenceHasTimeRange.wrappedValue {
                    return .range
                }
                if model.recurrenceHasExplicitTime.wrappedValue {
                    return .exact
                }
                return .none
            },
            set: { mode in
                model.isAllDay.wrappedValue = mode == .allDay
                model.recurrenceHasExplicitTime.wrappedValue = mode == .exact
                model.recurrenceHasTimeRange.wrappedValue = mode == .range
            }
        )
    }

    private var currentTimingMode: TaskFormTimingMode {
        timingModeBinding.wrappedValue
    }

    private var showsAssumedDoneControl: Bool {
        model.canAutoAssumeDailyDone || model.autoAssumeDailyDone.wrappedValue
    }

    private var assumedDoneControl: some View {
        TaskFormMacToggleBlock(
            title: "Auto-assume done",
            isOn: model.autoAssumeDailyDone,
            caption: presentation.autoAssumeDailyDoneHelpText,
            isDisabled: !model.canAutoAssumeDailyDone
        ) {
            EmptyView()
        }
    }

    @ViewBuilder
    private var todoDeadlineControl: some View {
        if model.taskType.wrappedValue == .todo {
            TaskFormMacToggleBlock(
                title: "Set deadline",
                isOn: model.deadlineEnabled
            ) {
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

    private var reminderControl: some View {
        TaskFormMacToggleBlock(
            title: "Set reminder",
            isOn: model.reminderEnabled,
            caption: model.reminderEventDate == nil
                ? "One notification at a specific date and time."
                : "Notify before the scheduled time, or choose a custom time."
        ) {
            VStack(alignment: .leading, spacing: 10) {
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
