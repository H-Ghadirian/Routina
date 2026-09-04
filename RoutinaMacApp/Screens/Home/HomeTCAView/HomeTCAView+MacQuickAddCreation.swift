import AppKit
import Combine
import ComposableArchitecture
import Foundation
import MapKit
import SwiftUI

extension HomeTCAView {
    func resetToolbarSearchPreviewState(
        for draft: RoutinaQuickAddDraft?,
        clearsPinnedDraft: Bool = true
    ) {
        toolbarSearchReminderChoice = .none
        toolbarSearchCustomReminderAt = Date()
        toolbarSearchEditableTaskTitle = draft?.name ?? ""
        toolbarSearchTaskTitleWasEdited = false
        toolbarSearchLinkMetadataURL = nil
        toolbarSearchResolvedLinkTitle = nil
        toolbarSearchLinkMetadataStatus = .idle
        if clearsPinnedDraft {
            toolbarSearchPinnedParserPreviewDraft = nil
        }
    }

    func defaultToolbarSearchTaskTitle(for draft: RoutinaQuickAddDraft) -> String {
        guard draft.usesGeneratedLinkName,
            toolbarSearchLinkMetadataURL == draft.primaryLinkURL,
            let toolbarSearchResolvedLinkTitle,
            let linkURL = draft.primaryLinkURL
        else {
            return draft.name
        }
        return RoutinaQuickAddLinkSupport.taskTitle(
            fromMetadataTitle: toolbarSearchResolvedLinkTitle,
            url: linkURL
        ) ?? draft.name
    }

    @MainActor
    func resolveToolbarSearchLinkTitle(for draft: RoutinaQuickAddDraft) async {
        guard let linkURL = draft.primaryLinkURL else { return }
        if toolbarSearchLinkMetadataURL == linkURL {
            switch toolbarSearchLinkMetadataStatus {
            case .resolved, .unavailable:
                return
            case .idle, .loading:
                break
            }
        }
        toolbarSearchLinkMetadataURL = linkURL
        guard RoutinaQuickAddLinkSupport.canFetchMetadata(for: linkURL) else {
            toolbarSearchLinkMetadataStatus = .unavailable
            return
        }

        toolbarSearchLinkMetadataStatus = .loading
        let metadataTitle = await HomeMacLinkMetadataResolver.title(for: linkURL)
        guard !Task.isCancelled,
            toolbarSearchLinkMetadataURL == linkURL,
            let currentDraft = RoutinaQuickAddParser.parse(
                toolbarSearchTextBinding.wrappedValue,
                calendar: calendar,
                includingPlaces: isPlacesEnabled
            ),
            currentDraft.primaryLinkURL == linkURL
        else {
            return
        }

        guard let metadataTitle else {
            toolbarSearchLinkMetadataStatus = .unavailable
            return
        }

        toolbarSearchResolvedLinkTitle = metadataTitle
        toolbarSearchLinkMetadataStatus = .resolved
        let shouldApplySuggestedTitle =
            currentDraft.usesGeneratedLinkName && !toolbarSearchTaskTitleWasEdited
        if shouldApplySuggestedTitle {
            if let suggestedTitle = RoutinaQuickAddLinkSupport.taskTitle(
                fromMetadataTitle: metadataTitle,
                url: linkURL
            ) {
                toolbarSearchEditableTaskTitle = suggestedTitle
            }
        }
    }

    func createTaskFromToolbarSearch(
        _ rawText: String,
        draft: RoutinaQuickAddDraft? = nil,
        submission: HomeMacToolbarQuickAddSubmission? = nil
    ) {
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty,
            !isToolbarSearchCreateInProgress,
            !hasToolbarSearchResult(for: trimmedText)
        else {
            return
        }

        if isMacBacklogMode {
            presentBacklogSearchCreationChoices(for: trimmedText)
            return
        }

        toolbarSearchCreateErrorMessage = nil
        isToolbarSearchCreateInProgress = true
        let createDraft =
            draft
            ?? RoutinaQuickAddParser.parse(
                trimmedText,
                calendar: calendar,
                includingPlaces: isPlacesEnabled
            )
        let resolvedSubmission =
            submission
            ?? createDraft.map { draft in
                HomeMacToolbarQuickAddSubmission(
                    draft: draft,
                    taskTitle: toolbarSearchEffectiveTaskTitle(for: draft),
                    reminderChoice: toolbarSearchReminderChoice,
                    customReminderAt: toolbarSearchCustomReminderAt,
                    calendar: calendar
                )
            }
        let primaryLinkTitle =
            createDraft?.primaryLinkURL == toolbarSearchLinkMetadataURL
            ? toolbarSearchResolvedLinkTitle
            : nil

        Task { @MainActor in
            defer { isToolbarSearchCreateInProgress = false }

            do {
                let result = try await RoutinaQuickAddService.createTask(
                    from: trimmedText,
                    context: modelContext,
                    calendar: calendar,
                    includingPlaces: isPlacesEnabled,
                    reminderAt: resolvedSubmission?.reminderAt,
                    taskNameOverride: resolvedSubmission?.taskTitle,
                    primaryLinkTitle: primaryLinkTitle
                )
                toolbarSearchTextBinding.wrappedValue = ""
                resetToolbarSearchPreviewState(for: nil)
                isToolbarSearchTaskTitleFocused = false
                handleQuickAddCreated(result)
            } catch {
                toolbarSearchCreateErrorMessage = error.localizedDescription
            }
        }
    }

    func openAddTaskFromToolbarSearch(_ rawText: String) {
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty,
            !hasToolbarSearchResult(for: trimmedText)
        else { return }

        if isMacBacklogMode {
            presentBacklogSearchCreationChoices(for: trimmedText)
            return
        }

        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        toolbarSearchCreateErrorMessage = nil
        addEditFormCoordinator.resetRevealedTaskFormSections()
        isToolbarSearchTextFocused = false
        toolbarSearchFocusDismissRequestID += 1
        toolbarSearchTextBinding.wrappedValue = ""
        quickAddCreatedToast = nil
        store.send(.openAddTaskSheet(seedName: trimmedText))
        scheduleAddTaskNameFocus()
    }

    func hasToolbarSearchResult(for searchText: String) -> Bool {
        hasTaskSearchResult(for: searchText)
            || (!isMacBacklogMode
                && !isMacTaskLadderMode
                && hasTimelineSearchResult(for: searchText))
    }

    func hasTaskSearchResult(for searchText: String) -> Bool {
        guard let normalizedQuery = HomeTaskSearchIndex.query(searchText) else { return false }
        let tasks: [RoutineTask]
        if isMacBacklogMode {
            tasks = backlogStore.tasks
        } else if isMacTaskLadderMode {
            tasks = taskRankingStore.tasks
        } else {
            tasks = store.routineTasks
        }
        return tasks.contains { task in
            let pathTitles =
                task.customTaskSectionID.flatMap {
                    HomeCustomTaskSectionStorage.pathTitles(for: $0, in: customTaskSections)
                } ?? []
            return HomeTaskSearchIndex.make(
                name: task.name ?? "",
                emoji: task.emoji ?? "",
                taskDescription: task.taskDescription,
                notes: task.notes,
                placeName: task.destinationAddress,
                tags: task.tags + pathTitles,
                flags: task.flags,
                goalTitles: []
            ).contains(normalizedQuery)
        }
    }

    func presentBacklogSearchCreationChoices(for taskName: String) {
        toolbarSearchCreateErrorMessage = nil
        isToolbarSearchTextFocused = false
        toolbarSearchFocusDismissRequestID += 1
        pendingBacklogSearchCreationText = taskName
    }

    var backlogSearchCreationDestinations: [HomeBacklogCreationDestination] {
        HomeCustomTaskSectionStorage.topLevelSections(
            in: customTaskSections,
            surface: .backlog
        ).flatMap { section in
            [HomeBacklogCreationDestination(id: section.id, title: "Backlog › \(section.title)")]
                + HomeCustomTaskSectionStorage.subsections(
                    of: section.id,
                    in: customTaskSections
                ).map { subsection in
                    HomeBacklogCreationDestination(
                        id: subsection.id,
                        title: "Backlog › \(section.title) › \(subsection.title)"
                    )
                }
        }
    }

    func createBacklogSearchTask(in sectionID: UUID?) {
        guard let taskName = pendingBacklogSearchCreationText else { return }
        pendingBacklogSearchCreationText = nil
        backlogStore.send(.searchTextChanged(""))
        resetToolbarSearchPreviewState(for: nil)
        isToolbarSearchTaskTitleFocused = false
        quickAddCreatedToast = nil
        if let sectionID {
            store.send(.openAddTaskInCustomSectionWithName(sectionID, taskName))
        } else {
            store.send(.openAddTaskSheet(seedName: taskName))
        }
        scheduleAddTaskNameFocus()
    }

    func showBacklogTaskInPlanner(_ taskID: UUID, searchText: String) {
        leaveBacklogAfterClosingEmbeddedTaskDetail {
            store.send(.macSidebarModeChanged(.routines))
            searchTextBinding.wrappedValue = searchText
            macSearchPresentationText = searchText
            openMacTaskDetails(taskID, presentation: .plannerPane)
        }
    }

    func showBacklogTaskInTimeline(_ taskID: UUID, searchText: String) {
        leaveBacklogAfterClosingEmbeddedTaskDetail {
            openTimelineInSidebar()
            searchTextBinding.wrappedValue = searchText
            macSearchPresentationText = searchText
            macTimelineSidebarScrollRequest =
                timelineEntries
                .first(where: { $0.taskID == taskID })
                .map { MacTimelineSidebarScrollRequest(entryID: $0.id) }
        }
    }

    func leaveBacklogAfterClosingEmbeddedTaskDetail(
        _ completion: @escaping @MainActor () -> Void
    ) {
        guard backlogStore.taskDetailState != nil else {
            completion()
            return
        }

        backlogStore.send(.workspaceDeactivated)
        DispatchQueue.main.async {
            completion()
        }
    }

    func handleQuickAddCreated(_ result: RoutinaQuickAddCreateResult) {
        requestRefresh()
        withAnimation(.easeOut(duration: 0.18)) {
            quickAddCreatedToast = MacTaskCreatedToast(
                taskID: result.taskID,
                taskName: result.taskName
            )
        }
    }

    func openQuickAddCreatedTask(_ toast: MacTaskCreatedToast) {
        quickAddCreatedToast = nil
        macHomeDetailMode = .details
        taskDetailPanePlacement = nil
        RoutinaDeepLinkDispatcher.open(.task(toast.taskID))
    }

    func openAddTask() {
        isEmotionLogEditorPresented = false
        isNoteEditorPresented = false
        isAwayStartPresented = false
        addEditFormCoordinator.resetRevealedTaskFormSections()
        store.send(.macSidebarModeChanged(.addTask))
        store.send(.setAddRoutineSheet(true))
        scheduleAddTaskNameFocus()
    }

    func openAddTodo() {
        openAddTask()
        store.send(.addRoutineSheet(.taskTypeChanged(.todo)))
    }

    func scheduleAddTaskNameFocus() {
        let delays: [TimeInterval] = [0, 0.05, 0.15, 0.3, 0.6, 1.0, 1.5]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                addEditFormCoordinator.requestNameFocus()
            }
        }
    }

}
