import ComposableArchitecture
import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct HomeFeatureTaskDetailActionRouterTests {
    @Test
    func markAsDoneSyncsSelectedTaskAndTimelineLogsImmediately() {
        var state = TestTaskDetailRouterState()
        var didSyncSelectedTask = false
        var syncedLogCounts: [Int] = []

        let router = makeRouter(
            syncSelectedTaskFromTaskDetail: { _ in
                didSyncSelectedTask = true
            },
            syncSelectedTaskLogs: { logs, _ in
                syncedLogCounts.append(logs.count)
            }
        )

        _ = router.handle(.markAsDone, state: &state)

        #expect(didSyncSelectedTask)
        #expect(syncedLogCounts == [0])
    }

    @Test
    func editSaveTappedSyncsSelectedTaskAndTimelineLogsImmediately() {
        var state = TestTaskDetailRouterState()
        var didSyncSelectedTask = false
        var syncedLogCounts: [Int] = []

        let router = makeRouter(
            syncSelectedTaskFromTaskDetail: { _ in
                didSyncSelectedTask = true
            },
            syncSelectedTaskLogs: { logs, _ in
                syncedLogCounts.append(logs.count)
            }
        )

        _ = router.handle(.editSaveTapped, state: &state)

        #expect(didSyncSelectedTask)
        #expect(syncedLogCounts == [0])
    }

    private func makeRouter(
        syncSelectedTaskFromTaskDetail: @escaping (inout TestTaskDetailRouterState) -> Void = { _ in },
        syncSelectedTaskLogs: @escaping ([RoutineLog], inout TestTaskDetailRouterState) -> Void = { _, _ in }
    ) -> HomeFeatureTaskDetailActionRouter<TestTaskDetailRouterState, TestTaskDetailRouterAction> {
        HomeFeatureTaskDetailActionRouter(
            clearTaskSelection: { _ in },
            updatePendingChecklistReloadGuard: { _, _ in },
            updatePendingChecklistUndoReloadGuard: { _ in },
            syncSelectedTaskFromTaskDetail: syncSelectedTaskFromTaskDetail,
            syncSelectedTaskLogs: syncSelectedTaskLogs,
            openLinkedTask: { _, _ in .none },
            openLinkedTaskSheet: { _ in }
        )
    }
}

private enum TestTaskDetailRouterAction: Equatable {}

private struct TestTaskDetailRouterState: Equatable {}
