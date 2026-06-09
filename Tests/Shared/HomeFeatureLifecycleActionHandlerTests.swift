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
struct HomeFeatureLifecycleActionHandlerTests {
    @Test
    func locationSnapshotUpdatedRetainsLastKnownCoordinateWhenAuthorizedRefreshHasNoCoordinate() {
        let previousSnapshot = LocationSnapshot(
            authorizationStatus: .authorizedWhenInUse,
            coordinate: LocationCoordinate(latitude: 52.5200, longitude: 13.4050),
            horizontalAccuracy: 25,
            timestamp: makeDate("2026-06-09T08:00:00Z")
        )
        let incomingSnapshot = LocationSnapshot(
            authorizationStatus: .authorizedAlways,
            coordinate: nil,
            horizontalAccuracy: nil,
            timestamp: nil
        )
        var state = TestLifecycleState(locationSnapshot: previousSnapshot)
        var didRefreshDisplays = false

        _ = makeHandler(refreshDisplays: { _ in didRefreshDisplays = true })
            .locationSnapshotUpdated(incomingSnapshot, state: &state)

        #expect(didRefreshDisplays)
        #expect(state.locationSnapshot.authorizationStatus == .authorizedAlways)
        #expect(state.locationSnapshot.coordinate == previousSnapshot.coordinate)
        #expect(state.locationSnapshot.horizontalAccuracy == previousSnapshot.horizontalAccuracy)
        #expect(state.locationSnapshot.timestamp == previousSnapshot.timestamp)
    }

    @Test
    func locationSnapshotUpdatedClearsCoordinateWhenAuthorizationIsLost() {
        let previousSnapshot = LocationSnapshot(
            authorizationStatus: .authorizedWhenInUse,
            coordinate: LocationCoordinate(latitude: 52.5200, longitude: 13.4050),
            horizontalAccuracy: 25,
            timestamp: makeDate("2026-06-09T08:00:00Z")
        )
        let incomingSnapshot = LocationSnapshot(
            authorizationStatus: .denied,
            coordinate: nil,
            horizontalAccuracy: nil,
            timestamp: nil
        )
        var state = TestLifecycleState(locationSnapshot: previousSnapshot)

        _ = makeHandler()
            .locationSnapshotUpdated(incomingSnapshot, state: &state)

        #expect(state.locationSnapshot == incomingSnapshot)
    }

    private func makeHandler(
        refreshDisplays: @escaping (inout TestLifecycleState) -> Void = { _ in }
    ) -> HomeFeatureLifecycleActionHandler<TestLifecycleState, Never> {
        HomeFeatureLifecycleActionHandler(
            temporaryViewState: { nil },
            applyTemporaryViewState: { _, _ in },
            tagColors: { [:] },
            refreshDisplays: refreshDisplays,
            setHideUnavailableRoutines: { _ in },
            persistTemporaryViewState: { _ in },
            loadOnAppearEffect: { _ in .none },
            manualRefreshEffect: { .none }
        )
    }
}

private struct TestLifecycleState: HomeFeatureLifecycleState {
    var hideUnavailableRoutines = false
    var locationSnapshot: LocationSnapshot
    var tagColors: [String: String] = [:]
    var isLoading = false
    var hasLoadedTaskSnapshot = false
}
