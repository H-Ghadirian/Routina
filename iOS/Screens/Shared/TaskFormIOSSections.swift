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
        }
    }
}

struct TaskFormIOSPlanningSection: View {
    let model: TaskFormModel

    var body: some View {
        Section(header: Text("Planning")) {
            Toggle("Plan to do", isOn: plannedDateEnabled)
            if model.plannedDate.wrappedValue != nil {
                DatePicker(
                    "Date",
                    selection: plannedDate,
                    displayedComponents: .date
                )
            }
        }
    }

    private var plannedDateEnabled: Binding<Bool> {
        Binding(
            get: { model.plannedDate.wrappedValue != nil },
            set: { isEnabled in
                model.plannedDate.wrappedValue = isEnabled
                    ? (model.plannedDate.wrappedValue ?? Date())
                    : nil
            }
        )
    }

    private var plannedDate: Binding<Date> {
        Binding(
            get: { model.plannedDate.wrappedValue ?? Date() },
            set: { model.plannedDate.wrappedValue = $0 }
        )
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
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Pressure",
                options: RoutineTaskPressure.allCases,
                selection: model.pressure,
                fillsAvailableWidth: true
            ) { pressure in
                Text(pressure.title)
            }
            Text("Use this for tasks that keep occupying your mind, even when they are not the most urgent.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct TaskFormIOSScheduleTypeSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    @ViewBuilder
    var body: some View {
        if model.scheduleMode.wrappedValue.taskType == .routine {
            Section(header: Text("Due Style")) {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Due Style",
                    options: RoutineScheduleBehavior.allCases,
                    selection: model.scheduleBehavior,
                    fillsAvailableWidth: true
                ) { behavior in
                    Text(behavior.rawValue)
                }
                TaskFormIOSScheduleBehaviorHint(behavior: model.scheduleBehavior.wrappedValue)
            }
        }

        Section(header: Text("Completion")) {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Completion",
                options: RoutineFinishMode.allCases,
                selection: model.routineFinishMode,
                fillsAvailableWidth: true
            ) { mode in
                Text(mode.rawValue)
            }
        }
    }
}

private struct TaskFormIOSScheduleBehaviorHint: View {
    let behavior: RoutineScheduleBehavior

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(behavior.rowPreviewBadges) { badge in
                    TaskFormIOSScheduleBehaviorPreviewBadge(badge: badge)
                }
            }

            Text(behavior.rowPreviewDescription)
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
        case .ready: return 0.12
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
            if let message = model.checklistValidationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
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
        Section(header: Text("Places")) {
            HStack {
                TaskFormPlaceSelectionMenu(model: model)
                Spacer()
                Button {
                    onManagePlaces()
                } label: {
                    Label("Manage", systemImage: "map")
                }
            }
            TaskFormSelectedPlacesView(model: model)
            TaskFormPlaceOptionsView(model: model)
        }
    }
}

struct TaskFormIOSRepeatPatternSections: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        if presentation.showsRepeatControls {
            repeatPatternSection
            recurrenceSpecificSections
        }

        if model.taskType.wrappedValue == .routine, showsAssumedDoneSection {
            assumedDoneSection
        }
    }

    @ViewBuilder
    private var repeatPatternSection: some View {
        Section(header: Text("Repeat Type")) {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Repeat Type",
                options: model.routineRepeatTypeCases,
                selection: model.routineRepeatType,
                fillsAvailableWidth: true
            ) { repeatType in
                Text(repeatType.rawValue)
            }
            if model.routineRepeatType.wrappedValue != .itemRunout && model.routineRepeatType.wrappedValue != .none {
                Text(presentation.recurrencePatternDescription).font(.caption).foregroundStyle(.secondary)
            }
            if model.taskType.wrappedValue == .record && model.routineRepeatType.wrappedValue != .none {
                Toggle("Nudges", isOn: model.trackingNudgesEnabled)
            }
        }

        if model.routineRepeatType.wrappedValue == .calendar {
            calendarPatternSection
        }
    }

    private var calendarPatternSection: some View {
        Section(header: Text("Calendar Pattern")) {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Calendar Pattern",
                options: RoutineRecurrenceRule.Kind.calendarCases,
                selection: model.calendarRecurrenceKind,
                fillsAvailableWidth: true
            ) { kind in
                Text(kind.pickerTitle)
            }
        }
    }

    @ViewBuilder
    private var recurrenceSpecificSections: some View {
        switch model.routineRepeatType.wrappedValue {
        case .none:
            EmptyView()

        case .interval:
            Section(header: Text("Frequency")) {
                frequencyUnitPicker
            }
            Section(header: Text("Repeat")) {
                Stepper(value: model.frequencyValue, in: model.intervalFrequencyValueBounds) {
                    Text(intervalRepeatLabel)
                }
            }

        case .calendar:
            calendarSpecificSections

        case .itemRunout:
            EmptyView()
        }
    }

    @ViewBuilder
    private var calendarSpecificSections: some View {
        switch model.recurrenceKind.wrappedValue {
        case .intervalDays, .dailyTime:
            EmptyView()

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

        case .monthlyDay:
            Section(header: Text("Day of Month")) {
                Stepper(value: model.recurrenceDayOfMonth, in: 1...31) {
                    Text(TaskFormPresentation.monthDayControlLabel(for: model.recurrenceDayOfMonth.wrappedValue))
                }
                Text(presentation.monthlyRecurrenceSummary)
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var frequencyUnitPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Frequency",
            options: TaskFormFrequencyUnit.allCases,
            selection: model.frequencyUnit,
            fillsAvailableWidth: true
        ) { unit in
            Text(unit.rawValue)
        }
    }

    private var intervalRepeatLabel: String {
        let label = TaskFormPresentation.stepperLabel(
            unit: model.frequencyUnit.wrappedValue,
            value: model.frequencyValue.wrappedValue
        )
        return model.scheduleBehavior.wrappedValue == .soft && model.trackingNudgesEnabled.wrappedValue
            ? "Nudge \(label.lowercased())"
            : label
    }

    private var showsAssumedDoneSection: Bool {
        model.canAutoAssumeDailyDone
            || (model.taskType.wrappedValue == .record && model.autoAssumeDailyDone.wrappedValue)
    }

    private var assumedDoneSection: some View {
        Section(header: Text("Assumed Done")) {
            Toggle("Auto-assume done", isOn: model.autoAssumeDailyDone)
                .disabled(!model.canAutoAssumeDailyDone)
            Text(presentation.autoAssumeDailyDoneHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
