import SwiftData
import SwiftUI

struct DayPlanEventPresentation: Identifiable {
    let id: UUID
}

struct DayPlanFocusAllocationPresentation: Identifiable {
    let sessionID: UUID

    var id: UUID { sessionID }
}

struct DayPlanFocusAllocationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let session: FocusSession
    let planTodayTasks: [RoutineTask]
    let existingBlocks: [DayPlanBlock]
    let onSave: ([DayPlanFocusTaskAllocation]) -> Void
    @State private var draftMinutesByTaskID: [UUID: Int]

    init(
        session: FocusSession,
        planTodayTasks: [RoutineTask],
        existingBlocks: [DayPlanBlock],
        onSave: @escaping ([DayPlanFocusTaskAllocation]) -> Void
    ) {
        self.session = session
        self.planTodayTasks = planTodayTasks
        self.existingBlocks = existingBlocks
        self.onSave = onSave
        _draftMinutesByTaskID = State(
            initialValue: Dictionary(
                uniqueKeysWithValues: existingBlocks.map { ($0.taskID, max(0, $0.durationMinutes)) }
            ))
    }

    var body: some View {
        NavigationStack {
            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                let availableMinutes = allocatableMinutes(at: context.date)

                List {
                    Section {
                        HStack {
                            Label(session.state == .completed ? "Recorded" : "Available", systemImage: "stopwatch")
                            Spacer()
                            Text(DayPlanFormatting.durationText(availableMinutes))
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Label("Allocated", systemImage: "slider.horizontal.3")
                            Spacer()
                            Text(
                                "\(DayPlanFormatting.durationText(totalDraftMinutes)) of \(DayPlanFormatting.durationText(availableMinutes))"
                            )
                            .foregroundStyle(totalDraftMinutes > availableMinutes ? .red : .secondary)
                        }
                    }

                    Section("Plan to do today") {
                        if planTodayTasks.isEmpty {
                            ContentUnavailableView("No planned tasks", systemImage: "tray")
                        } else {
                            ForEach(planTodayTasks) { task in
                                allocationRow(task, availableMinutes: availableMinutes)
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(allocations)
                            dismiss()
                        }
                        .disabled(totalDraftMinutes <= 0 || totalDraftMinutes > availableMinutes)
                    }
                }
            }
            .navigationTitle("Allocate Plan Focus")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #if os(macOS)
            .frame(width: 480, height: 460)
        #else
            .presentationDetents([.medium, .large])
        #endif
    }

    private var totalDraftMinutes: Int {
        draftMinutesByTaskID.values.reduce(0) { $0 + max(0, $1) }
    }

    private var allocations: [DayPlanFocusTaskAllocation] {
        planTodayTasks.compactMap { task in
            let minutes = max(0, draftMinutesByTaskID[task.id] ?? 0)
            guard minutes > 0 else { return nil }
            return DayPlanFocusTaskAllocation(taskID: task.id, minutes: minutes)
        }
    }

    private func allocationRow(_ task: RoutineTask, availableMinutes: Int) -> some View {
        let taskMinutes = draftMinutesByTaskID[task.id] ?? 0
        let otherMinutes = totalDraftMinutes - taskMinutes
        let upperBound = max(0, availableMinutes - otherMinutes)

        return Stepper(
            value: allocationBinding(for: task.id, upperBound: upperBound),
            in: 0...upperBound,
            step: 1
        ) {
            HStack(spacing: 10) {
                Text(CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "*")
                Text(DayPlanTaskSorting.title(for: task))
                    .foregroundStyle(.primary)
                Spacer()
                Text(DayPlanFormatting.durationText(taskMinutes))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func allocationBinding(for taskID: UUID, upperBound: Int) -> Binding<Int> {
        Binding(
            get: {
                min(max(0, draftMinutesByTaskID[taskID] ?? 0), upperBound)
            },
            set: { value in
                draftMinutesByTaskID[taskID] = min(max(0, value), upperBound)
            }
        )
    }

    private func allocatableMinutes(at date: Date) -> Int {
        let seconds: TimeInterval
        if let completedAt = session.completedAt {
            seconds = session.activeDurationSeconds(at: completedAt)
        } else {
            seconds = session.activeDurationSeconds(at: date)
        }
        return max(0, Int(floor(seconds / 60)))
    }
}

struct DayPlanEventDetail: View {
    let eventID: UUID
    @Query(sort: \RoutineEvent.startedAt, order: .reverse) private var events: [RoutineEvent]

    var body: some View {
        if let event = events.first(where: { $0.id == eventID }) {
            RoutineEventDetailView(event: event)
        } else {
            ContentUnavailableView(
                "Event not found",
                systemImage: "calendar",
                description: Text("The selected event is no longer available.")
            )
        }
    }
}

private struct DayPlanLifecycleModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var planner: DayPlanPlannerState
    var dataRevision: UUID
    var tasks: [RoutineTask]
    var sleepSessions: [SleepSession]
    var awaySessions: [AwaySession]
    var focusSessions: [FocusSession]
    var calendar: Calendar

    func body(content: Content) -> some View {
        content
            .onAppear {
                reconcileCountUpFocusSegments()
                planner.loadBlocks(calendar: calendar, context: modelContext)
                showExactTimedTasks()
                planner.selectDefaultTaskIfNeeded(from: tasks)
            }
            .onChange(of: planner.selectedDate) { _, _ in
                planner.handleSelectedDateChanged(calendar: calendar, context: modelContext)
                showExactTimedTasks()
            }
            .onChange(of: planner.visibleRangeMode) { _, _ in
                planner.loadBlocks(
                    calendar: calendar,
                    context: modelContext,
                    preservingCachedUnassignedFocusBlocks: true
                )
                showExactTimedTasks()
            }
            .onChange(of: dataRevision) { _, _ in
                reconcileCountUpFocusSegments()
                planner.loadBlocks(calendar: calendar, context: modelContext)
                showExactTimedTasks()
                planner.selectDefaultTaskIfNeeded(from: tasks)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    reconcileCountUpFocusSegments()
                    planner.loadBlocks(calendar: calendar, context: modelContext)
                    showExactTimedTasks()
                }
            }
    }

    private func reconcileCountUpFocusSegments() {
        DayPlanFocusSessionPlannerSync.reconcileCountUpFocusSegments(
            for: focusSessions,
            tasks: tasks,
            calendar: calendar,
            context: modelContext
        )
    }

    private func showExactTimedTasks() {
        let dates = planner.visibleAndSelectedDates(calendar: calendar)
        var blockedIntervalsByDayKey = DayPlanSleepBlocks.blockedIntervalsByDayKey(
            on: dates,
            from: sleepSessions,
            referenceDate: Date(),
            calendar: calendar
        )
        let awayBlockedIntervalsByDayKey = DayPlanAwayBlocks.blockedIntervalsByDayKey(
            on: dates,
            from: awaySessions,
            tasks: tasks,
            referenceDate: Date(),
            calendar: calendar
        )
        for (dayKey, intervals) in awayBlockedIntervalsByDayKey {
            blockedIntervalsByDayKey[dayKey, default: []].append(contentsOf: intervals)
        }
        planner.showExactTimedTasks(
            from: tasks,
            blockedIntervalsByDayKey: blockedIntervalsByDayKey,
            calendar: calendar,
            context: modelContext
        )
    }
}

extension View {
    func dayPlanLifecycle(
        planner: DayPlanPlannerState,
        dataRevision: UUID,
        tasks: [RoutineTask],
        sleepSessions: [SleepSession],
        awaySessions: [AwaySession],
        focusSessions: [FocusSession] = [],
        calendar: Calendar
    ) -> some View {
        modifier(
            DayPlanLifecycleModifier(
                planner: planner,
                dataRevision: dataRevision,
                tasks: tasks,
                sleepSessions: sleepSessions,
                awaySessions: awaySessions,
                focusSessions: focusSessions,
                calendar: calendar
            )
        )
    }
}

struct DayPlanTaskCandidateRow: View {
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
                        Text(task.isOneOffTask ? "One-time" : "Repeating")
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
        .onDrag {
            NSItemProvider(object: task.id.uuidString as NSString)
        }
    }
}
