import ComposableArchitecture
import SwiftUI

struct BacklogIOSView: View {
    let store: StoreOf<BacklogFeature>

    @AppStorage(
        UserDefaultStringValueKey.appSettingCustomTaskSections.rawValue,
        store: SharedDefaults.app
    ) private var customTaskSectionsRawValue = ""

    var body: some View {
        List {
            if store.isLoading && store.presentation.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading Backlog…")
                        Spacer()
                    }
                    .padding(.vertical, 28)
                }
            } else if isSearching && hasNoSearchResults {
                Section {
                    ContentUnavailableView.search(text: store.searchText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
            } else if store.presentation.isEmpty
                        && store.presentation.outsideBacklogResults.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Backlog is clear",
                        systemImage: "tray",
                        description: Text(
                            "Move a task here from the main task list, or create a Backlog section in Settings."
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                backlogSections
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Backlog")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: searchTextBinding, prompt: "Search Backlog")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.send(.refresh)
                } label: {
                    Label("Refresh Backlog", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .onChange(of: customTaskSectionsRawValue) { _, rawValue in
            store.send(
                .customSectionsChanged(
                    HomeCustomTaskSectionStorage.decoded(from: rawValue)
                )
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            store.send(.routineDataChanged)
        }
        .alert(
            "Backlog",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.send(.errorDismissed)
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var backlogSections: some View {
        ForEach(store.presentation.sections) { section in
            Section {
                if isSuperSectionExpanded(section.id) {
                    ForEach(section.tasks) { task in
                        taskRow(task, pathTitle: section.section.title)
                    }

                    ForEach(section.subsections) { subsection in
                        subsectionDisclosureRow(
                            subsection,
                            parentSection: section.section
                        )

                        if isSubsectionExpanded(subsection.id) {
                            ForEach(subsection.tasks) { task in
                                taskRow(
                                    task,
                                    pathTitle: "\(section.section.title) › \(subsection.section.title)"
                                )
                                .padding(.leading, 14)
                            }
                        }
                    }
                }
            } header: {
                superSectionHeader(section)
            }
        }

        if !store.presentation.hiddenByFlagTasks.isEmpty {
            Section("Hidden by flag") {
                ForEach(store.presentation.hiddenByFlagTasks) { task in
                    taskRow(task, pathTitle: "Hidden by flag")
                }
            }
        }

        if !store.presentation.outsideBacklogResults.isEmpty {
            Section {
                ForEach(store.presentation.outsideBacklogResults) { result in
                    NavigationLink {
                        BacklogIOSTaskDestination(
                            store: store,
                            taskID: result.task.id
                        )
                    } label: {
                        taskLabel(
                            result.task,
                            subtitle: result.locationTitle
                        )
                    }
                }
            } header: {
                Text(
                    store.presentation.taskCount == 0
                        ? "Found outside Backlog"
                        : "Other matches"
                )
            }
        }
    }

    private func superSectionHeader(
        _ section: BacklogTaskListPresentation.Section
    ) -> some View {
        let isExpanded = isSuperSectionExpanded(section.id)

        return Button {
            store.send(.superSectionDisclosureToggled(section.id))
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))

                Image(systemName: "folder.fill")

                Text(section.section.title)

                Text("\(section.taskCount)")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .foregroundStyle(sectionColor(section.section))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }

    private func subsectionDisclosureRow(
        _ subsection: BacklogTaskListPresentation.Subsection,
        parentSection: HomeCustomTaskSection
    ) -> some View {
        let isExpanded = isSubsectionExpanded(subsection.id)

        return Button {
            store.send(.subsectionDisclosureToggled(subsection.id))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))

                Image(systemName: "folder")

                VStack(alignment: .leading, spacing: 2) {
                    Text(subsection.section.title)

                    Text(parentSection.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text("\(subsection.tasks.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }

    private func taskRow(
        _ task: RoutineTask,
        pathTitle: String
    ) -> some View {
        NavigationLink {
            BacklogIOSTaskDestination(store: store, taskID: task.id)
        } label: {
            taskLabel(task, subtitle: taskSubtitle(task, pathTitle: pathTitle))
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if isExplicitlyBacklogged(task) {
                Button {
                    store.send(.moveTask(task.id, to: nil))
                } label: {
                    Label("Move to Home", systemImage: "house")
                }
                .tint(.blue)
            }
        }
    }

    private func taskLabel(
        _ task: RoutineTask,
        subtitle: String
    ) -> some View {
        HStack(spacing: 10) {
            Text(task.emoji ?? "✨")
                .font(.body)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.name ?? "Untitled task")
                    .lineLimit(2)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if task.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var searchTextBinding: Binding<String> {
        Binding(
            get: { store.searchText },
            set: { store.send(.searchTextChanged($0)) }
        )
    }

    private var isSearching: Bool {
        HomeTaskSearchIndex.query(store.searchText) != nil
    }

    private var hasNoSearchResults: Bool {
        store.presentation.taskCount == 0
            && store.presentation.outsideBacklogResults.isEmpty
    }

    private func isSuperSectionExpanded(_ sectionID: UUID) -> Bool {
        isSearching || !store.collapsedSuperSectionIDs.contains(sectionID)
    }

    private func isSubsectionExpanded(_ subsectionID: UUID) -> Bool {
        isSearching || !store.collapsedSubsectionIDs.contains(subsectionID)
    }

    private func isExplicitlyBacklogged(_ task: RoutineTask) -> Bool {
        guard let sectionID = task.customTaskSectionID else { return false }
        return store.customSections.contains {
            $0.id == sectionID && $0.surface == .backlog
        }
    }

    private func taskSubtitle(_ task: RoutineTask, pathTitle: String) -> String {
        let hidingFlags = RoutineFlagRules.flagsHidingFromTaskLists(
            task.flags,
            rules: store.flagRules
        )
        return ([pathTitle] + hidingFlags).joined(separator: " • ")
    }

    private func sectionColor(_ section: HomeCustomTaskSection) -> Color {
        guard let colorHex = section.colorHex else { return .accentColor }
        return Color(hex: colorHex)
    }
}

private struct BacklogIOSTaskDestination: View {
    let store: StoreOf<BacklogFeature>
    let taskID: UUID

    var body: some View {
        Group {
            if store.selectedTaskID == taskID,
               let detailStore = store.scope(
                   state: \.taskDetailState,
                   action: \.taskDetail
               ) {
                TaskDetailTCAView(store: detailStore)
            } else {
                ProgressView("Opening task…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: taskID) {
            if store.selectedTaskID != taskID {
                store.send(.taskSelected(taskID))
            }
        }
    }
}
