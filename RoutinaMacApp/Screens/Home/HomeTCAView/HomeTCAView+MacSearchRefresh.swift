import AppKit
import Combine
import ComposableArchitecture
import Foundation
import MapKit
import SwiftUI

extension HomeTCAView {
    func applyPlatformDeleteConfirmation<Content: View>(to view: Content) -> some View {
        view.alert(
            deleteConfirmationTitle,
            isPresented: deleteConfirmationBinding
        ) {
            Button("Delete", role: .destructive) {
                store.send(.deleteTasksConfirmed)
            }
            Button("Cancel", role: .cancel) {
                store.send(.setDeleteConfirmation(false))
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
    }

    func applyPlatformSearchExperience<Content: View>(
        to view: Content,
        searchText: Binding<String>
    ) -> some View {
        view
            .onAppear {
                updateMacSearchSidebarReveal(for: searchText.wrappedValue)
                applyMacSearchPresentation(searchText.wrappedValue)
            }
            .onChange(of: searchText.wrappedValue) { _, newValue in
                updateMacSearchSidebarReveal(for: newValue)
                scheduleMacSearchPresentationUpdate(for: newValue)
            }
            .onDisappear {
                macSearchPresentationUpdateTask?.cancel()
            }
    }

    @ViewBuilder
    func platformSearchField(searchText: Binding<String>) -> some View {
        HomeMacSearchField(
            placeholder: searchPlaceholderText,
            text: searchText
        )
    }

    func applyPlatformRefresh<Content: View>(to view: Content) -> some View {
        view
            .safeAreaInset(edge: .top) {
                if isManualCloudRefreshInProgress {
                    HomeManualCloudRefreshProgressBanner(
                        statusText: manualCloudRefreshStatusText
                    )
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: CloudKitSyncDiagnostics.didUpdateNotification
                )
            ) { _ in
                updateManualCloudRefreshStatus()
            }
            .alert(
                "Couldn't Refresh from iCloud",
                isPresented: Binding(
                    get: { store.manualRefreshErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            store.send(.manualRefreshErrorDismissed)
                        }
                    }
                )
            ) {
                Button("Try Again") {
                    Task { @MainActor in
                        await performManualCloudRefresh()
                    }
                }
                Button("OK", role: .cancel) {
                    store.send(.manualRefreshErrorDismissed)
                }
            } message: {
                Text(store.manualRefreshErrorMessage ?? "")
            }
    }

    @ViewBuilder
    var platformRefreshButton: some View {
        MacToolbarIconButton(title: "Sync with iCloud", systemImage: "arrow.clockwise") {
            Task { @MainActor in
                await performManualCloudRefresh()
            }
        }
    }

    @MainActor
    func performManualCloudRefresh() async {
        guard !isManualCloudRefreshInProgress else { return }

        isManualCloudRefreshInProgress = true
        manualCloudRefreshStatusText = "Checking iCloud for updates…"
        defer {
            isManualCloudRefreshInProgress = false
            manualCloudRefreshStatusText = ""
        }

        await store.send(.manualRefreshRequested).finish()
    }

    func updateManualCloudRefreshStatus() {
        guard isManualCloudRefreshInProgress else { return }

        let message = CloudKitSyncDiagnostics.snapshot().manualRefreshDisplayMessage
        if !message.isEmpty {
            manualCloudRefreshStatusText = message
        }
    }

    func applyPlatformHomeObservers<Content: View>(to view: Content) -> some View {
        HomeMacSidebarCommandRouter(
            content: view,
            mode: effectiveMacSidebarMode,
            onOpenRoutines: showRoutinesInSidebar,
            onOpenAddTask: openAddTask,
            onOpenFocus: presentHomeToolbarFocusPicker,
            onOpenAddEvent: openAddEvent,
            onOpenAddEmotion: openAddEmotion,
            onOpenAddNote: openAddNote,
            onOpenAddGoal: openAddGoal,
            onOpenCheckIn: openCheckInFromAddMenu,
            onOpenAway: openAwayFromAddMenu,
            onOpenTimeline: openTimelineInSidebar,
            onOpenStats: openStatsInSidebar,
            onOpenBacklog: openBacklogInMainWindow,
            onOpenTaskLadder: openTaskLadderInMainWindow,
            onScrollSelectedTaskInSidebar: scrollSelectedTaskInMacSidebar
        ) { mode in
            if mode == .settings {
                settingsStore.send(.onAppear)
            } else if mode == .goals {
                goalsStore.send(.onAppear)
            }
        }
        .onAppear {
            settingsStore.send(.onAppear)
            recordMacNavigationSnapshotIfNeeded()
        }
        .onChange(of: macNavigationSnapshot) { _, snapshot in
            recordMacNavigationSnapshotIfNeeded(snapshot)
        }
        .onChange(of: store.selectedTaskID) { _, taskID in
            if taskID != nil {
                isEmotionLogEditorPresented = false
                isNoteEditorPresented = false
                isAwayStartPresented = false
                normalizeTaskDetailPanePlacement()
            } else {
                taskDetailPanePlacement = nil
                plannerTaskDetailDoneSelection = nil
            }
        }
        .onChange(of: store.macSidebarMode) { _, mode in
            if mode != .routines {
                isNoteEditorPresented = false
                isAwayStartPresented = false
            }
        }
        .onChange(of: store.isAddRoutineSheetPresented) { wasPresented, isPresented in
            guard wasPresented,
                !isPresented,
                effectiveMacSidebarMode == .routines,
                let taskID = store.selectedTaskID
            else { return }
            searchTextBinding.wrappedValue = ""
            macSidebarTaskScrollRequest = MacSidebarTaskScrollRequest(taskID: taskID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .routinaMacNavigateBack)) { _ in
            goBackInMacNavigationHistory()
        }
        .onReceive(NotificationCenter.default.publisher(for: .routinaMacNavigateForward)) { _ in
            goForwardInMacNavigationHistory()
        }
        .onReceive(NotificationCenter.default.publisher(for: .routinaMacFocusSearchOrCreate)) { _ in
            focusExpandedToolbarSearchFromCommand()
        }
        .onChange(of: showsHomeToolbarSearch) { _, showsSearch in
            if !showsSearch {
                dismissToolbarSearchFocus()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .routinaOpenDeepLink)) { notification in
            alignMacDetailModeForDeepLinkNotification(notification)
        }
    }

    func focusExpandedToolbarSearchFromCommand() {
        guard showsHomeToolbarSearch else { return }
        toolbarSearchFocusRequestID += 1
        toolbarSearchExpansionTransitionID += 1
        let transitionID = toolbarSearchExpansionTransitionID

        if !isToolbarSearchExpanded {
            toolbarSearchVisiblePillWidth = HomeMacToolbarSearchLayout.compactWidth
            isToolbarSearchExpanded = true
        }

        if !isToolbarSearchTextFocused {
            isToolbarSearchTextFocused = true
        }

        DispatchQueue.main.async {
            guard toolbarSearchExpansionTransitionID == transitionID else { return }
            withAnimation(.easeInOut(duration: HomeMacToolbarSearchLayout.animationDuration)) {
                toolbarSearchVisiblePillWidth = HomeMacToolbarSearchLayout.focusedWidth
            }
        }
    }

    func dismissToolbarSearchFocus() {
        guard isToolbarSearchTextFocused || isToolbarSearchExpanded else { return }
        toolbarSearchExpansionTransitionID += 1
        isToolbarSearchTextFocused = false
        isToolbarSearchExpanded = false
        toolbarSearchVisiblePillWidth = HomeMacToolbarSearchLayout.compactWidth
        toolbarSearchFocusDismissRequestID += 1
    }

    func alignMacDetailModeForDeepLinkNotification(_ notification: Notification) {
        guard let deepLink = RoutinaDeepLinkDispatcher.deepLink(from: notification) else { return }
        switch deepLink {
        case .task:
            macHomeDetailMode = .details
            taskDetailPanePlacement = nil
        case .goal:
            break
        case let .note(noteID):
            macTimelineSidebarScrollRequest = MacTimelineSidebarScrollRequest(entryID: noteID)
        case let .event(eventID):
            macTimelineSidebarScrollRequest = MacTimelineSidebarScrollRequest(entryID: eventID)
        case .sprint:
            macHomeDetailMode = MacHomeDetailMode.board.visibleSurfaceMode
            taskDetailPanePlacement = nil
        case .sleep:
            macHomeDetailMode = .planner
            taskDetailPanePlacement = nil
        }
    }

    var searchPlaceholderText: String {
        if effectiveMacSidebarMode == .goals {
            return "Search goals"
        }
        if effectiveMacSidebarMode == .timeline {
            return "Search timeline"
        }
        if isMacBoardSidebarPresented {
            return "Search one-time tasks"
        }
        switch store.taskListMode {
        case .all:
            return "Search tasks"
        case .routines:
            return "Search repeating tasks"
        case .todos:
            return "Search one-time tasks"
        }
    }

}

private struct HomeManualCloudRefreshProgressBanner: View {
    let statusText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView()
                .progressViewStyle(.linear)
                .accessibilityLabel("Receiving iCloud data")
                .accessibilityValue(statusText)
            Text(statusText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}
