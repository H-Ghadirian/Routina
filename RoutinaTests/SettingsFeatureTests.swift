import ComposableArchitecture
import Foundation
import SwiftData
import Testing
@testable @preconcurrency import Routina

@MainActor
@Suite(.serialized)
struct SettingsFeatureTests {
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
    func saveCurrentLocationAsPlaceTapped_persistsPlace() async throws {
        let context = makeInMemoryContext()
        let snapshot = LocationSnapshot(
            authorizationStatus: .authorizedWhenInUse,
            coordinate: LocationCoordinate(latitude: 52.52, longitude: 13.405),
            horizontalAccuracy: 20,
            timestamp: makeDate("2026-03-17T10:00:00Z")
        )
        let store = TestStore(
            initialState: SettingsFeature.State(
                placeDraftName: "Home",
                placeDraftRadiusMeters: 180
            )
        ) {
            SettingsFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.locationClient.snapshot = { _ in snapshot }
        }
        var loadedPlaces: [RoutinePlaceSummary] = []

        await store.send(.saveCurrentLocationAsPlaceTapped) {
            $0.isPlaceOperationInProgress = true
            $0.placeStatusMessage = ""
        }
        await store.receive(.locationSnapshotUpdated(snapshot)) {
            $0.locationAuthorizationStatus = .authorizedWhenInUse
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
        await store.receive(.placeOperationFinished(success: true, message: "Saved Home.")) {
            $0.isPlaceOperationInProgress = false
            $0.placeDraftName = ""
            $0.placeStatusMessage = "Saved Home."
        }

        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        #expect(places.count == 1)
        #expect(places.first?.displayName == "Home")
        #expect(places.first?.radiusMeters == 180)
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
}
