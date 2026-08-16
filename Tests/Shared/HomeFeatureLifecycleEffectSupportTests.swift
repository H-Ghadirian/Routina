import ComposableArchitecture
import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct HomeFeatureLifecycleEffectSupportTests {
    @Test
    func manualRefreshFailureReportsRecoveryAndStillReloadsLocalData() async {
        let context = makeInMemoryContext()
        let expectedMessage = CloudSyncFeedbackSupport.manualRefreshErrorMessage(
            for: CloudSyncManualRefreshError.stalled(receivedRecordCount: 120)
        )
        let store = TestStore(initialState: ManualRefreshHarness.State()) {
            ManualRefreshHarness()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.refresh)
        await store.receive(.failed(expectedMessage)) {
            $0.errorMessage = expectedMessage
        }
        await store.receive(.reload) {
            $0.reloadCount = 1
        }
        await store.receive(.reload) {
            $0.reloadCount = 2
        }
    }
}

@Reducer
private struct ManualRefreshHarness {
    @Dependency(\.modelContext) private var modelContext

    @ObservableState
    struct State: Equatable {
        var errorMessage: String?
        var reloadCount = 0
    }

    enum Action: Equatable {
        case refresh
        case failed(String)
        case reload
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .refresh:
                return HomeFeatureLifecycleEffectSupport.manualRefreshEffect(
                    modelContext: { self.modelContext() },
                    pullLatestIntoLocalStore: { _ in
                        throw CloudSyncManualRefreshError.stalled(receivedRecordCount: 120)
                    },
                    sleepBeforeSecondRefresh: {},
                    onAppearAction: { .reload },
                    refreshFailedAction: { .failed($0) }
                )

            case let .failed(message):
                state.errorMessage = message
                return .none

            case .reload:
                state.reloadCount += 1
                return .none
            }
        }
    }
}
