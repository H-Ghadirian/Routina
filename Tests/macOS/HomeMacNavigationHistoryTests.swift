import Foundation
import Testing
@testable @preconcurrency import RoutinaMacOSDev

@MainActor
struct HomeMacNavigationHistoryTests {
    @Test
    func backAndForwardTraverseRecordedSnapshots() {
        let taskID = UUID()
        let emptyDetails = snapshot(detailMode: .details)
        let taskDetails = snapshot(
            sidebarSelection: .task(taskID),
            selectedTaskID: taskID,
            detailMode: .details
        )
        let places = snapshot(
            sidebarSelection: .task(taskID),
            selectedTaskID: taskID,
            detailMode: .places
        )
        var history = HomeMacNavigationHistory()

        history.record(emptyDetails)
        history.record(taskDetails)
        history.record(places)

        #expect(history.goBack(from: places) == taskDetails)
        #expect(history.goBack(from: taskDetails) == emptyDetails)
        #expect(history.goForward(from: emptyDetails) == taskDetails)
        #expect(history.goForward(from: taskDetails) == places)
    }

    @Test
    func recordingNewSnapshotAfterBackClearsForwardStack() {
        let taskAID = UUID()
        let taskBID = UUID()
        let emptyDetails = snapshot(detailMode: .details)
        let taskADetails = snapshot(
            sidebarSelection: .task(taskAID),
            selectedTaskID: taskAID,
            detailMode: .details
        )
        let places = snapshot(
            sidebarSelection: .task(taskAID),
            selectedTaskID: taskAID,
            detailMode: .places
        )
        let taskBDetails = snapshot(
            sidebarSelection: .task(taskBID),
            selectedTaskID: taskBID,
            detailMode: .details
        )
        var history = HomeMacNavigationHistory()

        history.record(emptyDetails)
        history.record(taskADetails)
        history.record(places)
        #expect(history.goBack(from: places) == taskADetails)

        history.record(taskBDetails)

        #expect(!history.canGoForward)
        #expect(history.goBack(from: taskBDetails) == taskADetails)
    }

    @Test
    func duplicateSnapshotsDoNotCreateHistoryEntries() {
        let emptyDetails = snapshot(detailMode: .details)
        var history = HomeMacNavigationHistory()

        history.record(emptyDetails)
        history.record(emptyDetails)

        #expect(!history.canGoBack)
        #expect(history.current == emptyDetails)
    }

    @Test
    func hiddenAdventureProgressModeNormalizesToStatsInHistorySnapshots() {
        let adventure = snapshot(
            sidebarMode: .stats,
            detailMode: .details,
            progressMode: .adventure
        )

        #expect(adventure.progressMode == .stats)
    }

    @Test
    func hiddenBoardDetailModeNormalizesToDetailsInHistorySnapshots() {
        let key = UserDefaultBoolValueKey.appSettingBoardScreenEnabled.rawValue
        let previousValue = SharedDefaults.app.object(forKey: key)
        defer {
            if let previousValue {
                SharedDefaults.app.set(previousValue, forKey: key)
            } else {
                SharedDefaults.app.removeObject(forKey: key)
            }
        }

        SharedDefaults.app[.appSettingBoardScreenEnabled] = false
        let board = snapshot(detailMode: .board)

        #expect(board.detailMode == .details)
    }

    @Test
    func taskDetailPanePlacementRequiresSelectedTaskAndCompatibleDetailMode() {
        let key = UserDefaultBoolValueKey.appSettingBoardScreenEnabled.rawValue
        let previousValue = SharedDefaults.app.object(forKey: key)
        defer {
            if let previousValue {
                SharedDefaults.app.set(previousValue, forKey: key)
            } else {
                SharedDefaults.app.removeObject(forKey: key)
            }
        }

        SharedDefaults.app[.appSettingBoardScreenEnabled] = true
        let taskID = UUID()

        let plannerPane = snapshot(
            sidebarSelection: .task(taskID),
            selectedTaskID: taskID,
            detailMode: .planner,
            taskDetailPanePlacement: .plannerAdjacent
        )
        let listPane = snapshot(
            sidebarSelection: .task(taskID),
            selectedTaskID: taskID,
            detailMode: .board,
            taskDetailPanePlacement: .listAdjacent
        )
        let listPaneInPlanner = snapshot(
            sidebarSelection: .task(taskID),
            selectedTaskID: taskID,
            detailMode: .planner,
            taskDetailPanePlacement: .listAdjacent
        )
        let detailsPane = snapshot(
            sidebarSelection: .task(taskID),
            selectedTaskID: taskID,
            detailMode: .details,
            taskDetailPanePlacement: .listAdjacent
        )
        let plannerWithoutTask = snapshot(
            detailMode: .planner,
            taskDetailPanePlacement: .plannerAdjacent
        )

        #expect(plannerPane.taskDetailPanePlacement == .plannerAdjacent)
        #expect(listPane.taskDetailPanePlacement == .listAdjacent)
        #expect(listPaneInPlanner.taskDetailPanePlacement == .plannerAdjacent)
        #expect(detailsPane.taskDetailPanePlacement == nil)
        #expect(plannerWithoutTask.taskDetailPanePlacement == nil)
    }

    private func snapshot(
        sidebarMode: HomeFeature.MacSidebarMode = .routines,
        sidebarSelection: HomeFeature.MacSidebarSelection? = nil,
        selectedTaskID: UUID? = nil,
        selectedSettingsSection: SettingsMacSection = .notifications,
        selectedBoardScope: HomeFeature.BoardScope = .backlog,
        detailMode: MacHomeDetailMode,
        progressMode: MacHomeProgressMode = .stats,
        taskDetailPanePlacement: MacTaskDetailPanePlacement? = nil
    ) -> HomeMacNavigationSnapshot {
        HomeMacNavigationSnapshot(
            sidebarMode: sidebarMode,
            sidebarSelection: sidebarSelection,
            selectedTaskID: selectedTaskID,
            selectedSettingsSection: selectedSettingsSection,
            selectedBoardScope: selectedBoardScope,
            detailMode: detailMode,
            progressMode: progressMode,
            taskDetailPanePlacement: taskDetailPanePlacement
        )
    }
}
