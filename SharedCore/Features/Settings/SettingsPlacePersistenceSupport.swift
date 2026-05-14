import Foundation
import SwiftData

enum SettingsPlacePersistenceError: LocalizedError {
    case invalidName
    case duplicateName
    case missingPlace

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "Enter a place name."
        case .duplicateName:
            return "A place with this name already exists."
        case .missingPlace:
            return "Place could not be found."
        }
    }
}

struct SettingsPlacePersistenceResult {
    var placeSummaries: [RoutinePlaceSummary]
    var cloudUsageEstimate: CloudUsageEstimate
}

enum SettingsPlacePersistence {
    @MainActor
    static func save(
        _ request: SettingsPlaceSaveRequest,
        in context: ModelContext
    ) throws -> SettingsPlacePersistenceResult {
        guard let cleanedName = RoutinePlace.cleanedName(request.cleanedName) else {
            throw SettingsPlacePersistenceError.invalidName
        }

        if try SettingsDataQueries.hasDuplicatePlaceName(cleanedName, in: context) {
            throw SettingsPlacePersistenceError.duplicateName
        }

        let place = RoutinePlace(
            name: cleanedName,
            latitude: request.coordinate.latitude,
            longitude: request.coordinate.longitude,
            radiusMeters: request.radiusMeters
        )
        context.insert(place)
        DeviceActivityRecorder.recordAction(
            .created,
            entity: .place,
            entityID: place.id,
            entityTitle: place.displayName,
            in: context
        )
        try context.save()

        return SettingsPlacePersistenceResult(
            placeSummaries: try SettingsDataQueries.fetchPlaceSummaries(in: context),
            cloudUsageEstimate: SettingsDataQueries.loadCloudUsageEstimate(in: context)
        )
    }

    @MainActor
    static func update(
        _ request: SettingsPlaceUpdateRequest,
        in context: ModelContext
    ) throws -> SettingsPlacePersistenceResult {
        guard let cleanedName = RoutinePlace.cleanedName(request.cleanedName) else {
            throw SettingsPlacePersistenceError.invalidName
        }

        if try SettingsDataQueries.hasDuplicatePlaceName(
            cleanedName,
            excluding: request.placeID,
            in: context
        ) {
            throw SettingsPlacePersistenceError.duplicateName
        }

        let placeID = request.placeID
        let descriptor = FetchDescriptor<RoutinePlace>(
            predicate: #Predicate { place in
                place.id == placeID
            }
        )

        guard let place = try context.fetch(descriptor).first else {
            throw SettingsPlacePersistenceError.missingPlace
        }

        place.name = cleanedName
        place.latitude = request.coordinate.latitude
        place.longitude = request.coordinate.longitude
        place.radiusMeters = min(max(request.radiusMeters, 25), 2_000)

        let activeSessions = try context.fetch(FetchDescriptor<PlaceCheckInSession>())
        for session in activeSessions where session.placeID == placeID && session.endedAt == nil {
            session.placeName = place.displayName
            session.latitude = place.latitude
            session.longitude = place.longitude
            session.placeRadiusMeters = place.radiusMeters
            session.updatedAt = Date()
        }

        DeviceActivityRecorder.recordAction(
            .updated,
            entity: .place,
            entityID: place.id,
            entityTitle: place.displayName,
            in: context
        )
        try context.save()

        return SettingsPlacePersistenceResult(
            placeSummaries: try SettingsDataQueries.fetchPlaceSummaries(in: context),
            cloudUsageEstimate: SettingsDataQueries.loadCloudUsageEstimate(in: context)
        )
    }

    @MainActor
    static func delete(
        _ request: SettingsPlaceDeletionRequest,
        in context: ModelContext
    ) throws -> SettingsPlacePersistenceResult {
        let placeID = request.placeID
        let placeDescriptor = FetchDescriptor<RoutinePlace>(
            predicate: #Predicate { place in
                place.id == placeID
            }
        )

        if let place = try context.fetch(placeDescriptor).first {
            let title = place.displayName
            context.delete(place)
            DeviceActivityRecorder.recordAction(
                .deleted,
                entity: .place,
                entityID: placeID,
                entityTitle: title,
                in: context
            )
        }

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks where task.placeID == placeID {
            task.placeID = nil
        }

        try context.save()

        return SettingsPlacePersistenceResult(
            placeSummaries: try SettingsDataQueries.fetchPlaceSummaries(in: context),
            cloudUsageEstimate: SettingsDataQueries.loadCloudUsageEstimate(in: context)
        )
    }
}
