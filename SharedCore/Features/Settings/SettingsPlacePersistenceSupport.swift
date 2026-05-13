import Foundation
import SwiftData

enum SettingsPlacePersistenceError: LocalizedError {
    case duplicateName

    var errorDescription: String? {
        switch self {
        case .duplicateName:
            return "A place with this name already exists."
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
        if try SettingsDataQueries.hasDuplicatePlaceName(request.cleanedName, in: context) {
            throw SettingsPlacePersistenceError.duplicateName
        }

        let place = RoutinePlace(
            name: request.cleanedName,
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
