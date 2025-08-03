import SwiftUI

struct WatchHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var syncStore: WatchRoutineSyncStore

    var body: some View {
        List {
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
                            Label("Done", systemImage: "checkmark")
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

    private func statusText(for routine: WatchRoutineSyncStore.WatchRoutine) -> String {
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
        if routine.isInProgress { return .orange }
        let dueIn = routine.daysUntilDue(from: Date())
        if dueIn < 0 { return .red }
        if dueIn == 0 { return .orange }
        return .secondary
    }
}

#Preview {
    WatchHomeView(syncStore: WatchRoutineSyncStore())
}
