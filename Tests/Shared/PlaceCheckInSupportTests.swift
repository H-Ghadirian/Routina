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
    func checkIn_sameActivePlaceFromPreviousDayAppearsInCurrentDayTimeline() throws {
        let context = makeInMemoryContext()
        let home = makePlace(in: context, name: "Home")
        let first = try PlaceCheckInSupport.checkIn(
            at: home,
            date: makeDate("2026-05-10T23:00:00Z"),
            in: context
        )
        let second = try PlaceCheckInSupport.checkIn(
            at: home,
            date: makeDate("2026-05-11T08:00:00Z"),
            in: context
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let timeline = PlaceCheckInSupport.sessions(
            [second],
            on: makeDate("2026-05-11T12:00:00Z"),
            calendar: calendar,
            referenceDate: makeDate("2026-05-11T08:00:00Z")
        )

        #expect(first.id == second.id)
        #expect(timeline.map(\.displayPlaceName) == ["Home"])
        #expect(
            PlaceCheckInSupport.totalDurationSeconds(
                for: timeline,
                on: makeDate("2026-05-11T12:00:00Z"),
                calendar: calendar,
                referenceDate: makeDate("2026-05-11T08:00:00Z")
            ) == 28_800
        )
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
        #expect(session.displayPlaceName.hasPrefix("Check-in at "))
        #expect(session.coordinate == coordinate)
        #expect(session.horizontalAccuracyMeters == 18)
        #expect(session.placeRadiusMeters == nil)
        #expect(session.activity == .errands)
    }

    @MainActor
    @Test
    func checkInAtCurrentLocation_usesProvidedRawPlaceName() throws {
        let context = makeInMemoryContext()
        let coordinate = LocationCoordinate(latitude: 48.8566, longitude: 2.3522)

        let session = try PlaceCheckInSupport.checkInAtCurrentLocation(
            coordinate: coordinate,
            rawPlaceName: "  Corner Bakery  ",
            date: makeDate("2026-05-10T11:00:00Z"),
            in: context
        )

        #expect(session.placeID == nil)
        #expect(session.displayPlaceName == "Corner Bakery")
        #expect(session.coordinate == coordinate)
    }

    @MainActor
    @Test
    func checkInAtCurrentLocation_updatesActiveRawSessionWithProvidedName() throws {
        let context = makeInMemoryContext()
        let coordinate = LocationCoordinate(latitude: 48.8566, longitude: 2.3522)
        let first = try PlaceCheckInSupport.checkInAtCurrentLocation(
            coordinate: coordinate,
            date: makeDate("2026-05-10T11:00:00Z"),
            in: context
        )

        let second = try PlaceCheckInSupport.checkInAtCurrentLocation(
            coordinate: LocationCoordinate(latitude: 48.8567, longitude: 2.3521),
            rawPlaceName: "Corner Bakery",
            date: makeDate("2026-05-10T11:05:00Z"),
            in: context
        )

        #expect(first.id == second.id)
        #expect(second.displayPlaceName == "Corner Bakery")
        #expect(try context.fetch(FetchDescriptor<PlaceCheckInSession>()).count == 1)
    }

    @MainActor
    @Test
    func checkInAtCurrentLocation_namesRawCoordinateNearSavedPlace() throws {
        let context = makeInMemoryContext()
        _ = makePlace(in: context, name: "Office", latitude: 52.5200, longitude: 13.4050, radiusMeters: 100)

        let session = try PlaceCheckInSupport.checkInAtCurrentLocation(
            coordinate: LocationCoordinate(latitude: 52.5230, longitude: 13.4050),
            date: makeDate("2026-05-10T11:00:00Z"),
            in: context
        )

        #expect(session.placeID == nil)
        #expect(session.displayPlaceName == "Near Office")
    }

    @MainActor
    @Test
    func checkInAtCurrentLocation_reusesPreviouslyNamedRawLocation() throws {
        let context = makeInMemoryContext()
        let coordinate = LocationCoordinate(latitude: 48.8566, longitude: 2.3522)
        context.insert(
            PlaceCheckInSession(
                placeID: nil,
                placeName: "Favorite Cafe",
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                startedAt: makeDate("2026-05-09T11:00:00Z"),
                endedAt: makeDate("2026-05-09T12:00:00Z")
            )
        )
        try context.save()

        let session = try PlaceCheckInSupport.checkInAtCurrentLocation(
            coordinate: LocationCoordinate(latitude: 48.8567, longitude: 2.3521),
            date: makeDate("2026-05-10T11:00:00Z"),
            in: context
        )

        #expect(session.placeID == nil)
        #expect(session.displayPlaceName == "Favorite Cafe")
    }

    @MainActor
    @Test
    func currentLocationDisplayName_usesContainingSavedPlace() throws {
        let context = makeInMemoryContext()
        _ = makePlace(in: context, name: "English Garden", latitude: 48.1569, longitude: 11.5920, radiusMeters: 200)
        let coordinate = LocationCoordinate(latitude: 48.1570, longitude: 11.5921)

        let name = PlaceCheckInSupport.currentLocationDisplayName(
            coordinate: coordinate,
            places: try context.fetch(FetchDescriptor<RoutinePlace>()),
            sessions: []
        )

        #expect(name == "English Garden")
    }

    @MainActor
    @Test
    func currentLocationDisplayName_reusesPreviouslyNamedRawLocation() throws {
        let context = makeInMemoryContext()
        let coordinate = LocationCoordinate(latitude: 48.1001, longitude: 11.5024)
        context.insert(
            PlaceCheckInSession(
                placeID: nil,
                placeName: "Quiet Bench",
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                startedAt: makeDate("2026-05-09T19:00:00Z"),
                endedAt: makeDate("2026-05-09T20:00:00Z")
            )
        )
        try context.save()

        let name = PlaceCheckInSupport.currentLocationDisplayName(
            coordinate: LocationCoordinate(latitude: 48.1002, longitude: 11.5025),
            places: [],
            sessions: try context.fetch(FetchDescriptor<PlaceCheckInSession>())
        )

        #expect(name == "Quiet Bench")
    }

    @MainActor
    @Test
    func currentLocationDisplayName_ignoresGeneratedRawNames() throws {
        let context = makeInMemoryContext()
        let coordinate = LocationCoordinate(latitude: 48.1001, longitude: 11.5024)
        context.insert(
            PlaceCheckInSession(
                placeID: nil,
                placeName: "Check-in at 19:00",
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                startedAt: makeDate("2026-05-09T19:00:00Z"),
                endedAt: makeDate("2026-05-09T20:00:00Z")
            )
        )
        try context.save()

        let name = PlaceCheckInSupport.currentLocationDisplayName(
            coordinate: LocationCoordinate(latitude: 48.1002, longitude: 11.5025),
            places: [],
            sessions: try context.fetch(FetchDescriptor<PlaceCheckInSession>())
        )

        #expect(name == nil)
    }

    @MainActor
    @Test
    func linkSessionToPlace_promotesRawCheckInToSavedPlace() throws {
        let context = makeInMemoryContext()
        let coordinate = LocationCoordinate(latitude: 48.8566, longitude: 2.3522)
        let session = PlaceCheckInSession(
            placeID: nil,
            placeName: "Check-in at 11:00",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            startedAt: makeDate("2026-05-10T11:00:00Z")
        )
        context.insert(session)
        let cafe = makePlace(in: context, name: "Cafe", latitude: 48.8565, longitude: 2.3520, radiusMeters: 125)

        let linked = try PlaceCheckInSupport.linkSessionToPlace(
            sessionID: session.id,
            place: cafe,
            date: makeDate("2026-05-10T11:05:00Z"),
            in: context
        )

        #expect(linked.id == session.id)
        #expect(linked.placeID == cafe.id)
        #expect(linked.displayPlaceName == "Cafe")
        #expect(linked.coordinate == coordinate)
        #expect(linked.placeRadiusMeters == 125)
        #expect(linked.updatedAt == makeDate("2026-05-10T11:05:00Z"))
    }

    @MainActor
    @Test
    func reconcileAutomaticCheckIn_startsPendingSavedPlaceSession() throws {
        let context = makeInMemoryContext()
        let office = makePlace(in: context, name: "Office", latitude: 52.5200, longitude: 13.4050, radiusMeters: 150)

        let session = try PlaceCheckInSupport.reconcileAutomaticCheckIn(
            coordinate: LocationCoordinate(latitude: 52.5204, longitude: 13.4052),
            horizontalAccuracyMeters: 42,
            activity: .work,
            date: makeDate("2026-05-10T09:00:00Z"),
            in: context
        )

        let unwrapped = try #require(session)
        #expect(unwrapped.placeID == office.id)
        #expect(unwrapped.displayPlaceName == "Office")
        #expect(unwrapped.isAutomatic)
        #expect(unwrapped.requiresConfirmation)
        #expect(unwrapped.confirmedAt == nil)
        #expect(try PlaceCheckInSupport.activeSession(in: context)?.id == unwrapped.id)
    }

    @MainActor
    @Test
    func reconcileAutomaticCheckIn_sameSavedPlaceDoesNotDuplicateActiveSession() throws {
        let context = makeInMemoryContext()
        _ = makePlace(in: context, name: "Office", latitude: 52.5200, longitude: 13.4050, radiusMeters: 150)
        let coordinate = LocationCoordinate(latitude: 52.5204, longitude: 13.4052)

        let first = try PlaceCheckInSupport.reconcileAutomaticCheckIn(
            coordinate: coordinate,
            date: makeDate("2026-05-10T09:00:00Z"),
            in: context
        )
        let second = try PlaceCheckInSupport.reconcileAutomaticCheckIn(
            coordinate: coordinate,
            date: makeDate("2026-05-10T09:15:00Z"),
            in: context
        )

        #expect(first?.id == second?.id)
        #expect(try context.fetch(FetchDescriptor<PlaceCheckInSession>()).count == 1)
    }

    @MainActor
    @Test
    func reconcileAutomaticCheckIn_endsAutomaticSessionWhenAwayFromSavedPlaces() throws {
        let context = makeInMemoryContext()
        let office = makePlace(in: context, name: "Office", latitude: 52.5200, longitude: 13.4050, radiusMeters: 150)
        let session = PlaceCheckInSession(
            placeID: office.id,
            placeName: office.displayName,
            latitude: office.latitude,
            longitude: office.longitude,
            startedAt: makeDate("2026-05-10T09:00:00Z"),
            captureMode: .automatic
        )
        context.insert(session)
        try context.save()

        let nextSession = try PlaceCheckInSupport.reconcileAutomaticCheckIn(
            coordinate: LocationCoordinate(latitude: 48.8566, longitude: 2.3522),
            date: makeDate("2026-05-10T10:00:00Z"),
            in: context
        )

        #expect(nextSession == nil)
        #expect(session.endedAt == makeDate("2026-05-10T10:00:00Z"))
    }

    @MainActor
    @Test
    func endActiveAutomaticSession_endsOnlyAutomaticSessions() throws {
        let context = makeInMemoryContext()
        let automaticSession = PlaceCheckInSession(
            placeID: nil,
            placeName: "Office",
            startedAt: makeDate("2026-05-10T09:00:00Z"),
            captureMode: .automatic
        )
        context.insert(automaticSession)
        try context.save()

        let endedAutomatic = try PlaceCheckInSupport.endActiveAutomaticSession(
            at: makeDate("2026-05-10T10:00:00Z"),
            in: context
        )

        #expect(endedAutomatic?.id == automaticSession.id)
        #expect(automaticSession.endedAt == makeDate("2026-05-10T10:00:00Z"))

        let manualSession = PlaceCheckInSession(
            placeID: nil,
            placeName: "Home",
            startedAt: makeDate("2026-05-10T11:00:00Z"),
            captureMode: .manual
        )
        context.insert(manualSession)
        try context.save()

        let endedManual = try PlaceCheckInSupport.endActiveAutomaticSession(
            at: makeDate("2026-05-10T12:00:00Z"),
            in: context
        )

        #expect(endedManual == nil)
        #expect(manualSession.endedAt == nil)
    }

    @MainActor
    @Test
    func confirmAutomaticSession_marksSessionConfirmed() throws {
        let context = makeInMemoryContext()
        let session = PlaceCheckInSession(
            placeID: nil,
            placeName: "Office",
            startedAt: makeDate("2026-05-10T09:00:00Z"),
            captureMode: .automatic
        )
        context.insert(session)
        try context.save()

        let confirmed = try PlaceCheckInSupport.confirmAutomaticSession(
            id: session.id,
            date: makeDate("2026-05-10T09:30:00Z"),
            in: context
        )

        #expect(confirmed.isAutomatic)
        #expect(!confirmed.requiresConfirmation)
        #expect(confirmed.confirmedAt == makeDate("2026-05-10T09:30:00Z"))
        #expect(confirmed.updatedAt == makeDate("2026-05-10T09:30:00Z"))
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
    func historyMapMarkersGroupsCoordinateSnapshots() throws {
        let homeID = UUID()
        let homeCoordinate = LocationCoordinate(latitude: 52.52, longitude: 13.405)
        let cafeCoordinate = LocationCoordinate(latitude: 48.8566, longitude: 2.3522)
        let firstHome = PlaceCheckInSession(
            placeID: homeID,
            placeName: "Home",
            latitude: homeCoordinate.latitude,
            longitude: homeCoordinate.longitude,
            startedAt: makeDate("2026-05-10T08:00:00Z"),
            endedAt: makeDate("2026-05-10T09:00:00Z")
        )
        let secondHome = PlaceCheckInSession(
            placeID: homeID,
            placeName: "Home",
            latitude: homeCoordinate.latitude,
            longitude: homeCoordinate.longitude,
            startedAt: makeDate("2026-05-11T08:00:00Z"),
            endedAt: makeDate("2026-05-11T10:00:00Z")
        )
        let activeCafe = PlaceCheckInSession(
            placeID: nil,
            placeName: "Cafe",
            latitude: cafeCoordinate.latitude,
            longitude: cafeCoordinate.longitude,
            startedAt: makeDate("2026-05-11T12:00:00Z"),
            endedAt: nil
        )
        let missingCoordinate = PlaceCheckInSession(
            placeID: nil,
            placeName: "Unknown",
            startedAt: makeDate("2026-05-11T13:00:00Z"),
            endedAt: makeDate("2026-05-11T14:00:00Z")
        )

        let markers = PlaceCheckInSupport.historyMapMarkers(
            from: [firstHome, activeCafe, missingCoordinate, secondHome]
        )
        let homeMarker = try #require(markers.first { $0.placeName == "Home" })
        let cafeMarker = try #require(markers.first { $0.placeName == "Cafe" })

        #expect(markers.count == 2)
        #expect(markers.first?.placeName == "Cafe")
        #expect(homeMarker.placeID == homeID)
        #expect(homeMarker.coordinate == homeCoordinate)
        #expect(homeMarker.count == 2)
        #expect(homeMarker.latestDate == makeDate("2026-05-11T10:00:00Z"))
        #expect(!homeMarker.containsActiveSession)
        #expect(cafeMarker.coordinate == cafeCoordinate)
        #expect(cafeMarker.count == 1)
        #expect(cafeMarker.containsActiveSession)
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
    func groupedSessionsByDay_returnsReverseChronologicalSectionsAndRows() throws {
        let home = PlaceCheckInSession(
            placeID: nil,
            placeName: "Home",
            startedAt: makeDate("2026-05-10T19:00:00Z"),
            endedAt: makeDate("2026-05-10T21:00:00Z")
        )
        let cafe = PlaceCheckInSession(
            placeID: nil,
            placeName: "Cafe",
            startedAt: makeDate("2026-05-11T09:00:00Z"),
            endedAt: makeDate("2026-05-11T10:00:00Z")
        )
        let office = PlaceCheckInSession(
            placeID: nil,
            placeName: "Office",
            startedAt: makeDate("2026-05-11T12:00:00Z"),
            endedAt: makeDate("2026-05-11T17:00:00Z")
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let sections = PlaceCheckInSupport.groupedSessionsByDay(
            [home, office, cafe],
            calendar: calendar
        )

        #expect(sections.map(\.date) == [
            makeDate("2026-05-11T00:00:00Z"),
            makeDate("2026-05-10T00:00:00Z")
        ])
        #expect(sections.first?.sessions.map(\.displayPlaceName) == ["Office", "Cafe"])
        #expect(sections.last?.sessions.map(\.displayPlaceName) == ["Home"])
    }

    @MainActor
    @Test
    func updateSession_reordersGroupedCheckInsByEditedStartTime() throws {
        let context = makeInMemoryContext()
        let cafe = PlaceCheckInSession(
            placeID: nil,
            placeName: "Cafe",
            startedAt: makeDate("2026-05-11T09:00:00Z"),
            endedAt: makeDate("2026-05-11T10:00:00Z")
        )
        let office = PlaceCheckInSession(
            placeID: nil,
            placeName: "Office",
            startedAt: makeDate("2026-05-11T12:00:00Z"),
            endedAt: makeDate("2026-05-11T17:00:00Z")
        )
        context.insert(cafe)
        context.insert(office)
        try context.save()

        _ = try PlaceCheckInSupport.updateSession(
            id: cafe.id,
            placeName: "Cafe",
            activity: nil,
            note: nil,
            imageData: nil,
            startedAt: makeDate("2026-05-11T14:00:00Z"),
            endedAt: makeDate("2026-05-11T15:00:00Z"),
            in: context
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let sessions = try context.fetch(FetchDescriptor<PlaceCheckInSession>())

        let sections = PlaceCheckInSupport.groupedSessionsByDay(
            sessions,
            calendar: calendar
        )

        #expect(sections.first?.sessions.map(\.displayPlaceName) == ["Cafe", "Office"])
    }

    @MainActor
    @Test
    func sessionsOnDay_includesSessionsThatOverlapSelectedDay() throws {
        let home = PlaceCheckInSession(
            placeID: nil,
            placeName: "Home",
            startedAt: makeDate("2026-05-10T23:00:00Z"),
            endedAt: makeDate("2026-05-11T08:00:00Z")
        )
        let office = PlaceCheckInSession(
            placeID: nil,
            placeName: "Office",
            startedAt: makeDate("2026-05-11T09:00:00Z"),
            endedAt: makeDate("2026-05-11T10:00:00Z")
        )
        let nextDay = PlaceCheckInSession(
            placeID: nil,
            placeName: "Gym",
            startedAt: makeDate("2026-05-12T07:00:00Z"),
            endedAt: makeDate("2026-05-12T08:00:00Z")
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let timeline = PlaceCheckInSupport.sessions(
            [office, nextDay, home],
            on: makeDate("2026-05-11T12:00:00Z"),
            calendar: calendar,
            referenceDate: makeDate("2026-05-11T12:00:00Z")
        )

        #expect(timeline.map(\.displayPlaceName) == ["Home", "Office"])
        #expect(
            PlaceCheckInSupport.totalDurationSeconds(
                for: timeline,
                on: makeDate("2026-05-11T12:00:00Z"),
                calendar: calendar,
                referenceDate: makeDate("2026-05-11T12:00:00Z")
            ) == 32_400
        )
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
            imageData: Data([0x01]),
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
            imageData: Data([0x02, 0x03]),
            startedAt: makeDate("2026-05-10T09:00:00Z"),
            endedAt: makeDate("2026-05-10T11:30:00Z"),
            updatedAt: makeDate("2026-05-10T12:00:00Z"),
            in: context
        )

        #expect(updated.displayPlaceName == "Office focus")
        #expect(updated.activity == .work)
        #expect(updated.note == "deep work block")
        #expect(updated.imageData == Data([0x02, 0x03]))
        #expect(updated.hasImage)
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
                imageData: nil,
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
            imageData: Data([0xA1, 0xB2, 0xC3]),
            startedAt: makeDate("2026-05-10T09:00:00Z"),
            endedAt: makeDate("2026-05-10T12:30:00Z"),
            createdAt: makeDate("2026-05-10T09:00:00Z"),
            updatedAt: makeDate("2026-05-10T12:30:00Z"),
            captureMode: .automatic,
            confirmedAt: makeDate("2026-05-10T09:05:00Z")
        )
        sourceContext.insert(session)
        try sourceContext.save()

        let packageURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        try SettingsRoutineDataPersistence.writeBackupPackage(
            to: packageURL,
            from: sourceContext,
            exportedAt: makeDate("2026-05-10T13:00:00Z")
        )

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            withBackupPackageAt: packageURL,
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
        #expect(restored.imageData == Data([0xA1, 0xB2, 0xC3]))
        #expect(restored.latitude == place.latitude)
        #expect(restored.longitude == place.longitude)
        #expect(restored.placeRadiusMeters == place.radiusMeters)
        #expect(restored.startedAt == session.startedAt)
        #expect(restored.endedAt == session.endedAt)
        #expect(restored.captureMode == .automatic)
        #expect(restored.confirmedAt == makeDate("2026-05-10T09:05:00Z"))
    }
}
