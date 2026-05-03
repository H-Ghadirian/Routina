import SwiftData
import SwiftUI

struct DayPlanView: View {
    @StateObject private var planner = DayPlanPlannerState()

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
#if os(macOS)
        VStack(alignment: .leading, spacing: 16) {
            DayPlanHeaderView(planner: planner)

            HSplitView {
                DayPlanSidebarView(planner: planner)
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)

                DayPlanTimelinePanelView(planner: planner)
                    .frame(minWidth: 520)
            }
        }
        .padding(20)
#else
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                DayPlanHeaderView(planner: planner)
                    .padding(.horizontal)
                    .padding(.top)

                DayPlanSidebarView(planner: planner)
                    .frame(maxHeight: 320)
                    .padding(.horizontal)

                DayPlanTimelinePanelView(planner: planner)
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .navigationTitle("Plan")
        }
#endif
    }
}
struct DayPlanSidebarView: View {
    @Environment(\.calendar) private var calendar
    @ObservedObject var planner: DayPlanPlannerState
    @Query private var tasks: [RoutineTask]
    var usesPanelBackground = true

    var body: some View {
        taskPanel
            .dayPlanLifecycle(planner: planner, tasks: tasks, calendar: calendar)
    }

    private var taskPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tasks")
                    .font(.headline)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search tasks", text: $planner.searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    if filteredTasks.isEmpty {
                        ContentUnavailableView(
                            "No tasks found",
                            systemImage: "tray",
                            description: Text("Create or search for a task to add it to the plan.")
                        )
                        .padding(.vertical, 24)
                    } else {
                        ForEach(filteredTasks) { task in
                            DayPlanTaskCandidateRow(
                                task: task,
                                title: DayPlanTaskSorting.title(for: task),
                                isSelected: task.id == planner.selectedTaskID
                            ) {
                                planner.selectTask(task)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Divider()

            editorPanel
        }
        .padding(usesPanelBackground ? 14 : 0)
        .background {
            if usesPanelBackground {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.thinMaterial)
            }
        }
    }

    private var editorPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(planner.selectedBlock == nil ? "Add to timeline" : "Edit block")
                    .font(.headline)
                Spacer()
                if planner.selectedBlock != nil {
                    Button("New") {
                        planner.selectedBlockID = nil
                    }
                    .controlSize(.small)
                }
            }

            Picker("Task", selection: $planner.selectedTaskID) {
                Text("Choose a task").tag(Optional<UUID>.none)
                ForEach(availableTasks) { task in
                    Text(DayPlanTaskSorting.title(for: task)).tag(Optional(task.id))
                }
            }

            DatePicker("Start", selection: startDateBinding, displayedComponents: [.hourAndMinute])
                .datePickerStyle(.compact)

            Stepper(
                "Duration: \(DayPlanFormatting.durationText(planner.durationMinutes))",
                value: $planner.durationMinutes,
                in: DayPlanBlock.minimumDurationMinutes...planner.maximumDurationForStart,
                step: 15
            )

            Text("Ends \(DayPlanFormatting.timeText(for: planner.startMinute + planner.durationMinutes, on: planner.selectedDate, calendar: calendar))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let conflictingBlock = planner.conflictingBlock {
                Label("Overlaps \(conflictingBlock.titleSnapshot)", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button(planner.selectedBlock == nil ? "Add" : "Save") {
                    if let selectedTask {
                        planner.commitBlock(task: selectedTask, calendar: calendar)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCommitBlock)

                if let selectedBlock = planner.selectedBlock {
                    Button("Delete", role: .destructive) {
                        planner.deleteBlock(selectedBlock.id, calendar: calendar)
                    }
                }
            }
        }
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: {
                let startOfDay = calendar.startOfDay(for: planner.selectedDate)
                return calendar.date(byAdding: .minute, value: planner.startMinute, to: startOfDay) ?? startOfDay
            },
            set: { date in
                let components = calendar.dateComponents([.hour, .minute], from: date)
                let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
                planner.startMinute = DayPlanBlock.clampedStartMinute(minute)
                planner.clampDurationForCurrentStart()
            }
        )
    }

    private var availableTasks: [RoutineTask] {
        DayPlanTaskSorting.availableTasks(from: tasks)
    }

    private var filteredTasks: [RoutineTask] {
        DayPlanTaskSorting.filteredTasks(from: availableTasks, query: planner.searchText)
    }

    private var selectedTask: RoutineTask? {
        guard let selectedTaskID = planner.selectedTaskID else { return nil }
        return tasks.first { $0.id == selectedTaskID }
    }

    private var canCommitBlock: Bool {
        selectedTask != nil && planner.conflictingBlock == nil
    }
}

struct DayPlanDetailView: View {
    @Environment(\.calendar) private var calendar
    @ObservedObject var planner: DayPlanPlannerState
    var selectedTaskID: UUID? = nil
    @Query private var tasks: [RoutineTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DayPlanHeaderView(planner: planner)
            DayPlanPlanningControlsView(planner: planner, selectedTask: selectedTask)
            DayPlanTimelinePanelView(planner: planner)
        }
        .padding(20)
        .onAppear {
            syncSelectedTask()
        }
        .onChange(of: selectedTaskID) { _, _ in
            syncSelectedTask()
        }
        .onChange(of: tasks.map(\.id)) { _, _ in
            syncSelectedTask()
        }
    }

    private var selectedTask: RoutineTask? {
        guard let selectedTaskID = planner.selectedTaskID else { return nil }
        return tasks.first { $0.id == selectedTaskID }
    }

    private func syncSelectedTask() {
        guard
            let selectedTaskID,
            let task = tasks.first(where: { $0.id == selectedTaskID })
        else { return }

        if planner.selectedTaskID != selectedTaskID {
            planner.selectedBlockID = nil
        }
        planner.selectTask(task)
    }
}

private struct DayPlanPlanningControlsView: View {
    @Environment(\.calendar) private var calendar
    @ObservedObject var planner: DayPlanPlannerState
    var selectedTask: RoutineTask?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                selectedTaskSummary

                Divider()
                    .frame(height: 34)

                HStack(spacing: 8) {
                    Text("Start")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    DatePicker("Start", selection: startDateBinding, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                Stepper(
                    "Duration: \(DayPlanFormatting.durationText(planner.durationMinutes))",
                    value: $planner.durationMinutes,
                    in: DayPlanBlock.minimumDurationMinutes...planner.maximumDurationForStart,
                    step: 15
                )
                .fixedSize()

                Text("Ends \(endTimeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer(minLength: 12)

                if planner.selectedBlock != nil {
                    Button("New") {
                        planner.selectedBlockID = nil
                    }
                    .controlSize(.small)
                }

                Button(planner.selectedBlock == nil ? "Add" : "Save") {
                    if let selectedTask {
                        planner.commitBlock(task: selectedTask, calendar: calendar)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canCommitBlock)

                if let selectedBlock = planner.selectedBlock {
                    Button(role: .destructive) {
                        planner.deleteBlock(selectedBlock.id, calendar: calendar)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Delete block")
                }
            }

            if let conflictingBlock = planner.conflictingBlock {
                Label("Overlaps \(conflictingBlock.titleSnapshot)", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var selectedTaskSummary: some View {
        HStack(spacing: 10) {
            DayPlanTaskAvatar(
                emoji: selectedTask?.emoji,
                tint: selectedTask?.color.swiftUIColor ?? .accentColor
            )
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTask.map { DayPlanTaskSorting.title(for: $0) } ?? "Select a task")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Text(planner.selectedBlock == nil ? "Add to selected day" : "Edit selected block")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 190, maxWidth: 280, alignment: .leading)
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: {
                let startOfDay = calendar.startOfDay(for: planner.selectedDate)
                return calendar.date(byAdding: .minute, value: planner.startMinute, to: startOfDay) ?? startOfDay
            },
            set: { date in
                let components = calendar.dateComponents([.hour, .minute], from: date)
                let minute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)
                planner.startMinute = DayPlanBlock.clampedStartMinute(minute)
                planner.clampDurationForCurrentStart()
            }
        )
    }

    private var endTimeText: String {
        DayPlanFormatting.timeText(
            for: planner.startMinute + planner.durationMinutes,
            on: planner.selectedDate,
            calendar: calendar
        )
    }

    private var canCommitBlock: Bool {
        selectedTask != nil && planner.conflictingBlock == nil
    }
}

private struct DayPlanHeaderView: View {
    @Environment(\.calendar) private var calendar
    @ObservedObject var planner: DayPlanPlannerState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button("Today") {
                planner.moveToToday(calendar: calendar)
            }
            .buttonStyle(.bordered)

            HStack(spacing: 4) {
                Button {
                    planner.moveWeek(by: -1, calendar: calendar)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Button {
                    planner.moveWeek(by: 1, calendar: calendar)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.plain)
            .font(.title3.weight(.medium))

            VStack(alignment: .leading, spacing: 3) {
                Text(planner.weekTitle(calendar: calendar))
                    .font(.title2.weight(.semibold))

                Text("\(planner.blocks.count) blocks on selected day, \(DayPlanFormatting.durationText(planner.plannedMinutes)) planned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            DatePicker("Selected day", selection: $planner.selectedDate, displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }
}

private struct DayPlanTimelinePanelView: View {
    @Environment(\.calendar) private var calendar
    @ObservedObject var planner: DayPlanPlannerState
    @Query private var tasks: [RoutineTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Day")
                    .font(.headline)
                Spacer()
                Text("\(DayPlanFormatting.durationText(planner.unplannedMinutes)) open on selected day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            DayPlanWeekCalendarView(
                dates: planner.weekDates(calendar: calendar),
                selectedBlockID: planner.selectedBlockID,
                selectedDate: planner.selectedDate,
                calendar: calendar,
                dropDurationMinutes: planner.durationMinutes,
                blocksForDate: { date in
                    planner.blocks(on: date, calendar: calendar)
                },
                taskTint: taskTint(for:),
                onSelectSlot: { date, minute in
                    planner.selectSlot(on: date, startMinute: minute, calendar: calendar)
                },
                onSelectBlock: { block, date in
                    planner.edit(block, on: date, calendar: calendar)
                },
                onDeleteBlock: { block in
                    planner.deleteBlock(block.id, calendar: calendar)
                },
                onMoveBlock: { blockID, date, minute in
                    planner.moveBlock(blockID, to: date, startMinute: minute, calendar: calendar)
                },
                onResizeBlock: { blockID, date, startMinute, durationMinutes in
                    planner.resizeBlock(
                        blockID,
                        on: date,
                        startMinute: startMinute,
                        durationMinutes: durationMinutes,
                        calendar: calendar
                    )
                },
                onDropTask: { taskID, date, minute in
                    dropTask(taskID, on: date, startMinute: minute)
                }
            )
        }
        .dayPlanLifecycle(planner: planner, tasks: tasks, calendar: calendar)
    }

    private func taskTint(for block: DayPlanBlock) -> Color {
        tasks.first { $0.id == block.taskID }?.color.swiftUIColor ?? .accentColor
    }

    private func dropTask(_ taskID: UUID, on date: Date, startMinute: Int) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        planner.selectSlot(on: date, startMinute: startMinute, calendar: calendar)
        planner.selectTask(task)
        planner.commitBlock(task: task, calendar: calendar)
    }
}

private struct DayPlanLifecycleModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var planner: DayPlanPlannerState
    var tasks: [RoutineTask]
    var calendar: Calendar

    func body(content: Content) -> some View {
        content
            .onAppear {
                planner.loadBlocks(calendar: calendar)
                planner.showExactTimedTasks(from: tasks, calendar: calendar)
                planner.selectDefaultTaskIfNeeded(from: tasks)
            }
            .onChange(of: planner.selectedDate) { _, _ in
                planner.handleSelectedDateChanged(calendar: calendar)
                planner.showExactTimedTasks(from: tasks, calendar: calendar)
            }
            .onChange(of: tasks.map(\.id)) { _, _ in
                planner.showExactTimedTasks(from: tasks, calendar: calendar)
                planner.selectDefaultTaskIfNeeded(from: tasks)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    planner.loadBlocks(calendar: calendar)
                    planner.showExactTimedTasks(from: tasks, calendar: calendar)
                }
            }
    }
}

private extension View {
    func dayPlanLifecycle(
        planner: DayPlanPlannerState,
        tasks: [RoutineTask],
        calendar: Calendar
    ) -> some View {
        modifier(DayPlanLifecycleModifier(planner: planner, tasks: tasks, calendar: calendar))
    }
}

private struct DayPlanTaskCandidateRow: View {
    var task: RoutineTask
    var title: String
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .center, spacing: 10) {
                DayPlanTaskAvatar(emoji: task.emoji, tint: task.color.swiftUIColor ?? .accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if task.isPinned {
                            Label("Pinned", systemImage: "pin.fill")
                        }
                        if let estimatedDurationMinutes = task.estimatedDurationMinutes {
                            Label(DayPlanFormatting.durationText(estimatedDurationMinutes), systemImage: "timer")
                        }
                        Text(task.isOneOffTask ? "Task" : "Routine")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding(10)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}
