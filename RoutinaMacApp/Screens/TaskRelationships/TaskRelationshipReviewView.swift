import ComposableArchitecture
import SwiftUI

struct TaskRelationshipReviewView: View {
    let store: StoreOf<TaskRelationshipReviewFeature>

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 250, idealWidth: 280, maxWidth: 340)

            detail
                .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tasks")
                        .font(.headline)

                    Text(store.catalogStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button {
                    store.send(.refreshTapped)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .help("Refresh task catalog")
                .disabled(
                    store.isLoadingCatalog
                        || store.isFindingSuggestions
                        || store.isAnalyzingAll
                )
            }
            .padding(16)

            Divider()

            if store.isLoadingCatalog {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Loading tasks…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.tasks) { task in
                            taskRow(task)
                        }
                    }
                    .padding(8)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private func taskRow(_ task: TaskRelationshipReviewTask) -> some View {
        let isSelected = store.selectedTaskID == task.id
        let isReviewed = store.reviewedTaskIDs.contains(task.id)
        let pendingSuggestionCount = store.suggestionsByTaskID[task.id]?.count ?? 0
        let batchFailureMessage = store.batchFailureMessagesByTaskID[task.id]
        let currentFingerprint = store.currentFingerprintsByTaskID[task.id]
        let reviewedFingerprint = store.reviewedFingerprintsByTaskID[task.id]
        let changeLabel = reviewedFingerprint == nil ? "New" : "Changed"

        return Button {
            store.send(.taskSelected(task.id))
        } label: {
            HStack(spacing: 10) {
                Text(task.emoji)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !task.path.isEmpty {
                        Text(task.path.joined(separator: " › "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if task.relationshipCount > 0 {
                        Text("\(task.relationshipCount) linked")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 6)

                if pendingSuggestionCount > 0 {
                    Text("\(pendingSuggestionCount)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.accentColor, in: Capsule())
                        .accessibilityLabel(
                            "\(pendingSuggestionCount) relationship suggestions"
                        )
                } else if let batchFailureMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Could not analyze this task")
                        .help(batchFailureMessage)
                } else if isReviewed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Reviewed and unchanged")
                } else if currentFingerprint != reviewedFingerprint {
                    Text(changeLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.savingSuggestionTargetID != nil || store.isAnalyzingAll)
    }

    @ViewBuilder
    private var detail: some View {
        if let selectedTask = store.selectedTask {
            VStack(spacing: 0) {
                detailHeader(selectedTask)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        selectedTaskContext(selectedTask)

                        if store.isAnalyzingAll {
                            batchAnalyzingState
                        } else if store.isFindingSuggestions {
                            analyzingState
                        } else if !store.suggestions.isEmpty {
                            if store.batchTotalCount > 0 {
                                batchResultSummary
                            }
                            suggestionsContent(sourceTask: selectedTask)
                        } else {
                            emptySuggestionState
                        }
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        } else {
            ContentUnavailableView(
                "No task selected",
                systemImage: "point.3.connected.trianglepath.dotted",
                description: Text(store.message ?? "Choose a task to review possible relationships.")
            )
        }
    }

    private func detailHeader(_ task: TaskRelationshipReviewTask) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Review Task Relationships")
                    .font(.title2.weight(.semibold))

                Text("AI suggestions never change tasks until you confirm them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                if store.isAnalyzingAll {
                    Button {
                        store.send(.stopAnalyzeAllTapped)
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(minHeight: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button {
                        store.send(.analyzeNewOrChangedTapped)
                    } label: {
                        Label(
                            "Analyze new & changed (\(store.newOrChangedCount))",
                            systemImage: "sparkles"
                        )
                            .frame(minHeight: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.canAnalyzeNewOrChanged)

                    Menu {
                        Button {
                            store.send(.findSuggestionsTapped)
                        } label: {
                            Label("Analyze selected task", systemImage: "scope")
                        }
                        .disabled(!store.canFindSuggestions)

                        Divider()

                        Button {
                            store.send(.analyzeAllTapped)
                        } label: {
                            Label("Reanalyze all tasks", systemImage: "square.stack.3d.up")
                        }
                        .disabled(!store.canAnalyzeAll)
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                            .frame(minHeight: 22)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private func selectedTaskContext(_ task: TaskRelationshipReviewTask) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(task.emoji)
                    .font(.largeTitle)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.title3.weight(.semibold))

                    Text(task.relationshipCount == 1
                         ? "1 existing relationship"
                         : "\(task.relationshipCount) existing relationships")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !task.path.isEmpty {
                Label(task.path.joined(separator: " › "), systemImage: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !task.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(task.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var analyzingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text("Looking for prerequisites and clearly related tasks…")
                .font(.headline)

            Text("Routina analyzes a bounded, relevant set so large task lists remain responsive.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private var batchAnalyzingState: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Analyzing \(store.batchTotalCount) tasks")
                        .font(.headline)

                    if let task = store.batchCurrentTask {
                        Text("Checking \(task.emoji) \(task.title)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            ProgressView(
                value: Double(store.batchCompletedCount),
                total: Double(max(store.batchTotalCount, 1))
            )

            HStack {
                Text("\(store.batchCompletedCount) of \(store.batchTotalCount) tasks processed")
                Spacer()
                Text("\(store.batchSuggestionCount) suggestions found")
                if store.batchFailureCount > 0 {
                    Text("• \(store.batchFailureLabel)")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text("Each task uses a bounded candidate set. Nothing is linked until you review and confirm a suggestion.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private var batchResultSummary: some View {
        let hasFailures = store.batchFailureCount > 0

        return HStack(spacing: 10) {
            Image(systemName: hasFailures
                  ? "exclamationmark.triangle.fill"
                  : "checkmark.circle.fill")
                .foregroundStyle(hasFailures ? Color.orange : .green)

            Text(
                "Processed \(store.batchCompletedCount) of \(store.batchTotalCount) tasks • "
                    + "\(store.batchSuggestionCount) suggestions remaining"
                    + (hasFailures ? " • \(store.batchFailureLabel)" : "")
            )
                .font(.callout.weight(.medium))

            Spacer(minLength: 8)
        }
        .padding(12)
        .background(
            (hasFailures ? Color.orange : Color.green).opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }

    private func suggestionsContent(sourceTask: TaskRelationshipReviewTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Possible relationships")
                .font(.headline)

            ForEach(store.suggestions) { suggestion in
                suggestionCard(suggestion, sourceTask: sourceTask)
            }
        }
    }

    private func suggestionCard(
        _ suggestion: TaskRelationshipSuggestion,
        sourceTask: TaskRelationshipReviewTask
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                taskIdentity(emoji: sourceTask.emoji, title: sourceTask.title)

                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)

                Picker("Relationship", selection: Binding(
                    get: { suggestion.kind },
                    set: { store.send(.suggestionKindChanged(suggestion.targetTaskID, $0)) }
                )) {
                    Label("Blocked by", systemImage: "exclamationmark.triangle")
                        .tag(RoutineTaskRelationshipKind.blockedBy)
                    Label("Blocks", systemImage: "arrow.turn.down.right")
                        .tag(RoutineTaskRelationshipKind.blocks)
                    Label("Related", systemImage: "link")
                        .tag(RoutineTaskRelationshipKind.related)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()

                Image(systemName: "arrow.right")
                    .foregroundStyle(.tertiary)

                taskIdentity(
                    emoji: suggestion.targetTaskEmoji,
                    title: suggestion.targetTaskTitle
                )
            }

            Text(suggestion.reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    store.send(.dismissSuggestionTapped(suggestion.targetTaskID))
                } label: {
                    Text("Dismiss")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .disabled(store.savingSuggestionTargetID != nil)

                Button {
                    store.send(.confirmSuggestionTapped(suggestion.targetTaskID))
                } label: {
                    Group {
                        if store.savingSuggestionTargetID == suggestion.targetTaskID {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Confirm")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.savingSuggestionTargetID != nil)
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
    }

    private func taskIdentity(emoji: String, title: String) -> some View {
        HStack(spacing: 6) {
            Text(emoji)
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptySuggestionState: some View {
        let hasBatchFailures = store.batchFailureCount > 0

        return VStack(spacing: 14) {
            Image(systemName: hasBatchFailures
                  ? "exclamationmark.triangle"
                  : (store.message == nil ? "sparkles" : "checkmark.circle"))
                .font(.system(size: 34))
                .foregroundStyle(
                    hasBatchFailures
                        ? Color.orange
                        : (store.message == nil ? Color.accentColor : .green)
                )

            Text(store.message ?? "Find possible relationships for this task")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Routina will suggest only prerequisites or clearly related tasks. You can edit every proposal before confirming it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if store.message != nil {
                Button {
                    store.send(.nextTaskTapped)
                } label: {
                    Label("Review next task", systemImage: "arrow.right")
                        .frame(minWidth: 150, minHeight: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}
