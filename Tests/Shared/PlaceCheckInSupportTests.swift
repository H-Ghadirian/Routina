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

struct PlaceCheckInSupportTests {
    @MainActor
    @Test
    func checkIn_endsPreviousPlaceSession() throws {
        let context = makeInMemoryContext()
        let home = makePlace(in: context, name: "Home")
        let office = makePlace(in: context, name: "Office")
        let homeStart = makeDate("2026-05-10T08:15:00Z")
        let officeStart = makeDate("2026-05-10T09:40:00Z")

        let homeSession = try PlaceCheckInSupport.checkIn(
            at: home,
            activity: .rest,
            date: homeStart,
            in: context
        )
        let officeSession = try PlaceCheckInSupport.checkIn(
            at: office,
            activity: .work,
            date: officeStart,
            in: context
        )

        #expect(homeSession.endedAt == officeStart)
        #expect(officeSession.endedAt == nil)
        #expect(officeSession.activity == .work)
        #expect(officeSession.latitude == office.latitude)
        #expect(officeSession.longitude == office.longitude)
        #expect(officeSession.placeRadiusMeters == office.radiusMeters)
        #expect(try PlaceCheckInSupport.activeSession(in: context)?.id == officeSession.id)
    }

    @MainActor
    @Test
    func checkIn_samePlaceUpdatesActiveSessionInsteadOfDuplicating() throws {
        let context = makeInMemoryContext()
        let office = makePlace(in: context, name: "Office")

        let first = try PlaceCheckInSupport.checkIn(
            at: office,
            date: makeDate("2026-05-10T09:00:00Z"),
            in: context
        )
        let second = try PlaceCheckInSupport.checkIn(
            at: office,
            activity: .work,
            date: makeDate("2026-05-10T09:30:00Z"),
            in: context
        )

        #expect(first.id == second.id)
        #expect(second.startedAt == makeDate("2026-05-10T09:00:00Z"))
        #expect(second.activity == .work)
        #expect(try context.fetch(FetchDescriptor<PlaceCheckInSession>()).count == 1)
    }

    @MainActor
    @Test
    func checkInAtCurrentLocation_usesContainingSavedPlace() throws {
        let context = makeInMemoryContext()
        let office = makePlace(in: context, name: "Office", latitude: 52.5200, longitude: 13.4050, radiusMeters: 150)

        let session = try PlaceCheckInSupport.checkInAtCurrentLocation(
            coordinate: LocationCoordinate(latitude: 52.5204, longitude: 13.4052),
            horizontalAccuracyMeters: 42,
            activity: .work,
            date: makeDate("2026-05-10T09:00:00Z"),
            in: context
        )

        #expect(session.placeID == office.id)
        #expect(session.displayPlaceName == "Office")
        #expect(session.latitude == office.latitude)
        #expect(session.longitude == office.longitude)
        #expect(session.horizontalAccuracyMeters == nil)
        #expect(session.placeRadiusMeters == office.radiusMeters)
    }

    @MainActor
    @Test
    func checkInAtCurrentLocation_recordsRawCoordinateAwayFromPlaces() throws {
        let context = makeInMemoryContext()
        _ = makePlace(in: context, name: "Office", latitude: 52.5200, longitude: 13.4050, radiusMeters: 150)
        let coordinate = LocationCoordinate(latitude: 48.8566, longitude: 2.3522)

        let session = try PlaceCheckInSupport.checkInAtCurrentLocation(
            coordinate: coordinate,
            horizontalAccuracyMeters: 18,
            activity: .errands,
            date: makeDate("2026-05-10T11:00:00Z"),
            in: context
        )

        #expect(session.placeID == nil)
        #expect(session.displayPlaceName == "Current Location")
        #expect(session.coordinate == coordinate)
        #expect(session.horizontalAccuracyMeters == 18)
        #expect(session.placeRadiusMeters == nil)
        #expect(session.activity == .errands)
    }

    @MainActor
    @Test
    func suggestedPlacesPrefersRecentCheckInsThenNames() throws {
        let context = makeInMemoryContext()
        let gym = makePlace(in: context, name: "Gym")
        let office = makePlace(in: context, name: "Office")
        let home = makePlace(in: context, name: "Home")

        context.insert(
            PlaceCheckInSession(
                placeID: home.id,
                placeName: home.displayName,
                startedAt: makeDate("2026-05-10T08:00:00Z"),
                endedAt: makeDate("2026-05-10T09:00:00Z")
            )
        )
        context.insert(
            PlaceCheckInSession(
                placeID: office.id,
                placeName: office.displayName,
                startedAt: makeDate("2026-05-10T10:00:00Z"),
                endedAt: makeDate("2026-05-10T17:00:00Z")
            )
        )
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<PlaceCheckInSession>())
        let suggested = PlaceCheckInSupport.suggestedPlaces(
            places: [gym, office, home],
            sessions: sessions,
            limit: 3
        )

        #expect(suggested.map(\.displayName) == ["Office", "Home", "Gym"])
    }

    @MainActor
    @Test
    func sessionsOnDay_returnsChronologicalPlaceTimeline() throws {
        let context = makeInMemoryContext()
        let morning = PlaceCheckInSession(
            placeID: nil,
            placeName: "Gym",
            startedAt: makeDate("2026-05-10T07:30:00Z"),
            endedAt: makeDate("2026-05-10T08:15:00Z")
        )
        let afternoon = PlaceCheckInSession(
            placeID: nil,
            placeName: "Office",
            startedAt: makeDate("2026-05-10T09:00:00Z"),
            endedAt: makeDate("2026-05-10T17:00:00Z")
        )
        let otherDay = PlaceCheckInSession(
            placeID: nil,
            placeName: "Home",
            startedAt: makeDate("2026-05-11T19:00:00Z"),
            endedAt: makeDate("2026-05-11T21:00:00Z")
        )
        context.insert(afternoon)
        context.insert(otherDay)
        context.insert(morning)
        try context.save()

        let calendar = Calendar(identifier: .gregorian)
        let timeline = PlaceCheckInSupport.sessions(
            [afternoon, otherDay, morning],
            on: makeDate("2026-05-10T12:00:00Z"),
            calendar: calendar
        )

        #expect(timeline.map(\.displayPlaceName) == ["Gym", "Office"])
        #expect(PlaceCheckInSupport.totalDurationSeconds(for: timeline) == 31_500)
    }

    @MainActor
    @Test
    func updateSession_correctsEditableCheckInFields() throws {
        let context = makeInMemoryContext()
        let session = PlaceCheckInSession(
            placeID: nil,
            placeName: "Current Location",
            activity: .other,
            note: "rough",
            startedAt: makeDate("2026-05-10T08:00:00Z"),
            endedAt: makeDate("2026-05-10T08:20:00Z"),
            createdAt: makeDate("2026-05-10T08:00:00Z"),
            updatedAt: makeDate("2026-05-10T08:20:00Z")
        )
        context.insert(session)
        try context.save()

        let updated = try PlaceCheckInSupport.updateSession(
            id: session.id,
            placeName: "  Office focus  ",
            activity: .work,
            note: "  deep work block  ",
            startedAt: makeDate("2026-05-10T09:00:00Z"),
            endedAt: makeDate("2026-05-10T11:30:00Z"),
            updatedAt: makeDate("2026-05-10T12:00:00Z"),
            in: context
        )

        #expect(updated.displayPlaceName == "Office focus")
        #expect(updated.activity == .work)
        #expect(updated.note == "deep work block")
        #expect(updated.startedAt == makeDate("2026-05-10T09:00:00Z"))
        #expect(updated.endedAt == makeDate("2026-05-10T11:30:00Z"))
        #expect(updated.updatedAt == makeDate("2026-05-10T12:00:00Z"))
    }

    @MainActor
    @Test
    func updateSession_rejectsEndBeforeStart() throws {
        let context = makeInMemoryContext()
        let session = PlaceCheckInSession(
            placeID: nil,
            placeName: "Gym",
            startedAt: makeDate("2026-05-10T08:00:00Z"),
            endedAt: makeDate("2026-05-10T09:00:00Z")
        )
        context.insert(session)
        try context.save()

        do {
            _ = try PlaceCheckInSupport.updateSession(
                id: session.id,
                placeName: "Gym",
                activity: nil,
                note: nil,
                startedAt: makeDate("2026-05-10T10:00:00Z"),
                endedAt: makeDate("2026-05-10T09:30:00Z"),
                in: context
            )
            Issue.record("Expected invalidDateRange error")
        } catch let error as PlaceCheckInSessionEditError {
            #expect(error == .invalidDateRange)
        }

        #expect(session.startedAt == makeDate("2026-05-10T08:00:00Z"))
        #expect(session.endedAt == makeDate("2026-05-10T09:00:00Z"))
    }

    @MainActor
    @Test
    func deleteSession_removesPlaceCheckInRecord() throws {
        let context = makeInMemoryContext()
        let session = PlaceCheckInSession(
            placeID: nil,
            placeName: "Cafe",
            startedAt: makeDate("2026-05-10T12:00:00Z"),
            endedAt: makeDate("2026-05-10T13:00:00Z")
        )
        context.insert(session)
        try context.save()

        let deleted = try PlaceCheckInSupport.deleteSession(id: session.id, in: context)

        #expect(deleted)
        #expect(try context.fetch(FetchDescriptor<PlaceCheckInSession>()).isEmpty)
        #expect(try PlaceCheckInSupport.deleteSession(id: session.id, in: context) == false)
    }

    @MainActor
    @Test
    func backupPackage_roundTripsPlaceCheckInSessions() throws {
        let sourceContext = makeInMemoryContext()
        let place = makePlace(in: sourceContext, name: "Office")
        let session = PlaceCheckInSession(
            id: UUID(),
            placeID: place.id,
            placeName: place.displayName,
            latitude: place.latitude,
            longitude: place.longitude,
            placeRadiusMeters: place.radiusMeters,
            activity: .work,
            note: "Morning block",
            startedAt: makeDate("2026-05-10T09:00:00Z"),
            endedAt: makeDate("2026-05-10T12:30:00Z"),
            createdAt: makeDate("2026-05-10T09:00:00Z"),
            updatedAt: makeDate("2026-05-10T12:30:00Z")
        )
        sourceContext.insert(session)
        try sourceContext.save()

        let package = try SettingsRoutineDataPersistence.buildBackupPackage(
            from: sourceContext,
            exportedAt: makeDate("2026-05-10T13:00:00Z")
        )

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            with: package.manifestData,
            in: restoreContext,
            importDate: makeDate("2026-05-10T13:05:00Z")
        )
        let restored = try #require(try restoreContext.fetch(FetchDescriptor<PlaceCheckInSession>()).first)

        #expect(summary.placeCheckInSessions == 1)
        #expect(restored.id == session.id)
        #expect(restored.placeID == place.id)
        #expect(restored.displayPlaceName == "Office")
        #expect(restored.activity == .work)
        #expect(restored.note == "Morning block")
        #expect(restored.latitude == place.latitude)
        #expect(restored.longitude == place.longitude)
        #expect(restored.placeRadiusMeters == place.radiusMeters)
        #expect(restored.startedAt == session.startedAt)
        #expect(restored.endedAt == session.endedAt)
    }
}
