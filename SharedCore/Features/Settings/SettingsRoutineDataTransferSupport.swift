import Foundation

enum SettingsRoutineDataTransferOperation: Equatable, Sendable {
    case export
    case `import`
    case verify

    var inProgressMessage: String {
        switch self {
        case .export:
            return "Saving task data..."
        case .import:
            return "Loading task data..."
        case .verify:
            return "Verifying backup..."
        }
    }
}

enum SettingsRoutineDataTransferEditor {
    static func begin(
        _ operation: SettingsRoutineDataTransferOperation,
        state: inout SettingsDataTransferState
    ) -> Bool {
        guard !state.isDataTransferInProgress else {
            return false
        }

        state.isDataTransferInProgress = true
        state.activeOperation = operation
        state.dataTransferStatusMessage = operation.inProgressMessage
        return true
    }

    static func finish(
        message: String,
        state: inout SettingsDataTransferState
    ) {
        state.isDataTransferInProgress = false
        state.activeOperation = nil
        state.dataTransferStatusMessage = message
    }
}
