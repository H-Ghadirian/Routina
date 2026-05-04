import SwiftUI

struct HomeMacBoardScopeInspectorView: View {
    let presentation: HomeBoardPresentation
    let sprintFocusSessions: [SprintFocusSession]
    let taskFocusSessions: [FocusSession]
    let taskFocusSessionTasks: [RoutineTask]
    let allocationSessionID: UUID?
    let allocationDrafts: [SprintFocusAllocationDraft]
    let onStartSprintFocus: (UUID) -> Void
    let onStopSprintFocus: (UUID) -> Void
    let onReviewSprintFocusAllocation: (UUID) -> Void
    let onAllocationMinutesChanged: (UUID, Int) -> Void
    let onSaveSprintFocusAllocation: () -> Void
    let onCancelSprintFocusAllocation: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                summaryCard
                sprintFocusCard
                countsCard
                dateCard
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: allocationSheetBinding) {
            sprintFocusAllocationSheet
                .frame(width: 480, height: 520)
        }
    }

    private var summaryCard: some View {
        inspectorCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(presentation.scopeTitle, systemImage: presentation.scopeIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(presentation.scopeDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var countsCard: some View {
        inspectorCard(title: "Tasks") {
            VStack(alignment: .leading, spacing: 8) {
                statRow("Open", presentation.openTodoCount, tint: .secondary)
                statRow("In Progress", presentation.inProgressTodoCount, tint: .blue)
                statRow("Blocked", presentation.blockedTodoCount, tint: .red)

                if !presentation.isBacklogScope {
                    statRow("Done", presentation.doneTodoCount, tint: .green)
                }
            }
        }
    }

    @ViewBuilder
    private var sprintFocusCard: some View {
        if let sprint = focusableSprint {
            inspectorCard(title: "Focus Timer") {
                let sessions = sprintFocusSessions
                    .filter { $0.sprintID == sprint.id }
                    .sorted { $0.startedAt > $1.startedAt }
                let activeSession = sessions.first(where: \.isActive)
                let activeTaskSession = activeTaskFocusSession
                let completedSessions = sessions.filter { !$0.isActive }

                VStack(alignment: .leading, spacing: 12) {
                    if let activeSession {
                        SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .lastTextBaseline) {
                                    Text(FocusSessionFormatting.durationText(seconds: elapsedSeconds(for: activeSession, now: context.date)))
                                        .font(.system(.title, design: .rounded).weight(.bold))
                                        .monospacedDigit()
                                    Text("elapsed")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 0)
                                }

                                Button {
                                    onStopSprintFocus(activeSession.id)
                                } label: {
                                    Label("Stop and allocate", systemImage: "stop.circle.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.teal)
                            }
                        }
                    } else if let activeTaskSession {
                        activeTaskFocusContent(activeTaskSession)
                    } else {
                        Button {
                            onStartSprintFocus(sprint.id)
                        } label: {
                            Label("Start sprint focus", systemImage: "timer")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                        .disabled(sprint.status == .finished || sprintFocusSessions.contains(where: \.isActive))
                    }

                    if !completedSessions.isEmpty {
                        Divider()
                        sprintFocusSessionHistory(completedSessions)
                    }
                }
            }
        }
    }

    private var dateCard: some View {
        inspectorCard(title: presentation.scopeDateCardTitle) {
            VStack(alignment: .leading, spacing: 8) {
                switch presentation.selectedScope {
                case .backlog:
                    dateRow("Created", nil)
                case let .namedBacklog(backlogID):
                    let backlog = presentation.backlogs.first { $0.id == backlogID }
                    dateRow("Created", backlog?.createdAt)
                case .currentSprint:
                    if presentation.activeSprints.isEmpty {
                        Text("No active sprint.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(presentation.activeSprints) { sprint in
                            sprintDateSummary(sprint)
                        }
                    }
                case let .sprint(sprintID):
                    if let sprint = presentation.sprints.first(where: { $0.id == sprintID }) {
                        sprintDateSummary(sprint)
                    }
                }
            }
        }
    }

    private func inspectorCard<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func statRow(_ title: String, _ value: Int, tint: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Text("\(value)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func sprintDateSummary(_ sprint: BoardSprint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sprint.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            dateRow("Start", sprint.startedAt)
            dateRow("Finish", sprint.finishedAt)

            if let activeDayTitle = presentation.activeDayTitle(for: sprint) {
                detailRow("Day", activeDayTitle)
            }
        }
    }

    private func dateRow(_ title: String, _ date: Date?) -> some View {
        detailRow(title, date.map(presentation.dateLabel(for:)) ?? "Not set")
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var activeTaskFocusSession: FocusSession? {
        taskFocusSessions.first { $0.state == .active }
    }

    private func activeTaskFocusContent(_ session: FocusSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Focusing on \(taskFocusTitle(for: session))", systemImage: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Stop that task focus timer before starting sprint focus.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func taskFocusTitle(for session: FocusSession) -> String {
        taskFocusSessionTasks.first(where: { $0.id == session.taskID })?.name ?? "a task"
    }

    private func sprintFocusSessionHistory(
        _ completedSessions: [SprintFocusSession]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Completed Sessions")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("\(allocationMinutesText(totalRecordedMinutes(in: completedSessions))) recorded")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text("\(completedSessions.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(completedSessions) { session in
                sprintFocusSessionRow(session)
            }
        }
    }

    private func sprintFocusSessionRow(_ session: SprintFocusSession) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(sprintFocusSessionSummary(session))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                onReviewSprintFocusAllocation(session.id)
            } label: {
                Label(
                    session.allocations.isEmpty ? "Allocate" : "Review",
                    systemImage: "slider.horizontal.3"
                )
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 2)
    }

    private func sprintFocusSessionSummary(_ session: SprintFocusSession) -> String {
        let recorded = allocationMinutesText(session.roundedDurationMinutes)
        guard session.allocatedMinutes > 0 else {
            return "\(recorded) recorded"
        }
        return "\(recorded) recorded, \(allocationMinutesText(session.allocatedMinutes)) allocated"
    }

    private func totalRecordedMinutes(in sessions: [SprintFocusSession]) -> Int {
        sessions.reduce(0) { $0 + $1.roundedDurationMinutes }
    }

    private var focusableSprint: BoardSprint? {
        switch presentation.selectedScope {
        case let .sprint(sprintID):
            return presentation.sprints.first(where: { $0.id == sprintID })
        case .currentSprint:
            return presentation.activeSprints.count == 1 ? presentation.activeSprints[0] : nil
        case .backlog, .namedBacklog:
            return nil
        }
    }

    private var allocationSheetBinding: Binding<Bool> {
        Binding(
            get: { allocationSessionID != nil },
            set: { if !$0 { onCancelSprintFocusAllocation() } }
        )
    }

    @ViewBuilder
    private var sprintFocusAllocationSheet: some View {
        if let sessionID = allocationSessionID,
           let session = sprintFocusSessions.first(where: { $0.id == sessionID }) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Allocate Sprint Focus")
                        .font(.title3.weight(.semibold))
                    Text("\(FocusSessionFormatting.compactDurationText(seconds: session.durationSeconds)) recorded. Assign minutes to tasks in this sprint.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if allocationDrafts.isEmpty {
                    Text("This sprint has no tasks yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    List {
                        ForEach(allocationDrafts) { draft in
                            sprintFocusAllocationRow(draft, session: session)
                        }
                    }
                    .listStyle(.inset)

                    HStack {
                        Text("Allocated")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 0)

                        Text("\(allocationMinutesText(totalAllocatedDraftMinutes)) of \(allocationMinutesText(session.roundedDurationMinutes))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }

                HStack {
                    Spacer()

                    Button("Cancel") {
                        onCancelSprintFocusAllocation()
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Save") {
                        onSaveSprintFocusAllocation()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(allocationDrafts.isEmpty)
                }
            }
            .padding(24)
        }
    }

    private func sprintFocusAllocationRow(
        _ draft: SprintFocusAllocationDraft,
        session: SprintFocusSession
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(taskTitle(for: draft.taskID))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(taskSubtitle(for: draft.taskID))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Stepper(
                value: allocationMinutesBinding(for: draft.taskID),
                in: 0...maximumAllocationMinutes(for: draft, session: session),
                step: 1
            ) {
                Text("\(draft.minutes)m")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .frame(width: 52, alignment: .trailing)
            }
            .frame(width: 150)
        }
        .padding(.vertical, 4)
    }

    private var totalAllocatedDraftMinutes: Int {
        allocationDrafts.reduce(0) { $0 + max(0, $1.minutes) }
    }

    private func maximumAllocationMinutes(
        for draft: SprintFocusAllocationDraft,
        session: SprintFocusSession
    ) -> Int {
        let otherAllocatedMinutes = allocationDrafts.reduce(0) { total, otherDraft in
            otherDraft.taskID == draft.taskID ? total : total + max(0, otherDraft.minutes)
        }
        return max(0, session.roundedDurationMinutes - otherAllocatedMinutes + draft.minutes)
    }

    private func allocationMinutesText(_ minutes: Int) -> String {
        minutes == 0 ? "0m" : RoutineTimeSpentFormatting.compactMinutesText(minutes)
    }

    private func allocationMinutesBinding(for taskID: UUID) -> Binding<Int> {
        Binding(
            get: { allocationDrafts.first(where: { $0.taskID == taskID })?.minutes ?? 0 },
            set: { onAllocationMinutesChanged(taskID, $0) }
        )
    }

    private func taskTitle(for taskID: UUID) -> String {
        presentation.boardTodoDisplays.first(where: { $0.id == taskID })?.name ?? "Task"
    }

    private func taskSubtitle(for taskID: UUID) -> String {
        presentation.boardTodoDisplays.first(where: { $0.id == taskID })?.todoState?.displayTitle ?? "Sprint task"
    }

    private func elapsedSeconds(for session: SprintFocusSession, now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(session.startedAt))
    }
}
