import ComposableArchitecture
import SwiftUI

extension BacklogMacView {
    func backlogSection(_ section: BacklogTaskListPresentation.Section) -> some View {
        let isExpanded = isSearching || !store.collapsedSuperSectionIDs.contains(section.id)

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

    func backlogSubsection(
        _ subsection: BacklogTaskListPresentation.Subsection,
        parentSection: HomeCustomTaskSection
    ) -> some View {
        let isExpanded = isSearching || !store.collapsedSubsectionIDs.contains(subsection.id)

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

    var automaticFlagSection: some View {
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

    var outsideBacklogSection: some View {
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

    func outsideBacklogResultRow(
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
                    backlogMoveMenuItems(for: result.task.id)
                }
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

    func newSubsectionControl(for parentSectionID: UUID) -> some View {
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

    @ViewBuilder
    func taskRow(
        _ task: RoutineTask,
        pathTitle: String,
        indentation: CGFloat = 0
    ) -> some View {
        if let row = store.presentation.rowPresentationsByTaskID[task.id] {
            BacklogMacTaskRow(
                task: task,
                row: row,
                rowNumber: store.presentation.rowNumbersByTaskID[task.id],
                pathTitle: pathTitle,
                indentation: indentation,
                isSelected: store.selectedTaskID == task.id,
                visibility: backlogTaskRowVisibility,
                showsPlaces: isPlacesEnabled,
                showsTomorrowPlanningShortcut: showsTomorrowInTaskList,
                tagColors: store.tagColors,
                onOpen: { store.send(.taskSelected(task.id)) },
                onPlanForToday: { planTaskForToday(task.id) },
                onPlanForTomorrow: { planTaskForTomorrow(task.id) },
                onChoosePlanDate: { presentPlanningDatePicker(for: task) },
                onClearPlan: { store.send(.planTask(task.id, nil)) },
                onMoveToMainTaskList: { store.send(.moveTask(task.id, to: nil)) },
                moveMenu: { backlogMoveMenuItems(for: task.id) }
            )
        }
    }

    var backlogTaskRowVisibility: HomeTaskRowVisibility {
        HomeTaskRowVisibility(storageRawValue: backlogTaskRowHiddenFieldsRawValue)
    }

    var isSearching: Bool {
        HomeTaskSearchIndex.query(store.searchText) != nil
    }

    var planningDatePickerPresentedBinding: Binding<Bool> {
        Binding(
            get: { planningDateTaskID != nil },
            set: { isPresented in
                if !isPresented {
                    dismissPlanningDatePicker()
                }
            }
        )
    }

    func planTaskForToday(_ taskID: UUID) {
        store.send(.planTask(taskID, calendar.startOfDay(for: Date())))
    }

    func planTaskForTomorrow(_ taskID: UUID) {
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)
            ?? today.addingTimeInterval(86_400)
        store.send(.planTask(taskID, calendar.startOfDay(for: tomorrow)))
    }

    func presentPlanningDatePicker(for task: RoutineTask) {
        planningDateTaskID = task.id
        planningDateDraft = task.plannedDate ?? Date()
    }

    func savePlanningDatePicker() {
        guard let taskID = planningDateTaskID else { return }
        store.send(.planTask(taskID, planningDateDraft))
        dismissPlanningDatePicker()
    }

    func dismissPlanningDatePicker() {
        planningDateTaskID = nil
    }

    @ViewBuilder
    func backlogMoveMenuItems(for taskID: UUID) -> some View {
        let sections = HomeCustomTaskSectionStorage.topLevelSections(
            in: store.customSections,
            surface: .backlog
        )

        ForEach(sections) { section in
            let subsections = HomeCustomTaskSectionStorage.subsections(
                of: section.id,
                in: store.customSections
            )

            if subsections.isEmpty {
                Button(section.title) {
                    store.send(.moveTask(taskID, to: section.id))
                }
            } else {
                Menu(section.title) {
                    Button("In \(section.title)") {
                        store.send(.moveTask(taskID, to: section.id))
                    }

                    ForEach(subsections) { subsection in
                        Button(subsection.title) {
                            store.send(.moveTask(taskID, to: subsection.id))
                        }
                    }
                }
            }
        }

        if !sections.isEmpty {
            Divider()
        }

        Button("New Backlog Super Section…") {
            presentNewBacklogSection(for: taskID)
        }
    }

    func presentNewBacklogSection(for taskID: UUID) {
        newSectionTaskID = taskID
        newSectionTitle = ""
        isNewSectionPromptPresented = true
    }

    func resetNewSectionPrompt() {
        isNewSectionPromptPresented = false
        newSectionTitle = ""
        newSectionTaskID = nil
    }

    func createBacklogSection() {
        guard
            let update = HomeCustomTaskSectionStorage.upsertingSection(
                title: newSectionTitle,
                surface: .backlog,
                in: storedCustomSections
            )
        else {
            return
        }
        persistCustomSections(update.sections)
        if let taskID = newSectionTaskID {
            store.send(.moveTask(taskID, to: update.section.id))
        }
        resetNewSectionPrompt()
    }

    func createBacklogSubsection(_ parentSectionID: UUID) {
        let title = newSubsectionTitleBySectionID[parentSectionID, default: ""]
        guard
            let update = HomeCustomTaskSectionStorage.upsertingSection(
                title: title,
                parentSectionID: parentSectionID,
                in: storedCustomSections
            )
        else {
            return
        }
        newSubsectionTitleBySectionID[parentSectionID] = ""
        persistCustomSections(update.sections)
    }

    var storedCustomSections: [HomeCustomTaskSection] {
        HomeCustomTaskSectionStorage.decoded(from: customTaskSectionsRawValue)
    }

    func persistCustomSections(_ sections: [HomeCustomTaskSection]) {
        customTaskSectionsRawValue = HomeCustomTaskSectionStorage.encoded(sections)
        AppSettingsPersistenceMirror.schedule()
        store.send(.customSectionsChanged(sections))
    }

    func toggleSection(_ sectionID: UUID) {
        guard !isSearching else { return }
        store.send(.superSectionDisclosureToggled(sectionID))
    }

    func toggleSubsection(_ subsectionID: UUID) {
        guard !isSearching else { return }
        store.send(.subsectionDisclosureToggled(subsectionID))
    }

    func sectionColor(_ section: HomeCustomTaskSection) -> Color {
        guard let colorHex = section.colorHex else { return .accentColor }
        return Color(hex: colorHex)
    }
}
