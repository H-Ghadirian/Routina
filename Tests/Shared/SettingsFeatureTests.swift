import ComposableArchitecture
import Foundation
import SwiftData
import Testing
@testable @preconcurrency import RoutinaAppSupport

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
            initialState: SettingsFeature.State(selectedAppIcon: .orange)
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
            $0.selectedAppIcon = .yellow
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
                appIconStatusMessage: "Old status",
                selectedAppIcon: .orange
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
            $0.appIconStatusMessage = ""
        }

        await store.receive(
            .appIconChangeFinished(
                requestedOption: .darkBlue,
                errorMessage: "Resource temporarily unavailable"
            )
        ) {
            $0.appIconStatusMessage = "App icon update failed: Resource temporarily unavailable"
        }

        #expect(store.state.selectedAppIcon == .orange)
        #expect(SharedDefaults.app[.selectedMacAppIcon] == AppIconOption.orange.rawValue)
    }

    @Test
    func savePlaceTapped_persistsSelectedPlace() async throws {
        let context = makeInMemoryContext()
        let store = TestStore(
            initialState: SettingsFeature.State(
                placeDraftName: "Home",
                placeDraftCoordinate: LocationCoordinate(latitude: 52.52, longitude: 13.405),
                placeDraftRadiusMeters: 180
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }
        var loadedPlaces: [RoutinePlaceSummary] = []
        var cloudEstimate = CloudUsageEstimate.zero

        await store.send(.savePlaceTapped) {
            $0.isPlaceOperationInProgress = true
            $0.placeStatusMessage = ""
        }
        await store.receive { action in
            guard case let .placesLoaded(places) = action else { return false }
            loadedPlaces = places
            #expect(places.count == 1)
            #expect(places.first?.name == "Home")
            #expect(places.first?.radiusMeters == 180)
            return true
        } assert: {
            $0.savedPlaces = loadedPlaces
        }
        await store.receive { action in
            guard case let .cloudUsageEstimateLoaded(estimate) = action else { return false }
            cloudEstimate = estimate
            #expect(estimate.placeCount == 1)
            #expect(estimate.taskCount == 0)
            return true
        } assert: {
            $0.cloudUsageEstimate = cloudEstimate
        }
        await store.receive(.placeOperationFinished(success: true, message: "Saved Home.")) {
            $0.isPlaceOperationInProgress = false
            $0.placeDraftName = ""
            $0.placeDraftCoordinate = nil
            $0.placeStatusMessage = "Saved Home."
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
                placeDraftName: "Home"
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.savePlaceTapped) {
            $0.placeStatusMessage = "Choose a location on the map first."
        }
    }

    @Test
    func duplicatePlaceDraft_disablesSaveAndShowsValidationMessage() {
        let state = SettingsFeature.State(
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

        #expect(state.hasDuplicatePlaceDraftName)
        #expect(state.isSavePlaceDisabled)
        #expect(state.savePlaceValidationMessage == "A place with this name already exists.")
    }

    @Test
    func savePlaceTapped_duplicateNameShowsValidationMessageAndDoesNotPersist() async throws {
        let context = makeInMemoryContext()
        _ = makePlace(in: context, name: "Home")

        let store = TestStore(
            initialState: SettingsFeature.State(
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
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.savePlaceTapped) {
            $0.isPlaceOperationInProgress = true
            $0.placeStatusMessage = ""
        }

        await store.receive(
            .placeOperationFinished(
                success: false,
                message: "A place with this name already exists."
            )
        ) {
            $0.isPlaceOperationInProgress = false
            $0.placeStatusMessage = "A place with this name already exists."
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
                savedPlaces: [
                    RoutinePlaceSummary(id: place.id, name: "Home", radiusMeters: place.radiusMeters, linkedRoutineCount: 1)
                ]
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }
        var cloudEstimate = CloudUsageEstimate.zero

        await store.send(.deletePlaceTapped(place.id)) {
            $0.isDeletePlaceConfirmationPresented = true
            $0.placePendingDeletion = RoutinePlaceSummary(
                id: place.id,
                name: "Home",
                radiusMeters: place.radiusMeters,
                linkedRoutineCount: 1
            )
        }
        await store.send(.deletePlaceConfirmed) {
            $0.isDeletePlaceConfirmationPresented = false
            $0.placePendingDeletion = nil
            $0.isPlaceOperationInProgress = true
            $0.placeStatusMessage = ""
        }
        await store.receive(.placesLoaded([])) {
            $0.savedPlaces = []
        }
        await store.receive { action in
            guard case let .cloudUsageEstimateLoaded(estimate) = action else { return false }
            cloudEstimate = estimate
            #expect(estimate.placeCount == 0)
            #expect(estimate.taskCount == 1)
            return true
        } assert: {
            $0.cloudUsageEstimate = cloudEstimate
        }
        await store.receive(.placeOperationFinished(success: true, message: "Place deleted.")) {
            $0.isPlaceOperationInProgress = false
            $0.placeStatusMessage = "Place deleted."
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
                savedPlaces: [summary]
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.deletePlaceTapped(placeID)) {
            $0.isDeletePlaceConfirmationPresented = true
            $0.placePendingDeletion = summary
        }

        await store.send(.setDeletePlaceConfirmation(false)) {
            $0.isDeletePlaceConfirmationPresented = false
            $0.placePendingDeletion = nil
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
                isDeletePlaceConfirmationPresented: true,
                savedPlaces: [initialSummary],
                placePendingDeletion: initialSummary
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.placesLoaded([updatedSummary])) {
            $0.savedPlaces = [updatedSummary]
            $0.placePendingDeletion = updatedSummary
        }
    }

    @Test
    func renameTagTapped_populatesDraftAndPresentsSheet() async {
        let context = makeInMemoryContext()
        let summary = RoutineTagSummary(name: "Fitness", linkedRoutineCount: 2)

        let store = TestStore(
            initialState: SettingsFeature.State(
                savedTags: [summary]
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.renameTagTapped("Fitness")) {
            $0.tagPendingRename = summary
            $0.tagRenameDraft = "Fitness"
            $0.isTagRenameSheetPresented = true
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
                savedTags: [fitnessSummary, morningSummary],
                tagPendingRename: fitnessSummary,
                tagRenameDraft: "Health",
                isTagRenameSheetPresented: true
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }
        var loadedTags: [RoutineTagSummary] = []
        var cloudEstimate = CloudUsageEstimate.zero

        await store.send(.saveTagRenameTapped) {
            $0.tagPendingRename = nil
            $0.tagRenameDraft = ""
            $0.isTagOperationInProgress = true
            $0.isTagRenameSheetPresented = false
            $0.tagStatusMessage = ""
        }
        await store.receive { action in
            guard case let .tagsLoaded(tags) = action else { return false }
            loadedTags = tags
            #expect(tags.map(\.name) == ["Health", "Morning"])
            #expect(tags.map(\.linkedRoutineCount) == [2, 2])
            return true
        } assert: {
            $0.savedTags = loadedTags
        }
        await store.receive { action in
            guard case let .cloudUsageEstimateLoaded(estimate) = action else { return false }
            cloudEstimate = estimate
            #expect(estimate.taskCount == 3)
            return true
        } assert: {
            $0.cloudUsageEstimate = cloudEstimate
        }
        await store.receive(.tagOperationFinished(success: true, message: "Updated tag to Health in 2 routines.")) {
            $0.isTagOperationInProgress = false
            $0.tagStatusMessage = "Updated tag to Health in 2 routines."
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
                tagPendingRename: summary,
                tagRenameDraft: "   ",
                isTagRenameSheetPresented: true
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }

        await store.send(.saveTagRenameTapped) {
            $0.tagStatusMessage = "Enter a tag name first."
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
                savedTags: [eveningSummary, healthSummary, morningSummary],
                tagPendingDeletion: morningSummary,
                isDeleteTagConfirmationPresented: true
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
        }
        var loadedTags: [RoutineTagSummary] = []
        var cloudEstimate = CloudUsageEstimate.zero

        await store.send(.deleteTagConfirmed) {
            $0.tagPendingDeletion = nil
            $0.isDeleteTagConfirmationPresented = false
            $0.isTagOperationInProgress = true
            $0.tagStatusMessage = ""
        }
        await store.receive { action in
            guard case let .tagsLoaded(tags) = action else { return false }
            loadedTags = tags
            #expect(tags.map(\.name) == ["Evening", "Health"])
            #expect(tags.map(\.linkedRoutineCount) == [1, 1])
            return true
        } assert: {
            $0.savedTags = loadedTags
        }
        await store.receive { action in
            guard case let .cloudUsageEstimateLoaded(estimate) = action else { return false }
            cloudEstimate = estimate
            #expect(estimate.taskCount == 3)
            return true
        } assert: {
            $0.cloudUsageEstimate = cloudEstimate
        }
        await store.receive(.tagOperationFinished(success: true, message: "Deleted Morning from 3 routines.")) {
            $0.isTagOperationInProgress = false
            $0.tagStatusMessage = "Deleted Morning from 3 routines."
        }

        let persistedTasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let persistedRead = try #require(persistedTasks.first(where: { $0.id == read.id }))
        let persistedPlan = try #require(persistedTasks.first(where: { $0.id == plan.id }))
        #expect(persistedRead.tags.isEmpty)
        #expect(persistedPlan.tags == ["Evening"])
        #expect(persistedTasks.allSatisfy { !RoutineTag.contains("Morning", in: $0.tags) })
    }
}
