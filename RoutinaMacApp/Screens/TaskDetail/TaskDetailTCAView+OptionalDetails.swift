import SwiftData
import SwiftUI

extension TaskDetailTCAView {
    var optionalDetailActions: [TaskDetailOptionalAction] {
        var actions: [TaskDetailOptionalAction] = []

        if !shouldShowCommentsSection {
            actions.append(
                TaskDetailOptionalAction(title: "Comment", systemImage: "text.bubble") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isCommentComposerVisible = true
                    }
                })
        }

        if shouldShowHeatmapAddAction {
            actions.append(
                TaskDetailOptionalAction(title: "Heatmap", systemImage: "square.grid.3x3.fill") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        _ = store.send(.revealHeatmapInTaskDetail)
                    }
                })
        }

        if !store.task.showsTaskDetailHistory {
            actions.append(
                TaskDetailOptionalAction(title: "History", systemImage: "clock.arrow.circlepath") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        _ = store.send(.revealHistoryInTaskDetail)
                        isRoutineLogsExpanded = true
                    }
                })
        }

        if shouldShowTimeAddAction {
            actions.append(
                TaskDetailOptionalAction(title: "Time", systemImage: "clock.badge") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isTimeControlRevealed = true
                        isTimeSectionExpanded = true
                    }
                })
        }

        if shouldShowTodoStateAddAction {
            actions.append(
                TaskDetailOptionalAction(title: "State", systemImage: "circle.grid.2x1") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        _ = store.send(.revealTodoStateInTaskDetail)
                        isTodoStateControlRevealed = true
                    }
                })
        }

        if shouldShowEstimationAddAction {
            actions.append(inlineEditSectionAction(title: "Estimate", section: .estimation))
        }

        if !shouldShowChecklistSection {
            actions.append(
                TaskDetailOptionalAction(title: "Checklist", systemImage: "checklist") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isChecklistSectionRevealed = true
                    }
                })
        }

        if store.task.tags.isEmpty && !isInlineEditSectionRevealed(.organization) {
            actions.append(inlineEditSectionAction(title: "Tags", section: .organization))
        }

        if shouldShowGoalSectionInAddMore && store.taskGoalSummaries.isEmpty && !isInlineEditSectionRevealed(.goals) {
            actions.append(inlineEditSectionAction(title: "Goals", section: .goals))
        }

        if TaskDetailEventActionVisibility.shouldShowAddEventsAction(
            hasLinkedEvents: !store.taskEventCandidates.isEmpty,
            areEventActionsEnabled: areMacEventEmotionActionsEnabled
        ), !isInlineEditSectionRevealed(.events) {
            actions.append(inlineEditSectionAction(title: "Events", section: .events))
        }

        if !shouldShowRelationshipsSection && !isInlineEditSectionRevealed(.linkedTasks) {
            actions.append(inlineEditSectionAction(title: "Linked Task", section: .linkedTasks))
        }

        if isPlacesEnabled && !isInlineEditSectionRevealed(.places) {
            actions.append(inlineEditSectionAction(title: "Places", section: .places))
        }

        if !store.task.hasTaskDescription && !isInlineEditSectionRevealed(.taskDescription) {
            actions.append(inlineEditSectionAction(title: "Description", section: .taskDescription))
        }

        if isNotesEnabled && !store.task.hasNotes && !isInlineEditSectionRevealed(.notes) {
            actions.append(inlineEditSectionAction(title: "Notes", section: .notes))
        }

        if store.task.resolvedLinkURLs.isEmpty && !isInlineEditSectionRevealed(.linkURL) {
            actions.append(inlineEditSectionAction(title: "Links", section: .linkURL))
        }

        if store.task.color == .none && !isInlineEditSectionRevealed(.color) {
            actions.append(inlineEditSectionAction(title: "Color", section: .color))
        }

        if !store.task.hasImage && !isInlineEditSectionRevealed(.image) {
            actions.append(inlineEditSectionAction(title: "Image", section: .image))
        }

        if isNotesEnabled && !store.task.hasVoiceNote && !isInlineEditSectionRevealed(.voiceNote) {
            actions.append(inlineEditSectionAction(title: "Voice Note", section: .voiceNote))
        }

        if store.taskAttachments.isEmpty && !isInlineEditSectionRevealed(.attachment) {
            actions.append(inlineEditSectionAction(title: "File", section: .attachment))
        }

        return actions
    }

    private var shouldShowEstimationAddAction: Bool {
        TaskDetailOptionalControlVisibility.showsEstimateAddAction(for: store.task)
            && !isInlineEditSectionRevealed(.estimation)
    }

    private var shouldShowGoalSectionInAddMore: Bool {
        isGoalsTabEnabled
    }

    private func inlineEditSectionAction(title: String, section: FormSection) -> TaskDetailOptionalAction {
        TaskDetailOptionalAction(title: title, systemImage: section.icon) {
            revealInlineEditSection(section)
        }
    }

    private func revealInlineEditSection(_ section: FormSection) {
        guard !inlineEditSections.contains(section) else { return }
        let shouldPrepareEditDraft = inlineEditSections.isEmpty
        if shouldPrepareEditDraft {
            store.send(.prepareInlineEdit)
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            inlineEditSections.append(section)
        }
    }

    @ViewBuilder
    var inlineEditSectionsView: some View {
        if !inlineEditSections.isEmpty {
            TaskDetailEditRoutineContent(
                store: store,
                isEditEmojiPickerPresented: $isEditEmojiPickerPresented,
                emojiOptions: emojiOptions,
                canSaveCurrentEdit: canSaveCurrentEdit,
                automaticPathTitles: editAutomaticPathTitles,
                focusSessionCount: focusSessionCountForTask,
                layout: .embeddedSections(inlineEditSections),
                onCancel: cancelInlineEditSections,
                onSave: saveInlineEditSections
            )
        }
    }

    private func isInlineEditSectionRevealed(_ section: FormSection) -> Bool {
        inlineEditSections.contains(section)
    }

    var editAutomaticPathTitles: [String]? {
        TaskFormSidebarPathPresentation.automaticPathTitles(
            customTaskSectionID: store.task.customTaskSectionID,
            sidebarPathTitles: sidebarLocation?.titles
        )
    }

    private func cancelInlineEditSections() {
        withAnimation(.easeInOut(duration: 0.18)) {
            inlineEditSections.removeAll()
        }
    }

    private func saveInlineEditSections() {
        guard canSaveCurrentEdit else { return }
        store.send(.editSaveTapped)
        withAnimation(.easeInOut(duration: 0.18)) {
            inlineEditSections.removeAll()
        }
    }

    func openCreateLinkedTask() {
        store.send(.openAddLinkedTask)
    }

    func openExistingTaskLinker() {
        isExistingTaskLinkerPresented = true
    }

    var existingTaskLinkerSheet: some View {
        TaskRelationshipPickerSheet(
            candidates: store.linkableRelationshipTasks,
            linkedTaskIDs: Set(store.resolvedRelationships.map(\.taskID)),
            initialKind: store.addLinkedTaskRelationshipKind,
            onSelect: { taskID, kind in
                store.send(.detailLinkExistingTask(taskID, kind))
            },
            sourceTaskTitle: store.task.name,
            createLinkedTask: { kind in
                store.send(.addLinkedTaskRelationshipKindChanged(kind))
                isExistingTaskLinkerPresented = false
                store.send(.openAddLinkedTask)
            },
            searchField: { searchText in
                TextField("Search tasks", text: searchText)
                    .routinaTaskRelationshipSearchFieldPlatform()
            }
        )
    }

    var shouldShowCommentsSection: Bool {
        isCommentComposerVisible
            || !store.task.comments.isEmpty
            || !store.detailCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || store.editingDetailCommentID != nil
    }

    var shouldShowRelationshipsSection: Bool {
        !store.resolvedRelationships.isEmpty
    }

    var shouldShowLinkedEventsSection: Bool {
        areMacEventEmotionActionsEnabled && !store.taskEventCandidates.isEmpty
    }

    var hasTaskExtras: Bool {
        store.task.hasTaskDescription
            || (isNotesEnabled && store.task.hasNotes)
            || store.task.hasImage
            || (isNotesEnabled && store.task.hasVoiceNote)
            || !store.taskAttachments.isEmpty
            || !store.task.resolvedLinkURLs.isEmpty
    }

    var shouldShowHeatmapSection: Bool {
        canShowHeatmapSection && store.task.showsTaskDetailHeatmap
    }

    private var shouldShowHeatmapAddAction: Bool {
        canShowHeatmapSection && !store.task.showsTaskDetailHeatmap
    }

    private var canShowHeatmapSection: Bool {
        guard presentation == .fullDetail else { return false }
        return store.task.supportsTaskDetailHeatmap
    }

    func resetRevealedOptionalControls() {
        isTimeControlRevealed = false
        isTodoStateControlRevealed = false
        isChecklistSectionRevealed = false
        inlineEditSections.removeAll()
    }

    var blockingFocusTitle: String? {
        externalBlockingFocusTitle ?? sprintBlockingFocusTitle
    }

    @MainActor
    func refreshFocusBlockingContext() async {
        refreshActiveBlockingTask()
        refreshSprintFocusBlock()
    }

    var focusSessionTaskCandidates: [RoutineTask] {
        guard let activeBlockingTask,
            activeBlockingTask.id != store.task.id
        else {
            return [store.task]
        }
        return [store.task, activeBlockingTask]
    }

    var availableEventCandidates: [RoutineEventLinkCandidate] {
        RoutineEventLinkCandidate.candidates(from: events)
    }

    func syncAvailableEvents() {
        store.send(.availableEventsLoaded(availableEventCandidates))
    }

    @MainActor
    private func refreshActiveBlockingTask() {
        guard
            let activeTaskID = focusSessions.first(where: { session in
                session.taskID != store.task.id
                    && session.completedAt == nil
                    && session.abandonedAt == nil
            })?.taskID
        else {
            activeBlockingTask = nil
            return
        }

        do {
            var descriptor = TaskDetailFetchDescriptors.task(for: activeTaskID)
            descriptor.fetchLimit = 1
            activeBlockingTask = try modelContext.fetch(descriptor).first
        } catch {
            activeBlockingTask = nil
        }
    }

    @MainActor
    private func refreshSprintFocusBlock() {
        do {
            var sessionDescriptor = FetchDescriptor<SprintFocusSessionRecord>(
                predicate: #Predicate { session in
                    session.stoppedAt == nil
                },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            sessionDescriptor.fetchLimit = 1

            guard let session = try modelContext.fetch(sessionDescriptor).first else {
                sprintBlockingFocusTitle = nil
                return
            }

            let sprintID = session.sprintID
            var sprintDescriptor = FetchDescriptor<BoardSprintRecord>(
                predicate: #Predicate { sprint in
                    sprint.id == sprintID
                }
            )
            sprintDescriptor.fetchLimit = 1
            sprintBlockingFocusTitle = try modelContext.fetch(sprintDescriptor).first?.title ?? "a sprint"
        } catch {
            sprintBlockingFocusTitle = nil
        }
    }

    var canSaveCurrentEdit: Bool {
        TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: store.state))
    }

    var presentationRouting: TaskDetailPresentationRouting {
        store.taskDetailPresentationRouting
    }

    var isInlineEditPresented: Bool {
        presentation.showsEditingEntryPoints && platformIsInlineEditPresented
    }

}
