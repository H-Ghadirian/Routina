import Foundation
import SwiftData

extension PlaceCheckInSupport {
    @MainActor
    @discardableResult
    static func linkSessionToPlace(
        sessionID: UUID,
        place: RoutinePlace,
        date: Date = Date(),
        in context: ModelContext,
        sourceDevice: RoutinaDeviceActivitySource? = nil
    ) throws -> PlaceCheckInSession {
        guard let session = try session(id: sessionID, in: context) else {
            throw PlaceCheckInSessionEditError.missingSession
        }

        session.placeID = place.id
        session.placeName = place.displayName
        if session.latitude == nil || session.longitude == nil {
            session.latitude = place.latitude
            session.longitude = place.longitude
        }
        session.placeRadiusMeters = place.radiusMeters
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

}
