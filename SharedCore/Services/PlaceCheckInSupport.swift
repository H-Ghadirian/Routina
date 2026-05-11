import Foundation
import SwiftData

enum PlaceCheckInSupport {
    @MainActor
    static func activeSession(in context: ModelContext) throws -> PlaceCheckInSession? {
        var descriptor = FetchDescriptor<PlaceCheckInSession>(
            predicate: #Predicate { session in
                session.endedAt == nil
            },
            sortBy: [
                SortDescriptor(\.startedAt, order: .reverse)
            ]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    @discardableResult
    static func checkIn(
        at place: RoutinePlace,
        activity: PlaceCheckInActivity? = nil,
        date: Date = Date(),
        in context: ModelContext
    ) throws -> PlaceCheckInSession {
        if
            let active = try activeSession(in: context),
            active.placeID == place.id,
            active.endedAt == nil
        {
            active.placeName = place.displayName
            active.latitude = place.latitude
            active.longitude = place.longitude
            active.horizontalAccuracyMeters = nil
            active.placeRadiusMeters = place.radiusMeters
            active.activity = activity ?? active.activity
            active.updatedAt = date
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
            return active
        }

        try endActiveSessions(at: date, in: context, saves: false)
        let session = PlaceCheckInSession(
            placeID: place.id,
            placeName: place.displayName,
            latitude: place.latitude,
            longitude: place.longitude,
            placeRadiusMeters: place.radiusMeters,
            activity: activity,
            startedAt: date,
            createdAt: date,
            updatedAt: date
        )
        context.insert(session)
        try context.save()
        NotificationCenter.default.postRoutineDidUpdate()
        return session
    }

    @MainActor
    @discardableResult
    static func checkIn(
        placeID: UUID,
        activity: PlaceCheckInActivity? = nil,
        date: Date = Date(),
        in context: ModelContext
    ) throws -> PlaceCheckInSession? {
        let descriptor = FetchDescriptor<RoutinePlace>(
            predicate: #Predicate { place in
                place.id == placeID
            }
        )
        guard let place = try context.fetch(descriptor).first else { return nil }
        return try checkIn(at: place, activity: activity, date: date, in: context)
    }

    @MainActor
    @discardableResult
    static func checkInAtCurrentLocation(
        coordinate: LocationCoordinate,
        horizontalAccuracyMeters: Double? = nil,
        activity: PlaceCheckInActivity? = nil,
        date: Date = Date(),
        in context: ModelContext
    ) throws -> PlaceCheckInSession {
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        if let place = nearestContainingPlace(to: coordinate, places: places) {
            return try checkIn(at: place, activity: activity, date: date, in: context)
        }

        if
            let active = try activeSession(in: context),
            isSameCurrentLocationSession(
                active,
                coordinate: coordinate,
                horizontalAccuracyMeters: horizontalAccuracyMeters
            )
        {
            active.placeName = "Current Location"
            active.latitude = coordinate.latitude
            active.longitude = coordinate.longitude
            active.horizontalAccuracyMeters = horizontalAccuracyMeters.map { max($0, 0) }
            active.placeRadiusMeters = nil
            active.activity = activity ?? active.activity
            active.updatedAt = date
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
            return active
        }

        try endActiveSessions(at: date, in: context, saves: false)
        let session = PlaceCheckInSession(
            placeID: nil,
            placeName: "Current Location",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            horizontalAccuracyMeters: horizontalAccuracyMeters,
            activity: activity,
            startedAt: date,
            createdAt: date,
            updatedAt: date
        )
        context.insert(session)
        try context.save()
        NotificationCenter.default.postRoutineDidUpdate()
        return session
    }

    @MainActor
    @discardableResult
    static func endActiveSession(
        at date: Date = Date(),
        in context: ModelContext
    ) throws -> PlaceCheckInSession? {
        let ended = try endActiveSessions(at: date, in: context, saves: true)
        return ended.first
    }

    @MainActor
    static func updateActiveActivity(
        _ activity: PlaceCheckInActivity?,
        date: Date = Date(),
        in context: ModelContext
    ) throws {
        guard let active = try activeSession(in: context) else { return }
        active.activity = activity
        active.updatedAt = date
        try context.save()
        NotificationCenter.default.postRoutineDidUpdate()
    }

    static func suggestedPlaces(
        places: [RoutinePlace],
        sessions: [PlaceCheckInSession],
        limit: Int = 5
    ) -> [RoutinePlace] {
        let placesByID = Dictionary(grouping: places, by: \.id).compactMapValues(\.first)
        var orderedIDs: [UUID] = []
        for session in sessions.sorted(by: compareSessionsByRecentUse) {
            guard let placeID = session.placeID,
                  placesByID[placeID] != nil,
                  !orderedIDs.contains(placeID)
            else { continue }
            orderedIDs.append(placeID)
        }

        let recentPlaces = orderedIDs.compactMap { placesByID[$0] }
        let remainingPlaces = places
            .filter { place in !orderedIDs.contains(place.id) }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
        return Array((recentPlaces + remainingPlaces).prefix(max(limit, 0)))
    }

    static func locationOrderedPlaces(
        places: [RoutinePlace],
        coordinate: LocationCoordinate?,
        sessions: [PlaceCheckInSession]
    ) -> [RoutinePlace] {
        guard let coordinate else {
            return suggestedPlaces(places: places, sessions: sessions, limit: places.count)
        }

        return places.sorted { lhs, rhs in
            let lhsContains = lhs.contains(coordinate)
            let rhsContains = rhs.contains(coordinate)
            if lhsContains != rhsContains {
                return lhsContains
            }

            let lhsDistance = lhs.distance(to: coordinate)
            let rhsDistance = rhs.distance(to: coordinate)
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    static func nearestContainingPlace(
        to coordinate: LocationCoordinate,
        places: [RoutinePlace]
    ) -> RoutinePlace? {
        places
            .filter { $0.contains(coordinate) }
            .min { lhs, rhs in
                lhs.distance(to: coordinate) < rhs.distance(to: coordinate)
            }
    }

    static func sessions(
        _ sessions: [PlaceCheckInSession],
        on day: Date,
        calendar: Calendar
    ) -> [PlaceCheckInSession] {
        sessions
            .filter { session in
                guard let timestamp = session.startedAt ?? session.createdAt else { return false }
                return calendar.isDate(timestamp, inSameDayAs: day)
            }
            .sorted { lhs, rhs in
                (lhs.startedAt ?? lhs.createdAt ?? .distantPast) < (rhs.startedAt ?? rhs.createdAt ?? .distantPast)
            }
    }

    static func totalDurationSeconds(
        for sessions: [PlaceCheckInSession],
        referenceDate: Date = Date()
    ) -> TimeInterval {
        sessions.reduce(0) { total, session in
            total + session.durationSeconds(referenceDate: referenceDate)
        }
    }

    private static func compareSessionsByRecentUse(
        _ lhs: PlaceCheckInSession,
        _ rhs: PlaceCheckInSession
    ) -> Bool {
        let lhsDate = lhs.endedAt ?? lhs.startedAt ?? lhs.createdAt ?? .distantPast
        let rhsDate = rhs.endedAt ?? rhs.startedAt ?? rhs.createdAt ?? .distantPast
        return lhsDate > rhsDate
    }

    private static func isSameCurrentLocationSession(
        _ session: PlaceCheckInSession,
        coordinate: LocationCoordinate,
        horizontalAccuracyMeters: Double?
    ) -> Bool {
        guard session.placeID == nil,
              let sessionCoordinate = session.coordinate
        else { return false }

        let tolerance = max(
            75,
            session.horizontalAccuracyMeters ?? 0,
            horizontalAccuracyMeters ?? 0
        )
        return sessionCoordinate.distance(to: coordinate) <= tolerance
    }

    @MainActor
    @discardableResult
    private static func endActiveSessions(
        at date: Date,
        in context: ModelContext,
        saves: Bool
    ) throws -> [PlaceCheckInSession] {
        let descriptor = FetchDescriptor<PlaceCheckInSession>(
            predicate: #Predicate { session in
                session.endedAt == nil
            }
        )
        let activeSessions = try context.fetch(descriptor)
        for session in activeSessions {
            session.end(at: date)
        }

        if saves, !activeSessions.isEmpty {
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
        }

        return activeSessions
    }
}
