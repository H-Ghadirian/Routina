import ComposableArchitecture
import SwiftUI

struct BacklogMacView: View {
    let store: StoreOf<BacklogFeature>

    @AppStorage(
        UserDefaultStringValueKey.appSettingCustomTaskSections.rawValue,
        store: SharedDefaults.app
    ) private var customTaskSectionsRawValue = ""
    @State private var newSectionTitle = ""
    @State private var newSubsectionTitleBySectionID: [UUID: String] = [:]

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
            } else if store.presentation.isEmpty {
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
                    }
                    .padding(10)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }

    private var newSectionControl: some View {
        HStack(spacing: 8) {
            TextField("New backlog section", text: $newSectionTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(createBacklogSection)

            Button("Add", action: createBacklogSection)
                .disabled(HomeCustomTaskSectionStorage.sanitizedTitle(newSectionTitle) == nil)
        }
    }

    private func backlogSection(_ section: BacklogTaskListPresentation.Section) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(sectionColor(section.section))

                Text(section.section.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Text("\(section.taskCount)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)

            ForEach(section.tasks) { task in
                taskRow(task, pathTitle: section.section.title)
            }

            ForEach(section.subsections) { subsection in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .foregroundStyle(.secondary)

                        Text(subsection.section.title)
                            .font(.caption.weight(.medium))

                        Text("\(subsection.tasks.count)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 18)
                    .padding(.top, 4)

                    ForEach(subsection.tasks) { task in
                        taskRow(
                            task,
                            pathTitle: "\(section.section.title) › \(subsection.section.title)",
                            indentation: 14
                        )
                    }
                }
            }

            newSubsectionControl(for: section.section.id)
                .padding(.leading, 18)
                .padding(.top, 3)
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
            TaskDetailTCAView(store: detailStore)
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
        return count == 1 ? "1 task" : "\(count) tasks"
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

    private func sectionColor(_ section: HomeCustomTaskSection) -> Color {
        guard let colorHex = section.colorHex else { return .accentColor }
        return Color(hex: colorHex)
    }
}

private struct BacklogDestination: Identifiable {
    let id: UUID
    let title: String
}
