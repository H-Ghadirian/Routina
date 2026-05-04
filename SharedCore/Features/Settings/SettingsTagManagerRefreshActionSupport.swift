import ComposableArchitecture
import Foundation
import SwiftData

enum SettingsTagManagerRefreshActionExecution {
    static func tagManagerAppeared(
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        .run { @MainActor send in
            send(.tagsLoaded(SettingsRefreshExecution.loadTagSummaries(
                modelContext: modelContext
            )))
            send(.fastFilterTagsLoaded(appSettingsClient.fastFilterTags()))
            send(.tagColorsLoaded(appSettingsClient.tagColors()))
            send(.relatedTagRulesLoaded(appSettingsClient.relatedTagRules()))
            send(.learnedRelatedTagRulesLoaded(
                RoutineTagRelations.learnedRules(
                    from: SettingsRefreshExecution.loadTaskTagCollections(
                        modelContext: modelContext
                    )
                )
            ))
        }
    }
}
