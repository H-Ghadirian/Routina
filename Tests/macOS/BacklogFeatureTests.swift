import ComposableArchitecture
import Testing
@testable @preconcurrency import RoutinaMacOSDev

@MainActor
struct BacklogFeatureTests {
    @Test
    func automaticRefreshDoesNotEnterVisibleLoadingState() async {
        let context = makeInMemoryContext()
        let store = TestStore(initialState: BacklogFeature.State()) {
            BacklogFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.automaticRefresh)
        await store.receive(.tasksLoaded([], [], []))
    }

    @Test
    func manualRefreshStillUsesVisibleLoadingState() async {
        let context = makeInMemoryContext()
        let store = TestStore(initialState: BacklogFeature.State()) {
            BacklogFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.refresh) {
            $0.isLoading = true
        }
        await store.receive(.tasksLoaded([], [], [])) {
            $0.isLoading = false
        }
    }
}
