import SwiftUI

struct TaskFormMacSectionCard<Content: View, HeaderAccessory: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let headerAccessory: HeaderAccessory
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) where HeaderAccessory == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.headerAccessory = EmptyView()
        self.content = content()
    }

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.headerAccessory = headerAccessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 12)
                headerAccessory
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
            .toggleStyle(.switch)
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

struct TaskFormMacPlanningCard: View {
    let model: TaskFormModel

    var body: some View {
        TaskFormMacSectionCard(title: "Planning") {
            TaskFormMacToggleBlock(title: "Plan to do", isOn: plannedDateEnabled) {
                DatePicker(
                    "Date",
                    selection: plannedDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
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
        case .ready: return 0.12
        default: return 0.14
        }
    }
}

struct TaskFormMacIdentityCard<NameField: View>: View {
    let model: TaskFormModel
    let smartNameDraft: RoutinaQuickAddDraft?
    let smartNameCalendar: Calendar
    let onApplySmartName: (() -> Void)?
    @ViewBuilder let nameField: NameField

    var body: some View {
        TaskFormMacSectionCard(
            title: "Identity",
            headerAccessory: {
                actionButtons
            }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    selectedEmojiButton

                    VStack(alignment: .leading, spacing: 8) {
                        nameField
                        validationMessage
                        smartNamePreview
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                emojiPickerRow
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if model.onCancel != nil || model.onSave != nil {
            HStack(spacing: 8) {
                if let onCancel = model.onCancel {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                if let onSave = model.onSave {
                    Button {
                        onSave()
                    } label: {
                        if model.isSaving {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Saving…")
                            }
                            .accessibilityLabel("Saving task")
                        } else {
                            Text("Save")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(model.isSaveDisabled)
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
    @Environment(\.calendar) private var calendar

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
            return 130
        case .record:
            return 300
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
            } else if model.taskType.wrappedValue == .record {
                Divider()
                recordCompletionControl
                routineCadenceControls
                if showsAssumedDoneControl {
                    assumedDoneControl
                }
            }
        }
    }

    private var schedulingSupportColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.taskType.wrappedValue == .routine {
                scheduleResultPreview
            }

            if model.supportsExactDateReminder {
                reminderControl
            }

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

    @ViewBuilder
    private var taskTypeControl: some View {
        if model.visibilityMode == .progressiveCreate {
            creationTaskTypeControl
        } else {
            existingTaskTypeControl
        }
    }

    private var creationTaskTypeControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Task type",
                options: TaskFormCreationKind.allCases,
                selection: model.creationKind
            ) { kind in
                Text(kind.rawValue)
            }

            if model.creationKind.wrappedValue == .repeating {
                Toggle("Track this routine", isOn: model.tracksRepeatingTask)
                    .toggleStyle(.switch)
                    .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var existingTaskTypeControl: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                primaryKindControl
                taskKindControl
            }

            VStack(alignment: .leading, spacing: 10) {
                primaryKindControl
                taskKindControl
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var primaryKindControl: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Kind",
            options: TaskFormPrimaryKind.allCases,
            selection: model.primaryKind
        ) { kind in
            Text(kind.rawValue)
        }
    }

    @ViewBuilder
    private var taskKindControl: some View {
        if model.primaryKind.wrappedValue == .task {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Task kind",
                options: TaskFormTaskKind.allCases,
                selection: model.taskKind
            ) { kind in
                Text(kind.rawValue)
            }
        }
    }

    private var showsAvailabilityControl: Bool {
        switch model.taskType.wrappedValue {
        case .todo:
            return true
        case .routine:
            return presentation.showsRepeatControls
        case .record:
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

    private var recordCompletionControl: some View {
        TaskFormMacControlBlock(title: "Completion") {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Completion",
                options: RoutineFinishMode.allCases,
                selection: model.routineFinishMode
            ) { mode in
                Text(mode.rawValue)
            }
        }
    }

    private var scheduleBehaviorControl: some View {
        TaskFormMacControlBlock(title: "Due style") {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Due style",
                options: RoutineScheduleBehavior.allCases,
                selection: model.scheduleBehavior
            ) { behavior in
                Text(behavior.rawValue)
            }
        }
    }

    private var routineFormatControl: some View {
        TaskFormMacControlBlock(title: "Completion") {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Completion",
                options: RoutineFinishMode.allCases,
                selection: model.routineFinishMode
            ) { mode in
                Text(mode.rawValue)
            }
        }
    }

    @ViewBuilder
    private var routineCadenceControls: some View {
        VStack(alignment: .leading, spacing: 18) {
            if presentation.showsRepeatControls {
                repeatPatternControls
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
        if model.supportsAdvancedRecurrence {
            TaskFormMacControlBlock(title: "Repeat model") {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Repeat model",
                    options: RoutineRecurrenceEditorMode.allCases,
                    selection: model.recurrenceEditorMode
                ) { mode in
                    Text(mode.rawValue)
                }
            }
        }

        if model.recurrenceEditorMode.wrappedValue == .advanced,
           model.supportsAdvancedRecurrence {
            TaskFormMacControlBlock(title: "Advanced recurrence") {
                AdvancedRecurrenceEditor(
                    rule: model.advancedRecurrenceRule,
                    weekdayOptions: presentation.weekdayOptions
                )
            }
            if model.taskType.wrappedValue == .record {
                TaskFormMacControlBlock(title: "Nudges") {
                    Toggle("Nudges", isOn: model.trackingNudgesEnabled)
                        .toggleStyle(.switch)
                }
            }
        } else {
            TaskFormMacControlBlock(title: "Repeat type") {
                HStack(spacing: 0) {
                    RoutinaGlassSegmentedControl(
                        accessibilityLabel: "Repeat type",
                        options: model.routineRepeatTypeCases,
                        selection: model.routineRepeatType
                    ) { repeatType in
                        Text(repeatType.rawValue)
                    }
                    Spacer(minLength: 0)
                }
            }

            if model.routineRepeatType.wrappedValue == .calendar {
                calendarPatternControl
            }

            if model.taskType.wrappedValue == .record && model.routineRepeatType.wrappedValue != .none {
                TaskFormMacControlBlock(title: "Nudges") {
                    Toggle("Nudges", isOn: model.trackingNudgesEnabled)
                        .toggleStyle(.switch)
                }
            }

            switch model.routineRepeatType.wrappedValue {
            case .none:
                EmptyView()

            case .interval:
                TaskFormMacControlBlock(title: "Repeat") {
                    frequencyStepper(prefix: intervalFrequencyPrefix)
                }
            case .calendar:
                calendarSpecificControls
            case .itemRunout:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var calendarSpecificControls: some View {
        switch model.recurrenceKind.wrappedValue {
        case .intervalDays, .dailyTime:
            EmptyView()
        case .weekly:
            weeklyControls
        case .monthlyDay:
            monthlyControls
        }
    }

    private var intervalFrequencyPrefix: String {
        model.scheduleBehavior.wrappedValue == .soft && model.trackingNudgesEnabled.wrappedValue
            ? "Nudge every"
            : "Every"
    }

    private var calendarPatternControl: some View {
        TaskFormMacControlBlock(title: "Calendar pattern") {
            HStack(spacing: 0) {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Calendar pattern",
                    options: RoutineRecurrenceRule.Kind.calendarCases,
                    selection: model.calendarRecurrenceKind
                ) { kind in
                    Text(kind.pickerTitle)
                }
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

            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Unit",
                options: TaskFormFrequencyUnit.allCases,
                selection: model.frequencyUnit,
                fillsAvailableWidth: true
            ) { unit in
                Text(unit.rawValue)
            }
            .frame(width: 220)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var availabilityControl: some View {
        if model.taskType.wrappedValue == .todo {
            TaskFormMacControlBlock(title: "Date availability") {
                dateAvailabilityControls
            }
            TaskFormMacControlBlock(title: "Time availability") {
                timeAvailabilityControls
            }
        } else {
            TaskFormMacControlBlock(title: "Duration") {
                routineDurationControls
            }
            TaskFormMacControlBlock(title: "Time availability") {
                timeAvailabilityControls
            }
        }
    }

    private var weeklyControls: some View {
        weeklyDayControl
    }

    private var weeklyDayControl: some View {
        TaskFormMacControlBlock(title: "Weekday") {
            LazyVGrid(columns: weekdayGridColumns, alignment: .leading, spacing: 8) {
                ForEach(presentation.weekdayOptions, id: \.id) { option in
                    Toggle(option.name, isOn: weekdaySelectionBinding(for: option.id))
                        .toggleStyle(.button)
                }
            }

            Text(presentation.weeklyRecurrenceSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var monthlyControls: some View {
        monthlyDayControl
    }

    private var monthlyDayControl: some View {
        TaskFormMacControlBlock(title: "Month day") {
            LazyVGrid(columns: monthDayGridColumns, alignment: .leading, spacing: 8) {
                ForEach(1...31, id: \.self) { day in
                    Toggle(isOn: monthDaySelectionBinding(for: day)) {
                        Text("\(day)")
                            .frame(maxWidth: .infinity)
                    }
                    .toggleStyle(.button)
                    .accessibilityLabel(TaskFormPresentation.monthDayControlLabel(for: day))
                }
            }

            Text(presentation.monthlyRecurrenceSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var weekdayGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 96), spacing: 8)]
    }

    private var monthDayGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 44), spacing: 8)]
    }

    private func weekdaySelectionBinding(for weekday: Int) -> Binding<Bool> {
        Binding(
            get: { model.effectiveRecurrenceWeekdays.contains(weekday) },
            set: { isSelected in
                let updatedWeekdays = updatedSelection(
                    value: weekday,
                    isSelected: isSelected,
                    selection: model.effectiveRecurrenceWeekdays
                )
                model.setRecurrenceWeekdays(updatedWeekdays)
            }
        )
    }

    private func monthDaySelectionBinding(for day: Int) -> Binding<Bool> {
        Binding(
            get: { model.effectiveRecurrenceDaysOfMonth.contains(day) },
            set: { isSelected in
                let updatedDays = updatedSelection(
                    value: day,
                    isSelected: isSelected,
                    selection: model.effectiveRecurrenceDaysOfMonth
                )
                model.setRecurrenceDaysOfMonth(updatedDays)
            }
        )
    }

    private func updatedSelection(
        value: Int,
        isSelected: Bool,
        selection: [Int]
    ) -> [Int] {
        var selectedValues = Set(selection)
        if isSelected {
            selectedValues.insert(value)
        } else {
            guard selectedValues.count > 1 else { return selection.sorted() }
            selectedValues.remove(value)
        }
        return selectedValues.sorted()
    }

    private var dateAvailabilityControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Date availability",
                options: TaskFormDateAvailabilityMode.allCases,
                selection: dateAvailabilityModeBinding
            ) { mode in
                Text(mode.rawValue)
            }

            dateAvailabilityPickers
        }
    }

    private var timeAvailabilityControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Time availability",
                options: TaskFormTimingMode.cases(for: model.taskType.wrappedValue),
                selection: timingModeBinding
            ) { mode in
                Text(mode.rawValue)
            }

            if currentTimingMode == .exact {
                DatePicker(
                    "Time",
                    selection: model.recurrenceTimeOfDay,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
            } else if currentTimingMode.usesTimeRange {
                if let timeRangeHelpText {
                    Text(timeRangeHelpText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                routineTimeRangePickers
            }
        }
    }

    private var routineDurationControls: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Duration",
            options: RoutineDurationMode.allCases,
            selection: model.routineDurationMode
        ) { mode in
            Text(mode.rawValue)
        }
    }

    @ViewBuilder
    private var dateAvailabilityPickers: some View {
        switch currentDateAvailabilityMode {
        case .none:
            EmptyView()
        case .exact:
            DatePicker(
                "Date",
                selection: todoAvailabilityStartBinding,
                displayedComponents: .date
            )
            .fixedSize()
        case .range:
            todoDateRangePickers
        }
    }

    private var routineTimeRangePickers: some View {
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

    private var timeRangeHelpText: String? {
        let startText = model.recurrenceTimeRangeStart.wrappedValue.formatted(
            date: .omitted,
            time: .shortened
        )
        let endText = model.recurrenceTimeRangeEnd.wrappedValue.formatted(
            date: .omitted,
            time: .shortened
        )
        return currentTimingMode.timeRangeHelpText(
            startTimeText: startText,
            endTimeText: endText
        )
    }

    private var todoDateRangePickers: some View {
        HStack(spacing: 12) {
            DatePicker(
                "Starts",
                selection: todoAvailabilityStartBinding,
                displayedComponents: .date
            )
            .fixedSize()

            DatePicker(
                "Ends",
                selection: todoAvailabilityEndBinding,
                displayedComponents: .date
            )
            .fixedSize()
        }
    }

    private var dateAvailabilityModeBinding: Binding<TaskFormDateAvailabilityMode> {
        Binding(
            get: {
                if model.availabilityStartDate.wrappedValue == nil {
                    return .none
                }
                if model.availabilityEndDate.wrappedValue != nil {
                    return .range
                }
                return .exact
            },
            set: { mode in
                applyTodoDateAvailabilityMode(mode)
            }
        )
    }

    private var currentDateAvailabilityMode: TaskFormDateAvailabilityMode {
        dateAvailabilityModeBinding.wrappedValue
    }

    private var timingModeBinding: Binding<TaskFormTimingMode> {
        Binding(
            get: {
                if model.isAllDay.wrappedValue {
                    return .allDay
                }
                if model.recurrenceHasTimeRange.wrappedValue {
                    return model.recurrenceTimeRangeRole.wrappedValue == .scheduledBlock
                        ? .timeBlock
                        : .availableWindow
                }
                if model.recurrenceHasExplicitTime.wrappedValue {
                    return .exact
                }
                return .none
            },
            set: { mode in
                applyTimingMode(mode)
            }
        )
    }

    private var currentTimingMode: TaskFormTimingMode {
        timingModeBinding.wrappedValue
    }

    private var todoAvailabilityStartBinding: Binding<Date> {
        Binding(
            get: { model.availabilityStartDate.wrappedValue ?? Date() },
            set: { setTodoAvailabilityStartDate($0) }
        )
    }

    private var todoAvailabilityEndBinding: Binding<Date> {
        Binding(
            get: {
                let start = model.availabilityStartDate.wrappedValue ?? Date()
                return model.availabilityEndDate.wrappedValue ?? dateAfter(start)
            },
            set: { setTodoAvailabilityEndDate($0) }
        )
    }

    private func applyTimingMode(_ mode: TaskFormTimingMode) {
        model.isAllDay.wrappedValue = mode == .allDay
        model.recurrenceHasExplicitTime.wrappedValue = mode == .exact
        model.recurrenceHasTimeRange.wrappedValue = mode.usesTimeRange
        if let role = mode.timeRangeRole {
            model.recurrenceTimeRangeRole.wrappedValue = role
        }
    }

    private func applyTodoDateAvailabilityMode(_ mode: TaskFormDateAvailabilityMode) {
        let start = model.availabilityStartDate.wrappedValue ?? Date()
        let end = model.availabilityEndDate.wrappedValue ?? dateAfter(start)
        switch mode {
        case .none:
            model.availabilityStartDate.wrappedValue = nil
            model.availabilityEndDate.wrappedValue = nil
        case .exact:
            model.availabilityStartDate.wrappedValue = calendar.startOfDay(for: start)
            model.availabilityEndDate.wrappedValue = nil
        case .range:
            let normalizedStart = calendar.startOfDay(for: start)
            let normalizedEnd = calendar.startOfDay(for: end)
            model.availabilityStartDate.wrappedValue = normalizedStart
            model.availabilityEndDate.wrappedValue = normalizedEnd < normalizedStart ? normalizedStart : normalizedEnd
        }
    }

    private func setTodoAvailabilityStartDate(_ date: Date) {
        let storedDate = calendar.startOfDay(for: date)
        model.availabilityStartDate.wrappedValue = storedDate

        if currentDateAvailabilityMode == .range,
           let end = model.availabilityEndDate.wrappedValue,
           calendar.startOfDay(for: end) < storedDate {
            model.availabilityEndDate.wrappedValue = storedDate
        }
    }

    private func setTodoAvailabilityEndDate(_ date: Date) {
        let start = calendar.startOfDay(for: model.availabilityStartDate.wrappedValue ?? Date())
        let storedDate = calendar.startOfDay(for: date)
        model.availabilityEndDate.wrappedValue = storedDate < start ? start : storedDate
    }

    private func dateAfter(_ date: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
            ?? calendar.startOfDay(for: date)
    }

    private var showsAssumedDoneControl: Bool {
        model.canAutoAssumeDailyDone
            || (model.taskType.wrappedValue == .record && model.autoAssumeDailyDone.wrappedValue)
    }

    private var assumedDoneControl: some View {
        TaskFormMacToggleBlock(
            title: "Auto-assume done",
            isOn: model.autoAssumeDailyDone,
            caption: presentation.autoAssumeDailyDoneHelpText,
            isDisabled: !model.canAutoAssumeDailyDone
        ) {}
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
            isOn: model.reminderEnabled
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
