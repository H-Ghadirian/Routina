import ComposableArchitecture
import SwiftUI

struct BacklogMacView: View {
    let store: StoreOf<BacklogFeature>
    let onShowTaskInPlanner: (UUID, String) -> Void
    let onShowTaskInTimeline: (UUID, String) -> Void

    init(
        store: StoreOf<BacklogFeature>,
        onShowTaskInPlanner: @escaping (UUID, String) -> Void = { _, _ in },
        onShowTaskInTimeline: @escaping (UUID, String) -> Void = { _, _ in }
    ) {
        self.store = store
        self.onShowTaskInPlanner = onShowTaskInPlanner
        self.onShowTaskInTimeline = onShowTaskInTimeline
    }

    @AppStorage(
        UserDefaultStringValueKey.appSettingCustomTaskSections.rawValue,
        store: SharedDefaults.app
    ) private var customTaskSectionsRawValue = ""
    @State private var newSectionTitle = ""
    @State private var newSubsectionTitleBySectionID: [UUID: String] = [:]
    @State private var collapsedSectionIDs: Set<UUID> = []
    @State private var collapsedSubsectionIDs: Set<UUID> = []

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 280, idealWidth: 330, maxWidth: 420)

            detail
                .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            store.send(.onAppear)
        }
        .onDisappear {
            store.send(.onDisappear)
        }
        .onChange(of: customTaskSectionsRawValue) { _, rawValue in
            store.send(.customSectionsChanged(HomeCustomTaskSectionStorage.decoded(from: rawValue)))
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            store.send(.routineDataChanged)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Backlog")
                        .font(.title2.weight(.semibold))

                    Spacer(minLength: 8)

                    Text(backlogCountLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Button {
                        store.send(.refresh)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh Backlog")
                    .disabled(store.isLoading)
                }

                Text("Tasks kept off your everyday radar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            newSectionControl
                .padding(12)

            Divider()

            if store.isLoading && store.presentation.isEmpty {
                ProgressView("Loading Backlog…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isSearching
                        && store.presentation.taskCount == 0
                        && store.presentation.outsideBacklogResults.isEmpty {
                ContentUnavailableView.search(text: store.searchText)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.presentation.isEmpty
                        && store.presentation.outsideBacklogResults.isEmpty {
                ContentUnavailableView(
                    "Backlog is clear",
                    systemImage: "tray",
                    description: Text("Create a section for work you want off your main task list, or use a hiding Flag.")
                )
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(store.presentation.sections) { section in
                            backlogSection(section)
                        }

                        if !store.presentation.hiddenByFlagTasks.isEmpty {
                            automaticFlagSection
                        }

                        if !store.presentation.outsideBacklogResults.isEmpty {
                            outsideBacklogSection
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var newSectionControl: some View {
        HStack(spacing: 8) {
            TextField("New super section", text: $newSectionTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(createBacklogSection)

            Button("Add", action: createBacklogSection)
                .disabled(HomeCustomTaskSectionStorage.sanitizedTitle(newSectionTitle) == nil)
        }
    }

    private func backlogSection(_ section: BacklogTaskListPresentation.Section) -> some View {
        let isExpanded = isSearching || !collapsedSectionIDs.contains(section.id)

        return VStack(alignment: .leading, spacing: 5) {
            Button {
                toggleSection(section.id)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(sectionColor(section.section))
                        .frame(width: 12)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Image(systemName: "folder.fill")
                        .foregroundStyle(sectionColor(section.section))

                    Text(section.section.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("\(section.taskCount)")
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(section.tasks) { task in
                    taskRow(task, pathTitle: section.section.title)
                }

                ForEach(section.subsections) { subsection in
                    backlogSubsection(subsection, parentSection: section.section)
                }

                if !isSearching {
                    newSubsectionControl(for: section.section.id)
                        .padding(.leading, 18)
                        .padding(.top, 3)
                }
            }
        }
    }

    private func backlogSubsection(
        _ subsection: BacklogTaskListPresentation.Subsection,
        parentSection: HomeCustomTaskSection
    ) -> some View {
        let isExpanded = isSearching || !collapsedSubsectionIDs.contains(subsection.id)

        return VStack(alignment: .leading, spacing: 5) {
            Button {
                toggleSubsection(subsection.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)

                    Text(subsection.section.title)
                        .font(.caption.weight(.medium))

                    Spacer(minLength: 0)

                    Text("\(subsection.tasks.count)")
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 18)
                .padding(.trailing, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(subsection.tasks) { task in
                    taskRow(
                        task,
                        pathTitle: "\(parentSection.title) › \(subsection.section.title)",
                        indentation: 14
                    )
                }
            }
        }
    }

    private var automaticFlagSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: "flag.fill")
                    .foregroundStyle(.orange)

                Text("Hidden by flag")
                    .font(.caption.weight(.semibold))

                Text("\(store.presentation.hiddenByFlagTasks.count)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)

            ForEach(store.presentation.hiddenByFlagTasks) { task in
                taskRow(task, pathTitle: "Hidden by flag")
            }
        }
    }

    private var outsideBacklogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.presentation.taskCount == 0 ? "No matches in Backlog" : "Found outside Backlog")
                    .font(.caption.weight(.semibold))

                if store.presentation.taskCount == 0 {
                    Text("Found outside Backlog")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)

            ForEach(store.presentation.outsideBacklogResults) { result in
                outsideBacklogResultRow(result)
            }
        }
        .padding(.top, store.presentation.taskCount == 0 ? 2 : 8)
    }

    private func outsideBacklogResultRow(
        _ result: BacklogTaskListPresentation.OutsideBacklogResult
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                store.send(.taskSelected(result.task.id))
            } label: {
                HStack(spacing: 9) {
                    Text(result.task.emoji ?? "✨")
                        .font(.body)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(result.task.name ?? "Untitled task")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)

                        Text(result.locationTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(result.task.name ?? "Untitled task") task details")

            HStack(spacing: 7) {
                Button("Open Task") {
                    store.send(.taskSelected(result.task.id))
                }

                switch result.revealDestination {
                case .planner:
                    Button("Show in Planner") {
                        onShowTaskInPlanner(result.task.id, store.searchText)
                    }
                case .timeline:
                    Button("Show in Timeline") {
                        onShowTaskInTimeline(result.task.id, store.searchText)
                    }
                }

                Menu("Move to Backlog…") {
                    ForEach(backlogDestinations) { destination in
                        Button(destination.title) {
                            store.send(.moveTask(result.task.id, to: destination.id))
                        }
                    }
                }
                .disabled(backlogDestinations.isEmpty)
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.68))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
    }

    private func newSubsectionControl(for parentSectionID: UUID) -> some View {
        let draft = Binding(
            get: { newSubsectionTitleBySectionID[parentSectionID, default: ""] },
            set: { newSubsectionTitleBySectionID[parentSectionID] = $0 }
        )
        return HStack(spacing: 7) {
            TextField("New subsection", text: draft)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .onSubmit { createBacklogSubsection(parentSectionID) }

            Button {
                createBacklogSubsection(parentSectionID)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help("Add subsection")
            .disabled(HomeCustomTaskSectionStorage.sanitizedTitle(draft.wrappedValue) == nil)
        }
    }

    private func taskRow(
        _ task: RoutineTask,
        pathTitle: String,
        indentation: CGFloat = 0
    ) -> some View {
        let isSelected = store.selectedTaskID == task.id

        return Button {
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

                    taskSubtitle(task, pathTitle: pathTitle)
                }

                Spacer(minLength: 4)

                if task.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 10 + indentation)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open Task") {
                store.send(.taskSelected(task.id))
            }

            Menu("Move to Backlog") {
                ForEach(backlogDestinations) { destination in
                    Button(destination.title) {
                        store.send(.moveTask(task.id, to: destination.id))
                    }
                }
            }

            if task.customTaskSectionID != nil {
                Button("Move to Radar") {
                    store.send(.moveTask(task.id, to: nil))
                }
            }
        }
    }

    @ViewBuilder
    private func taskSubtitle(_ task: RoutineTask, pathTitle: String) -> some View {
        let hidingFlags = RoutineFlagRules.flagsHidingFromTaskLists(task.flags, rules: store.flagRules)
        let labels = [pathTitle] + (hidingFlags.isEmpty ? [] : [hidingFlags.joined(separator: ", ")])
        Text(labels.joined(separator: " • "))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var detail: some View {
        if let detailStore = store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(
                store: detailStore,
                showsPrincipalToolbarTitle: false
            )
        } else {
            ContentUnavailableView(
                "Select a backlog task",
                systemImage: "tray.full",
                description: Text("Open a task to review its details or edit it without bringing it back to the main sidebar.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var backlogCountLabel: String {
        let count = store.presentation.taskCount
        if isSearching {
            return count == 1 ? "1 in Backlog" : "\(count) in Backlog"
        }
        return count == 1 ? "1 task" : "\(count) tasks"
    }

    private var isSearching: Bool {
        HomeTaskSearchIndex.query(store.searchText) != nil
    }

    private var backlogDestinations: [BacklogDestination] {
        HomeCustomTaskSectionStorage.topLevelSections(
            in: store.customSections,
            surface: .backlog
        ).flatMap { section in
            let parent = BacklogDestination(id: section.id, title: section.title)
            let subsections = HomeCustomTaskSectionStorage.subsections(
                of: section.id,
                in: store.customSections
            ).map { subsection in
                BacklogDestination(
                    id: subsection.id,
                    title: "\(section.title) › \(subsection.title)"
                )
            }
            return [parent] + subsections
        }
    }

    private func createBacklogSection() {
        guard let update = HomeCustomTaskSectionStorage.upsertingSection(
            title: newSectionTitle,
            surface: .backlog,
            in: storedCustomSections
        ) else {
            return
        }
        newSectionTitle = ""
        persistCustomSections(update.sections)
    }

    private func createBacklogSubsection(_ parentSectionID: UUID) {
        let title = newSubsectionTitleBySectionID[parentSectionID, default: ""]
        guard let update = HomeCustomTaskSectionStorage.upsertingSection(
            title: title,
            parentSectionID: parentSectionID,
            in: storedCustomSections
        ) else {
            return
        }
        newSubsectionTitleBySectionID[parentSectionID] = ""
        persistCustomSections(update.sections)
    }

    private var storedCustomSections: [HomeCustomTaskSection] {
        HomeCustomTaskSectionStorage.decoded(from: customTaskSectionsRawValue)
    }

    private func persistCustomSections(_ sections: [HomeCustomTaskSection]) {
        customTaskSectionsRawValue = HomeCustomTaskSectionStorage.encoded(sections)
        AppSettingsPersistenceMirror.schedule()
        store.send(.customSectionsChanged(sections))
    }

    private func toggleSection(_ sectionID: UUID) {
        guard !isSearching else { return }
        if collapsedSectionIDs.contains(sectionID) {
            collapsedSectionIDs.remove(sectionID)
        } else {
            collapsedSectionIDs.insert(sectionID)
        }
    }

    private func toggleSubsection(_ subsectionID: UUID) {
        guard !isSearching else { return }
        if collapsedSubsectionIDs.contains(subsectionID) {
            collapsedSubsectionIDs.remove(subsectionID)
        } else {
            collapsedSubsectionIDs.insert(subsectionID)
        }
    }

    private func sectionColor(_ section: HomeCustomTaskSection) -> Color {
        guard let colorHex = section.colorHex else { return .accentColor }
        return Color(hex: colorHex)
    }
}

private struct BacklogDestination: Identifiable {
    let id: UUID
    let title: String
}
