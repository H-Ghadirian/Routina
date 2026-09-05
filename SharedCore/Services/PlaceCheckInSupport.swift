import Foundation
import SwiftData

enum PlaceCheckInSessionEditError: Error, Equatable {
    case invalidDateRange
    case invalidPlaceName
    case missingSession
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
    static let rawCurrentLocationName = "Current Location"

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
        if let active = try activeSession(in: context),
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
        rawPlaceName: String? = nil,
        activity: PlaceCheckInActivity? = nil,
        date: Date = Date(),
        in context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> PlaceCheckInSession {
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let sessions = try context.fetch(FetchDescriptor<PlaceCheckInSession>())
        if let place = nearestContainingPlace(to: coordinate, places: places) {
            return try checkIn(at: place, activity: activity, date: date, in: context, sourceDevice: sourceDevice)
        }

        let cleanedRawPlaceName = RoutinePlace.cleanedName(rawPlaceName)
        let resolvedRawPlaceName =
            cleanedRawPlaceName
            ?? suggestedRawCurrentLocationName(
                coordinate: coordinate,
                places: places,
                sessions: sessions,
                date: date
            )

        if let active = try activeSession(in: context),
            isSameCurrentLocationSession(
                active,
                coordinate: coordinate,
                horizontalAccuracyMeters: horizontalAccuracyMeters
            )
        {
            if cleanedRawPlaceName != nil || isGeneratedRawCurrentLocationName(active.placeName) {
                active.placeName = resolvedRawPlaceName
            }
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
            placeName: resolvedRawPlaceName,
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
            if let active,
                shouldEndActiveAutomaticSession(
                    active,
                    coordinate: coordinate,
                    horizontalAccuracyMeters: horizontalAccuracyMeters,
                    places: places
                )
            {
                _ = try endActiveSession(at: date, in: context, sourceDevice: sourceDevice)
            }
            return nil
        }

        if let active,
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
    static func session(
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
