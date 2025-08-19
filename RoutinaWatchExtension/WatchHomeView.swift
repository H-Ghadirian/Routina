import SwiftUI

struct WatchHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var syncStore: WatchRoutineSyncStore

    var body: some View {
        List {
            if let activeFocusSession = syncStore.activeFocusSession {
                focusSessionRow(activeFocusSession)
            }

            if !syncStore.isCompanionAppInstalled {
                watchStateMessage(
                    systemImage: "iphone.slash",
                    title: "Install iPhone app",
                    message: "Install Routina on iPhone to enable watch sync."
                )
            } else if !syncStore.isPhoneReachable && syncStore.routines.isEmpty {
                watchStateMessage(
                    systemImage: "iphone",
                    title: "Open Routina on iPhone",
                    message: "Open Routina on iPhone for the first sync."
                )
            } else if syncStore.routines.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "applewatch.slash")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("No routines yet")
                        .font(.headline)
                    Text("Add a routine on iPhone and keep both apps open for first sync.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            } else {
                if !syncStore.isPhoneReachable {
                    watchStateMessage(
                        systemImage: "arrow.triangle.2.circlepath",
                        title: "Showing cached routines",
                        message: "Open iPhone app to sync latest changes."
                    )
                }

                ForEach(syncStore.routines) { routine in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(routine.emoji) \(routine.name)")
                            .font(.headline)
                            .lineLimit(1)

                        if let nextStepTitle = routine.nextStepTitle {
                            Text("Next: \(nextStepTitle)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Text(statusText(for: routine))
                            .font(.footnote)
                            .foregroundStyle(statusColor(for: routine))
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            syncStore.markRoutineDone(id: routine.id)
                        } label: {
                            Label(actionTitle(for: routine), systemImage: "checkmark")
                        }
                        .tint(.green)
                        .disabled(!routine.canMarkDone())
                    }
                }
            }
        }
        .navigationTitle("Routina")
        .onAppear {
            syncStore.requestSync()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                syncStore.requestSync()
            }
        }
    }

    private func focusSessionRow(_ session: WatchRoutineSyncStore.WatchFocusSession) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .foregroundStyle(.teal)
                    Text("Focus")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }

                Text(focusTimerText(for: session, now: context.date))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)

                Text("\(session.taskEmoji) \(session.taskName)")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)

                if session.isCountUp {
                    ProgressView()
                        .tint(.teal)
                } else {
                    ProgressView(value: focusProgress(for: session, now: context.date))
                        .tint(.teal)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func watchStateMessage(systemImage: String, title: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
    }

    private func focusTimerText(for session: WatchRoutineSyncStore.WatchFocusSession, now: Date) -> String {
        if session.isCountUp {
            return focusDurationText(seconds: session.elapsedSeconds(at: now))
        }

        return focusDurationText(seconds: session.remainingSeconds(at: now))
    }

    private func focusProgress(for session: WatchRoutineSyncStore.WatchFocusSession, now: Date) -> Double {
        guard session.plannedDurationSeconds > 0 else { return 1 }
        return min(1, max(0, session.elapsedSeconds(at: now) / session.plannedDurationSeconds))
    }

    private func focusDurationText(seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func statusText(for routine: WatchRoutineSyncStore.WatchRoutine) -> String {
        if routine.isOneOffTask {
            if routine.isInProgress {
                return "Step \(routine.completedStepCount + 1) of \(routine.steps.count)"
            }
            return "To do"
        }
        if routine.isChecklistDriven {
            let dueIn = routine.daysUntilDue(from: Date())
            if dueIn < 0 {
                let overdueDays = abs(dueIn)
                let dayWord = overdueDays == 1 ? "day" : "days"
                return "Overdue by \(overdueDays) \(dayWord)"
            }
            if dueIn == 0, let nextDueChecklistItemTitle = routine.nextDueChecklistItemTitle {
                return "\(nextDueChecklistItemTitle) due today"
            }
            if dueIn == 0 { return "Due today" }
            if routine.isDoneToday() { return "Updated today" }
            return "Due in \(dueIn) days"
        }
        if routine.isChecklistCompletionRoutine {
            if routine.isDoneToday() {
                return "Done today"
            }
            if routine.completedChecklistItemCount > 0 {
                return "Checklist \(routine.completedChecklistItemCount) of \(max(routine.checklistItemCount, 1))"
            }
            let dueIn = routine.daysUntilDue(from: Date())
            if dueIn < 0 {
                let overdueDays = abs(dueIn)
                let dayWord = overdueDays == 1 ? "day" : "days"
                return "Overdue by \(overdueDays) \(dayWord)"
            }
            if dueIn == 0 { return "Due today" }
            if let nextPendingChecklistItemTitle = routine.nextPendingChecklistItemTitle {
                return "Next: \(nextPendingChecklistItemTitle)"
            }
            return "Due in \(dueIn) days"
        }
        if routine.isInProgress {
            return "Step \(routine.completedStepCount + 1) of \(routine.steps.count)"
        }
        let dueIn = routine.daysUntilDue(from: Date())
        if dueIn < 0 {
            let overdueDays = abs(dueIn)
            let dayWord = overdueDays == 1 ? "day" : "days"
            return "Overdue by \(overdueDays) \(dayWord)"
        }
        if dueIn == 0 { return "Due today" }
        return "Due in \(dueIn) days"
    }

    private func statusColor(for routine: WatchRoutineSyncStore.WatchRoutine) -> Color {
        if routine.isOneOffTask {
            return routine.isInProgress ? .orange : .blue
        }
        if routine.isChecklistDriven {
            let dueIn = routine.daysUntilDue(from: Date())
            if dueIn < 0 { return .red }
            if dueIn == 0 { return .orange }
            if routine.isDoneToday() { return .green }
            return .secondary
        }
        if routine.isChecklistCompletionRoutine {
            if routine.completedChecklistItemCount > 0 { return .orange }
            if routine.isDoneToday() { return .green }
            let dueIn = routine.daysUntilDue(from: Date())
            if dueIn < 0 { return .red }
            if dueIn == 0 { return .orange }
            return .secondary
        }
        if routine.isInProgress { return .orange }
        let dueIn = routine.daysUntilDue(from: Date())
        if dueIn < 0 { return .red }
        if dueIn == 0 { return .orange }
        return .secondary
    }

    private func actionTitle(for routine: WatchRoutineSyncStore.WatchRoutine) -> String {
        if routine.isChecklistDriven {
            return "Buy Due"
        }
        if routine.isChecklistCompletionRoutine {
            return "Checklist"
        }
        return "Done"
    }
}

#Preview {
    WatchHomeView(syncStore: WatchRoutineSyncStore())
}
