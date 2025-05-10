import ComposableArchitecture
import Testing
@testable @preconcurrency import RoutinaMacOSDev

@MainActor
struct AppFeatureTests {
    @Test
    func tabSelected_switchesToStatsTab() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.tabSelected(.stats)) {
            $0.selectedTab = .stats
        }
    }

    @Test
    func tabSelected_switchesToSearchTab() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.tabSelected(.search)) {
            $0.selectedTab = .search
        }
    }
}
