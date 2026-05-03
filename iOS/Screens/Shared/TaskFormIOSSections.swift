import SwiftUI

struct TaskFormIOSDeadlineSection: View {
    let model: TaskFormModel
    let persianDeadlineText: String?

    var body: some View {
        Section(header: Text("Deadline")) {
            Toggle("Set deadline", isOn: model.deadlineEnabled)
            if model.deadlineEnabled.wrappedValue {
                DatePicker("Deadline", selection: model.deadline)
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

struct TaskFormIOSEstimationSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        Section(header: Text("Estimation")) {
            Toggle("Set duration estimate", isOn: estimatedDurationEnabledBinding)
            if estimatedDurationEnabledBinding.wrappedValue {
                Stepper(value: estimatedDurationStepperBinding, in: 5...10_080, step: 5) {
                    Text(TaskFormPresentation.estimatedDurationLabel(for: estimatedDurationStepperBinding.wrappedValue))
                }
            }

            if model.taskType.wrappedValue == .todo, model.actualDurationMinutes != nil {
                Toggle("Set actual time spent", isOn: actualDurationEnabledBinding)
                if actualDurationEnabledBinding.wrappedValue {
                    Stepper(value: actualDurationStepperBinding, in: 1...1_440, step: 5) {
                        Text(TaskFormPresentation.estimatedDurationLabel(for: actualDurationStepperBinding.wrappedValue))
                    }
                }
            }

            Toggle("Set story points", isOn: storyPointsEnabledBinding)
            if storyPointsEnabledBinding.wrappedValue {
                Stepper(value: storyPointsStepperBinding, in: 1...100) {
                    Text(TaskFormPresentation.storyPointsLabel(for: storyPointsStepperBinding.wrappedValue))
                }
            }

            Toggle("Show focus timer", isOn: model.focusModeEnabled)

            Text(presentation.estimationHelpText).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var estimatedDurationEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.estimatedDurationMinutes.wrappedValue != nil },
            set: { isEnabled in
                model.estimatedDurationMinutes.wrappedValue = isEnabled
                    ? (model.estimatedDurationMinutes.wrappedValue ?? 30)
                    : nil
            }
        )
    }

    private var estimatedDurationStepperBinding: Binding<Int> {
        Binding(
            get: { max(model.estimatedDurationMinutes.wrappedValue ?? 30, 5) },
            set: { model.estimatedDurationMinutes.wrappedValue = RoutineTask.sanitizedEstimatedDurationMinutes(max($0, 5)) }
        )
    }

    private var actualDurationEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.actualDurationMinutes?.wrappedValue != nil },
            set: { isEnabled in
                guard let actualDurationMinutes = model.actualDurationMinutes else { return }
                actualDurationMinutes.wrappedValue = isEnabled
                    ? (actualDurationMinutes.wrappedValue ?? model.estimatedDurationMinutes.wrappedValue ?? 30)
                    : nil
            }
        )
    }

    private var actualDurationStepperBinding: Binding<Int> {
        Binding(
            get: { max(model.actualDurationMinutes?.wrappedValue ?? model.estimatedDurationMinutes.wrappedValue ?? 30, 1) },
            set: { model.actualDurationMinutes?.wrappedValue = RoutineTask.sanitizedActualDurationMinutes(max($0, 1)) }
        )
    }

    private var storyPointsEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.storyPoints.wrappedValue != nil },
            set: { isEnabled in
                model.storyPoints.wrappedValue = isEnabled
                    ? (model.storyPoints.wrappedValue ?? 1)
                    : nil
            }
        )
    }

    private var storyPointsStepperBinding: Binding<Int> {
        Binding(
            get: { max(model.storyPoints.wrappedValue ?? 1, 1) },
            set: { model.storyPoints.wrappedValue = RoutineTask.sanitizedStoryPoints(max($0, 1)) }
        )
    }
}

struct TaskFormIOSScheduleTypeSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        Section(header: Text("Schedule Type")) {
            Picker("Schedule Type", selection: model.scheduleMode) {
                Text("Fixed").tag(RoutineScheduleMode.fixedInterval)
                Text("Soft").tag(RoutineScheduleMode.softInterval)
                Text("Checklist").tag(RoutineScheduleMode.fixedIntervalChecklist)
                Text("Runout").tag(RoutineScheduleMode.derivedFromChecklist)
            }
            .pickerStyle(.segmented)
            Text(presentation.scheduleModeDescription).font(.caption).foregroundStyle(.secondary)
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
                if model.scheduleMode.wrappedValue == .derivedFromChecklist {
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
                                if model.scheduleMode.wrappedValue == .derivedFromChecklist {
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
        if model.scheduleMode.wrappedValue == .softInterval {
            softReminderSection
        } else {
            repeatPatternSection
            recurrenceSpecificSections
        }

        if model.taskType.wrappedValue == .routine {
            assumedDoneSection
        }
    }

    private var softReminderSection: some View {
        Section(header: Text("Soft Reminder")) {
            frequencyUnitPicker

            Stepper(value: model.frequencyValue, in: 1...365) {
                Text("Highlight again after \(TaskFormPresentation.stepperLabel(unit: model.frequencyUnit.wrappedValue, value: model.frequencyValue.wrappedValue).lowercased())")
            }

            Text("This routine stays visible and never becomes overdue. The app will just give it a softer nudge after this much time has passed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var repeatPatternSection: some View {
        Section(header: Text("Repeat Pattern")) {
            Picker("Repeat Pattern", selection: model.recurrenceKind) {
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
            Section(header: Text("Time of Day")) {
                DatePicker("Time", selection: model.recurrenceTimeOfDay, displayedComponents: .hourAndMinute)
                Text("Due every day at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened)).")
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
            Section(header: Text("Time of Day")) {
                Toggle("Set exact time", isOn: model.recurrenceHasExplicitTime)
                if model.recurrenceHasExplicitTime.wrappedValue {
                    DatePicker("Time", selection: model.recurrenceTimeOfDay, displayedComponents: .hourAndMinute)
                }
                Text(presentation.weeklyRecurrenceTimeHelpText())
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
            Section(header: Text("Time of Day")) {
                Toggle("Set exact time", isOn: model.recurrenceHasExplicitTime)
                if model.recurrenceHasExplicitTime.wrappedValue {
                    DatePicker("Time", selection: model.recurrenceTimeOfDay, displayedComponents: .hourAndMinute)
                }
                Text(presentation.monthlyRecurrenceTimeHelpText())
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
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
