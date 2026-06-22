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
    let onCompletedDuration: ((TimeInterval) -> Void)?

    init(
        task: RoutineTask,
        sessions: [FocusSession],
        allTasks: [RoutineTask],
        isEmbedded: Bool = false,
        showsEmbeddedHeader: Bool = true,
        showsEmbeddedStartControls: Bool = true,
        blockingFocusTitle: String? = nil,
        onCompletedDuration: ((TimeInterval) -> Void)? = nil
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
        self.onCompletedDuration = onCompletedDuration
    }

    private let durationOptions: [TimeInterval] = [
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
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        if isForcedExpanded {
                            isExpanded = true
                        } else {
                            isExpanded.toggle()
                        }
                    }
                } label: {
                    HStack(alignment: isEmbedded ? .center : .top, spacing: isEmbedded ? 8 : 12) {
                        if !isEmbedded {
                            Image(systemName: "timer")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.teal)
                                .frame(width: 30, height: 30)
                                .routinaGlassPill(tint: .teal, tintOpacity: 0.14)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Focus")
                                .font(isEmbedded ? .subheadline.weight(.semibold) : .headline)
                                .foregroundStyle(.primary)

                            if !isEmbedded {
                                Text(focusSubtitle(snapshot: snapshot))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else if let statusText = embeddedFocusStatusText(snapshot: snapshot) {
                                Text(statusText)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isContentExpanded ? 180 : 0))
                            .padding(.top, isEmbedded ? 0 : 6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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

    private func focusSubtitle(snapshot: FocusSessionCardSnapshot) -> String {
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

    private func embeddedFocusStatusText(snapshot: FocusSessionCardSnapshot) -> String? {
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

    private var startFocusControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    countUpStartButton
                    if !isEmbedded {
                        durationStartButtons
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    countUpStartButton
                    if !isEmbedded {
                        durationStartButtons
                    }
                }
            }

            if !isEmbedded {
                Text(focusTrackingDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var countUpStartButton: some View {
        Button {
            startCountUpSession()
        } label: {
            Label(isEmbedded ? "Count up" : "Start count up", systemImage: "stopwatch")
        }
        .buttonStyle(.borderedProminent)
        .tint(.teal)
        .controlSize(.regular)
    }

    private var durationStartButtons: some View {
        HStack(spacing: 8) {
            ForEach(durationOptions.prefix(3), id: \.self) { seconds in
                Button(FocusSessionFormatting.compactDurationText(seconds: seconds)) {
                    startSession(duration: seconds)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Menu {
                ForEach(durationOptions.dropFirst(3), id: \.self) { seconds in
                    Button(FocusSessionFormatting.compactDurationText(seconds: seconds)) {
                        startSession(duration: seconds)
                    }
                }
            } label: {
                Label("More durations", systemImage: "ellipsis.circle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("More focus durations")
        }
    }

    private var focusTrackingDescription: String {
        if onCompletedDuration != nil {
            return "Finished focus sessions are added to time spent."
        }
        return "Focus time is tracked separately from completions."
    }

    private var isSleepModeActive: Bool {
        !activeSleepSessions.isEmpty
    }

    private var sleepModeActiveContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Sleep mode is active", systemImage: "bed.double.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Wake up before starting a focus timer.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func activeSessionContent(_ session: FocusSession, snapshot: FocusSessionCardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                let isCountUp = session.plannedDurationSeconds <= 0
                let elapsedSeconds = elapsedSeconds(for: session, now: context.date)
                let progress = progress(for: session, now: context.date)
                let displaySeconds = isCountUp
                    ? elapsedSeconds
                    : remainingSeconds(for: session, now: context.date)
                let timerStateLabel = session.isPaused
                    ? "paused"
                    : (isCountUp ? "elapsed" : "remaining")

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .lastTextBaseline) {
                        Text(FocusSessionFormatting.durationText(seconds: displaySeconds))
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .monospacedDigit()
                        Text(timerStateLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                    }

                    if isCountUp {
                        FocusSessionBlockProgressView(elapsedSeconds: elapsedSeconds)
                    } else {
                        ProgressView(value: progress)
                            .tint(.teal)
                    }

                    HStack(spacing: 10) {
                        Button {
                            if session.isPaused {
                                resume(session)
                            } else {
                                pause(session)
                            }
                        } label: {
                            Label(
                                session.isPaused ? "Resume" : "Pause",
                                systemImage: session.isPaused ? "play.circle.fill" : "pause.circle.fill"
                            )
                        }
                        .buttonStyle(.bordered)
                        .tint(.teal)

                        Button {
                            finish(session)
                        } label: {
                            Label("Finish", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)

                        Button(role: .destructive) {
                            abandon(session)
                        } label: {
                            Label("Abandon", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private func otherTaskActiveContent(_ session: FocusSession) -> some View {
        let taskName = session.focusTagTitle
            ?? (session.isUnassigned
                ? "unassigned focus"
                : allTasks.first { $0.id == session.taskID }?.name ?? "another task")

        return VStack(alignment: .leading, spacing: 10) {
            Label("Focusing on \(taskName)", systemImage: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Finish or abandon that session before starting a task focus session.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func blockingFocusContent(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Focusing on \(title)", systemImage: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Stop that focus timer before starting a task focus session.")
                .font(.caption)
                .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func startSession(duration: TimeInterval) {
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

    private func startCountUpSession() {
        startSession(duration: 0)
    }

    private func finish(_ session: FocusSession) {
        guard session.completedAt == nil else { return }
        let endedAt = Date()
        session.closePauseIfNeeded(at: endedAt)
        session.completedAt = endedAt
        syncEndedCountUpPlannerBlock(for: session, endedAt: endedAt)
        onCompletedDuration?(session.actualDurationSeconds)
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

    private func abandon(_ session: FocusSession) {
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

    private func pause(_ session: FocusSession) {
        let pausedAt = Date()
        guard session.pause(at: pausedAt) else { return }
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

    private func resume(_ session: FocusSession) {
        let resumedAt = Date()
        guard session.resume(at: resumedAt) else { return }
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
        let durationSeconds = TimeInterval(editDurationMinutes * 60)
        session.startedAt = editStartedAt
        session.completedAt = editStartedAt.addingTimeInterval(durationSeconds)
        session.abandonedAt = nil
        session.plannedDurationSeconds = durationSeconds
        session.clearPauseTracking()
        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .focusSession,
            entityID: session.id,
            entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
            in: modelContext
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

    private func progress(for session: FocusSession, now: Date) -> Double {
        let elapsed = session.activeDurationSeconds(at: now)
        guard session.plannedDurationSeconds > 0 else { return 1 }
        return min(1, elapsed / session.plannedDurationSeconds)
    }

    private func elapsedSeconds(for session: FocusSession, now: Date) -> TimeInterval {
        session.activeDurationSeconds(at: now)
    }

    private func remainingSeconds(for session: FocusSession, now: Date) -> TimeInterval {
        let elapsed = session.activeDurationSeconds(at: now)
        return max(0, session.plannedDurationSeconds - elapsed)
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
#if (os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)) || os(macOS)
        FocusShieldSupport.syncFocusShield(using: modelContext)
    #endif
    }
}
