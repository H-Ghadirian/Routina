import SwiftUI

extension HomeTCAView {
    var macNavigationSnapshot: HomeMacNavigationSnapshot {
        HomeMacNavigationSnapshot(
            sidebarMode: store.macSidebarMode,
            sidebarSelection: store.macSidebarSelection,
            selectedTaskID: store.selectedTaskID,
            selectedSettingsSection: store.selectedSettingsSection,
            selectedBoardScope: store.selectedBoardScope,
            detailMode: macHomeDetailMode,
            progressMode: macHomeProgressMode
        )
    }

    var shouldRecordMacNavigationSnapshot: Bool {
        !store.isAddRoutineSheetPresented
            && !store.isMacFilterDetailPresented
            && !isAwayStartPresented
            && store.macSidebarMode != .addTask
    }

    func recordMacNavigationSnapshotIfNeeded(_ snapshot: HomeMacNavigationSnapshot? = nil) {
        guard shouldRecordMacNavigationSnapshot, !isRestoringMacNavigationHistory else { return }
        macNavigationHistory.record(snapshot ?? macNavigationSnapshot)
    }

    func goBackInMacNavigationHistory() {
        guard shouldRecordMacNavigationSnapshot,
              let snapshot = macNavigationHistory.goBack(from: macNavigationSnapshot) else {
            return
        }

        restoreMacNavigationSnapshot(snapshot)
    }

    func goForwardInMacNavigationHistory() {
        guard shouldRecordMacNavigationSnapshot,
              let snapshot = macNavigationHistory.goForward(from: macNavigationSnapshot) else {
            return
        }

        restoreMacNavigationSnapshot(snapshot)
    }

    private func restoreMacNavigationSnapshot(_ snapshot: HomeMacNavigationSnapshot) {
        isRestoringMacNavigationHistory = true

        withAnimation(.easeInOut(duration: 0.18)) {
            macHomeDetailMode = snapshot.detailMode.visibleSurfaceMode
            macHomeProgressMode = snapshot.progressMode.visibleSurfaceMode
        }

        if snapshot.sidebarMode == .settings,
           store.selectedSettingsSection != snapshot.selectedSettingsSection {
            store.send(.selectedSettingsSectionChanged(snapshot.selectedSettingsSection))
        }

        if store.selectedBoardScope != snapshot.selectedBoardScope {
            store.send(.selectedBoardScopeChanged(snapshot.selectedBoardScope))
        }

        if store.macSidebarMode != snapshot.sidebarMode {
            store.send(.macSidebarModeChanged(snapshot.sidebarMode))
        }

        if snapshot.sidebarMode == .settings,
           store.selectedSettingsSection != snapshot.selectedSettingsSection {
            store.send(.selectedSettingsSectionChanged(snapshot.selectedSettingsSection))
        }

        restoreMacSidebarSelection(from: snapshot)

        Task { @MainActor in
            await Task.yield()
            isRestoringMacNavigationHistory = false
            macNavigationHistory.replaceCurrent(macNavigationSnapshot)
        }
    }

    private func restoreMacSidebarSelection(from snapshot: HomeMacNavigationSnapshot) {
        switch snapshot.sidebarSelection {
        case let .task(taskID):
            macSidebarTaskScrollRequest = MacSidebarTaskScrollRequest(
                taskID: taskID,
                anchor: .minimalReveal
            )
            store.send(.macSidebarSelectionChanged(.task(taskID)))

        case let .timelineEntry(entryID):
            macTimelineSidebarScrollRequest = MacTimelineSidebarScrollRequest(entryID: entryID)
            store.send(.macSidebarSelectionChanged(.timelineEntry(entryID)))
            if store.selectedTaskID != snapshot.selectedTaskID {
                store.send(.setSelectedTask(snapshot.selectedTaskID))
            }

        case nil:
            if store.macSidebarSelection != nil {
                store.send(.macSidebarSelectionChanged(nil))
            }
            if store.selectedTaskID != snapshot.selectedTaskID {
                store.send(.setSelectedTask(snapshot.selectedTaskID))
            }
        }
    }
}
