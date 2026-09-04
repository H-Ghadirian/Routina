import SwiftUI

struct DayPlanSlotActionSidebar: View {
    let date: Date
    let startMinute: Int
    @Binding var durationMinutes: Int
    let tasks: [RoutineTask]
    let defaultTaskID: UUID?
    let now: Date
    let calendar: Calendar
    let includesAway: Bool
    let onCreateTaskBlock: (UUID, Int) -> String?
    let onCreateTaskAndBlock: (String, Int) -> String?
    let onLogAway: (AwaySessionPreset, String?, UUID?, Int) -> String?
    let onLogSleep: (Int) -> String?
    let onDismiss: () -> Void

    @State private var mode: DayPlanSlotActionMode = .task
    @State private var selectedTaskID: UUID?
    @State private var taskQuery = ""
    @State private var selectedAwayOption: DayPlanAwayLogOption = .away(.custom)
    @State private var awayTitle = ""
    @State private var awayLinkedTaskID: UUID?
    @State private var errorText: String?

    init(
        date: Date,
        startMinute: Int,
        durationMinutes: Binding<Int>,
        tasks: [RoutineTask],
        defaultTaskID: UUID?,
        now: Date,
        calendar: Calendar,
        includesAway: Bool = true,
        onCreateTaskBlock: @escaping (UUID, Int) -> String?,
        onCreateTaskAndBlock: @escaping (String, Int) -> String?,
        onLogAway: @escaping (AwaySessionPreset, String?, UUID?, Int) -> String?,
        onLogSleep: @escaping (Int) -> String?,
        onDismiss: @escaping () -> Void
    ) {
        self.date = date
        self.startMinute = DayPlanBlock.clampedStartMinute(startMinute)
        self._durationMinutes = durationMinutes
        self.tasks = tasks
        self.defaultTaskID = defaultTaskID
        self.now = now
        self.calendar = calendar
        self.includesAway = includesAway
        self.onCreateTaskBlock = onCreateTaskBlock
        self.onCreateTaskAndBlock = onCreateTaskAndBlock
        self.onLogAway = onLogAway
        self.onLogSleep = onLogSleep
        self.onDismiss = onDismiss

        let initialTaskID = defaultTaskID.flatMap { id in tasks.first(where: { $0.id == id })?.id } ?? tasks.first?.id
        _selectedTaskID = State(initialValue: initialTaskID)
        _awayLinkedTaskID = State(initialValue: initialTaskID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if DayPlanSlotActionMode.showsModePicker(includingAway: includesAway) {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Slot action",
                    options: DayPlanSlotActionMode.visibleCases(includingAway: includesAway),
                    selection: $mode,
                    minimumSegmentWidth: 92,
                    fillsAvailableWidth: true
                ) { actionMode in
                    Text(actionMode.title)
                }
            }

            switch mode {
            case .task:
                taskBlockContent
            case .away:
                awayLogContent
            }

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            normalizeModeForAwayVisibility()
            setTaskDuration(durationMinutes)
        }
        .onChange(of: includesAway) { _, _ in
            normalizeModeForAwayVisibility()
        }
        .onChange(of: mode) { _, newMode in
            errorText = nil
            switch newMode {
            case .task:
                setTaskDuration(durationMinutes)
            case .away:
                if selectedAwayOption.isSleep {
                    selectedAwayOption = .away(.custom)
                }
                setAwayDuration(selectedAwayOption.defaultDurationMinutes, for: selectedAwayOption)
            }
        }
        .onChange(of: taskQuery) { _, _ in
            selectedTaskID = nil
            errorText = nil
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: mode == .task ? "calendar.badge.plus" : selectedAwayOption.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    (mode == .task ? Color.accentColor : selectedAwayOption.tint), in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(intervalTitle)
                    .font(.headline.monospacedDigit().weight(.semibold))
                Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Close")
            .contentShape(Circle())
        }
    }

    private var taskBlockContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            taskChooser

            DayPlanSlotDurationControl(
                title: "Duration",
                minutes: taskDurationBinding,
                range: DayPlanSlotActionPresentation.taskDurationRange(startMinute: startMinute),
                step: 15,
                presets: DayPlanSlotActionPresentation.taskDurationPresets,
                tint: .accentColor
            )

            Button {
                submitTaskBlock()
            } label: {
                Label(taskSubmitTitle, systemImage: "calendar.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSubmitTaskBlock)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var taskChooser: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Find or create task", text: $taskQuery)
                    .textFieldStyle(.plain)

                if !taskQuery.isEmpty {
                    Button {
                        taskQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear")
                }
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .frame(height: 38)
            .routinaGlassPanel(cornerRadius: 8, interactive: true)

            ScrollView {
                LazyVStack(spacing: 6) {
                    if let creatableTaskName {
                        Button {
                            selectedTaskID = nil
                            errorText = nil
                        } label: {
                            DayPlanSlotCreateTaskRow(
                                title: creatableTaskName,
                                isSelected: selectedTaskID == nil
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    ForEach(filteredTasks) { task in
                        Button {
                            selectTask(task)
                        } label: {
                            DayPlanSlotTaskChoiceRow(
                                task: task,
                                isSelected: selectedTaskID == task.id
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    if filteredTasks.isEmpty && creatableTaskName == nil {
                        Text("No matching tasks")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.visible)
            .frame(maxHeight: 164)
        }
    }

    private var awayLogContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if includesAway {
                LazyVGrid(columns: DayPlanSlotActionPresentation.awayOptionColumns, spacing: 8) {
                    ForEach(DayPlanAwayLogOption.options(includingAway: includesAway)) { option in
                        Button {
                            selectAwayOption(option)
                        } label: {
                            DayPlanAwayOptionCard(
                                option: option,
                                isSelected: selectedAwayOption == option
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            if !selectedAwayOption.isSleep {
                TextField("Title", text: $awayTitle)
                    .textFieldStyle(.roundedBorder)

                Picker("Linked task", selection: awayTaskSelectionBinding) {
                    Text("No linked task").tag(Optional<UUID>.none)
                    ForEach(tasks) { task in
                        Text(DayPlanTaskSorting.title(for: task)).tag(Optional(task.id))
                    }
                }
                .pickerStyle(.menu)
            }

            DayPlanSlotDurationControl(
                title: selectedAwayOption.durationTitle,
                minutes: awayDurationBinding,
                range: selectedAwayDurationRange,
                step: selectedAwayOption.isSleep ? 15 : 5,
                presets: selectedAwayDurationPresets,
                tint: selectedAwayOption.tint
            )

            Button {
                submitAwayLog()
            } label: {
                Label(selectedAwayOption.logActionTitle, systemImage: selectedAwayOption.logActionSystemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedAwayOption.tint)
            .disabled(!canLogAway)

            if !canLogAway {
                Text(selectedAwayOption.finishedIntervalMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var filteredTasks: [RoutineTask] {
        DayPlanSlotTaskPickerPresentation.filteredTasks(tasks, matching: taskQuery)
    }

    private var creatableTaskName: String? {
        DayPlanSlotTaskPickerPresentation.creatableTaskName(from: taskQuery, tasks: tasks)
    }

    private var canSubmitTaskBlock: Bool {
        selectedTaskID != nil || creatableTaskName != nil
    }

    private var taskSubmitTitle: String {
        selectedTaskID == nil && creatableTaskName != nil ? "Create Task & Add Block" : "Add Block"
    }

    private func selectTask(_ task: RoutineTask) {
        selectedTaskID = task.id
        errorText = nil
        if let estimate = task.estimatedDurationMinutes {
            setTaskDuration(estimate)
        }
    }

    private func selectAwayOption(_ option: DayPlanAwayLogOption) {
        guard includesAway else { return }
        selectedAwayOption = option
        errorText = nil
        if option.isSleep {
            awayLinkedTaskID = nil
        }
        setAwayDuration(option.defaultDurationMinutes, for: option)
    }

    private func normalizeModeForAwayVisibility() {
        guard !DayPlanSlotActionMode.visibleCases(includingAway: includesAway).contains(mode) else {
            return
        }

        mode = .task
        selectedAwayOption = .away(.custom)
        awayLinkedTaskID = nil
        setTaskDuration(durationMinutes)
    }

    private var taskDurationBinding: Binding<Int> {
        Binding(
            get: { clampedTaskDurationMinutes },
            set: { setTaskDuration($0) }
        )
    }

    private var awayDurationBinding: Binding<Int> {
        Binding(
            get: { clampedAwayDurationMinutes },
            set: { setAwayDuration($0, for: selectedAwayOption) }
        )
    }

    private var awayTaskSelectionBinding: Binding<UUID?> {
        Binding(
            get: { awayLinkedTaskID },
            set: { awayLinkedTaskID = $0 }
        )
    }

    private var selectedAwayDurationRange: ClosedRange<Int> {
        DayPlanSlotActionPresentation.awayDurationRange(
            for: selectedAwayOption,
            startMinute: startMinute
        )
    }

    private var selectedAwayDurationPresets: [Int] {
        DayPlanSlotActionPresentation.awayDurationPresets(for: selectedAwayOption)
    }

    private var intervalTitle: String {
        DayPlanSlotActionPresentation.intervalTitle(
            date: date,
            startMinute: startMinute,
            durationMinutes: activeDurationMinutes,
            calendar: calendar
        )
    }

    private var activeDurationMinutes: Int {
        mode == .task ? clampedTaskDurationMinutes : clampedAwayDurationMinutes
    }

    private var clampedTaskDurationMinutes: Int {
        DayPlanSlotActionPresentation.clampedTaskDuration(
            durationMinutes,
            startMinute: startMinute
        )
    }

    private var clampedAwayDurationMinutes: Int {
        DayPlanSlotActionPresentation.clampedAwayDuration(
            durationMinutes,
            option: selectedAwayOption,
            startMinute: startMinute
        )
    }

    private var selectedStartDate: Date? {
        calendar.date(byAdding: .minute, value: startMinute, to: calendar.startOfDay(for: date))
    }

    private var selectedAwayEndDate: Date? {
        guard let startDate = selectedStartDate else {
            return nil
        }
        return calendar.date(byAdding: .minute, value: clampedAwayDurationMinutes, to: startDate)
    }

    private var canLogAway: Bool {
        guard let selectedAwayEndDate else { return false }
        return selectedAwayEndDate <= now
    }

    private func submitTaskBlock() {
        let error: String?
        if let selectedTaskID {
            error = onCreateTaskBlock(selectedTaskID, clampedTaskDurationMinutes)
        } else if let creatableTaskName {
            error = onCreateTaskAndBlock(creatableTaskName, clampedTaskDurationMinutes)
        } else {
            error = "Choose or name a task."
        }

        if let error {
            errorText = error
        } else {
            errorText = nil
            onDismiss()
        }
    }

    private func submitAwayLog() {
        guard canLogAway else {
            errorText = selectedAwayOption.finishedIntervalMessage
            return
        }

        let error: String?
        if selectedAwayOption.isSleep {
            error = onLogSleep(clampedAwayDurationMinutes)
        } else if let awayPreset = selectedAwayOption.awayPreset {
            error = onLogAway(
                awayPreset,
                awayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : awayTitle,
                awayLinkedTaskID,
                clampedAwayDurationMinutes
            )
        } else {
            error = "Choose an option."
        }

        if let error {
            errorText = error
        } else {
            errorText = nil
            onDismiss()
        }
    }

    private func setTaskDuration(_ newValue: Int) {
        durationMinutes = DayPlanSlotActionPresentation.clampedTaskDuration(
            newValue,
            startMinute: startMinute
        )
    }

    private func setAwayDuration(_ newValue: Int, for option: DayPlanAwayLogOption) {
        durationMinutes = DayPlanSlotActionPresentation.clampedAwayDuration(
            newValue,
            option: option,
            startMinute: startMinute
        )
    }
}
