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
@Suite(.serialized)
struct SettingsFeatureDependencyTests {
    @Test
    func onAppear_hydratesStateFromDependenciesAndLoadsContextData() async throws {
        let context = makeInMemoryContext()
        let place = makePlace(in: context, name: "Home")
        let task = makeTask(
            in: context,
            name: "Read",
            interval: 1,
            lastDone: nil,
            emoji: "📚",
            placeID: place.id,
            tags: ["Focus"]
        )
        _ = makeLog(in: context, task: task, timestamp: makeDate("2026-03-20T08:30:00Z"))
        try context.save()

        let reminderTime = makeDate("2026-03-20T06:45:00Z")
        let snapshot = LocationSnapshot(
            authorizationStatus: .authorizedAlways,
            coordinate: LocationCoordinate(latitude: 52.52, longitude: 13.405),
            horizontalAccuracy: 20,
            timestamp: makeDate("2026-03-20T10:00:00Z")
        )
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "cloudKitSyncDiagnostics.summary")
        defaults.removeObject(forKey: "cloudKitSyncDiagnostics.timestamp")
        defaults.removeObject(forKey: "cloudKitSyncDiagnostics.pushStatus")

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appInfoClient = AppInfoClient(
                versionString: { "9.9.9" },
                dataModeDescription: { "Local + Cloud" },
                cloudContainerDescription: { "iCloud.com.routina" },
                isCloudSyncEnabled: { true }
            )
            $0.appSettingsClient = AppSettingsClient(
                notificationsEnabled: { true },
                setNotificationsEnabled: { _ in },
                hideUnavailableRoutines: { false },
                setHideUnavailableRoutines: { _ in },
                routineListSectioningMode: { .deadlineDate },
                setRoutineListSectioningMode: { _ in },
                tagCounterDisplayMode: { .defaultValue },
                setTagCounterDisplayMode: { _ in },
                notificationReminderTime: { reminderTime },
                setNotificationReminderTime: { _ in },
                selectedAppIcon: { .teal },
                temporaryViewState: { nil },
                setTemporaryViewState: { _ in },
                resetTemporaryViewState: { }
            )
            $0.notificationClient.systemNotificationsAuthorized = { true }
            $0.locationClient.snapshot = { _ in snapshot }
        }

        var loadedEstimate = CloudUsageEstimate.zero
        var loadedPlaces: [RoutinePlaceSummary] = []
        var loadedTags: [RoutineTagSummary] = []

        await store.send(.onAppear) {
            $0.appVersion = "9.9.9"
            $0.dataModeDescription = "Local + Cloud"
            $0.iCloudContainerDescription = "iCloud.com.routina"
            $0.cloudSyncAvailable = true
            $0.notificationsEnabled = true
            $0.notificationReminderTime = reminderTime
            $0.routineListSectioningMode = .deadlineDate
            $0.selectedAppIcon = .teal
            $0.appIconStatusMessage = ""
            $0.isDebugSectionVisible = false
        }

        await store.receive(.systemNotificationPermissionChecked(true))
        await store.receive { action in
            guard case let .cloudUsageEstimateLoaded(estimate) = action else { return false }
            loadedEstimate = estimate
            #expect(estimate.taskCount == 1)
            #expect(estimate.placeCount == 1)
            #expect(estimate.logCount == 1)
            return true
        } assert: {
            $0.cloudUsageEstimate = loadedEstimate
        }
        await store.receive { action in
            guard case let .placesLoaded(places) = action else { return false }
            loadedPlaces = places
            #expect(places.count == 1)
            #expect(places.first?.name == "Home")
            #expect(places.first?.linkedRoutineCount == 1)
            return true
        } assert: {
            $0.savedPlaces = loadedPlaces
        }
        await store.receive { action in
            guard case let .tagsLoaded(tags) = action else { return false }
            loadedTags = tags
            #expect(tags.count == 1)
            #expect(tags.first?.name == "Focus")
            #expect(tags.first?.linkedRoutineCount == 1)
            return true
        } assert: {
            $0.savedTags = loadedTags
        }
        await store.receive(.locationSnapshotUpdated(snapshot)) {
            $0.locationAuthorizationStatus = .authorizedAlways
            $0.lastKnownLocationCoordinate = snapshot.coordinate
        }
    }

    @Test
    func toggleNotifications_offPersistsPreferenceAndCancelsAllNotifications() async {
        let context = makeInMemoryContext()
        let capturedNotificationPreference = LockIsolated<Bool?>(nil)
        let cancelAllCallCount = LockIsolated(0)

        let store = TestStore(
            initialState: SettingsFeature.State(notificationsEnabled: true)
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.setNotificationsEnabled = { isEnabled in
                capturedNotificationPreference.setValue(isEnabled)
            }
            $0.notificationClient.cancelAll = {
                cancelAllCallCount.setValue(cancelAllCallCount.value + 1)
            }
        }

        await store.send(.toggleNotifications(false)) {
            $0.notificationsEnabled = false
        }

        #expect(capturedNotificationPreference.value == false)
        #expect(cancelAllCallCount.value == 1)
    }
}
