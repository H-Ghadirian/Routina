import SwiftData
import SwiftUI

struct FocusSessionCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isExpanded = false
    @State private var editingSession: FocusSession?
    @State private var editStartedAt = Date()
    @State private var editDurationMinutes = 25

    let task: RoutineTask
    let sessions: [FocusSession]
    let allTasks: [RoutineTask]
    let isEmbedded: Bool
    let onCompletedDuration: ((TimeInterval) -> Void)?

    init(
        task: RoutineTask,
        sessions: [FocusSession],
        allTasks: [RoutineTask],
        isEmbedded: Bool = false,
        onCompletedDuration: ((TimeInterval) -> Void)? = nil
    ) {
        self.task = task
        self.sessions = sessions
        self.allTasks = allTasks
        self.isEmbedded = isEmbedded
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

        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "timer")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.teal)
                        .frame(width: 30, height: 30)
                        .background(.teal.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Focus")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(focusSubtitle(snapshot: snapshot))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                if let activeSessionForTask = snapshot.activeSessionForTask {
                    activeSessionContent(activeSessionForTask)
                } else if let activeSessionForAnotherTask = snapshot.activeSessionForAnotherTask {
                    otherTaskActiveContent(activeSessionForAnotherTask)
                } else {
                    startFocusControls
                }

                if !snapshot.completedSessionsForTask.isEmpty {
                    Divider()
                    focusHistorySummary(snapshot: snapshot)
                    focusSessionHistory(snapshot: snapshot)
                }
            }
        }
        .padding(isEmbedded ? 0 : 16)
        .background {
            if !isEmbedded {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardBackground)
            }
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
            isExpanded = false
        }
    }

    private var cardBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
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
        if snapshot.activeSessionForTask != nil {
            return "Session in progress"
        }
        if snapshot.activeSessionForAnotherTask != nil {
            return "Another task is already in focus"
        }
        if snapshot.completedSessionsForTask.isEmpty {
            return "Start a timer without marking this task done."
        }
        return "\(FocusSessionFormatting.compactDurationText(seconds: snapshot.totalCompletedSeconds)) logged for this task"
    }

    private var startFocusControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                startCountUpSession()
            } label: {
                Label("Count up", systemImage: "stopwatch")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .controlSize(.regular)

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
                    Label("More", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("More focus durations")
            }

            Text(focusTrackingDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var focusTrackingDescription: String {
        if onCompletedDuration != nil {
            return "Finished focus sessions are added to time spent."
        }
        return "Focus time is tracked separately from completions."
    }

    private func activeSessionContent(_ session: FocusSession) -> some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
            let isCountUp = session.plannedDurationSeconds <= 0
            let progress = progress(for: session, now: context.date)
            let displaySeconds = isCountUp
                ? elapsedSeconds(for: session, now: context.date)
                : remainingSeconds(for: session, now: context.date)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .lastTextBaseline) {
                    Text(FocusSessionFormatting.durationText(seconds: displaySeconds))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Text(isCountUp ? "elapsed" : "remaining")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                }

                if isCountUp {
                    ProgressView()
                        .tint(.teal)
                } else {
                    ProgressView(value: progress)
                        .tint(.teal)
                }

                HStack(spacing: 10) {
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

    private func otherTaskActiveContent(_ session: FocusSession) -> some View {
        let taskName = allTasks.first { $0.id == session.taskID }?.name ?? "another task"

        return VStack(alignment: .leading, spacing: 10) {
            Label("Focusing on \(taskName)", systemImage: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Finish or abandon that session before starting a new one.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func focusHistorySummary(snapshot: FocusSessionCardSnapshot) -> some View {
        HStack(spacing: 12) {
            metricTile(
                title: "Total",
                value: FocusSessionFormatting.compactDurationText(seconds: snapshot.totalCompletedSeconds)
            )
            metricTile(
                title: "Sessions",
                value: snapshot.completedSessionsForTask.count.formatted()
            )
            if let latest = snapshot.completedSessionsForTask.first?.completedAt {
                metricTile(
                    title: "Latest",
                    value: latest.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
    }

    private func focusSessionHistory(snapshot: FocusSessionCardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent focus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(snapshot.completedSessionsForTask.prefix(3)) { session in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.completedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                            .font(.caption.weight(.semibold))

                        Text(FocusSessionFormatting.compactDurationText(seconds: session.actualDurationSeconds))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    Button {
                        beginEditing(session)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Edit focus session")
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func metricTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func startSession(duration: TimeInterval) {
        modelContext.insert(
            FocusSession(
                taskID: task.id,
                plannedDurationSeconds: duration
            )
        )
        saveContext()
    }

    private func startCountUpSession() {
        startSession(duration: 0)
    }

    private func finish(_ session: FocusSession) {
        guard session.completedAt == nil else { return }
        session.completedAt = Date()
        onCompletedDuration?(session.actualDurationSeconds)
        saveContext()
    }

    private func abandon(_ session: FocusSession) {
        session.abandonedAt = Date()
        saveContext()
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
        saveContext()
    }

    private func delete(_ session: FocusSession) {
        modelContext.delete(session)
        saveContext()
    }

    private func progress(for session: FocusSession, now: Date) -> Double {
        guard let startedAt = session.startedAt else { return 0 }
        let elapsed = max(0, now.timeIntervalSince(startedAt))
        guard session.plannedDurationSeconds > 0 else { return 1 }
        return min(1, elapsed / session.plannedDurationSeconds)
    }

    private func elapsedSeconds(for session: FocusSession, now: Date) -> TimeInterval {
        guard let startedAt = session.startedAt else { return 0 }
        return max(0, now.timeIntervalSince(startedAt))
    }

    private func remainingSeconds(for session: FocusSession, now: Date) -> TimeInterval {
        guard let startedAt = session.startedAt else {
            return session.plannedDurationSeconds
        }
        let elapsed = max(0, now.timeIntervalSince(startedAt))
        return max(0, session.plannedDurationSeconds - elapsed)
    }

    private func saveContext() {
        do {
            try modelContext.save()
            NotificationCenter.default.postRoutineDidUpdate()
        } catch {
            NSLog("Focus session save failed: \(error.localizedDescription)")
        }
    }
}

private struct FocusSessionCardSnapshot {
    let activeSessionForTask: FocusSession?
    let activeSessionForAnotherTask: FocusSession?
    let completedSessionsForTask: [FocusSession]
    let totalCompletedSeconds: TimeInterval

    init(taskID: UUID, sessions: [FocusSession]) {
        var activeSessionForTask: FocusSession?
        var activeSessionForAnotherTask: FocusSession?
        var completedSessionsForTask: [FocusSession] = []

        for session in sessions {
            if session.taskID == taskID {
                if session.completedAt != nil {
                    completedSessionsForTask.append(session)
                } else if session.abandonedAt == nil && activeSessionForTask == nil {
                    activeSessionForTask = session
                }
            } else if session.completedAt == nil
                        && session.abandonedAt == nil
                        && activeSessionForAnotherTask == nil {
                activeSessionForAnotherTask = session
            }
        }

        completedSessionsForTask.sort {
            ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
        }

        self.activeSessionForTask = activeSessionForTask
        self.activeSessionForAnotherTask = activeSessionForAnotherTask
        self.completedSessionsForTask = completedSessionsForTask
        self.totalCompletedSeconds = completedSessionsForTask.reduce(0) {
            $0 + $1.actualDurationSeconds
        }
    }
}
