import Foundation
import ComposableArchitecture
import SwiftData

enum SettingsTagExecution {
    static func rename(
        _ request: SettingsTagRenameRequest,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                let result = try SettingsTagPersistence.rename(request, in: context)
                NotificationCenter.default.postRoutineDidUpdate()
                NotificationCenter.default.postRoutineTagDidRename(
                    from: request.originalTagName,
                    to: request.cleanedName
                )
                send(.tagsLoaded(result.tagSummaries))
                send(.cloudUsageEstimateLoaded(result.cloudUsageEstimate))
                send(
                    .tagOperationFinished(
                        success: true,
                        message: SettingsFeedbackSupport.renameTagSuccessMessage(
                            updatedTagName: request.cleanedName,
                            updatedRoutineCount: result.updatedRoutineCount
                        )
                    )
                )
            } catch {
                send(
                    .tagOperationFinished(
                        success: false,
                        message: "Updating tag failed: \(error.localizedDescription)"
                    )
                )
            }
        }
    }

    static func delete(
        _ request: SettingsTagDeletionRequest,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                let result = try SettingsTagPersistence.delete(request, in: context)
                NotificationCenter.default.postRoutineDidUpdate()
                NotificationCenter.default.postRoutineTagDidDelete(request.tagName)
                send(.tagsLoaded(result.tagSummaries))
                send(.cloudUsageEstimateLoaded(result.cloudUsageEstimate))
                send(
                    .tagOperationFinished(
                        success: true,
                        message: SettingsFeedbackSupport.deleteTagSuccessMessage(
                            deletedTagName: request.tagName,
                            updatedRoutineCount: result.updatedRoutineCount
                        )
                    )
                )
            } catch {
                send(
                    .tagOperationFinished(
                        success: false,
                        message: "Deleting tag failed: \(error.localizedDescription)"
                    )
                )
            }
        }
    }
}
