import SwiftData
import SwiftUI
#if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
import FamilyControls
#endif
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct FocusSessionCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Query private var activeSleepSessions: [SleepSession]
    @State private var isExpanded = false
    @State private var editingSession: FocusSession?
    @State private var editStartedAt = Date()
    @State private var editDurationMinutes = 25
    #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
    @AppStorage(
        UserDefaultBoolValueKey.appSettingFocusShieldEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isFocusShieldEnabled = false
    @State private var focusShieldSelection = FocusShieldSupport.loadSelection()
    @State private var isFocusShieldPickerPresented = false
    @State private var isRequestingFocusShieldAuthorization = false
    @State private var focusShieldStatusMessage: String?
    #endif
    #if os(macOS)
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacFocusAppBlockingEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isMacFocusAppBlockingEnabled = true
    @State private var macBlockedApps = FocusShieldSupport.loadMacBlockedApps()
    @State private var macFocusShieldStatusMessage: String?
    #endif

    let task: RoutineTask
    let sessions: [FocusSession]
    let allTasks: [RoutineTask]
    let isEmbedded: Bool
    let blockingFocusTitle: String?
    let onCompletedDuration: ((TimeInterval) -> Void)?

    init(
        task: RoutineTask,
        sessions: [FocusSession],
        allTasks: [RoutineTask],
        isEmbedded: Bool = false,
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
        self.task = task
        self.sessions = sessions
        self.allTasks = allTasks
        self.isEmbedded = isEmbedded
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

        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    if isForcedExpanded {
                        isExpanded = true
                    } else {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "timer")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.teal)
                        .frame(width: 30, height: 30)
                        .routinaGlassPill(tint: .teal, tintOpacity: 0.14)

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
                        .rotationEffect(.degrees(isContentExpanded ? 180 : 0))
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isContentExpanded {
                if isSleepModeActive {
                    sleepModeActiveContent
                } else if let activeSessionForTask = snapshot.activeSessionForTask {
                    activeSessionContent(activeSessionForTask)
                } else if let activeSessionForAnotherTask = snapshot.activeSessionForAnotherTask {
                    otherTaskActiveContent(activeSessionForAnotherTask)
                } else if let blockingFocusTitle {
                    blockingFocusContent(blockingFocusTitle)
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
            isExpanded = false
        }
        .task {
            syncFocusShieldForCurrentContext()
        }
        #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
        .familyActivityPicker(
            title: "Blocked During Focus",
            headerText: "Choose the apps, categories, and websites Routina should block while a focus timer is running.",
            footerText: "Routina only receives private tokens for your choices.",
            isPresented: $isFocusShieldPickerPresented,
            selection: $focusShieldSelection
        )
        .onChange(of: focusShieldSelection) { _, selection in
            FocusShieldSupport.saveSelection(selection)
            focusShieldStatusMessage = selection.routinaSummaryText
            syncFocusShieldForCurrentContext()
        }
        .onChange(of: isFocusShieldEnabled) { _, _ in
            focusShieldStatusMessage = focusShieldSelection.routinaSummaryText
            syncFocusShieldForCurrentContext()
        }
        #elseif os(macOS)
        .onChange(of: isMacFocusAppBlockingEnabled) { _, _ in
            macFocusShieldStatusMessage = FocusShieldSupport.macBlockedAppsSummaryText(macBlockedApps)
            syncFocusShieldForCurrentContext()
        }
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

            #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
            focusShieldControls
            #elseif os(macOS)
            macFocusShieldControls
            #endif

            Text(focusTrackingDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
    private var focusShieldControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isFocusShieldEnabled) {
                Label("Block apps and websites", systemImage: "lock.shield")
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(.switch)

            if isFocusShieldEnabled {
                HStack(spacing: 8) {
                    Button {
                        requestFocusShieldAuthorization()
                    } label: {
                        Label(focusShieldAuthorizationButtonTitle, systemImage: "person.badge.key")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRequestingFocusShieldAuthorization)

                    Button {
                        focusShieldSelection = FocusShieldSupport.loadSelection()
                        isFocusShieldPickerPresented = true
                    } label: {
                        Label("Choose", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)
                    .disabled(focusShieldAuthorizationState != .approved)
                }

                Text(focusShieldDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .routinaGlassCard(cornerRadius: 10, tint: .teal, tintOpacity: 0.05)
    }

    private var focusShieldAuthorizationState: FocusShieldAuthorizationState {
        FocusShieldSupport.authorizationState()
    }

    private var focusShieldAuthorizationButtonTitle: String {
        switch focusShieldAuthorizationState {
        case .approved:
            return "Allowed"
        case .denied:
            return "Allow Access"
        case .notDetermined:
            return "Allow Access"
        case .unavailable:
            return "Unavailable"
        }
    }

    private var focusShieldDescription: String {
        if let focusShieldStatusMessage {
            return focusShieldStatusMessage
        }

        switch focusShieldAuthorizationState {
        case .approved:
            return focusShieldSelection.routinaSummaryText
        case .denied:
            return "Screen Time access is off. Allow access to block selected apps and websites during focus."
        case .notDetermined:
            return "Allow Screen Time access, then choose what to block during focus."
        case .unavailable:
            return "App and website blocking is available on iPhone and iPad."
        }
    }

    private func requestFocusShieldAuthorization() {
        isRequestingFocusShieldAuthorization = true
        Task { @MainActor in
            do {
                try await FocusShieldSupport.requestAuthorization()
                focusShieldStatusMessage = FocusShieldSupport.authorizationState() == .approved
                    ? focusShieldSelection.routinaSummaryText
                    : "Screen Time access was not approved."
                syncFocusShieldForCurrentContext()
            } catch {
                focusShieldStatusMessage = "Screen Time access failed: \(error.localizedDescription)"
            }
            isRequestingFocusShieldAuthorization = false
        }
    }
    #endif

    #if os(macOS)
    private var macFocusShieldControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isMacFocusAppBlockingEnabled) {
                Label("Block apps", systemImage: "lock.shield")
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(.switch)

            if isMacFocusAppBlockingEnabled {
                HStack(spacing: 8) {
                    Button {
                        chooseMacBlockedApps()
                    } label: {
                        Label("Choose Apps", systemImage: "plus.app")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        macBlockedApps = []
                        FocusShieldSupport.saveMacBlockedApps(macBlockedApps)
                        macFocusShieldStatusMessage = FocusShieldSupport.macBlockedAppsSummaryText(macBlockedApps)
                        syncFocusShieldForCurrentContext()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(macBlockedApps.isEmpty)
                }

                if !macBlockedApps.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(macBlockedApps) { app in
                            HStack(spacing: 8) {
                                Text(app.displayName)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)

                                Spacer(minLength: 8)

                                Button {
                                    removeMacBlockedApp(app)
                                } label: {
                                    Label("Remove \(app.displayName)", systemImage: "minus.circle")
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .help("Remove")
                            }
                        }
                    }
                }

                Text(macFocusShieldDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .routinaGlassCard(cornerRadius: 10, tint: .teal, tintOpacity: 0.05)
    }

    private var macFocusShieldDescription: String {
        if let macFocusShieldStatusMessage {
            return "\(macFocusShieldStatusMessage). Website blocking is only available through iOS Screen Time."
        }

        let appSummary = FocusShieldSupport.macBlockedAppsSummaryText(macBlockedApps)
        return "\(appSummary). Routina closes selected Mac apps while a focus timer is running. Website blocking is only available through iOS Screen Time."
    }

    private func chooseMacBlockedApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose apps to block while a focus timer is running."
        panel.prompt = "Choose"

        guard panel.runModal() == .OK else { return }

        let newApps = panel.urls.compactMap(FocusShieldSupport.macBlockedApp(from:))
        guard !newApps.isEmpty else {
            macFocusShieldStatusMessage = "No valid apps selected"
            return
        }

        macBlockedApps.append(contentsOf: newApps)
        FocusShieldSupport.saveMacBlockedApps(macBlockedApps)
        macBlockedApps = FocusShieldSupport.loadMacBlockedApps()
        macFocusShieldStatusMessage = FocusShieldSupport.macBlockedAppsSummaryText(macBlockedApps)
        syncFocusShieldForCurrentContext()
    }

    private func removeMacBlockedApp(_ app: MacFocusBlockedApp) {
        macBlockedApps.removeAll { $0.id == app.id }
        FocusShieldSupport.saveMacBlockedApps(macBlockedApps)
        macBlockedApps = FocusShieldSupport.loadMacBlockedApps()
        macFocusShieldStatusMessage = FocusShieldSupport.macBlockedAppsSummaryText(macBlockedApps)
        syncFocusShieldForCurrentContext()
    }
    #endif

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

    private func activeSessionContent(_ session: FocusSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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

            #if os(iOS) && canImport(FamilyControls) && canImport(ManagedSettings)
            focusShieldControls
            #elseif os(macOS)
            macFocusShieldControls
            #endif
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
        do {
            guard try SleepSessionSupport.activeSession(in: modelContext) == nil else {
                return
            }
            let startedAt = Date()
            let session = FocusSession(
                taskID: task.id,
                startedAt: startedAt,
                plannedDurationSeconds: duration
            )
            modelContext.insert(session)
            DayPlanFocusSessionPlannerSync.saveStartedFocusBlock(
                for: task,
                session: session,
                startedAt: startedAt,
                durationSeconds: duration,
                calendar: calendar,
                context: modelContext
            )
            DeviceActivityRecorder.recordAction(
                .started,
                entity: .focusSession,
                entityID: session.id,
                entityTitle: RoutineTask.trimmedName(task.name) ?? "Untitled task",
                in: modelContext
            )
            saveContext()
            syncFocusShieldForCurrentContext()
        } catch {
            NSLog("Failed to check sleep mode before starting focus: \(error.localizedDescription)")
        }
    }

    private func startCountUpSession() {
        startSession(duration: 0)
    }

    private func finish(_ session: FocusSession) {
        guard session.completedAt == nil else { return }
        let endedAt = Date()
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
        session.abandonedAt = endedAt
        syncEndedCountUpPlannerBlock(for: session, endedAt: endedAt)
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

    private func syncEndedCountUpPlannerBlock(for session: FocusSession, endedAt: Date) {
        DayPlanFocusSessionPlannerSync.saveEndedCountUpFocusBlock(
            for: task,
            session: session,
            endedAt: endedAt,
            calendar: calendar,
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
