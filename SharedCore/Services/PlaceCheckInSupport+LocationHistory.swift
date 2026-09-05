import Foundation

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

extension PlaceCheckInSupport {
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
        let remainingPlaces =
            places
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

    static func shouldEndActiveAutomaticSession(
        _ session: PlaceCheckInSession,
        coordinate: LocationCoordinate,
        horizontalAccuracyMeters: Double?,
        places: [RoutinePlace]
    ) -> Bool {
        guard session.isAutomatic else { return false }
        guard let sessionCoordinate = automaticSessionCoordinate(session, places: places) else {
            return true
        }

        let radiusMeters = max(automaticSessionRadius(session, places: places), 25)
        let exitGraceMeters = max(
            75,
            horizontalAccuracyMeters ?? 0,
            session.horizontalAccuracyMeters ?? 0
        )
        return sessionCoordinate.distance(to: coordinate) > radiusMeters + exitGraceMeters
    }

    private static func automaticSessionCoordinate(
        _ session: PlaceCheckInSession,
        places: [RoutinePlace]
    ) -> LocationCoordinate? {
        if let placeID = session.placeID,
            let place = places.first(where: { $0.id == placeID })
        {
            return LocationCoordinate(latitude: place.latitude, longitude: place.longitude)
        }

        return session.coordinate
    }

    private static func automaticSessionRadius(
        _ session: PlaceCheckInSession,
        places: [RoutinePlace]
    ) -> Double {
        if let placeID = session.placeID,
            let place = places.first(where: { $0.id == placeID })
        {
            return place.radiusMeters
        }

        return session.placeRadiusMeters ?? 150
    }

    static func suggestedRawCurrentLocationName(
        coordinate: LocationCoordinate,
        places: [RoutinePlace],
        sessions: [PlaceCheckInSession],
        date: Date,
        calendar: Calendar = .current
    ) -> String {
        if let previousName = previousNamedRawLocationName(
            coordinate: coordinate,
            sessions: sessions
        ) {
            return previousName
        }

        if let nearbyPlace = nearestNearbyPlace(to: coordinate, places: places) {
            return "Near \(nearbyPlace.displayName)"
        }

        return fallbackRawCurrentLocationName(date: date, calendar: calendar)
    }

    static func currentLocationDisplayName(
        coordinate: LocationCoordinate,
        places: [RoutinePlace],
        sessions: [PlaceCheckInSession]
    ) -> String? {
        if let place = nearestContainingPlace(to: coordinate, places: places) {
            return place.displayName
        }

        return previousNamedRawLocationName(
            coordinate: coordinate,
            sessions: sessions
        )
    }

    static func isGeneratedRawCurrentLocationName(_ name: String?) -> Bool {
        guard let cleanedName = RoutinePlace.cleanedName(name) else {
            return true
        }
        return cleanedName == rawCurrentLocationName
            || cleanedName.hasPrefix("Check-in at ")
            || cleanedName.hasPrefix("Near ")
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

        return
            sessions
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

        return
            sessionsByDay
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

    static func currentActiveSessionID(
        in sessions: [PlaceCheckInSession]
    ) -> UUID? {
        sessions
            .filter(\.isActive)
            .min(by: compareSessionsByActivePriority)?
            .id
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

    private static func compareSessionsByActivePriority(
        _ lhs: PlaceCheckInSession,
        _ rhs: PlaceCheckInSession
    ) -> Bool {
        let lhsDate = lhs.startedAt ?? lhs.createdAt ?? .distantPast
        let rhsDate = rhs.startedAt ?? rhs.createdAt ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }

        let lhsUpdatedAt = lhs.updatedAt ?? .distantPast
        let rhsUpdatedAt = rhs.updatedAt ?? .distantPast
        if lhsUpdatedAt != rhsUpdatedAt {
            return lhsUpdatedAt > rhsUpdatedAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    static func isSameCurrentLocationSession(
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

    private static func previousNamedRawLocationName(
        coordinate: LocationCoordinate,
        sessions: [PlaceCheckInSession]
    ) -> String? {
        sessions
            .filter { session in
                guard session.placeID == nil,
                    let sessionCoordinate = session.coordinate,
                    !isGeneratedRawCurrentLocationName(session.placeName)
                else { return false }
                return sessionCoordinate.distance(to: coordinate) <= 150
            }
            .sorted(by: compareSessionsByRecentUse)
            .compactMap { RoutinePlace.cleanedName($0.placeName) }
            .first
    }

    private static func nearestNearbyPlace(
        to coordinate: LocationCoordinate,
        places: [RoutinePlace]
    ) -> RoutinePlace? {
        places
            .filter { place in
                let nearbyThreshold = max(place.radiusMeters + 500, 300)
                return place.distance(to: coordinate) <= nearbyThreshold
            }
            .min { lhs, rhs in
                lhs.distance(to: coordinate) < rhs.distance(to: coordinate)
            }
    }

    private static func fallbackRawCurrentLocationName(
        date: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else {
            return rawCurrentLocationName
        }

        return "Check-in at \(String(format: "%02d:%02d", hour, minute))"
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

}
