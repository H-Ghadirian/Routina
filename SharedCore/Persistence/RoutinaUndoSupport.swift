import Foundation
import SwiftData

enum RoutinaUndoSupport {
    @MainActor private static var undoManagerProvider: (() -> UndoManager?)?
    @MainActor private static var contextPreparer: ((ModelContext) -> Void)?
    @MainActor private static weak var activeUndoManager: UndoManager?
    @MainActor private static var activeScopedUndoHandler: (() -> Bool)?
    @MainActor private static var activeScopedRedoHandler: (() -> Bool)?

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
    static func setActiveUndoManager(_ undoManager: UndoManager?) {
        activeUndoManager = undoManager
    }

    @MainActor
    static func setActiveScopedUndo(
        undo: (() -> Bool)?,
        redo: (() -> Bool)?
    ) {
        activeScopedUndoHandler = undo
        activeScopedRedoHandler = redo
    }

    @MainActor
    static func clearActiveScopedUndo() {
        activeScopedUndoHandler = nil
        activeScopedRedoHandler = nil
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
    static var currentUndoManager: UndoManager? {
        activeUndoManager ?? undoManagerProvider?()
    }

    @MainActor
    static func removeUndoActions(withTarget target: AnyObject) {
        currentUndoManager?.removeAllActions(withTarget: target)
    }

    @MainActor
    @discardableResult
    static func performUndo() -> Bool {
        if activeScopedUndoHandler?() == true {
            return true
        }

        guard let undoManager = currentUndoManager,
              undoManager.canUndo
        else { return false }

        undoManager.undo()
        return true
    }

    @MainActor
    @discardableResult
    static func performRedo() -> Bool {
        if activeScopedRedoHandler?() == true {
            return true
        }

        guard let undoManager = currentUndoManager,
              undoManager.canRedo
        else { return false }

        undoManager.redo()
        return true
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
