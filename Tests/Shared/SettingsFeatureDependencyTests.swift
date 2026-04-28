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
                appLockEnabled: { true },
                setAppLockEnabled: { _ in },
                gitFeaturesEnabled: { true },
                setGitFeaturesEnabled: { _ in },
                showPersianDates: { true },
                setShowPersianDates: { _ in },
                routineListSectioningMode: { .deadlineDate },
                setRoutineListSectioningMode: { _ in },
                tagCounterDisplayMode: { .defaultValue },
                setTagCounterDisplayMode: { _ in },
                relatedTagRules: { [] },
                setRelatedTagRules: { _ in },
                tagColors: { [:] },
                setTagColors: { _ in },
                notificationReminderTime: { reminderTime },
                setNotificationReminderTime: { _ in },
                selectedAppIcon: { .teal },
                temporaryViewState: { nil },
                setTemporaryViewState: { _ in },
                resetTemporaryViewState: { }
            )
            $0.deviceAuthenticationClient.status = {
                DeviceAuthenticationStatus(
                    isAvailable: true,
                    methodDescription: "Face ID or your device passcode",
                    unavailableReason: nil
                )
            }
            $0.notificationClient.systemNotificationsAuthorized = { true }
            $0.locationClient.snapshot = { _ in snapshot }
        }

        var loadedEstimate = CloudUsageEstimate.zero
        var loadedPlaces: [RoutinePlaceSummary] = []
        var loadedTags: [RoutineTagSummary] = []

        await store.send(.onAppear) {
            $0.diagnostics.appVersion = "9.9.9"
            $0.diagnostics.dataModeDescription = "Local + Cloud"
            $0.diagnostics.iCloudContainerDescription = "iCloud.com.routina"
            $0.cloud.cloudSyncAvailable = true
            $0.notifications.notificationsEnabled = true
            $0.notifications.notificationReminderTime = reminderTime
            $0.appearance.routineListSectioningMode = .deadlineDate
            $0.appearance.isAppLockEnabled = true
            $0.appearance.isGitFeaturesEnabled = true
            $0.appearance.showPersianDates = true
            $0.appearance.appLockMethodDescription = "Face ID or your device passcode"
            $0.appearance.selectedAppIcon = .teal
            $0.appearance.appIconStatusMessage = ""
            $0.diagnostics.isDebugSectionVisible = false
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
            $0.cloud.cloudUsageEstimate = loadedEstimate
        }
        await store.receive { action in
            guard case let .placesLoaded(places) = action else { return false }
            loadedPlaces = places
            #expect(places.count == 1)
            #expect(places.first?.name == "Home")
            #expect(places.first?.linkedRoutineCount == 1)
            return true
        } assert: {
            $0.places.savedPlaces = loadedPlaces
        }
        await store.receive { action in
            guard case let .tagsLoaded(tags) = action else { return false }
            loadedTags = tags
            #expect(tags.count == 1)
            #expect(tags.first?.name == "Focus")
            #expect(tags.first?.linkedRoutineCount == 1)
            return true
        } assert: {
            $0.tags.savedTags = loadedTags
            $0.tags.relatedTagDrafts = ["focus": ""]
        }
        await store.receive(.tagColorsLoaded([:]))
        await store.receive(.relatedTagRulesLoaded([]))
        await store.receive(.learnedRelatedTagRulesLoaded([]))
        await store.receive(.locationSnapshotUpdated(snapshot)) {
            $0.places.locationAuthorizationStatus = .authorizedAlways
            $0.places.lastKnownLocationCoordinate = snapshot.coordinate
        }
    }

    @Test
    func toggleNotifications_offPersistsPreferenceAndCancelsAllNotifications() async {
        let context = makeInMemoryContext()
        let capturedNotificationPreference = LockIsolated<Bool?>(nil)
        let cancelAllCallCount = LockIsolated(0)

        let store = TestStore(
            initialState: SettingsFeature.State(
                notifications: .init(notificationsEnabled: true)
            )
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
            $0.notifications.notificationsEnabled = false
        }

        #expect(capturedNotificationPreference.value == false)
        #expect(cancelAllCallCount.value == 1)
    }

    @Test
    func openAppSettingsTapped_opensNotificationSettingsURLWhenAvailable() async {
        let context = makeInMemoryContext()
        let openedURL = LockIsolated<URL?>(nil)
        let settingsURL = URL(string: "app-settings:notifications")!

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.urlOpenerClient = URLOpenerClient(
                open: { url in
                    openedURL.setValue(url)
                },
                notificationSettingsURL: { settingsURL }
            )
        }

        await store.send(.openAppSettingsTapped)

        #expect(openedURL.value == settingsURL)
    }
}
