import Foundation

enum SettingsRoutineDataTransferOperation: Equatable {
    case export
    case `import`

    var inProgressMessage: String {
        switch self {
        case .export:
            return "Saving routine data..."
        case .import:
            return "Loading routine data..."
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
        state.dataTransferStatusMessage = operation.inProgressMessage
        return true
    }

    static func finish(
        message: String,
        state: inout SettingsDataTransferState
    ) {
        state.isDataTransferInProgress = false
        state.dataTransferStatusMessage = message
    }
}
