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
    func progressModeParticipatesInHistorySnapshots() {
        let stats = snapshot(
            sidebarMode: .stats,
            detailMode: .details,
            progressMode: .stats
        )
        let adventure = snapshot(
            sidebarMode: .stats,
            detailMode: .details,
            progressMode: .adventure
        )
        var history = HomeMacNavigationHistory()

        history.record(stats)
        history.record(adventure)

        #expect(history.goBack(from: adventure) == stats)
        #expect(history.goForward(from: stats) == adventure)
    }

    private func snapshot(
        sidebarMode: HomeFeature.MacSidebarMode = .routines,
        sidebarSelection: HomeFeature.MacSidebarSelection? = nil,
        selectedTaskID: UUID? = nil,
        selectedSettingsSection: SettingsMacSection = .notifications,
        selectedBoardScope: HomeFeature.BoardScope = .backlog,
        detailMode: MacHomeDetailMode,
        progressMode: MacHomeProgressMode = .stats
    ) -> HomeMacNavigationSnapshot {
        HomeMacNavigationSnapshot(
            sidebarMode: sidebarMode,
            sidebarSelection: sidebarSelection,
            selectedTaskID: selectedTaskID,
            selectedSettingsSection: selectedSettingsSection,
            selectedBoardScope: selectedBoardScope,
            detailMode: detailMode,
            progressMode: progressMode
        )
    }
}
