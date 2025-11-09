import SwiftUI

struct WatchHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var syncStore: WatchRoutineSyncStore

    var body: some View {
        List {
            if syncStore.routines.isEmpty {
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
                ForEach(syncStore.routines) { routine in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(routine.emoji) \(routine.name)")
                            .font(.headline)
                            .lineLimit(1)

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
                        .disabled(routine.isDoneToday())
                        .accessibilityLabel("Done")
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

    private func statusText(for routine: WatchRoutineSyncStore.WatchRoutine) -> String {
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
        let dueIn = routine.daysUntilDue(from: Date())
        if dueIn < 0 { return .red }
        if dueIn == 0 { return .orange }
        return .secondary
    }
}

#Preview {
    WatchHomeView(syncStore: WatchRoutineSyncStore())
}
