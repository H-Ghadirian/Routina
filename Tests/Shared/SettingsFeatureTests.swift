import ComposableArchitecture
import ConcurrencyExtras
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
struct SettingsFeatureTests {
    @Test
    func cloudUsageEstimate_countsRecordsAndMediaPayload() throws {
        let context = makeInMemoryContext()
        let place = makePlace(in: context, name: "Home")
        let task = makeTask(
            in: context,
            name: "Read",
            interval: 1,
            lastDone: makeDate("2026-03-20T10:00:00Z"),
            emoji: "📚",
            placeID: place.id,
            tags: ["Focus", "Evening"]
        )
        task.imageData = Data(repeating: 0xAB, count: 1_024)
        task.voiceNoteData = Data(repeating: 0xEF, count: 256)
        task.voiceNoteDurationSeconds = 4
        let placeCheckIn = PlaceCheckInSession(
            placeID: place.id,
            placeName: place.displayName,
            imageData: Data(repeating: 0xCD, count: 512),
            startedAt: makeDate("2026-03-21T09:00:00Z")
        )
        context.insert(placeCheckIn)
        let goal = RoutineGoal(title: "Portfolio")
        context.insert(goal)
        task.goalIDs = [goal.id]
        let note = RoutineNote(
            title: "Reading note",
            body: "Remember the source.",
            tags: ["Focus"],
            imageData: Data(repeating: 0xAC, count: 128),
            voiceNoteData: Data(repeating: 0xBC, count: 64),
            voiceNoteDurationSeconds: 1,
            createdAt: makeDate("2026-03-21T09:30:00Z")
        )
        context.insert(note)
        _ = makeLog(in: context, task: task, timestamp: makeDate("2026-03-21T08:30:00Z"))
        try context.save()

        let estimate = try CloudUsageEstimate.estimate(in: context)

        #expect(estimate.taskCount == 1)
        #expect(estimate.logCount == 1)
        #expect(estimate.placeCount == 1)
        #expect(estimate.goalCount == 1)
        #expect(estimate.noteCount == 1)
        #expect(estimate.imageCount == 3)
        #expect(estimate.imagePayloadBytes == 1_664)
        #expect(estimate.voiceNoteCount == 2)
        #expect(estimate.voiceNotePayloadBytes == 320)
        #expect(estimate.taskPayloadBytes > 0)
        #expect(estimate.logPayloadBytes > 0)
        #expect(estimate.placePayloadBytes > 0)
        #expect(estimate.goalPayloadBytes > 0)
        #expect(estimate.notePayloadBytes > 0)
        #expect(estimate.totalPayloadBytes >= 1_984)
    }

    @Test
    func cloudDataReset_requiresAppLockBeforeAuthentication() {
        var state = SettingsCloudState(
            cloudSyncAvailable: true,
            isCloudDataResetConfirmationPresented: true
        )

        #expect(!SettingsCloudEditor.beginDataResetAuthentication(
            appLockEnabled: false,
            hasRecentBackup: true,
            state: &state
        ))
        #expect(state.isCloudDataResetConfirmationPresented)
        #expect(!state.isCloudDataResetAuthenticationInProgress)
        #expect(!state.isCloudDataResetInProgress)
        #expect(state.cloudStatusMessage == "Turn on App Lock before deleting iCloud data.")
    }

    @Test
    func cloudDataReset_requiresRecentBackupBeforeAuthentication() {
        var state = SettingsCloudState(
            cloudSyncAvailable: true,
            isCloudDataResetConfirmationPresented: true
        )

        #expect(!SettingsCloudEditor.beginDataResetAuthentication(
            appLockEnabled: true,
            hasRecentBackup: false,
            state: &state
        ))
        #expect(state.isCloudDataResetConfirmationPresented)
        #expect(!state.isCloudDataResetAuthenticationInProgress)
        #expect(!state.isCloudDataResetInProgress)
        #expect(state.cloudStatusMessage == "Save a backup within the last 24 hours before deleting iCloud data.")
    }

    @Test
    func cloudDataReset_appLockAuthenticationFailureStopsReset() {
        var state = SettingsCloudState(
            cloudSyncAvailable: true,
            isCloudDataResetConfirmationPresented: true
        )

        #expect(SettingsCloudEditor.beginDataResetAuthentication(
            appLockEnabled: true,
            hasRecentBackup: true,
            state: &state
        ))
        #expect(state.isCloudDataResetConfirmationPresented)
        #expect(state.isCloudDataResetAuthenticationInProgress)
        #expect(!state.isCloudDataResetInProgress)

        #expect(!SettingsCloudEditor.finishDataResetAuthentication(
            .failure("Authentication was canceled."),
            state: &state
        ))
        #expect(state.isCloudDataResetConfirmationPresented)
        #expect(!state.isCloudDataResetAuthenticationInProgress)
        #expect(!state.isCloudDataResetInProgress)
        #expect(state.cloudStatusMessage == "Authentication was canceled.")
    }

    @Test
    func cloudDataReset_appLockAuthenticationSuccessAllowsReset() {
        var state = SettingsCloudState(
            cloudSyncAvailable: true,
            isCloudDataResetConfirmationPresented: true
        )

        #expect(SettingsCloudEditor.beginDataResetAuthentication(
            appLockEnabled: true,
            hasRecentBackup: true,
            state: &state
        ))
        #expect(SettingsCloudEditor.finishDataResetAuthentication(.success, state: &state))

        #expect(SettingsCloudEditor.prepareDataReset(
            hasCloudContainerIdentifier: true,
            state: &state
        ))
        #expect(!state.isCloudDataResetConfirmationPresented)
        #expect(!state.isCloudDataResetAuthenticationInProgress)
        #expect(state.isCloudDataResetInProgress)
        #expect(state.cloudStatusMessage == "Deleting iCloud data...")
    }

    @Test
    func localUserDataReset_deletesEverySwiftDataUserModel() throws {
        let context = makeInMemoryContext()
        let source = RoutinaDeviceActivitySource(
            installationID: "test-device",
            displayName: "Test Mac",
            platform: .mac,
            modelName: "Mac",
            systemName: "macOS",
            systemVersion: "26.4",
            appVersion: "1",
            bundleIdentifier: "com.routina.test"
        )
        let place = makePlace(in: context, name: "Home")
        let goal = RoutineGoal(title: "Health")
        context.insert(goal)
        let task = makeTask(
            in: context,
            name: "Stretch",
            interval: 1,
            lastDone: makeDate("2026-06-06T08:00:00Z"),
            emoji: nil,
            placeID: place.id
        )
        task.goalIDs = [goal.id]
        _ = makeLog(in: context, task: task, timestamp: makeDate("2026-06-06T08:30:00Z"))

        let sprint = BoardSprintRecord(title: "Launch", status: .active)
        let backlog = BoardBacklogRecord(title: "Someday")
        let sprintFocus = SprintFocusSessionRecord(sprintID: sprint.id)
        let note = RoutineNote(title: "Timeline note", body: "Body")
        context.insert(FocusSession(taskID: task.id))
        context.insert(sprint)
        context.insert(SprintAssignmentRecord(todoID: task.id, sprintID: sprint.id))
        context.insert(backlog)
        context.insert(BacklogAssignmentRecord(todoID: task.id, backlogID: backlog.id))
        context.insert(sprintFocus)
        context.insert(SprintFocusAllocationRecord(
            sessionID: sprintFocus.id,
            taskID: task.id,
            minutes: 25
        ))
        context.insert(SleepSession())
        context.insert(AwaySession())
        context.insert(PlaceCheckInSession(placeID: place.id, placeName: place.displayName))
        context.insert(EmotionLog(
            family: .joy,
            label: "happy",
            valence: 0.8,
            arousal: 0.4,
            intensity: 3
        ))
        context.insert(note)
        context.insert(RoutineNoteAttachment(
            noteID: note.id,
            fileName: "note.txt",
            data: Data("note".utf8)
        ))
        context.insert(RoutineEvent(title: "Appointment"))
        context.insert(RoutineAttachment(
            taskID: task.id,
            fileName: "task.txt",
            data: Data("task".utf8)
        ))
        context.insert(RoutinaDeviceSession(
            installationID: source.installationID,
            displayName: source.displayName,
            platform: source.platform,
            modelName: source.modelName,
            systemName: source.systemName,
            systemVersion: source.systemVersion,
            appVersion: source.appVersion,
            bundleIdentifier: source.bundleIdentifier
        ))
        context.insert(RoutinaDeviceActionLog(
            action: .created,
            entity: .task,
            entityID: task.id.uuidString,
            source: source
        ))
        context.insert(DayPlanBlockRecord(
            taskID: task.id,
            dayKey: "2026-06-06",
            startMinute: 9 * 60,
            durationMinutes: 45,
            titleSnapshot: "Stretch"
        ))
        try context.save()

        try LocalUserDataResetService.wipeAllUserData(in: context)

        #expect(try count(RoutineTask.self, in: context) == 0)
        #expect(try count(RoutineGoal.self, in: context) == 0)
        #expect(try count(RoutineLog.self, in: context) == 0)
        #expect(try count(FocusSession.self, in: context) == 0)
        #expect(try count(SprintFocusSessionRecord.self, in: context) == 0)
        #expect(try count(SprintFocusAllocationRecord.self, in: context) == 0)
        #expect(try count(SleepSession.self, in: context) == 0)
        #expect(try count(AwaySession.self, in: context) == 0)
        #expect(try count(PlaceCheckInSession.self, in: context) == 0)
        #expect(try count(RoutinePlace.self, in: context) == 0)
        #expect(try count(EmotionLog.self, in: context) == 0)
        #expect(try count(RoutineNote.self, in: context) == 0)
        #expect(try count(RoutineNoteAttachment.self, in: context) == 0)
        #expect(try count(RoutineEvent.self, in: context) == 0)
        #expect(try count(RoutineAttachment.self, in: context) == 0)
        #expect(try count(RoutinaDeviceSession.self, in: context) == 0)
        #expect(try count(RoutinaDeviceActionLog.self, in: context) == 0)
        #expect(try count(DayPlanBlockRecord.self, in: context) == 0)
        #expect(try count(BoardSprintRecord.self, in: context) == 0)
        #expect(try count(SprintAssignmentRecord.self, in: context) == 0)
        #expect(try count(BoardBacklogRecord.self, in: context) == 0)
        #expect(try count(BacklogAssignmentRecord.self, in: context) == 0)
    }

    @Test
    func appIconOptionMappings_matchExpectedAlternateIconNames() {
        #expect(AppIconOption.orange.iOSAlternateIconName == nil)
        #expect(AppIconOption.yellow.iOSAlternateIconName == "AppIconYellow")
        #expect(AppIconOption.teal.iOSAlternateIconName == "AppIconTeal")
        #expect(AppIconOption.lightBlue.iOSAlternateIconName == "AppIconLightBlue")
        #expect(AppIconOption.darkBlue.iOSAlternateIconName == "AppIconDarkBlue")
    }

    @Test
    func appIconSelected_successUpdatesSelection() async {
        let previousSelection = SharedDefaults.app[.selectedMacAppIcon]
        defer {
            SharedDefaults.app[.selectedMacAppIcon] = previousSelection
        }

        SharedDefaults.app[.selectedMacAppIcon] = AppIconOption.orange.rawValue

        let store = TestStore(
            initialState: SettingsFeature.State(
                appearance: .init(selectedAppIcon: .orange)
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appIconClient.requestChange = { option in
                #expect(option == .yellow)
                return nil
            }
        }

        await store.send(.appIconSelected(.yellow))

        await store.receive(.appIconChangeFinished(requestedOption: .yellow, errorMessage: nil)) {
            $0.appearance.selectedAppIcon = .yellow
        }
    }

    @Test
    func appIconSelected_failureKeepsCurrentSelectionAndShowsError() async {
        let previousSelection = SharedDefaults.app[.selectedMacAppIcon]
        defer {
            SharedDefaults.app[.selectedMacAppIcon] = previousSelection
        }

        SharedDefaults.app[.selectedMacAppIcon] = AppIconOption.orange.rawValue

        let store = TestStore(
            initialState: SettingsFeature.State(
                appearance: .init(
                    appIconStatusMessage: "Old status",
                    selectedAppIcon: .orange
                )
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appIconClient.requestChange = { option in
                #expect(option == .darkBlue)
                return "Resource temporarily unavailable"
            }
        }

        await store.send(.appIconSelected(.darkBlue)) {
            $0.appearance.appIconStatusMessage = ""
        }

        await store.receive(
            .appIconChangeFinished(
                requestedOption: .darkBlue,
                errorMessage: "Resource temporarily unavailable"
            )
        ) {
            $0.appearance.appIconStatusMessage = "App icon update failed: Resource temporarily unavailable"
        }

        #expect(store.state.appearance.selectedAppIcon == .orange)
        #expect(SharedDefaults.app[.selectedMacAppIcon] == AppIconOption.orange.rawValue)
    }

    @Test
    func toggleNotifications_offDisablesSettingAndCancelsAllNotifications() async {
        let didCancelAll = LockIsolated(false)
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(
            initialState: SettingsFeature.State(
                notifications: .init(notificationsEnabled: true)
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setNotificationsEnabled = { persistedValue.setValue($0) }
            $0.notificationClient.cancelAll = { didCancelAll.setValue(true) }
        }

        await store.send(.toggleNotifications(false)) {
            $0.notifications.notificationsEnabled = false
        }

        #expect(persistedValue.value == false)
        #expect(didCancelAll.value)
    }

    @Test
    func onAppear_loadsPersistedTagCounterDisplayMode() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.tagCounterDisplayMode = { .doneOnly }
            $0.appInfoClient = AppInfoClient(
                versionString: { "1.0" },
                dataModeDescription: { "Local" },
                cloudContainerDescription: { "Disabled" },
                isCloudSyncEnabled: { false }
            )
            $0.notificationClient.systemNotificationsAuthorized = { true }
            $0.locationClient.snapshot = { _ in
                LocationSnapshot(
                    authorizationStatus: .notDetermined,
                    coordinate: nil,
                    horizontalAccuracy: nil,
                    timestamp: nil
                )
            }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)

        #expect(store.state.appearance.tagCounterDisplayMode == .doneOnly)
    }

    @Test
    func tagCounterDisplayModeChanged_persistsSelection() async {
        let persistedValue = LockIsolated<TagCounterDisplayMode?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setTagCounterDisplayMode = { persistedValue.setValue($0) }
        }

        await store.send(.tagCounterDisplayModeChanged(.combinedTotal)) {
            $0.appearance.tagCounterDisplayMode = .combinedTotal
        }

        #expect(persistedValue.value == .combinedTotal)
    }

    @Test
    func taskRowFieldVisibilityChanged_persistsSelection() async {
        let persistedValue = LockIsolated<HomeTaskRowVisibility?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setTaskRowVisibility = { persistedValue.setValue($0) }
        }

        await store.send(.taskRowFieldVisibilityChanged(.tags, false)) {
            $0.appearance.taskRowVisibility = HomeTaskRowVisibility(hiddenFields: [.tags])
        }

        #expect(persistedValue.value == HomeTaskRowVisibility(hiddenFields: [.tags]))
    }

    @Test
    func appColorSchemeChanged_persistsSelection() async {
        let persistedValue = LockIsolated<AppColorScheme?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setAppColorScheme = { persistedValue.setValue($0) }
        }

        await store.send(.appColorSchemeChanged(.dark)) {
            $0.appearance.appColorScheme = .dark
        }

        #expect(persistedValue.value == .dark)
    }

    @Test
    func gitFeaturesToggled_persistsSelection() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setGitFeaturesEnabled = { persistedValue.setValue($0) }
        }

        await store.send(.gitFeaturesToggled(true)) {
            $0.appearance.isGitFeaturesEnabled = true
        }

        #expect(persistedValue.value == true)
    }

    @Test
    func showPersianDatesToggled_persistsSelection() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setShowPersianDates = { persistedValue.setValue($0) }
        }

        await store.send(.showPersianDatesToggled(true)) {
            $0.appearance.showPersianDates = true
        }

        #expect(persistedValue.value == true)
    }

    @Test
    func defaultSettingsKeepPersianDatesOff() {
        #expect(!SettingsFeature.State().appearance.showPersianDates)
        #expect(!RoutinaUserPreferences().showPersianDates)
    }

    @Test
    func taskSharingToggled_persistsSelection() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setTaskSharingEnabled = { persistedValue.setValue($0) }
        }

        await store.send(.taskSharingToggled(true)) {
            $0.appearance.isTaskSharingEnabled = true
        }

        #expect(persistedValue.value == true)
    }

    @Test
    func taskRelationshipVisualizerToggled_persistsSelection() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setTaskRelationshipVisualizerEnabled = { persistedValue.setValue($0) }
        }

        await store.send(.taskRelationshipVisualizerToggled(true)) {
            $0.appearance.isTaskRelationshipVisualizerEnabled = true
        }

        #expect(persistedValue.value == true)
    }

    @Test
    func placesToggled_persistsSelection() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setPlacesEnabled = { persistedValue.setValue($0) }
        }

        await store.send(.placesToggled(true)) {
            $0.appearance.isPlacesEnabled = true
        }

        #expect(persistedValue.value == true)
    }

    @Test
    func notesToggled_persistsSelection() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setNotesEnabled = { persistedValue.setValue($0) }
        }

        await store.send(.notesToggled(true)) {
            $0.appearance.isNotesEnabled = true
        }

        #expect(persistedValue.value == true)
    }

    @Test
    func awayToggled_persistsSelection() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setAwayEnabled = { persistedValue.setValue($0) }
        }

        await store.send(.awayToggled(true)) {
            $0.appearance.isAwayEnabled = true
        }

        #expect(persistedValue.value == true)
    }

    @Test
    func filterQuerySectionsToggled_persistsSelection() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setFilterQuerySectionsEnabled = { persistedValue.setValue($0) }
        }

        await store.send(.filterQuerySectionsToggled(true)) {
            $0.appearance.showsFilterQuerySections = true
        }

        #expect(persistedValue.value == true)
    }

    @Test
    func unlockUnlimitedTasksToggled_persistsSelection() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setUnlockUnlimitedTasks = { persistedValue.setValue($0) }
        }

        await store.send(.unlockUnlimitedTasksToggled(true)) {
            $0.appearance.unlocksUnlimitedTasks = true
        }

        #expect(persistedValue.value == true)
    }

    @Test
    func defaultSettingsKeepTaskSharingOff() {
        #expect(AppSettingsDefaults.boolValues[.appSettingTaskSharingEnabled] == .some(false))
        #expect(!SettingsFeature.State().appearance.isTaskSharingEnabled)
        #expect(!RoutinaUserPreferences().taskSharingEnabled)
    }

    @Test
    func defaultSettingsKeepTaskRelationshipVisualizerOff() {
        #expect(AppSettingsDefaults.boolValues[.appSettingTaskRelationshipVisualizerEnabled] == .some(false))
        #expect(!SettingsFeature.State().appearance.isTaskRelationshipVisualizerEnabled)
        #expect(!RoutinaUserPreferences().taskRelationshipVisualizerEnabled)
    }

    @Test
    func defaultSettingsKeepPlacesOff() {
        #expect(AppSettingsDefaults.boolValues[.appSettingPlacesEnabled] == .some(false))
        #expect(!SettingsFeature.State().appearance.isPlacesEnabled)
        #expect(!RoutinaUserPreferences().placesEnabled)
    }

    @Test
    func defaultSettingsKeepNotesAndAwayOff() {
        #expect(AppSettingsDefaults.boolValues[.appSettingNotesEnabled] == .some(false))
        #expect(AppSettingsDefaults.boolValues[.appSettingAwayEnabled] == .some(false))
        #expect(!SettingsFeature.State().appearance.isNotesEnabled)
        #expect(!SettingsFeature.State().appearance.isAwayEnabled)
        #expect(!RoutinaUserPreferences().notesEnabled)
        #expect(!RoutinaUserPreferences().awayEnabled)
    }

    @Test
    func defaultSettingsKeepFilterQuerySectionsOff() {
        #expect(AppSettingsDefaults.boolValues[.appSettingFilterQuerySectionsEnabled] == .some(false))
        #expect(!SettingsFeature.State().appearance.showsFilterQuerySections)
        #expect(!RoutinaUserPreferences().filterQuerySectionsEnabled)
    }

    @Test
    func defaultSettingsKeepMacStatsDashboardControlsOff() {
        #expect(AppSettingsDefaults.boolValues[.appSettingMacStatsDashboardControlsEnabled] == .some(false))
    }

    @Test
    func defaultSettingsKeepUnlimitedTaskUnlockOffWhenNotConfigured() {
        #expect(SettingsFeature.State().appearance.unlocksUnlimitedTasks == false)
        #expect(RoutinaUserPreferences().unlockUnlimitedTasks == false)
    }

    @Test
    func showTimelineTasksInDayPlannerToggled_persistsSelection() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setShowTimelineTasksInDayPlanner = { persistedValue.setValue($0) }
        }

        await store.send(.showTimelineTasksInDayPlannerToggled(false)) {
            $0.appearance.showsTimelineTasksInDayPlanner = false
        }

        #expect(persistedValue.value == false)
    }

    @Test
    func separateDailyRoutinesInTaskListToggled_persistsSelection() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setSeparateDailyRoutinesInTaskList = { persistedValue.setValue($0) }
        }

        await store.send(.separateDailyRoutinesInTaskListToggled(true)) {
            $0.appearance.separatesDailyRoutinesInTaskList = true
        }

        #expect(persistedValue.value == true)
    }

    @Test
    func showTomorrowInTaskListToggled_persistsSelection() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setShowTomorrowInTaskList = { persistedValue.setValue($0) }
        }

        await store.send(.showTomorrowInTaskListToggled(true)) {
            $0.appearance.showsTomorrowInTaskList = true
        }

        #expect(persistedValue.value == true)
    }

    @Test
    func showDoneCountInToolbarToggled_persistsSelection() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setShowDoneCountInToolbar = { persistedValue.setValue($0) }
        }

        await store.send(.showDoneCountInToolbarToggled(true)) {
            $0.appearance.showsDoneCountInToolbar = true
        }

        #expect(persistedValue.value == true)
    }

    @Test
    func defaultSettingsKeepDailyRoutinesMergedInTaskList() {
        #expect(!SettingsFeature.State().appearance.separatesDailyRoutinesInTaskList)
        #expect(!RoutinaUserPreferences().separateDailyRoutinesInTaskList)
    }

    @Test
    func defaultSettingsKeepTomorrowTaskListSectionOff() {
        #expect(AppSettingsDefaults.boolValues[.appSettingShowTomorrowInTaskList] == .some(false))
        #expect(!SettingsFeature.State().appearance.showsTomorrowInTaskList)
        #expect(!RoutinaUserPreferences().showTomorrowInTaskList)
    }

    @Test
    func defaultSettingsKeepDoneToolbarCountOff() {
        #expect(AppSettingsDefaults.boolValues[.appSettingMacShowDoneCountInToolbar] == .some(false))
        #expect(!SettingsFeature.State().appearance.showsDoneCountInToolbar)
        #expect(!RoutinaUserPreferences().macShowDoneCountInToolbar)
    }

    @Test
    func defaultSettingsKeepTagTaskKindSubsectionsOff() {
        #expect(AppSettingsDefaults.boolValues[.appSettingSeparateTodosAndRoutinesInTagTaskListSections] == .some(false))
        #expect(!RoutinaUserPreferences().separateTodosAndRoutinesInTagTaskListSections)
    }

    @Test
    func defaultSettingsKeepTagDeadlineStatusSectionsOff() {
        #expect(AppSettingsDefaults.boolValues[.appSettingSeparateDeadlineStatusInTagTaskListSections] == .some(false))
        #expect(!RoutinaUserPreferences().separateDeadlineStatusInTagTaskListSections)
    }

    @Test
    func automaticPlaceCheckInToggled_persistsSelection() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setAutomaticPlaceCheckInEnabled = { persistedValue.setValue($0) }
        }

        await store.send(.automaticPlaceCheckInToggled(false)) {
            $0.places.isAutomaticCheckInEnabled = false
        }

        #expect(persistedValue.value == false)
    }

    @Test
    func appLockToggled_onAuthenticatesThenPersistsSetting() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setAppLockEnabled = { persistedValue.setValue($0) }
            $0.deviceAuthenticationClient.status = {
                DeviceAuthenticationStatus(
                    isAvailable: true,
                    methodDescription: "Face ID or your device passcode",
                    unavailableReason: nil
                )
            }
            $0.deviceAuthenticationClient.authenticate = { reason in
                #expect(reason == "Enable app lock for Routina")
                return .success
            }
        }

        await store.send(.appLockToggled(true)) {
            $0.appearance.isAppLockToggleInProgress = true
            $0.appearance.appLockMethodDescription = "Face ID or your device passcode"
        }

        await store.receive(.appLockEnableFinished(.success)) {
            $0.appearance.isAppLockEnabled = true
            $0.appearance.isAppLockToggleInProgress = false
            $0.appearance.appLockMethodDescription = "Face ID or your device passcode"
            $0.appearance.appLockStatusMessage = "App lock is on."
        }

        #expect(persistedValue.value == true)
    }

    @Test
    func appLockToggled_onWithoutAvailableAuthenticationShowsError() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setAppLockEnabled = { persistedValue.setValue($0) }
            $0.deviceAuthenticationClient.status = {
                DeviceAuthenticationStatus(
                    isAvailable: false,
                    methodDescription: "Face ID or your device passcode",
                    unavailableReason: "Set up a device passcode before enabling app lock."
                )
            }
        }

        await store.send(.appLockToggled(true)) {
            $0.appearance.appLockMethodDescription = "Face ID or your device passcode"
            $0.appearance.appLockUnavailableReason = "Set up a device passcode before enabling app lock."
            $0.appearance.appLockStatusMessage = "Set up a device passcode before enabling app lock."
        }

        #expect(persistedValue.value == nil)
        #expect(store.state.appearance.isAppLockEnabled == false)
    }

    @Test
    func appLockToggled_offAuthenticatesThenPersistsSetting() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(
            initialState: SettingsFeature.State(
                appearance: .init(isAppLockEnabled: true)
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setAppLockEnabled = { persistedValue.setValue($0) }
            $0.deviceAuthenticationClient.status = {
                DeviceAuthenticationStatus(
                    isAvailable: true,
                    methodDescription: "Touch ID or your Mac password",
                    unavailableReason: nil
                )
            }
            $0.deviceAuthenticationClient.authenticate = { reason in
                #expect(reason == "Disable app lock for Routina")
                return .success
            }
        }

        await store.send(.appLockToggled(false)) {
            $0.appearance.isAppLockToggleInProgress = true
            $0.appearance.appLockMethodDescription = "Touch ID or your Mac password"
        }

        await store.receive(.appLockDisableFinished(.success)) {
            $0.appearance.isAppLockEnabled = false
            $0.appearance.isAppLockToggleInProgress = false
            $0.appearance.appLockMethodDescription = "Touch ID or your Mac password"
            $0.appearance.appLockStatusMessage = "App lock is off."
        }

        #expect(persistedValue.value == false)
    }

    @Test
    func appLockToggled_offAuthenticationFailureKeepsAppLockOn() async {
        let persistedValue = LockIsolated<Bool?>(nil)

        let store = TestStore(
            initialState: SettingsFeature.State(
                appearance: .init(isAppLockEnabled: true)
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setAppLockEnabled = { persistedValue.setValue($0) }
            $0.deviceAuthenticationClient.status = {
                DeviceAuthenticationStatus(
                    isAvailable: true,
                    methodDescription: "Touch ID or your Mac password",
                    unavailableReason: nil
                )
            }
            $0.deviceAuthenticationClient.authenticate = { reason in
                #expect(reason == "Disable app lock for Routina")
                return .failure("Authentication was canceled.")
            }
        }

        await store.send(.appLockToggled(false)) {
            $0.appearance.isAppLockToggleInProgress = true
            $0.appearance.appLockMethodDescription = "Touch ID or your Mac password"
        }

        await store.receive(.appLockDisableFinished(.failure("Authentication was canceled."))) {
            $0.appearance.isAppLockEnabled = true
            $0.appearance.isAppLockToggleInProgress = false
            $0.appearance.appLockMethodDescription = "Touch ID or your Mac password"
            $0.appearance.appLockStatusMessage = "Authentication was canceled."
        }

        #expect(persistedValue.value == nil)
    }

    @Test
    func appLockToggled_offWithoutAvailableAuthenticationKeepsAppLockOn() async {
        let persistedValue = LockIsolated<Bool?>(nil)
        let authenticateCallCount = LockIsolated(0)

        let store = TestStore(
            initialState: SettingsFeature.State(
                appearance: .init(isAppLockEnabled: true)
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setAppLockEnabled = { persistedValue.setValue($0) }
            $0.deviceAuthenticationClient.status = {
                DeviceAuthenticationStatus(
                    isAvailable: false,
                    methodDescription: "Touch ID or your Mac password",
                    unavailableReason: "Set up Touch ID or use your Mac password to enable app lock."
                )
            }
            $0.deviceAuthenticationClient.authenticate = { _ in
                authenticateCallCount.withValue { $0 += 1 }
                return .success
            }
        }

        await store.send(.appLockToggled(false)) {
            $0.appearance.appLockMethodDescription = "Touch ID or your Mac password"
            $0.appearance.appLockUnavailableReason = "Set up Touch ID or use your Mac password to enable app lock."
            $0.appearance.appLockStatusMessage = "Device authentication is unavailable, so App Lock stays on."
        }

        #expect(store.state.appearance.isAppLockEnabled)
        #expect(persistedValue.value == nil)
        #expect(authenticateCallCount.value == 0)
    }

    @Test
    func resetAllSettings_requiresAppLockBeforeAuthentication() async {
        let resetCallCount = LockIsolated(0)
        let authenticateCallCount = LockIsolated(0)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.appLockEnabled = { false }
            $0.appSettingsClient.resetAllSettingsToDefaults = {
                resetCallCount.withValue { $0 += 1 }
            }
            $0.deviceAuthenticationClient.status = {
                DeviceAuthenticationStatus(
                    isAvailable: true,
                    methodDescription: "Face ID or your device passcode",
                    unavailableReason: nil
                )
            }
            $0.deviceAuthenticationClient.authenticate = { _ in
                authenticateCallCount.withValue { $0 += 1 }
                return .success
            }
        }

        await store.send(.resetAllSettingsToDefaultsTapped) {
            $0.appearance.appLockMethodDescription = "Face ID or your device passcode"
            $0.appearance.settingsResetStatusMessage = "Turn on App Lock before resetting settings."
        }

        #expect(resetCallCount.value == 0)
        #expect(authenticateCallCount.value == 0)
    }

    @Test
    func resetAllSettings_authenticatesThenRestoresDefaultSettingsState() async {
        let resetCallCount = LockIsolated(0)
        let now = makeDate("2026-06-25T09:00:00Z")
        let defaultReminderTime = NotificationPreferences.defaultReminderDate(on: now)

        let store = TestStore(
            initialState: SettingsFeature.State(
                notifications: .init(notificationsEnabled: true),
                appearance: .init(
                    appColorScheme: .dark,
                    tagCounterDisplayMode: .doneOnly,
                    taskRowVisibility: HomeTaskRowVisibility(hiddenFields: [.statusBadge]),
                    timelineRowVisibility: HomeTimelineRowVisibility(hiddenFields: [.subtitle]),
                    isAppLockEnabled: true,
                    isGitFeaturesEnabled: true,
                    selectedAppIcon: .teal,
                    hasTemporaryViewStateToReset: true
                ),
                places: .init(isAutomaticCheckInEnabled: false)
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.date.now = now
            $0.notificationClient = .noop
            $0.appSettingsClient.appLockEnabled = { true }
            $0.appSettingsClient.resetAllSettingsToDefaults = {
                resetCallCount.withValue { $0 += 1 }
            }
            $0.deviceAuthenticationClient.status = {
                DeviceAuthenticationStatus(
                    isAvailable: true,
                    methodDescription: "Touch ID or your Mac password",
                    unavailableReason: nil
                )
            }
            $0.deviceAuthenticationClient.authenticate = { reason in
                #expect(reason == "Reset Routina settings to defaults")
                return .success
            }
        }

        await store.send(.resetAllSettingsToDefaultsTapped) {
            $0.appearance.isSettingsResetAuthenticationInProgress = true
            $0.appearance.appLockMethodDescription = "Touch ID or your Mac password"
        }

        await store.receive(.settingsDefaultsResetAuthenticationFinished(.success)) {
            $0.notifications = SettingsNotificationsState(notificationReminderTime: defaultReminderTime)
            $0.appearance = SettingsAppearanceState(
                appLockMethodDescription: "Touch ID or your Mac password",
                settingsResetStatusMessage: "Settings were reset to defaults."
            )
            $0.places.isAutomaticCheckInEnabled = true
        }

        #expect(resetCallCount.value == 1)
    }

    @Test
    func resetCloudDataConfirmed_authenticatesWithAppLockBeforeDeleting() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-06-06T12:00:00Z")
        let authenticateReason = LockIsolated<String?>(nil)

        let store = TestStore(
            initialState: SettingsFeature.State(
                appearance: .init(isAppLockEnabled: true),
                cloud: .init(
                    cloudSyncAvailable: true,
                    isCloudDataResetConfirmationPresented: true
                ),
                dataTransfer: .init(lastSuccessfulBackupDate: now.addingTimeInterval(-60 * 60))
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now)
            $0.modelContext = { context }
            $0.appSettingsClient.appLockEnabled = { true }
            $0.deviceAuthenticationClient.authenticate = { reason in
                authenticateReason.setValue(reason)
                return .failure("Authentication was canceled.")
            }
        }

        await store.send(.resetCloudDataConfirmed) {
            $0.cloud.isCloudDataResetAuthenticationInProgress = true
            $0.cloud.cloudStatusMessage = "Confirming App Lock..."
        }

        await store.receive(.cloudDataResetAuthenticationFinished(.failure("Authentication was canceled."))) {
            $0.cloud.isCloudDataResetAuthenticationInProgress = false
            $0.cloud.cloudStatusMessage = "Authentication was canceled."
        }

        #expect(authenticateReason.value == "Delete Routina iCloud data")
    }

    @Test
    func resetCloudDataConfirmed_requiresRecentBackupBeforeAuthentication() async {
        let context = makeInMemoryContext()
        let now = makeDate("2026-06-06T12:00:00Z")
        let authenticateCallCount = LockIsolated(0)

        let store = TestStore(
            initialState: SettingsFeature.State(
                appearance: .init(isAppLockEnabled: true),
                cloud: .init(
                    cloudSyncAvailable: true,
                    isCloudDataResetConfirmationPresented: true
                )
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now)
            $0.modelContext = { context }
            $0.appSettingsClient.appLockEnabled = { true }
            $0.deviceAuthenticationClient.authenticate = { _ in
                authenticateCallCount.withValue { $0 += 1 }
                return .success
            }
        }

        await store.send(.resetCloudDataConfirmed) {
            $0.cloud.cloudStatusMessage = "Save a backup within the last 24 hours before deleting iCloud data."
        }

        #expect(authenticateCallCount.value == 0)
    }

    @Test
    func savePlaceTapped_persistsSelectedPlace() async throws {
        let context = makeInMemoryContext()
        let store = TestStore(
            initialState: SettingsFeature.State(
                places: .init(
                    placeDraftName: "Home",
                    placeDraftKind: "Supermarket",
                    placeDraftCoordinate: LocationCoordinate(latitude: 52.52, longitude: 13.405),
                    placeDraftRadiusMeters: 180
                )
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }
        var loadedPlaces: [RoutinePlaceSummary] = []
        var cloudEstimate = CloudUsageEstimate.zero

        await store.send(.savePlaceTapped) {
            $0.places.isPlaceOperationInProgress = true
            $0.places.placeStatusMessage = ""
        }
        await store.receive { action in
            guard case let .placesLoaded(places) = action else { return false }
            loadedPlaces = places
            #expect(places.count == 1)
            #expect(places.first?.name == "Home")
            #expect(places.first?.kind == "Supermarket")
            #expect(places.first?.radiusMeters == 180)
            return true
        } assert: {
            $0.places.savedPlaces = loadedPlaces
        }
        await store.receive { action in
            guard case let .cloudUsageEstimateLoaded(estimate) = action else { return false }
            cloudEstimate = estimate
            #expect(estimate.placeCount == 1)
            #expect(estimate.taskCount == 0)
            return true
        } assert: {
            $0.cloud.cloudUsageEstimate = cloudEstimate
        }
        await store.receive(.placeOperationFinished(success: true, message: "Saved Home.")) {
            $0.places.isPlaceOperationInProgress = false
            $0.places.placeDraftName = ""
            $0.places.placeDraftKind = ""
            $0.places.placeDraftCoordinate = nil
            $0.places.placeStatusMessage = "Saved Home."
        }

        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        #expect(places.count == 1)
        #expect(places.first?.displayName == "Home")
        #expect(places.first?.displayKind == "Supermarket")
        #expect(places.first?.radiusMeters == 180)
    }

    @Test
    func savePlaceTapped_withoutSelectedLocationShowsValidationMessage() async {
        let context = makeInMemoryContext()
        let store = TestStore(
            initialState: SettingsFeature.State(
                places: .init(placeDraftName: "Home")
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.savePlaceTapped) {
            $0.places.placeStatusMessage = "Choose a location on the map first."
        }
    }

    @Test
    func duplicatePlaceDraft_disablesSaveAndShowsValidationMessage() {
        let state = SettingsFeature.State(
            places: .init(
                savedPlaces: [
                    RoutinePlaceSummary(
                        id: UUID(),
                        name: "Home",
                        radiusMeters: 150,
                        linkedRoutineCount: 1
                    )
                ],
                placeDraftName: " home "
            )
        )

        #expect(state.places.hasDuplicateDraftName)
        #expect(state.places.isSaveDisabled)
        #expect(state.places.saveValidationMessage == "A place with this name already exists.")
    }

    @Test
    func savePlaceTapped_duplicateNameShowsValidationMessageAndDoesNotPersist() async throws {
        let context = makeInMemoryContext()
        _ = makePlace(in: context, name: "Home")

        let store = TestStore(
            initialState: SettingsFeature.State(
                places: .init(
                    savedPlaces: [
                        RoutinePlaceSummary(
                            id: UUID(),
                            name: "Home",
                            radiusMeters: 150,
                            linkedRoutineCount: 0
                        )
                    ],
                    placeDraftName: " home ",
                    placeDraftCoordinate: LocationCoordinate(latitude: 52.52, longitude: 13.405),
                    placeDraftRadiusMeters: 180
                )
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.savePlaceTapped) {
            $0.places.isPlaceOperationInProgress = true
            $0.places.placeStatusMessage = ""
        }

        await store.receive(
            .placeOperationFinished(
                success: false,
                message: "A place with this name already exists."
            )
        ) {
            $0.places.isPlaceOperationInProgress = false
            $0.places.placeStatusMessage = "A place with this name already exists."
        }

        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        #expect(places.count == 1)
        #expect(places.first?.displayName == "Home")
    }

    @Test
    func updatePlace_updatesSavedPlaceAndActiveSessionSnapshot() throws {
        let context = makeInMemoryContext()
        let place = makePlace(in: context, name: "Home", latitude: 48.10, longitude: 11.50, radiusMeters: 75)
        let session = try PlaceCheckInSupport.checkIn(at: place, in: context)
        let coordinate = LocationCoordinate(latitude: 48.12, longitude: 11.52)

        let result = try SettingsPlacePersistence.update(
            SettingsPlaceUpdateRequest(
                placeID: place.id,
                cleanedName: "Studio",
                coordinate: coordinate,
                radiusMeters: 225
            ),
            in: context
        )

        #expect(place.displayName == "Studio")
        #expect(place.latitude == coordinate.latitude)
        #expect(place.longitude == coordinate.longitude)
        #expect(place.radiusMeters == 225)
        #expect(session.displayPlaceName == "Studio")
        #expect(session.latitude == coordinate.latitude)
        #expect(session.longitude == coordinate.longitude)
        #expect(session.placeRadiusMeters == 225)
        #expect(result.placeSummaries.map(\.name) == ["Studio"])
    }

    @Test
    func updatePlace_rejectsDuplicateNameExceptCurrentPlace() throws {
        let context = makeInMemoryContext()
        let home = makePlace(in: context, name: "Home")
        _ = makePlace(in: context, name: "Office")

        _ = try SettingsPlacePersistence.update(
            SettingsPlaceUpdateRequest(
                placeID: home.id,
                cleanedName: "Home",
                coordinate: LocationCoordinate(latitude: 52.52, longitude: 13.405),
                radiusMeters: 150
            ),
            in: context
        )

        do {
            _ = try SettingsPlacePersistence.update(
                SettingsPlaceUpdateRequest(
                    placeID: home.id,
                    cleanedName: "office",
                    coordinate: LocationCoordinate(latitude: 52.52, longitude: 13.405),
                    radiusMeters: 150
                ),
                in: context
            )
            Issue.record("Expected duplicateName error")
        } catch let error as SettingsPlacePersistenceError {
            #expect(error == .duplicateName)
        }
    }

    @Test
    func deletePlaceTapped_clearsRoutineLinks() async throws {
        let context = makeInMemoryContext()
        let place = makePlace(in: context, name: "Home")
        let task = makeTask(in: context, name: "Laundry", interval: 7, lastDone: nil, emoji: "🧺", placeID: place.id)
        try context.save()

        let store = TestStore(
            initialState: SettingsFeature.State(
                places: .init(
                    savedPlaces: [
                        RoutinePlaceSummary(id: place.id, name: "Home", radiusMeters: place.radiusMeters, linkedRoutineCount: 1)
                    ]
                )
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }
        var cloudEstimate = CloudUsageEstimate.zero

        await store.send(.deletePlaceTapped(place.id)) {
            $0.places.isDeletePlaceConfirmationPresented = true
            $0.places.placePendingDeletion = RoutinePlaceSummary(
                id: place.id,
                name: "Home",
                radiusMeters: place.radiusMeters,
                linkedRoutineCount: 1
            )
        }
        await store.send(.deletePlaceConfirmed) {
            $0.places.isDeletePlaceConfirmationPresented = false
            $0.places.placePendingDeletion = nil
            $0.places.isPlaceOperationInProgress = true
            $0.places.placeStatusMessage = ""
        }
        await store.receive(.placesLoaded([])) {
            $0.places.savedPlaces = []
        }
        await store.receive { action in
            guard case let .cloudUsageEstimateLoaded(estimate) = action else { return false }
            cloudEstimate = estimate
            #expect(estimate.placeCount == 0)
            #expect(estimate.taskCount == 1)
            return true
        } assert: {
            $0.cloud.cloudUsageEstimate = cloudEstimate
        }
        await store.receive(.placeOperationFinished(success: true, message: "Place deleted.")) {
            $0.places.isPlaceOperationInProgress = false
            $0.places.placeStatusMessage = "Place deleted."
        }

        let remainingPlaces = try context.fetch(FetchDescriptor<RoutinePlace>())
        let persistedTask = try #require(context.fetch(FetchDescriptor<RoutineTask>()).first(where: { $0.id == task.id }))
        #expect(remainingPlaces.isEmpty)
        #expect(persistedTask.placeID == nil)
    }

    @Test
    func deletePlaceConfirmationCancelled_clearsPendingDeletion() async {
        let context = makeInMemoryContext()
        let placeID = UUID()
        let summary = RoutinePlaceSummary(id: placeID, name: "Home", radiusMeters: 150, linkedRoutineCount: 2)

        let store = TestStore(
            initialState: SettingsFeature.State(
                places: .init(savedPlaces: [summary])
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.deletePlaceTapped(placeID)) {
            $0.places.isDeletePlaceConfirmationPresented = true
            $0.places.placePendingDeletion = summary
        }

        await store.send(.setDeletePlaceConfirmation(false)) {
            $0.places.isDeletePlaceConfirmationPresented = false
            $0.places.placePendingDeletion = nil
        }
    }

    @Test
    func placesLoaded_refreshesPendingDeletionSummary() async {
        let context = makeInMemoryContext()
        let placeID = UUID()
        let initialSummary = RoutinePlaceSummary(id: placeID, name: "Home", radiusMeters: 150, linkedRoutineCount: 1)
        let updatedSummary = RoutinePlaceSummary(id: placeID, name: "Home", radiusMeters: 200, linkedRoutineCount: 3)

        let store = TestStore(
            initialState: SettingsFeature.State(
                places: .init(
                    savedPlaces: [initialSummary],
                    placePendingDeletion: initialSummary,
                    isDeletePlaceConfirmationPresented: true
                )
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.placesLoaded([updatedSummary])) {
            $0.places.savedPlaces = [updatedSummary]
            $0.places.placePendingDeletion = updatedSummary
        }
    }

    @Test
    func renameTagTapped_populatesDraftAndPresentsSheet() async {
        let context = makeInMemoryContext()
        let summary = RoutineTagSummary(name: "Fitness", linkedRoutineCount: 2)

        let store = TestStore(
            initialState: SettingsFeature.State(
                tags: .init(savedTags: [summary])
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.renameTagTapped("Fitness")) {
            $0.tags.tagPendingRename = summary
            $0.tags.tagRenameDraft = "Fitness"
            $0.tags.isTagRenameSheetPresented = true
        }
    }

    @Test
    func saveTagRenameTapped_updatesAllMatchingRoutines() async throws {
        let context = makeInMemoryContext()
        let notesKey = UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue
        let previousNotesValue = SharedDefaults.app.object(forKey: notesKey)
        defer {
            if let previousNotesValue {
                SharedDefaults.app.set(previousNotesValue, forKey: notesKey)
            } else {
                SharedDefaults.app.removeObject(forKey: notesKey)
            }
        }
        SharedDefaults.app[.appSettingNotesEnabled] = true
        let fitness = makeTask(in: context, name: "Workout", interval: 1, lastDone: nil, emoji: "💪", tags: ["Fitness", "Morning"])
        let stretch = makeTask(in: context, name: "Stretch", interval: 2, lastDone: nil, emoji: "🧘", tags: ["fitness"])
        _ = makeTask(in: context, name: "Read", interval: 3, lastDone: nil, emoji: "📚", tags: ["Morning"])
        let goal = RoutineGoal(title: "Get stronger", tags: ["Fitness"])
        context.insert(goal)
        let note = RoutineNote(title: "Trainer notes", body: "Ask about recovery.", tags: ["Fitness"])
        context.insert(note)
        try context.save()

        let fitnessSummary = RoutineTagSummary(name: "Fitness", linkedRoutineCount: 2, linkedGoalCount: 1, linkedNoteCount: 1)
        let morningSummary = RoutineTagSummary(name: "Morning", linkedRoutineCount: 2)

        let store = TestStore(
            initialState: SettingsFeature.State(
                tags: .init(
                    savedTags: [fitnessSummary, morningSummary],
                    tagPendingRename: fitnessSummary,
                    tagRenameDraft: "Health",
                    isTagRenameSheetPresented: true
                )
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }
        var loadedTags: [RoutineTagSummary] = []
        var cloudEstimate = CloudUsageEstimate.zero

        await store.send(.saveTagRenameTapped) {
            $0.tags.tagPendingRename = nil
            $0.tags.tagRenameDraft = ""
            $0.tags.isTagOperationInProgress = true
            $0.tags.isTagRenameSheetPresented = false
            $0.tags.tagStatusMessage = ""
            $0.tags.relatedTagDrafts = [
                "fitness": "",
                "morning": ""
            ]
        }
        await store.receive { action in
            guard case let .tagsLoaded(tags) = action else { return false }
            loadedTags = tags
            #expect(tags.map(\.name) == ["Health", "Morning"])
            #expect(tags.map(\.linkedRoutineCount) == [2, 2])
            #expect(tags.map(\.linkedGoalCount) == [1, 0])
            #expect(tags.map(\.linkedNoteCount) == [1, 0])
            return true
        } assert: {
            $0.tags.savedTags = loadedTags
            $0.tags.relatedTagDrafts = [
                "health": "",
                "morning": ""
            ]
        }
        await store.receive { action in
            guard case let .cloudUsageEstimateLoaded(estimate) = action else { return false }
            cloudEstimate = estimate
            #expect(estimate.taskCount == 3)
            #expect(estimate.noteCount == 1)
            return true
        } assert: {
            $0.cloud.cloudUsageEstimate = cloudEstimate
        }
        await store.receive(.tagOperationFinished(success: true, message: "Updated tag to Health in 2 routines and 1 goal and 1 note.")) {
            $0.tags.isTagOperationInProgress = false
            $0.tags.tagStatusMessage = "Updated tag to Health in 2 routines and 1 goal and 1 note."
        }

        let persistedTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let persistedFitness = try #require(persistedTasks.first(where: { $0.id == fitness.id }))
        let persistedStretch = try #require(persistedTasks.first(where: { $0.id == stretch.id }))
        let persistedGoal = try #require(try context.fetch(FetchDescriptor<RoutineGoal>()).first { $0.id == goal.id })
        let persistedNote = try #require(try context.fetch(FetchDescriptor<RoutineNote>()).first { $0.id == note.id })
        #expect(persistedFitness.tags == ["Health", "Morning"])
        #expect(persistedStretch.tags == ["Health"])
        #expect(persistedGoal.tags == ["Health"])
        #expect(persistedNote.tags == ["Health"])
    }

    @Test
    func saveTagRenameTapped_withoutNameShowsValidationMessage() async {
        let context = makeInMemoryContext()
        let summary = RoutineTagSummary(name: "Fitness", linkedRoutineCount: 1)

        let store = TestStore(
            initialState: SettingsFeature.State(
                tags: .init(
                    tagPendingRename: summary,
                    tagRenameDraft: "   ",
                    isTagRenameSheetPresented: true
                )
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.saveTagRenameTapped) {
            $0.tags.tagStatusMessage = "Enter a tag name first."
        }
    }

    @Test
    func deleteTagConfirmed_removesTagFromAllMatchingRoutines() async throws {
        let context = makeInMemoryContext()
        let notesKey = UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue
        let previousNotesValue = SharedDefaults.app.object(forKey: notesKey)
        defer {
            if let previousNotesValue {
                SharedDefaults.app.set(previousNotesValue, forKey: notesKey)
            } else {
                SharedDefaults.app.removeObject(forKey: notesKey)
            }
        }
        SharedDefaults.app[.appSettingNotesEnabled] = true
        _ = makeTask(in: context, name: "Workout", interval: 1, lastDone: nil, emoji: "💪", tags: ["Health", "Morning"])
        let read = makeTask(in: context, name: "Read", interval: 3, lastDone: nil, emoji: "📚", tags: ["Morning"])
        let plan = makeTask(in: context, name: "Plan", interval: 4, lastDone: nil, emoji: "📝", tags: ["Evening", "Morning"])
        let goal = RoutineGoal(title: "Wake earlier", tags: ["Morning"])
        context.insert(goal)
        let note = RoutineNote(title: "Morning pages", body: "Keep ideas here.", tags: ["Morning"])
        context.insert(note)
        try context.save()

        let morningSummary = RoutineTagSummary(name: "Morning", linkedRoutineCount: 3, linkedGoalCount: 1, linkedNoteCount: 1)
        let healthSummary = RoutineTagSummary(name: "Health", linkedRoutineCount: 1)
        let eveningSummary = RoutineTagSummary(name: "Evening", linkedRoutineCount: 1)

        let store = TestStore(
            initialState: SettingsFeature.State(
                tags: .init(
                    savedTags: [eveningSummary, healthSummary, morningSummary],
                    tagPendingDeletion: morningSummary,
                    isDeleteTagConfirmationPresented: true
                )
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }
        var loadedTags: [RoutineTagSummary] = []
        var cloudEstimate = CloudUsageEstimate.zero

        await store.send(.deleteTagConfirmed) {
            $0.tags.tagPendingDeletion = nil
            $0.tags.isDeleteTagConfirmationPresented = false
            $0.tags.isTagOperationInProgress = true
            $0.tags.tagStatusMessage = ""
            $0.tags.relatedTagDrafts = [
                "evening": "",
                "health": "",
                "morning": ""
            ]
        }
        await store.receive { action in
            guard case let .tagsLoaded(tags) = action else { return false }
            loadedTags = tags
            #expect(tags.map(\.name) == ["Evening", "Health"])
            #expect(tags.map(\.linkedRoutineCount) == [1, 1])
            #expect(tags.map(\.linkedGoalCount) == [0, 0])
            #expect(tags.map(\.linkedNoteCount) == [0, 0])
            return true
        } assert: {
            $0.tags.savedTags = loadedTags
            $0.tags.relatedTagDrafts = [
                "evening": "",
                "health": ""
            ]
        }
        await store.receive { action in
            guard case let .cloudUsageEstimateLoaded(estimate) = action else { return false }
            cloudEstimate = estimate
            #expect(estimate.taskCount == 3)
            #expect(estimate.noteCount == 1)
            return true
        } assert: {
            $0.cloud.cloudUsageEstimate = cloudEstimate
        }
        await store.receive(.tagOperationFinished(success: true, message: "Deleted Morning from 3 routines and 1 goal and 1 note.")) {
            $0.tags.isTagOperationInProgress = false
            $0.tags.tagStatusMessage = "Deleted Morning from 3 routines and 1 goal and 1 note."
        }

        let persistedTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let persistedRead = try #require(persistedTasks.first(where: { $0.id == read.id }))
        let persistedPlan = try #require(persistedTasks.first(where: { $0.id == plan.id }))
        #expect(persistedRead.tags.isEmpty)
        #expect(persistedPlan.tags == ["Evening"])
        #expect(persistedTasks.allSatisfy { !RoutineTag.contains("Morning", in: $0.tags) })
        #expect(try context.fetch(FetchDescriptor<RoutineGoal>()).first { $0.id == goal.id }?.tags.isEmpty == true)
        #expect(try context.fetch(FetchDescriptor<RoutineNote>()).first { $0.id == note.id }?.tags.isEmpty == true)
    }

    @Test
    func addRelatedTagDraftSubmitted_addsNewRelatedTagsAndPersistsRules() async {
        let persistedRules = LockIsolated<[RoutineRelatedTagRule]>([])
        let cleaningSummary = RoutineTagSummary(name: "Cleaning", linkedRoutineCount: 1)
        let homeSummary = RoutineTagSummary(name: "Home", linkedRoutineCount: 1)
        let organizingSummary = RoutineTagSummary(name: "Organizing", linkedRoutineCount: 1)

        let store = TestStore(
            initialState: SettingsFeature.State(
                tags: .init(
                    savedTags: [cleaningSummary, homeSummary, organizingSummary],
                    relatedTagRules: [
                        RoutineRelatedTagRule(tag: "Cleaning", relatedTags: ["Home"])
                    ],
                    relatedTagDrafts: [
                        "cleaning": "Home",
                        "home": "",
                        "organizing": ""
                    ]
                )
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setRelatedTagRules = { persistedRules.setValue($0) }
        }

        await store.send(.addRelatedTagDraftSubmitted(
            tagName: "Cleaning",
            draft: "Organizing, home, Cleaning"
        )) {
            $0.tags.relatedTagRules = [
                RoutineRelatedTagRule(tag: "Cleaning", relatedTags: ["Home", "Organizing"])
            ]
            $0.tags.relatedTagDrafts = [
                "cleaning": "Home, Organizing",
                "home": "",
                "organizing": ""
            ]
            $0.tags.tagStatusMessage = "Added #Organizing to #Cleaning."
        }

        #expect(persistedRules.value == [
            RoutineRelatedTagRule(tag: "Cleaning", relatedTags: ["Home", "Organizing"])
        ])
    }

    @Test
    func removeRelatedTagTapped_removesChipAndPersistsRules() async {
        let persistedRules = LockIsolated<[RoutineRelatedTagRule]>([])
        let cleaningSummary = RoutineTagSummary(name: "Cleaning", linkedRoutineCount: 1)
        let homeSummary = RoutineTagSummary(name: "Home", linkedRoutineCount: 1)
        let organizingSummary = RoutineTagSummary(name: "Organizing", linkedRoutineCount: 1)

        let store = TestStore(
            initialState: SettingsFeature.State(
                tags: .init(
                    savedTags: [cleaningSummary, homeSummary, organizingSummary],
                    relatedTagRules: [
                        RoutineRelatedTagRule(tag: "Cleaning", relatedTags: ["Home", "Organizing"])
                    ],
                    relatedTagDrafts: [
                        "cleaning": "Home, Organizing",
                        "home": "",
                        "organizing": ""
                    ]
                )
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.appSettingsClient.setRelatedTagRules = { persistedRules.setValue($0) }
        }

        await store.send(.removeRelatedTagTapped(
            tagName: "Cleaning",
            relatedTag: "Home"
        )) {
            $0.tags.relatedTagRules = [
                RoutineRelatedTagRule(tag: "Cleaning", relatedTags: ["Organizing"])
            ]
            $0.tags.relatedTagDrafts = [
                "cleaning": "Organizing",
                "home": "",
                "organizing": ""
            ]
            $0.tags.tagStatusMessage = "Removed #Home from #Cleaning."
        }

        #expect(persistedRules.value == [
            RoutineRelatedTagRule(tag: "Cleaning", relatedTags: ["Organizing"])
        ])
    }

    @Test
    func resetTemporaryViewStateTapped_clearsSavedTemporaryViewPreferences() async {
        let context = makeInMemoryContext()
        let resetCallCount = LockIsolated(0)

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient.resetTemporaryViewState = { resetCallCount.withValue { $0 += 1 } }
        }

        await store.send(.resetTemporaryViewStateTapped) {
            $0.appearance.temporaryViewStateStatusMessage = "Saved filters and temporary selections were reset."
        }

        #expect(resetCallCount.value == 1)
    }

    @Test
    func hiddenPlannerActivityCountsAsTemporaryViewStateToReset() {
        var appSettingsClient = AppSettingsClient.noop
        appSettingsClient.hiddenDayPlanTimelineActivityIDs = {
            "timeline-assumed-00000000-0000-0000-0000-000000000001-2026-06-22"
        }

        #expect(SettingsExecutionSupport.hasTemporaryViewStateToReset(appSettingsClient: appSettingsClient))
    }

    @Test
    func exportRoutineDataTapped_cancelledSelectionFinishesGracefully() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.routineDataTransferClient.selectExportURL = { _ in nil }
        }

        await store.send(.exportRoutineDataTapped) {
            $0.dataTransfer.isDataTransferInProgress = true
            $0.dataTransfer.activeOperation = .export
            $0.dataTransfer.dataTransferStatusMessage = "Saving routine data..."
        }

        await store.receive(.routineDataTransferFinished(success: false, message: "Save canceled.")) {
            $0.dataTransfer.isDataTransferInProgress = false
            $0.dataTransfer.activeOperation = nil
            $0.dataTransfer.dataTransferStatusMessage = "Save canceled."
        }
    }

    @Test
    func exportRoutineDataDestinationSelected_writesSelectedBackupPackage() async throws {
        let context = makeInMemoryContext()
        let now = makeDate("2026-06-06T12:00:00Z")
        let persistedBackupDate = LockIsolated<Date?>(nil)
        let task = RoutineTask(
            name: "Backup me",
            link: "example.com/primary",
            links: ["example.com/primary", "https://example.com/second"],
            tags: ["Safe"]
        )
        context.insert(task)
        try context.save()

        let packageURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            setTestDateDependencies(&$0, now: now)
            $0.modelContext = { context }
            $0.appSettingsClient.setLastRoutineDataBackupDate = { date in
                persistedBackupDate.setValue(date)
            }
        }

        await store.send(.exportRoutineDataDestinationSelected(packageURL)) {
            $0.dataTransfer.isDataTransferInProgress = true
            $0.dataTransfer.activeOperation = .export
            $0.dataTransfer.dataTransferStatusMessage = "Saving routine data..."
        }

        await store.receive(.routineDataTransferFinished(success: true, message: "Saved to \(packageURL.lastPathComponent).")) {
            $0.dataTransfer.isDataTransferInProgress = false
            $0.dataTransfer.activeOperation = nil
            $0.dataTransfer.dataTransferStatusMessage = "Saved to \(packageURL.lastPathComponent)."
            $0.dataTransfer.lastSuccessfulBackupDate = now
        }
        #expect(persistedBackupDate.value == now)

        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: packageURL.path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue)

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            withBackupPackageAt: packageURL,
            in: restoreContext
        )
        let restoredTask = try #require(restoreContext.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(summary.tasks == 1)
        #expect(restoredTask.id == task.id)
        #expect(restoredTask.link == "https://example.com/primary")
        #expect(restoredTask.links == ["https://example.com/primary", "https://example.com/second"])
        #expect(restoredTask.tags == ["Safe"])
    }

    @Test
    func importRoutineDataTapped_cancelledSelectionFinishesGracefully() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.routineDataTransferClient.selectImportURL = { nil }
        }

        await store.send(.importRoutineDataTapped) {
            $0.dataTransfer.isDataTransferInProgress = true
            $0.dataTransfer.activeOperation = .import
            $0.dataTransfer.dataTransferStatusMessage = "Loading routine data..."
        }

        await store.receive(.routineDataTransferFinished(success: false, message: "Load canceled.")) {
            $0.dataTransfer.isDataTransferInProgress = false
            $0.dataTransfer.activeOperation = nil
            $0.dataTransfer.dataTransferStatusMessage = "Load canceled."
        }
    }

    @Test
    func importRoutineDataSourceSelected_loadsSelectedBackupPackage() async throws {
        let notesKey = UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue
        let awayKey = UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue
        let previousNotesValue = SharedDefaults.app.object(forKey: notesKey)
        let previousAwayValue = SharedDefaults.app.object(forKey: awayKey)
        defer {
            if let previousNotesValue {
                SharedDefaults.app.set(previousNotesValue, forKey: notesKey)
            } else {
                SharedDefaults.app.removeObject(forKey: notesKey)
            }
            if let previousAwayValue {
                SharedDefaults.app.set(previousAwayValue, forKey: awayKey)
            } else {
                SharedDefaults.app.removeObject(forKey: awayKey)
            }
        }
        SharedDefaults.app[.appSettingNotesEnabled] = true
        SharedDefaults.app[.appSettingAwayEnabled] = true

        let exportContext = makeInMemoryContext()
        let task = RoutineTask(name: "Restore me", tags: ["Safe"])
        exportContext.insert(task)
        try exportContext.save()

        let packageURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        try SettingsRoutineDataPersistence.writeBackupPackage(
            to: packageURL,
            from: exportContext
        )

        let importContext = makeInMemoryContext()
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { importContext }
            $0.notificationClient.cancelAll = {}
            $0.notificationClient.systemNotificationsAuthorized = { false }
        }

        await store.send(.importRoutineDataSourceSelected(packageURL)) {
            $0.dataTransfer.isDataTransferInProgress = true
            $0.dataTransfer.activeOperation = .import
            $0.dataTransfer.dataTransferStatusMessage = "Loading routine data..."
        }

        var cloudEstimate = CloudUsageEstimate.zero
        await store.receive { action in
            guard case let .cloudUsageEstimateLoaded(estimate) = action else { return false }
            cloudEstimate = estimate
            #expect(estimate.taskCount == 1)
            return true
        } assert: {
            $0.cloud.cloudUsageEstimate = cloudEstimate
        }

        let successMessage = "Loaded 1 routines, 0 goals, 0 places, 0 logs, 0 sleep sessions, 0 away sessions, 0 place check-ins, 0 emotions, 0 notes, 0 events, and 0 attachments."
        await store.receive(.routineDataTransferFinished(success: true, message: successMessage)) {
            $0.dataTransfer.isDataTransferInProgress = false
            $0.dataTransfer.activeOperation = nil
            $0.dataTransfer.dataTransferStatusMessage = successMessage
        }

        let restoredTask = try #require(importContext.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(restoredTask.id == task.id)
        #expect(restoredTask.tags == ["Safe"])
    }
}

@MainActor
private func count<T: PersistentModel>(_ model: T.Type, in context: ModelContext) throws -> Int {
    try context.fetch(FetchDescriptor<T>()).count
}
