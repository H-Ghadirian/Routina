import Foundation
import SwiftData

enum RoutinaUndoSupport {
    @MainActor private static var undoManagerProvider: (() -> UndoManager?)?
    @MainActor private static var contextPreparer: ((ModelContext) -> Void)?

    @MainActor
    static func configure(
        undoManagerProvider: @escaping () -> UndoManager?,
        contextPreparer: @escaping (ModelContext) -> Void
    ) {
        self.undoManagerProvider = undoManagerProvider
        self.contextPreparer = contextPreparer
    }

    @MainActor
    static func prepareContext(_ context: ModelContext) {
        contextPreparer?(context)
    }

    @MainActor
    static func undoableMutationContext(from sourceContext: ModelContext) -> ModelContext {
        guard undoManagerProvider?() != nil else {
            return ModelContext(sourceContext.container)
        }

        contextPreparer?(sourceContext)
        return sourceContext
    }

    @MainActor
    static func performWithoutUndo<Result>(_ operation: () throws -> Result) rethrows -> Result {
        guard let undoManager = undoManagerProvider?(),
              undoManager.isUndoRegistrationEnabled
        else {
            return try operation()
        }

        undoManager.disableUndoRegistration()
        defer { undoManager.enableUndoRegistration() }
        return try operation()
    }
}
