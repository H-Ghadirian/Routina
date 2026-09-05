import ComposableArchitecture
import SwiftUI

enum TaskRankingIOSSelection {
    case task
    case searchMatch
}

struct TaskRankingIOSTaskDestination: View {
    let store: StoreOf<TaskRankingFeature>
    let taskID: UUID
    let selection: TaskRankingIOSSelection

    var body: some View {
        Group {
            if store.selectedTaskID == taskID,
                let detailStore = store.scope(
                    state: \.taskDetailState,
                    action: \.taskDetail
                )
            {
                TaskDetailTCAView(store: detailStore)
            } else {
                ProgressView("Opening task…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: taskID) {
            guard store.selectedTaskID != taskID else { return }
            switch selection {
            case .task:
                store.send(.taskSelected(taskID))
            case .searchMatch:
                store.send(.searchMatchSelected(taskID))
            }
        }
    }
}

struct TaskLadderIOSGroupDetailView: View {
    let group: TaskLadderGroup
    let childCount: Int

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Text(group.displayEmoji)
                        .font(.largeTitle)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.displayName)
                            .font(.title2.weight(.semibold))

                        Text(childCount == 1 ? "1 actionable task" : "\(childCount) actionable tasks")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Task Ladder values") {
                ForEach(TaskRankingMetric.allCases.filter { $0 != .estimatedTime }) { metric in
                    LabeledContent(metric.title) {
                        Text(metric.value(for: group)?.title ?? "No value")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Group Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
