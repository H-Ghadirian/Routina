import Foundation
import ComposableArchitecture
import SwiftData

enum SettingsPlaceExecution {
    static func save(
        _ request: SettingsPlaceSaveRequest,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                let result = try SettingsPlacePersistence.save(request, in: context)
                NotificationCenter.default.postRoutineDidUpdate()
                send(.placesLoaded(result.placeSummaries))
                send(.cloudUsageEstimateLoaded(result.cloudUsageEstimate))
                send(
                    .placeOperationFinished(
                        success: true,
                        message: "Saved \(request.cleanedName)."
                    )
                )
            } catch let error as SettingsPlacePersistenceError {
                send(
                    .placeOperationFinished(
                        success: false,
                        message: error.localizedDescription
                    )
                )
            } catch {
                send(
                    .placeOperationFinished(
                        success: false,
                        message: "Saving place failed: \(error.localizedDescription)"
                    )
                )
            }
        }
    }

    static func delete(
        _ request: SettingsPlaceDeletionRequest,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                let result = try SettingsPlacePersistence.delete(request, in: context)
                NotificationCenter.default.postRoutineDidUpdate()
                send(.placesLoaded(result.placeSummaries))
                send(.cloudUsageEstimateLoaded(result.cloudUsageEstimate))
                send(.placeOperationFinished(success: true, message: "Place deleted."))
            } catch {
                send(
                    .placeOperationFinished(
                        success: false,
                        message: "Deleting place failed: \(error.localizedDescription)"
                    )
                )
            }
        }
    }
}
