import ComposableArchitecture
import Foundation
import SwiftData

enum HomeFeatureLifecycleEffectSupport {
    static func manualRefreshEffect<Action>(
        modelContext: @escaping @MainActor @Sendable () -> ModelContext,
        pullLatestIntoLocalStore: @escaping @MainActor @Sendable (ModelContext) async throws -> Void,
        sleepBeforeSecondRefresh: @escaping @Sendable () async throws -> Void,
        onAppearAction: @escaping @MainActor @Sendable () -> Action
    ) -> Effect<Action> {
        .run { @MainActor send in
            let context = modelContext()
            if context.hasChanges {
                try? context.save()
            }

            try? await pullLatestIntoLocalStore(context)
            send(onAppearAction())

            // CloudKit imports are asynchronous; do a second pass shortly after manual refresh.
            try? await sleepBeforeSecondRefresh()
            send(onAppearAction())
        }
    }
}
