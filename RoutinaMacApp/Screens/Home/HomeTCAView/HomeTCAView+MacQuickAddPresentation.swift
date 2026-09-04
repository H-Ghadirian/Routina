import AppKit
import Combine
import ComposableArchitecture
import Foundation
import MapKit
import SwiftUI

extension HomeTCAView {
    func applyAddRoutinePresentation<Content: View>(to content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                toolbarSearchParserPreview
            }
            .overlay(alignment: .topTrailing) {
                toolbarSearchToasts
            }
            .animation(
                .easeOut(duration: 0.12),
                value: toolbarSearchPinnedParserPreviewDraft != nil
            )
            .animation(
                .easeOut(duration: 0.18),
                value: store.taskCreationConfirmation
            )
            .onChange(of: toolbarSearchTextBinding.wrappedValue) { oldValue, newValue in
                reconcileToolbarSearchPreviewState(
                    previousText: oldValue,
                    currentText: newValue
                )
            }
            .onChange(of: toolbarSearchCreateDraft, initial: true) { _, draft in
                guard let draft else { return }
                toolbarSearchPinnedParserPreviewDraft = RoutinaQuickAddPreviewPinning.updatedDraft(
                    currentText: toolbarSearchTextBinding.wrappedValue,
                    currentDraft: draft,
                    pinnedDraft: toolbarSearchPinnedParserPreviewDraft,
                    canBeginPresentation: true
                )
            }
            .onChange(of: toolbarSearchHasConfirmedResult) { _, hasConfirmedResult in
                if hasConfirmedResult {
                    toolbarSearchPinnedParserPreviewDraft = nil
                    isToolbarSearchTaskTitleFocused = false
                }
            }
            .task(id: toolbarSearchLinkResolutionID) {
                guard
                    let draft = RoutinaQuickAddParser.parse(
                        toolbarSearchTextBinding.wrappedValue,
                        calendar: calendar,
                        includingPlaces: isPlacesEnabled
                    )
                else { return }
                await resolveToolbarSearchLinkTitle(for: draft)
            }
            .alert("Could Not Create Task", isPresented: toolbarSearchCreateErrorBinding) {
                Button("OK", role: .cancel) {
                    toolbarSearchCreateErrorMessage = nil
                }
            } message: {
                if let toolbarSearchCreateErrorMessage {
                    Text(toolbarSearchCreateErrorMessage)
                }
            }
    }

    @ViewBuilder
    var toolbarSearchParserPreview: some View {
        let shouldShowParserPreview =
            showsHomeToolbarSearch
            && (isToolbarSearchExpanded || isToolbarSearchTaskTitleFocused)
        if shouldShowParserPreview, let toolbarSearchPinnedParserPreviewDraft {
            HomeMacToolbarSearchParserPreview(
                draft: toolbarSearchPinnedParserPreviewDraft,
                taskTitle: toolbarSearchTaskTitleBinding(
                    for: toolbarSearchPinnedParserPreviewDraft
                ),
                isTaskTitleFocused: $isToolbarSearchTaskTitleFocused,
                reminderChoice: $toolbarSearchReminderChoice,
                customReminderAt: $toolbarSearchCustomReminderAt,
                linkMetadataStatus: toolbarSearchLinkMetadataStatus,
                isUpdating: toolbarSearchParserPreviewIsUpdating,
                onSubmit: { submission in
                    createTaskFromToolbarSearch(
                        toolbarSearchTextBinding.wrappedValue,
                        draft: toolbarSearchPinnedParserPreviewDraft,
                        submission: submission
                    )
                }
            )
            .frame(
                width: HomeMacToolbarSearchLayout.focusedWidth,
                alignment: .leading
            )
            .padding(
                .top,
                HomeMacToolbarSearchLayout.topToolbarHeight
                    + HomeMacToolbarSearchLayout.parserPreviewTopPadding
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
            .zIndex(20)
        }
    }

    var toolbarSearchToasts: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if let taskCreationConfirmation = store.taskCreationConfirmation {
                let toast = MacTaskCreatedToast(
                    id: taskCreationConfirmation.id,
                    taskID: taskCreationConfirmation.taskID,
                    taskName: taskCreationConfirmation.taskName
                )

                MacTaskCreatedToastView(
                    toast: toast,
                    onOpen: nil,
                    onClose: {
                        store.send(.dismissTaskCreationConfirmation)
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: toast.id) {
                    do {
                        try await Task.sleep(for: .seconds(10))
                        await MainActor.run {
                            if store.taskCreationConfirmation?.id == toast.id {
                                store.send(.dismissTaskCreationConfirmation)
                            }
                        }
                    } catch {}
                }
            }

            if let quickAddCreatedToast {
                MacTaskCreatedToastView(
                    toast: quickAddCreatedToast,
                    onOpen: {
                        openQuickAddCreatedTask(quickAddCreatedToast)
                    },
                    onClose: {
                        self.quickAddCreatedToast = nil
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: quickAddCreatedToast.id) {
                    do {
                        try await Task.sleep(for: .seconds(10))
                        await MainActor.run {
                            if self.quickAddCreatedToast?.id == quickAddCreatedToast.id {
                                self.quickAddCreatedToast = nil
                            }
                        }
                    } catch {}
                }
            }

            if let macHomeNoticeToast {
                MacHomeNoticeToastView(
                    toast: macHomeNoticeToast,
                    onClose: {
                        self.macHomeNoticeToast = nil
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: macHomeNoticeToast.id) {
                    do {
                        try await Task.sleep(for: .seconds(5))
                        await MainActor.run {
                            if self.macHomeNoticeToast?.id == macHomeNoticeToast.id {
                                self.macHomeNoticeToast = nil
                            }
                        }
                    } catch {}
                }
            }
        }
        .padding(.top, HomeMacToolbarSearchLayout.topToolbarHeight + 18)
        .padding(.trailing, 22)
    }

    var toolbarSearchCreateErrorBinding: Binding<Bool> {
        Binding(
            get: { toolbarSearchCreateErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    toolbarSearchCreateErrorMessage = nil
                }
            }
        )
    }

    var canCreateTaskFromToolbarSearch: Bool {
        let trimmedText = toolbarSearchTextBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedText.isEmpty
            && !isToolbarSearchCreateInProgress
            && isActiveToolbarSearchPresentationCurrent
            && !activeToolbarSearchHasResult
    }

    var toolbarSearchCreateDraft: RoutinaQuickAddDraft? {
        guard canCreateTaskFromToolbarSearch,
            let draft = RoutinaQuickAddParser.parse(
                toolbarSearchTextBinding.wrappedValue,
                calendar: calendar,
                includingPlaces: isPlacesEnabled
            ),
            draft.hasDetectedMetadata
        else {
            return nil
        }

        return draft
    }

    var toolbarSearchHasConfirmedResult: Bool {
        isActiveToolbarSearchPresentationCurrent && activeToolbarSearchHasResult
    }

    var isActiveToolbarSearchPresentationCurrent: Bool {
        isMacBacklogMode || isMacTaskLadderMode || isMacSearchPresentationCurrent
    }

    var activeToolbarSearchHasResult: Bool {
        if isMacBacklogMode {
            return backlogStore.presentation.hasAnySearchResult
        }
        if isMacTaskLadderMode {
            return !taskRankingStore.searchPresentation.matches.isEmpty
                || !taskRankingStore.searchPresentation.outsideMatches.isEmpty
        }
        return toolbarSearchHasResult
    }

    var toolbarSearchParserPreviewIsUpdating: Bool {
        guard
            !toolbarSearchTextBinding.wrappedValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        else {
            return false
        }
        return RoutinaQuickAddParser.parse(
            toolbarSearchTextBinding.wrappedValue,
            calendar: calendar,
            includingPlaces: isPlacesEnabled
        ) == nil
    }

    var toolbarSearchLinkResolutionID: String? {
        guard
            let draft = RoutinaQuickAddParser.parse(
                toolbarSearchTextBinding.wrappedValue,
                calendar: calendar,
                includingPlaces: isPlacesEnabled
            ),
            let linkURL = draft.primaryLinkURL
        else {
            return nil
        }
        return linkURL.absoluteString
    }

    func toolbarSearchTaskTitleBinding(
        for draft: RoutinaQuickAddDraft
    ) -> Binding<String> {
        Binding(
            get: { toolbarSearchEffectiveTaskTitle(for: draft) },
            set: { newValue in
                toolbarSearchEditableTaskTitle = newValue
                toolbarSearchTaskTitleWasEdited = true
            }
        )
    }

    func toolbarSearchEffectiveTaskTitle(for draft: RoutinaQuickAddDraft) -> String {
        return toolbarSearchEditableTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? draft.name
            : toolbarSearchEditableTaskTitle
    }

    func reconcileToolbarSearchPreviewState(
        previousText: String,
        currentText: String
    ) {
        let previousDraft = RoutinaQuickAddParser.parse(
            previousText,
            calendar: calendar,
            includingPlaces: isPlacesEnabled
        )
        let currentDraft = RoutinaQuickAddParser.parse(
            currentText,
            calendar: calendar,
            includingPlaces: isPlacesEnabled
        )
        toolbarSearchPinnedParserPreviewDraft = RoutinaQuickAddPreviewPinning.updatedDraft(
            currentText: currentText,
            currentDraft: currentDraft,
            pinnedDraft: toolbarSearchPinnedParserPreviewDraft,
            canBeginPresentation: false
        )

        guard
            RoutinaQuickAddDraftContinuity.canPreservePreviewState(
                previousText: previousText,
                currentText: currentText,
                previousDraft: previousDraft,
                currentDraft: currentDraft
            )
        else {
            resetToolbarSearchPreviewState(
                for: currentDraft,
                clearsPinnedDraft: false
            )
            return
        }

        guard !toolbarSearchTaskTitleWasEdited,
            let currentDraft
        else {
            return
        }
        toolbarSearchEditableTaskTitle = defaultToolbarSearchTaskTitle(for: currentDraft)
    }

}
