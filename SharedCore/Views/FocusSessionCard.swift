import SwiftData
import SwiftUI

struct FocusSessionCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Query private var activeSleepSessions: [SleepSession]
    @State private var isExpanded: Bool
    @State private var isShowingAllHistory = false
    @State private var editingSession: FocusSession?
    @State private var editStartedAt = Date()
    @State private var editDurationMinutes = 25

    let task: RoutineTask
    let sessions: [FocusSession]
    let allTasks: [RoutineTask]
    let isEmbedded: Bool
    let showsEmbeddedHeader: Bool
    let showsEmbeddedStartControls: Bool
    let blockingFocusTitle: String?

    init(
        task: RoutineTask,
        sessions: [FocusSession],
        allTasks: [RoutineTask],
        isEmbedded: Bool = false,
        showsEmbeddedHeader: Bool = true,
        showsEmbeddedStartControls: Bool = true,
        blockingFocusTitle: String? = nil
    ) {
        _activeSleepSessions = Query(
            filter: #Predicate<SleepSession> { session in
                session.endedAt == nil
            },
            sort: \.startedAt,
            order: .reverse
        )
        _isExpanded = State(initialValue: isEmbedded)
        self.task = task
        self.sessions = sessions
        self.allTasks = allTasks
        self.isEmbedded = isEmbedded
        self.showsEmbeddedHeader = showsEmbeddedHeader
        self.showsEmbeddedStartControls = showsEmbeddedStartControls
        self.blockingFocusTitle = blockingFocusTitle
    }

    let durationOptions: [TimeInterval] = [
        15 * 60,
        25 * 60,
        45 * 60,
        60 * 60,
        90 * 60,
    ]

    var body: some View {
        let snapshot = FocusSessionCardSnapshot(taskID: task.id, sessions: sessions)
        let isForcedExpanded = snapshot.activeSessionForTask != nil
        let isContentExpanded = isExpanded || isForcedExpanded

        VStack(alignment: .leading, spacing: isEmbedded ? 12 : 14) {
            if !isEmbedded || showsEmbeddedHeader {
                if isForcedExpanded {
                    focusHeader(
                        snapshot: snapshot,
                        isContentExpanded: isContentExpanded,
                        showsDisclosureIndicator: false
                    )
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        focusHeader(
                            snapshot: snapshot,
                            isContentExpanded: isContentExpanded,
                            showsDisclosureIndicator: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if isContentExpanded {
                if isSleepModeActive {
                    sleepModeActiveContent
                } else if let activeSessionForTask = snapshot.activeSessionForTask {
                    activeSessionContent(activeSessionForTask, snapshot: snapshot)
                } else if let activeSessionForAnotherTask = snapshot.activeSessionForAnotherTask {
                    otherTaskActiveContent(activeSessionForAnotherTask)
                } else if let blockingFocusTitle {
                    blockingFocusContent(blockingFocusTitle)
                } else {
                    if !isEmbedded || showsEmbeddedStartControls {
                        startFocusControls
                    }
                }

                if !snapshot.completedSessionsForTask.isEmpty {
                    Divider()
                    if isEmbedded {
                        FocusSessionCompactHistoryView(
                            snapshot: snapshot,
                            isShowingAllHistory: $isShowingAllHistory,
                            onEdit: { beginEditing($0) }
                        )
                    } else {
                        FocusSessionHistorySummaryView(
                            snapshot: snapshot,
                            showsAccumulatedBlocks: snapshot.activeSessionForTask == nil
                        )
                        FocusSessionHistoryListView(
                            sessions: snapshot.completedSessionsForTask,
                            isShowingAllHistory: $isShowingAllHistory,
                            onEdit: { beginEditing($0) }
                        )
                    }
                }
            }
        }
        .padding(isEmbedded ? 0 : 16)
        .routinaIf(!isEmbedded) { view in
            view.routinaGlassCard(cornerRadius: 12, tint: .teal, tintOpacity: 0.06)
        }
        .overlay {
            if !isEmbedded {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .sheet(item: $editingSession) { session in
            #if os(macOS)
                macEditSheet(for: session)
                    .frame(width: 420)
                    .padding(24)
            #else
                NavigationStack {
                    Form {
                        Section("Session") {
                            DatePicker(
                                "Started",
                                selection: $editStartedAt,
                                displayedComponents: [.date, .hourAndMinute]
                            )

                            Stepper(value: $editDurationMinutes, in: 1...720) {
                                HStack {
                                    Text("Duration")
                                    Spacer()
                                    Text(FocusSessionFormatting.compactDurationText(seconds: TimeInterval(editDurationMinutes * 60)))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Section {
                            Button(role: .destructive) {
                                delete(session)
                                editingSession = nil
                            } label: {
                                Label("Delete Session", systemImage: "trash")
                            }
                        }
                    }
                    .navigationTitle("Edit Focus")
                    #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                editingSession = nil
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                saveEdits(to: session)
                                editingSession = nil
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            #endif
        }
        .onChange(of: task.id) { _, _ in
            isExpanded = isEmbedded
            isShowingAllHistory = false
        }
        .onChange(of: snapshot.completedSessionsForTask.count) { _, count in
            if count <= 3 {
                isShowingAllHistory = false
            }
        }
        .task {
            syncFocusShieldForCurrentContext()
        }
    }

    #if os(macOS)
        private func macEditSheet(for session: FocusSession) -> some View {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edit Focus")
                        .font(.title3.weight(.semibold))
                    Text("Adjust the recorded start time and duration.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    DatePicker(
                        "Started",
                        selection: $editStartedAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)

                    Stepper(value: $editDurationMinutes, in: 1...720) {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(FocusSessionFormatting.compactDurationText(seconds: TimeInterval(editDurationMinutes * 60)))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack {
                    Button(role: .destructive) {
                        delete(session)
                        editingSession = nil
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Spacer()

                    Button("Cancel") {
                        editingSession = nil
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Save") {
                        saveEdits(to: session)
                        editingSession = nil
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    #endif

    func focusSubtitle(snapshot: FocusSessionCardSnapshot) -> String {
        if isSleepModeActive {
            return "Sleep mode is active"
        }
        if snapshot.activeSessionForTask != nil {
            return "Session in progress"
        }
        if snapshot.activeSessionForAnotherTask != nil {
            return "Another task is already in focus"
        }
        if blockingFocusTitle != nil {
            return "Another focus timer is already running"
        }
        if snapshot.completedSessionsForTask.isEmpty {
            return "Start a timer without marking this task done."
        }
        return "\(FocusSessionFormatting.compactDurationText(seconds: snapshot.totalCompletedSeconds)) logged for this task"
    }

    func embeddedFocusStatusText(snapshot: FocusSessionCardSnapshot) -> String? {
        if isSleepModeActive {
            return "Sleep active"
        }
        if snapshot.activeSessionForTask != nil {
            return "Running"
        }
        if snapshot.activeSessionForAnotherTask != nil || blockingFocusTitle != nil {
            return "Busy"
        }
        if !snapshot.completedSessionsForTask.isEmpty {
            return FocusSessionFormatting.compactDurationText(seconds: snapshot.totalCompletedSeconds)
        }
        return nil
    }

    private var isSleepModeActive: Bool {
        !activeSleepSessions.isEmpty
    }

    func startSession(duration: TimeInterval) {
        do {
            _ = try FocusSessionSupport.startTaskFocus(
                task: task,
                plannedDurationSeconds: duration,
                context: modelContext,
                calendar: calendar
            )
        } catch {
            NSLog("Failed to start task focus: \(error.localizedDescription)")
        }
    }

    func startCountUpSession() {
        startSession(duration: 0)
    }

    func finish(_ session: FocusSession) {
        guard session.completedAt == nil else { return }
        let endedAt = Date()
        let pausedAt = session.pausedAt
        if let pausedAt {
            syncPausedCountUpPlannerSegment(for: session, pausedAt: pausedAt)
        }
        session.closePauseIfNeeded(at: endedAt)
        session.completedAt = endedAt
        if pausedAt == nil {
            syncEndedCountUpPlannerBlock(for: session, endedAt: endedAt)
        }
        DeviceActivityRecorder.recordAction(
            .completed,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
            in: modelContext
        )
        saveContext()
        syncFocusShieldForCurrentContext()
    }

    func abandon(_ session: FocusSession) {
        let endedAt = Date()
        session.closePauseIfNeeded(at: endedAt)
        session.abandonedAt = endedAt
        removeFocusPlannerBlock(for: session)
        DeviceActivityRecorder.recordAction(
            .ended,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
            details: "Abandoned focus session",
            in: modelContext
        )
        saveContext()
        syncFocusShieldForCurrentContext()
    }

    func pause(_ session: FocusSession) {
        let pausedAt = Date()
        guard session.pause(at: pausedAt) else { return }
        syncPausedCountUpPlannerSegment(for: session, pausedAt: pausedAt)
        DeviceActivityRecorder.recordAction(
            .paused,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
            details: "Paused focus session",
            at: pausedAt,
            in: modelContext
        )
        saveContext()
        syncFocusShieldForCurrentContext()
    }

    func resume(_ session: FocusSession) {
        let resumedAt = Date()
        let pausedAt = session.pausedAt
        if let pausedAt {
            syncPausedCountUpPlannerSegment(for: session, pausedAt: pausedAt)
        }
        guard session.resume(at: resumedAt) else { return }
        syncResumedCountUpPlannerSegment(for: session, resumedAt: resumedAt)
        DeviceActivityRecorder.recordAction(
            .resumed,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
            details: "Resumed focus session",
            at: resumedAt,
            in: modelContext
        )
        saveContext()
        syncFocusShieldForCurrentContext()
    }

    private func syncEndedCountUpPlannerBlock(for session: FocusSession, endedAt: Date) {
        DayPlanFocusSessionPlannerSync.saveEndedCountUpFocusBlock(
            for: task,
            session: session,
            endedAt: endedAt,
            calendar: calendar,
            context: modelContext
        )
    }

    private func syncPausedCountUpPlannerSegment(for session: FocusSession, pausedAt: Date) {
        DayPlanFocusSessionPlannerSync.savePausedCountUpFocusSegment(
            for: task,
            session: session,
            pausedAt: pausedAt,
            calendar: calendar,
            context: modelContext
        )
    }

    private func syncResumedCountUpPlannerSegment(for session: FocusSession, resumedAt: Date) {
        DayPlanFocusSessionPlannerSync.saveResumedCountUpFocusSegment(
            for: task,
            session: session,
            resumedAt: resumedAt,
            calendar: calendar,
            context: modelContext
        )
    }

    private func removeFocusPlannerBlock(for session: FocusSession) {
        DayPlanFocusSessionPlannerSync.removeFocusBlock(
            for: session,
            context: modelContext
        )
    }

    private func beginEditing(_ session: FocusSession) {
        editStartedAt = session.startedAt ?? session.completedAt ?? Date()
        editDurationMinutes = max(1, Int((session.actualDurationSeconds / 60).rounded()))
        editingSession = session
    }

    private func saveEdits(to session: FocusSession) {
        _ = DayPlanFocusSessionPlannerSync.updateCompletedFocusSession(
            session,
            startedAt: editStartedAt,
            durationMinutes: editDurationMinutes,
            titleSnapshot: DayPlanTaskSorting.title(for: task),
            emojiSnapshot: CalendarTaskImportSupport.displayEmoji(for: task.emoji),
            calendar: calendar,
            context: modelContext
        )
        saveContext()
        syncFocusShieldForCurrentContext()
    }

    private func delete(_ session: FocusSession) {
        DeviceActivityRecorder.recordAction(
            .deleted,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
            in: modelContext
        )
        modelContext.delete(session)
        saveContext()
        syncFocusShieldForCurrentContext()
    }

    private func saveContext() {
        do {
            try modelContext.save()
            syncFocusTimerSurfaces()
            NotificationCenter.default.postRoutineDidUpdate()
        } catch {
            NSLog("Focus session save failed: \(error.localizedDescription)")
        }
    }

    private func syncFocusTimerSurfaces() {
        #if os(iOS) && canImport(ActivityKit)
            Task { @MainActor in
                await FocusTimerLiveActivityService.sync(using: modelContext)
            }
        #endif
    }

    private func syncFocusShieldForCurrentContext() {
        #if (os(iOS) && ROUTINA_IOS_FAMILY_CONTROLS && canImport(FamilyControls) && canImport(ManagedSettings)) || os(macOS)
            FocusShieldSupport.syncFocusShield(using: modelContext)
        #endif
    }
}
