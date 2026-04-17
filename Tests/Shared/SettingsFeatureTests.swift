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
    func cloudUsageEstimate_countsRecordsAndImagePayload() throws {
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
        _ = makeLog(in: context, task: task, timestamp: makeDate("2026-03-21T08:30:00Z"))
        try context.save()

        let estimate = try CloudUsageEstimate.estimate(in: context)

        #expect(estimate.taskCount == 1)
        #expect(estimate.logCount == 1)
        #expect(estimate.placeCount == 1)
        #expect(estimate.imageCount == 1)
        #expect(estimate.imagePayloadBytes == 1_024)
        #expect(estimate.taskPayloadBytes > 0)
        #expect(estimate.logPayloadBytes > 0)
        #expect(estimate.placePayloadBytes > 0)
        #expect(estimate.totalPayloadBytes >= 1_024)
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
    func savePlaceTapped_persistsSelectedPlace() async throws {
        let context = makeInMemoryContext()
        let store = TestStore(
            initialState: SettingsFeature.State(
                places: .init(
                    placeDraftName: "Home",
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
            $0.places.placeDraftCoordinate = nil
            $0.places.placeStatusMessage = "Saved Home."
        }

        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        #expect(places.count == 1)
        #expect(places.first?.displayName == "Home")
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
        let fitness = makeTask(in: context, name: "Workout", interval: 1, lastDone: nil, emoji: "💪", tags: ["Fitness", "Morning"])
        let stretch = makeTask(in: context, name: "Stretch", interval: 2, lastDone: nil, emoji: "🧘", tags: ["fitness"])
        _ = makeTask(in: context, name: "Read", interval: 3, lastDone: nil, emoji: "📚", tags: ["Morning"])
        try context.save()

        let fitnessSummary = RoutineTagSummary(name: "Fitness", linkedRoutineCount: 2)
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
        }
        await store.receive { action in
            guard case let .tagsLoaded(tags) = action else { return false }
            loadedTags = tags
            #expect(tags.map(\.name) == ["Health", "Morning"])
            #expect(tags.map(\.linkedRoutineCount) == [2, 2])
            return true
        } assert: {
            $0.tags.savedTags = loadedTags
        }
        await store.receive { action in
            guard case let .cloudUsageEstimateLoaded(estimate) = action else { return false }
            cloudEstimate = estimate
            #expect(estimate.taskCount == 3)
            return true
        } assert: {
            $0.cloud.cloudUsageEstimate = cloudEstimate
        }
        await store.receive(.tagOperationFinished(success: true, message: "Updated tag to Health in 2 routines.")) {
            $0.tags.isTagOperationInProgress = false
            $0.tags.tagStatusMessage = "Updated tag to Health in 2 routines."
        }

        let persistedTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let persistedFitness = try #require(persistedTasks.first(where: { $0.id == fitness.id }))
        let persistedStretch = try #require(persistedTasks.first(where: { $0.id == stretch.id }))
        #expect(persistedFitness.tags == ["Health", "Morning"])
        #expect(persistedStretch.tags == ["Health"])
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
        _ = makeTask(in: context, name: "Workout", interval: 1, lastDone: nil, emoji: "💪", tags: ["Health", "Morning"])
        let read = makeTask(in: context, name: "Read", interval: 3, lastDone: nil, emoji: "📚", tags: ["Morning"])
        let plan = makeTask(in: context, name: "Plan", interval: 4, lastDone: nil, emoji: "📝", tags: ["Evening", "Morning"])
        try context.save()

        let morningSummary = RoutineTagSummary(name: "Morning", linkedRoutineCount: 3)
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
        }
        await store.receive { action in
            guard case let .tagsLoaded(tags) = action else { return false }
            loadedTags = tags
            #expect(tags.map(\.name) == ["Evening", "Health"])
            #expect(tags.map(\.linkedRoutineCount) == [1, 1])
            return true
        } assert: {
            $0.tags.savedTags = loadedTags
        }
        await store.receive { action in
            guard case let .cloudUsageEstimateLoaded(estimate) = action else { return false }
            cloudEstimate = estimate
            #expect(estimate.taskCount == 3)
            return true
        } assert: {
            $0.cloud.cloudUsageEstimate = cloudEstimate
        }
        await store.receive(.tagOperationFinished(success: true, message: "Deleted Morning from 3 routines.")) {
            $0.tags.isTagOperationInProgress = false
            $0.tags.tagStatusMessage = "Deleted Morning from 3 routines."
        }

        let persistedTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let persistedRead = try #require(persistedTasks.first(where: { $0.id == read.id }))
        let persistedPlan = try #require(persistedTasks.first(where: { $0.id == plan.id }))
        #expect(persistedRead.tags.isEmpty)
        #expect(persistedPlan.tags == ["Evening"])
        #expect(persistedTasks.allSatisfy { !RoutineTag.contains("Morning", in: $0.tags) })
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
    func exportRoutineDataTapped_cancelledSelectionFinishesGracefully() async {
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { makeInMemoryContext() }
            $0.routineDataTransferClient.selectExportURL = { _ in nil }
        }

        await store.send(.exportRoutineDataTapped) {
            $0.dataTransfer.isDataTransferInProgress = true
            $0.dataTransfer.dataTransferStatusMessage = "Saving routine data..."
        }

        await store.receive(.routineDataTransferFinished(success: false, message: "Save canceled.")) {
            $0.dataTransfer.isDataTransferInProgress = false
            $0.dataTransfer.dataTransferStatusMessage = "Save canceled."
        }
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
            $0.dataTransfer.dataTransferStatusMessage = "Loading routine data..."
        }

        await store.receive(.routineDataTransferFinished(success: false, message: "Load canceled.")) {
            $0.dataTransfer.isDataTransferInProgress = false
            $0.dataTransfer.dataTransferStatusMessage = "Load canceled."
        }
    }
}
