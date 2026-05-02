import SwiftData
import SwiftUI

final class DayPlanPlannerState: ObservableObject {
    @Published var selectedDate = Date()
    @Published var blocks: [DayPlanBlock] = []
    @Published var selectedTaskID: UUID?
    @Published var selectedBlockID: UUID?
    @Published var searchText = ""
    @Published var startMinute = 9 * 60
    @Published var durationMinutes = 60

    var selectedBlock: DayPlanBlock? {
        guard let selectedBlockID else { return nil }
        return blocks.first { $0.id == selectedBlockID }
    }

    var plannedMinutes: Int {
        blocks.reduce(0) { $0 + $1.durationMinutes }
    }

    var unplannedMinutes: Int {
        max(DayPlanBlock.minutesPerDay - plannedMinutes, 0)
    }

    var maximumDurationForStart: Int {
        max(
            DayPlanBlock.minimumDurationMinutes,
            DayPlanBlock.minutesPerDay - DayPlanBlock.clampedStartMinute(startMinute)
        )
    }

    var conflictingBlock: DayPlanBlock? {
        conflict(startMinute: startMinute, durationMinutes: durationMinutes, ignoring: selectedBlockID)
    }

    func loadBlocks(calendar: Calendar) {
        blocks = DayPlanStorage.loadBlocks(for: selectedDate, calendar: calendar)
    }

    func persistBlocks(calendar: Calendar) {
        DayPlanStorage.saveBlocks(blocks, for: selectedDate, calendar: calendar)
    }

    func selectDefaultTaskIfNeeded(from tasks: [RoutineTask]) {
        if let selectedTaskID, tasks.contains(where: { $0.id == selectedTaskID }) {
            return
        }
        selectedTaskID = DayPlanTaskSorting.availableTasks(from: tasks).first?.id
    }

    func selectTask(_ task: RoutineTask) {
        selectedTaskID = task.id
        if selectedBlock == nil, let estimate = task.estimatedDurationMinutes {
            durationMinutes = DayPlanBlock.clampedDuration(estimate, startMinute: startMinute)
        }
    }

    func edit(_ block: DayPlanBlock) {
        selectedBlockID = block.id
        selectedTaskID = block.taskID
        startMinute = block.startMinute
        durationMinutes = block.durationMinutes
        clampDurationForCurrentStart()
    }

    func deleteBlock(_ id: DayPlanBlock.ID, calendar: Calendar) {
        blocks.removeAll { $0.id == id }
        if selectedBlockID == id {
            selectedBlockID = nil
        }
        persistBlocks(calendar: calendar)
    }

    func commitBlock(task: RoutineTask, calendar: Calendar) {
        guard conflictingBlock == nil else { return }

        let dayKey = DayPlanStorage.dayKey(for: selectedDate, calendar: calendar)
        let now = Date()
        let title = DayPlanTaskSorting.title(for: task)
        let emoji = task.emoji?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let selectedBlock, let index = blocks.firstIndex(where: { $0.id == selectedBlock.id }) {
            blocks[index] = DayPlanBlock(
                id: selectedBlock.id,
                taskID: task.id,
                dayKey: dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: title,
                emojiSnapshot: emoji,
                createdAt: selectedBlock.createdAt,
                updatedAt: now
            )
        } else {
            let block = DayPlanBlock(
                taskID: task.id,
                dayKey: dayKey,
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                titleSnapshot: title,
                emojiSnapshot: emoji,
                createdAt: now,
                updatedAt: now
            )
            blocks.append(block)
            selectedBlockID = block.id
        }

        blocks.sort { $0.startMinute < $1.startMinute }
        persistBlocks(calendar: calendar)
    }

    func conflict(
        startMinute: Int,
        durationMinutes: Int,
        ignoring ignoredBlockID: DayPlanBlock.ID?
    ) -> DayPlanBlock? {
        let start = DayPlanBlock.clampedStartMinute(startMinute)
        let duration = DayPlanBlock.clampedDuration(durationMinutes, startMinute: start)
        let end = start + duration

        return blocks.first { block in
            guard block.id != ignoredBlockID else { return false }
            return max(start, block.startMinute) < min(end, block.endMinute)
        }
    }

    func clampDurationForCurrentStart() {
        durationMinutes = DayPlanBlock.clampedDuration(durationMinutes, startMinute: startMinute)
    }
}

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
    @ObservedObject var planner: DayPlanPlannerState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DayPlanHeaderView(planner: planner)
            DayPlanTimelinePanelView(planner: planner)
        }
        .padding(20)
    }
}

private struct DayPlanHeaderView: View {
    @Environment(\.calendar) private var calendar
    @ObservedObject var planner: DayPlanPlannerState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plan")
                    .font(.largeTitle.weight(.semibold))
                Text("\(planner.blocks.count) blocks, \(DayPlanFormatting.durationText(planner.plannedMinutes)) planned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            DatePicker("Day", selection: $planner.selectedDate, displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.compact)

            Button("Today") {
                planner.selectedDate = Date()
                planner.loadBlocks(calendar: calendar)
            }
            .controlSize(.small)
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
                Text(DayPlanStorage.dayKey(for: planner.selectedDate, calendar: calendar))
                    .font(.headline)
                    .monospacedDigit()
                Spacer()
                Text("\(DayPlanFormatting.durationText(planner.unplannedMinutes)) open")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            DayPlanTimelineView(
                blocks: planner.blocks,
                selectedBlockID: planner.selectedBlockID,
                selectedDate: planner.selectedDate,
                calendar: calendar,
                taskTint: taskTint(for:),
                onSelectStartMinute: { minute in
                    planner.selectedBlockID = nil
                    planner.startMinute = DayPlanBlock.clampedStartMinute(minute)
                    planner.clampDurationForCurrentStart()
                },
                onSelectBlock: { block in
                    planner.edit(block)
                },
                onDeleteBlock: { block in
                    planner.deleteBlock(block.id, calendar: calendar)
                }
            )
        }
        .dayPlanLifecycle(planner: planner, tasks: tasks, calendar: calendar)
    }

    private func taskTint(for block: DayPlanBlock) -> Color {
        tasks.first { $0.id == block.taskID }?.color.swiftUIColor ?? .accentColor
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
                planner.selectDefaultTaskIfNeeded(from: tasks)
            }
            .onChange(of: planner.selectedDate) { _, _ in
                planner.selectedBlockID = nil
                planner.loadBlocks(calendar: calendar)
            }
            .onChange(of: tasks.map(\.id)) { _, _ in
                planner.selectDefaultTaskIfNeeded(from: tasks)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    planner.loadBlocks(calendar: calendar)
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

private enum DayPlanTaskSorting {
    static func availableTasks(from tasks: [RoutineTask]) -> [RoutineTask] {
        tasks
            .filter { !$0.isCompletedOneOff && !$0.isCanceledOneOff }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned
                }

                if lhs.isOneOffTask != rhs.isOneOffTask {
                    return lhs.isOneOffTask
                }

                let lhsDeadline = lhs.deadline ?? .distantFuture
                let rhsDeadline = rhs.deadline ?? .distantFuture
                if lhsDeadline != rhsDeadline {
                    return lhsDeadline < rhsDeadline
                }

                return title(for: lhs).localizedCaseInsensitiveCompare(title(for: rhs)) == .orderedAscending
            }
    }

    static func filteredTasks(from tasks: [RoutineTask], query: String) -> [RoutineTask] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return tasks }

        let normalizedQuery = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return tasks.filter { task in
            let searchableText = ([title(for: task), task.emoji ?? ""] + task.tags)
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return searchableText.contains(normalizedQuery)
        }
    }

    static func title(for task: RoutineTask) -> String {
        let trimmed = RoutineTask.trimmedName(task.name) ?? ""
        return trimmed.isEmpty ? "Untitled task" : trimmed
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

private struct DayPlanTaskAvatar: View {
    var emoji: String?
    var tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.16))
            if let emoji, !emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(emoji)
            } else {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 34, height: 34)
    }
}

private struct DayPlanTimelineView: View {
    var blocks: [DayPlanBlock]
    var selectedBlockID: DayPlanBlock.ID?
    var selectedDate: Date
    var calendar: Calendar
    var taskTint: (DayPlanBlock) -> Color
    var onSelectStartMinute: (Int) -> Void
    var onSelectBlock: (DayPlanBlock) -> Void
    var onDeleteBlock: (DayPlanBlock) -> Void

    private let hourHeight: CGFloat = 64

    var body: some View {
        ScrollView(.vertical) {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    hourRows

                    ForEach(blocks) { block in
                        DayPlanBlockCard(
                            block: block,
                            tint: taskTint(block),
                            isSelected: block.id == selectedBlockID,
                            selectedDate: selectedDate,
                            calendar: calendar,
                            onSelect: {
                                onSelectBlock(block)
                            },
                            onDelete: {
                                onDeleteBlock(block)
                            }
                        )
                        .frame(
                            width: max(proxy.size.width - 84, 160),
                            height: max(blockHeight(for: block), 36)
                        )
                        .offset(x: 72, y: yOffset(for: block.startMinute))
                        .zIndex(block.id == selectedBlockID ? 2 : 1)
                    }
                }
            }
            .frame(height: hourHeight * 24)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
    }

    private var hourRows: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Button {
                    onSelectStartMinute(hour * 60)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text(DayPlanFormatting.hourText(for: hour, on: selectedDate, calendar: calendar))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                            .padding(.top, 8)

                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 1)
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(height: hourHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(hour.isMultiple(of: 2) ? Color.secondary.opacity(0.04) : Color.clear)
            }
        }
    }

    private func yOffset(for minute: Int) -> CGFloat {
        CGFloat(minute) / 60 * hourHeight
    }

    private func blockHeight(for block: DayPlanBlock) -> CGFloat {
        CGFloat(block.durationMinutes) / 60 * hourHeight
    }
}

private struct DayPlanBlockCard: View {
    var block: DayPlanBlock
    var tint: Color
    var isSelected: Bool
    var selectedDate: Date
    var calendar: Calendar
    var onSelect: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 10) {
                DayPlanTaskAvatar(emoji: block.emojiSnapshot, tint: tint)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(block.titleSnapshot)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(rangeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Spacer(minLength: 6)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(isSelected ? 0.22 : 0.14))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(isSelected ? 0.75 : 0.35), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private var rangeText: String {
        let start = DayPlanFormatting.timeText(for: block.startMinute, on: selectedDate, calendar: calendar)
        let end = DayPlanFormatting.timeText(for: block.endMinute, on: selectedDate, calendar: calendar)
        let duration = DayPlanFormatting.durationText(block.durationMinutes)
        return "\(start)-\(end)  \(duration)"
    }
}

enum DayPlanFormatting {
    static func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        switch (hours, remainingMinutes) {
        case (0, let minutes):
            return "\(minutes)m"
        case (let hours, 0):
            return "\(hours)h"
        default:
            return "\(hours)h \(remainingMinutes)m"
        }
    }

    static func hourText(for hour: Int, on date: Date, calendar: Calendar) -> String {
        timeText(for: hour * 60, on: date, calendar: calendar)
    }

    static func timeText(for minute: Int, on date: Date, calendar: Calendar) -> String {
        let startOfDay = calendar.startOfDay(for: date)
        let clampedMinute = min(max(minute, 0), DayPlanBlock.minutesPerDay)
        let time = calendar.date(byAdding: .minute, value: clampedMinute, to: startOfDay) ?? startOfDay
        return time.formatted(date: .omitted, time: .shortened)
    }
}
