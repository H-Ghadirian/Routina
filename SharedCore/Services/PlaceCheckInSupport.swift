import Foundation
import SwiftData

enum PlaceCheckInSessionEditError: Error, Equatable {
    case invalidDateRange
    case invalidPlaceName
    case missingSession
}

struct PlaceCheckInHistoryMapMarker: Equatable, Identifiable {
    let id: String
    var placeID: UUID?
    var placeName: String
    var coordinate: LocationCoordinate
    var count: Int
    var latestDate: Date?
    var containsActiveSession: Bool

    var title: String {
        if count == 1 {
            return placeName
        }
        return "\(placeName) (\(count))"
    }

    var accessibilityLabel: String {
        if count == 1 {
            return "Check-in at \(placeName)"
        }
        return "\(count) check-ins at \(placeName)"
    }
}

struct PlaceCheckInDaySection: Equatable, Identifiable {
    let date: Date
    var sessions: [PlaceCheckInSession]

    var id: Date { date }
}

extension PlaceCheckInSessionEditError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidDateRange:
            return "The check-in end time cannot be before the start time."
        case .invalidPlaceName:
            return "The check-in needs a place name."
        case .missingSession:
            return "That check-in no longer exists."
        }
    }
}

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
        in context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
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
            if active.requiresConfirmation {
                active.confirmedAt = date
            }
            active.updatedAt = date
            DeviceActivityRecorder.recordAction(
                .updated,
                entity: .placeCheckIn,
                entityID: active.id,
                entityTitle: active.displayPlaceName,
                sourceDevice: sourceDevice,
                at: date,
                in: context
            )
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
            return active
        }

        try endActiveSessions(at: date, in: context, saves: false, sourceDevice: sourceDevice)
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
        DeviceActivityRecorder.recordAction(
            .started,
            entity: .placeCheckIn,
            entityID: session.id,
            entityTitle: session.displayPlaceName,
            sourceDevice: sourceDevice,
            at: date,
            in: context
        )
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
        in context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> PlaceCheckInSession? {
        let descriptor = FetchDescriptor<RoutinePlace>(
            predicate: #Predicate { place in
                place.id == placeID
            }
        )
        guard let place = try context.fetch(descriptor).first else { return nil }
        return try checkIn(at: place, activity: activity, date: date, in: context, sourceDevice: sourceDevice)
    }

    @MainActor
    @discardableResult
    static func checkInAtCurrentLocation(
        coordinate: LocationCoordinate,
        horizontalAccuracyMeters: Double? = nil,
        activity: PlaceCheckInActivity? = nil,
        date: Date = Date(),
        in context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> PlaceCheckInSession {
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        if let place = nearestContainingPlace(to: coordinate, places: places) {
            return try checkIn(at: place, activity: activity, date: date, in: context, sourceDevice: sourceDevice)
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
            DeviceActivityRecorder.recordAction(
                .updated,
                entity: .placeCheckIn,
                entityID: active.id,
                entityTitle: active.displayPlaceName,
                sourceDevice: sourceDevice,
                at: date,
                in: context
            )
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
            return active
        }

        try endActiveSessions(at: date, in: context, saves: false, sourceDevice: sourceDevice)
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
        DeviceActivityRecorder.recordAction(
            .started,
            entity: .placeCheckIn,
            entityID: session.id,
            entityTitle: session.displayPlaceName,
            sourceDevice: sourceDevice,
            at: date,
            in: context
        )
        try context.save()
        NotificationCenter.default.postRoutineDidUpdate()
        return session
    }

    @MainActor
    @discardableResult
    static func reconcileAutomaticCheckIn(
        coordinate: LocationCoordinate,
        horizontalAccuracyMeters: Double? = nil,
        activity: PlaceCheckInActivity? = nil,
        date: Date = Date(),
        in context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> PlaceCheckInSession? {
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let active = try activeSession(in: context)

        guard let place = nearestContainingPlace(to: coordinate, places: places) else {
            if let active, active.isAutomatic {
                _ = try endActiveSession(at: date, in: context, sourceDevice: sourceDevice)
            }
            return nil
        }

        if
            let active,
            active.placeID == place.id,
            active.endedAt == nil
        {
            return active
        }

        try endActiveSessions(at: date, in: context, saves: false, sourceDevice: sourceDevice)
        let session = PlaceCheckInSession(
            placeID: place.id,
            placeName: place.displayName,
            latitude: place.latitude,
            longitude: place.longitude,
            horizontalAccuracyMeters: nil,
            placeRadiusMeters: place.radiusMeters,
            activity: activity,
            startedAt: date,
            createdAt: date,
            updatedAt: date,
            captureMode: .automatic
        )
        context.insert(session)
        DeviceActivityRecorder.recordAction(
            .started,
            entity: .placeCheckIn,
            entityID: session.id,
            entityTitle: session.displayPlaceName,
            details: "Automatic saved-place check-in",
            sourceDevice: sourceDevice,
            at: date,
            in: context
        )
        try context.save()
        NotificationCenter.default.postRoutineDidUpdate()
        return session
    }

    @MainActor
    @discardableResult
    static func endActiveSession(
        at date: Date = Date(),
        in context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> PlaceCheckInSession? {
        let ended = try endActiveSessions(at: date, in: context, saves: true, sourceDevice: sourceDevice)
        return ended.first
    }

    @MainActor
    @discardableResult
    static func endActiveAutomaticSession(
        at date: Date = Date(),
        in context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> PlaceCheckInSession? {
        guard let active = try activeSession(in: context), active.isAutomatic else {
            return nil
        }
        return try endActiveSession(at: date, in: context, sourceDevice: sourceDevice)
    }

    @MainActor
    @discardableResult
    static func confirmAutomaticSession(
        id: UUID,
        date: Date = Date(),
        in context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> PlaceCheckInSession {
        guard let session = try session(id: id, in: context) else {
            throw PlaceCheckInSessionEditError.missingSession
        }

        session.confirmedAt = date
        session.updatedAt = date
        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .placeCheckIn,
            entityID: session.id,
            entityTitle: session.displayPlaceName,
            details: "Confirmed automatic check-in",
            sourceDevice: sourceDevice,
            at: date,
            in: context
        )
        try context.save()
        NotificationCenter.default.postRoutineDidUpdate()
        return session
    }

    @MainActor
    static func updateActiveActivity(
        _ activity: PlaceCheckInActivity?,
        date: Date = Date(),
        in context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws {
        guard let active = try activeSession(in: context) else { return }
        active.activity = activity
        active.updatedAt = date
        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .placeCheckIn,
            entityID: active.id,
            entityTitle: active.displayPlaceName,
            sourceDevice: sourceDevice,
            at: date,
            in: context
        )
        try context.save()
        NotificationCenter.default.postRoutineDidUpdate()
    }

    @MainActor
    @discardableResult
    static func updateSession(
        id: UUID,
        placeName: String,
        activity: PlaceCheckInActivity?,
        note: String?,
        imageData: Data?,
        startedAt: Date,
        endedAt: Date?,
        updatedAt date: Date = Date(),
        in context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> PlaceCheckInSession {
        guard let cleanedPlaceName = RoutinePlace.cleanedName(placeName) else {
            throw PlaceCheckInSessionEditError.invalidPlaceName
        }
        if let endedAt, endedAt < startedAt {
            throw PlaceCheckInSessionEditError.invalidDateRange
        }

        guard let session = try session(id: id, in: context) else {
            throw PlaceCheckInSessionEditError.missingSession
        }

        session.placeName = cleanedPlaceName
        session.activity = activity
        session.note = PlaceCheckInSession.cleanedNote(note)
        session.imageData = imageData
        session.startedAt = startedAt
        session.endedAt = endedAt
        session.updatedAt = date
        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .placeCheckIn,
            entityID: session.id,
            entityTitle: session.displayPlaceName,
            sourceDevice: sourceDevice,
            at: date,
            in: context
        )
        try context.save()
        NotificationCenter.default.postRoutineDidUpdate()
        return session
    }

    @MainActor
    @discardableResult
    static func deleteSession(
        id: UUID,
        in context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> Bool {
        guard let session = try session(id: id, in: context) else {
            return false
        }

        let title = session.displayPlaceName
        context.delete(session)
        DeviceActivityRecorder.recordAction(
            .deleted,
            entity: .placeCheckIn,
            entityID: id,
            entityTitle: title,
            sourceDevice: sourceDevice,
            in: context
        )
        try context.save()
        NotificationCenter.default.postRoutineDidUpdate()
        return true
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
        calendar: Calendar,
        referenceDate: Date = Date()
    ) -> [PlaceCheckInSession] {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }

        return sessions
            .filter { session in
                sessionOverlaps(
                    session,
                    dayStart: dayStart,
                    dayEnd: dayEnd,
                    referenceDate: referenceDate
                )
            }
            .sorted { lhs, rhs in
                let lhsStart = effectiveStartDate(lhs, dayStart: dayStart)
                let rhsStart = effectiveStartDate(rhs, dayStart: dayStart)
                if lhsStart != rhsStart {
                    return lhsStart < rhsStart
                }
                return (lhs.startedAt ?? lhs.createdAt ?? .distantPast) < (rhs.startedAt ?? rhs.createdAt ?? .distantPast)
            }
    }

    static func groupedSessionsByDay(
        _ sessions: [PlaceCheckInSession],
        calendar: Calendar
    ) -> [PlaceCheckInDaySection] {
        var sessionsByDay: [Date: [PlaceCheckInSession]] = [:]
        for session in sessions {
            guard let date = timelineDate(for: session) else { continue }
            sessionsByDay[calendar.startOfDay(for: date), default: []].append(session)
        }

        return sessionsByDay
            .map { date, sessions in
                PlaceCheckInDaySection(
                    date: date,
                    sessions: sessions.sorted { lhs, rhs in
                        let lhsDate = timelineDate(for: lhs) ?? .distantPast
                        let rhsDate = timelineDate(for: rhs) ?? .distantPast
                        if lhsDate != rhsDate {
                            return lhsDate > rhsDate
                        }
                        return lhs.displayPlaceName.localizedCaseInsensitiveCompare(rhs.displayPlaceName) == .orderedAscending
                    }
                )
            }
            .sorted { lhs, rhs in
                lhs.date > rhs.date
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

    static func totalDurationSeconds(
        for sessions: [PlaceCheckInSession],
        on day: Date,
        calendar: Calendar,
        referenceDate: Date = Date()
    ) -> TimeInterval {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return 0
        }

        return sessions.reduce(0) { total, session in
            guard let startedAt = session.startedAt ?? session.createdAt else {
                return total
            }

            let finishedAt = session.endedAt ?? referenceDate
            let normalizedFinish = finishedAt > startedAt ? finishedAt : startedAt
            let clampedStart = startedAt > dayStart ? startedAt : dayStart
            let clampedFinish = normalizedFinish < dayEnd ? normalizedFinish : dayEnd
            return total + max(0, clampedFinish.timeIntervalSince(clampedStart))
        }
    }

    static func historyMapMarkers(
        from sessions: [PlaceCheckInSession]
    ) -> [PlaceCheckInHistoryMapMarker] {
        var markersByID: [String: PlaceCheckInHistoryMapMarker] = [:]

        for session in sessions {
            guard let coordinate = session.coordinate else { continue }

            let markerID = historyMapMarkerID(for: coordinate)
            let latestDate = recentUseDate(for: session)
            if var marker = markersByID[markerID] {
                marker.count += 1
                marker.containsActiveSession = marker.containsActiveSession || session.isActive

                if (latestDate ?? .distantPast) >= (marker.latestDate ?? .distantPast) {
                    marker.placeID = session.placeID
                    marker.placeName = session.displayPlaceName
                    marker.coordinate = coordinate
                    marker.latestDate = latestDate
                }
                markersByID[markerID] = marker
            } else {
                markersByID[markerID] = PlaceCheckInHistoryMapMarker(
                    id: markerID,
                    placeID: session.placeID,
                    placeName: session.displayPlaceName,
                    coordinate: coordinate,
                    count: 1,
                    latestDate: latestDate,
                    containsActiveSession: session.isActive
                )
            }
        }

        return markersByID.values.sorted { lhs, rhs in
            if lhs.containsActiveSession != rhs.containsActiveSession {
                return lhs.containsActiveSession
            }

            let lhsDate = lhs.latestDate ?? .distantPast
            let rhsDate = rhs.latestDate ?? .distantPast
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }

            return lhs.placeName.localizedCaseInsensitiveCompare(rhs.placeName) == .orderedAscending
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

    private static func sessionOverlaps(
        _ session: PlaceCheckInSession,
        dayStart: Date,
        dayEnd: Date,
        referenceDate: Date
    ) -> Bool {
        guard let startedAt = session.startedAt ?? session.createdAt else {
            return false
        }

        let finishedAt = session.endedAt ?? referenceDate
        let normalizedFinish = finishedAt > startedAt ? finishedAt : startedAt
        return startedAt < dayEnd && normalizedFinish > dayStart
    }

    private static func effectiveStartDate(
        _ session: PlaceCheckInSession,
        dayStart: Date
    ) -> Date {
        let startedAt = session.startedAt ?? session.createdAt ?? .distantPast
        return startedAt > dayStart ? startedAt : dayStart
    }

    private static func timelineDate(for session: PlaceCheckInSession) -> Date? {
        session.startedAt ?? session.createdAt ?? session.endedAt
    }

    private static func recentUseDate(for session: PlaceCheckInSession) -> Date? {
        session.endedAt ?? session.startedAt ?? session.createdAt
    }

    static func historyMapMarkerID(for coordinate: LocationCoordinate) -> String {
        let latitudeBucket = Int((coordinate.latitude * 100_000).rounded())
        let longitudeBucket = Int((coordinate.longitude * 100_000).rounded())
        return "\(latitudeBucket):\(longitudeBucket)"
    }

    @MainActor
    private static func session(
        id: UUID,
        in context: ModelContext
    ) throws -> PlaceCheckInSession? {
        var descriptor = FetchDescriptor<PlaceCheckInSession>(
            predicate: #Predicate { session in
                session.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    @discardableResult
    private static func endActiveSessions(
        at date: Date,
        in context: ModelContext,
        saves: Bool,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> [PlaceCheckInSession] {
        let descriptor = FetchDescriptor<PlaceCheckInSession>(
            predicate: #Predicate { session in
                session.endedAt == nil
            }
        )
        let activeSessions = try context.fetch(descriptor)
        for session in activeSessions {
            session.end(at: date)
            DeviceActivityRecorder.recordAction(
                .ended,
                entity: .placeCheckIn,
                entityID: session.id,
                entityTitle: session.displayPlaceName,
                sourceDevice: sourceDevice,
                at: date,
                in: context
            )
        }

        if saves, !activeSessions.isEmpty {
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
        }

        return activeSessions
    }
}
