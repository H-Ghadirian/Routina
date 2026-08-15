import ComposableArchitecture
import SwiftUI

struct TaskRankingMacView: View {
    let store: StoreOf<TaskRankingFeature>
    @AppStorage(
        UserDefaultStringValueKey.appSettingMacTaskRankingReversedMetrics.rawValue,
        store: SharedDefaults.app
    ) private var reversedMetricsRawValue = ""
    @AppStorage(
        UserDefaultStringValueKey.appSettingFlagRules.rawValue,
        store: SharedDefaults.app
    ) private var flagRulesRawValue = ""
    @State private var collapsedSectionIDs = Set<String>()

    var body: some View {
        HSplitView {
            rankingList
                .frame(minWidth: 340, idealWidth: 440, maxWidth: 560)

            taskDetail
                .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            store.send(
                .reversedMetricsChanged(
                    TaskRankingDirectionStorage.decode(reversedMetricsRawValue)
                )
            )
            store.send(.onAppear)
        }
        .onDisappear { store.send(.onDisappear) }
        .onChange(of: store.reversedMetrics) { _, reversedMetrics in
            reversedMetricsRawValue = TaskRankingDirectionStorage.encode(reversedMetrics)
            AppSettingsPersistenceMirror.schedule()
        }
        .onChange(of: flagRulesRawValue) { _, _ in
            store.send(.flagRulesChanged)
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            store.send(.routineDataChanged)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Rank by", selection: Binding(
                    get: { store.metric },
                    set: { store.send(.metricChanged($0)) }
                )) {
                    ForEach(TaskRankingMetric.allCases) { metric in
                        Text(metric.title).tag(metric)
                    }
                }
                .labelsHidden()
                .frame(width: 170)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.directionToggled)
                } label: {
                    Label(store.metric.directionTitle(isReversed: store.isReversed), systemImage: "arrow.up.arrow.down")
                }
                .help("Reverse order: \(store.metric.directionTitle(isReversed: !store.isReversed))")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.refresh)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .help("Refresh task ranking")
                .disabled(store.isLoading)
            }
        }
        .alert(
            "Task Ranking",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.send(.errorDismissed) } }
            ),
            actions: {
                Button("OK", role: .cancel) { store.send(.errorDismissed) }
            },
            message: { Text(store.errorMessage ?? "") }
        )
    }

    private var rankingList: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Task Ladder")
                        .font(.title2.weight(.semibold))

                    Spacer(minLength: 8)

                    Text(taskCountLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(listSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            if store.isLoading && store.presentation.isEmpty {
                ProgressView("Loading active tasks…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.presentation.isEmpty {
                ContentUnavailableView(
                    "No tasks in Task Ladder",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Paused, blocked, completed, canceled, archived, and Flag-hidden tasks stay out of the task ladder.")
                )
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(store.presentation.sections) { section in
                            rankingSection(section)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.42))
    }

    private func rankingSection(_ section: TaskRankingPresentation.Section) -> some View {
        let isCollapsed = collapsedSectionIDs.contains(section.id)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleRankingSection(section)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(section.title)
                        .font(.headline)
                    Text("\(section.tasks.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if !section.supportsManualOrdering {
                        Text(section.isMissingValue ? "Separate" : "Read only")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(isCollapsed ? "Expand" : "Collapse") \(section.title)")
            .accessibilityValue(isCollapsed ? "Collapsed" : "Expanded")
            .background(section.isMissingValue ? Color.secondary.opacity(0.08) : Color.accentColor.opacity(0.09))

            if !isCollapsed {
                Divider()

                ForEach(section.tasks) { task in
                    rankingRow(task, in: section)
                    if task.id != section.tasks.last?.id {
                        Divider().padding(.leading, 12)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(section.isMissingValue ? Color.secondary.opacity(0.2) : Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    private func toggleRankingSection(_ section: TaskRankingPresentation.Section) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if collapsedSectionIDs.contains(section.id) {
                collapsedSectionIDs.remove(section.id)
            } else {
                collapsedSectionIDs.insert(section.id)
            }
        }
    }

    private func rankingRow(
        _ task: RoutineTask,
        in section: TaskRankingPresentation.Section
    ) -> some View {
        let isSelected = store.selectedTaskID == task.id
        return HStack(spacing: 9) {
            Button {
                store.send(.taskSelected(task.id))
            } label: {
                HStack(spacing: 9) {
                    Text(task.emoji ?? "✨")
                        .font(.body)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.name ?? "Untitled task")
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        if let metadata = store.presentation.rowMetadataByTaskID[task.id] {
                            rowMetadata(metadata)
                        }
                    }

                    Spacer(minLength: 2)
                }
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if section.supportsManualOrdering {
                VStack(spacing: 2) {
                    Button {
                        store.send(.moveTask(task.id, .up))
                    } label: {
                        Image(systemName: "chevron.up")
                            .frame(width: 22, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Move up")

                    Button {
                        store.send(.moveTask(task.id, .down))
                    } label: {
                        Image(systemName: "chevron.down")
                            .frame(width: 22, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Move down")
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .background(isSelected ? Color.accentColor.opacity(0.14) : .clear)
        .contextMenu {
            Button("Open Task") {
                store.send(.taskSelected(task.id))
            }
            if section.supportsManualOrdering {
                Divider()
                Button("Move Up") { store.send(.moveTask(task.id, .up)) }
                Button("Move Down") { store.send(.moveTask(task.id, .down)) }
            }
        }
    }

    @ViewBuilder
    private func rowMetadata(_ metadata: TaskRankingPresentation.RowMetadata) -> some View {
        if !metadata.tagLabels.isEmpty || metadata.isRepeating {
            HStack(spacing: 6) {
                if !metadata.tagLabels.isEmpty {
                    Text(metadata.tagLabels.joined(separator: " • "))
                        .lineLimit(1)
                }

                if metadata.isRepeating {
                    Label("Repeating", systemImage: "repeat")
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityLabel("Repeating task")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var taskDetail: some View {
        if let detailStore = store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(store: detailStore)
        } else {
            ContentUnavailableView(
                "Select a task",
                systemImage: "arrow.up.arrow.down.circle",
                description: Text("Move categorical tasks up or down to set their place in this metric’s ladder.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var taskCountLabel: String {
        let count = store.presentation.taskCount
        return count == 1 ? "1 task" : "\(count) tasks"
    }

    private var listSubtitle: String {
        if store.metric == .estimatedTime {
            return "\(store.metric.directionTitle(isReversed: store.isReversed)) • factual sort"
        }
        return "\(store.metric.directionTitle(isReversed: store.isReversed)) • move tasks within or between values"
    }

}
