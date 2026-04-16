import Foundation

enum SettingsCloudEditor {
    static func beginSync(
        state: inout SettingsCloudState
    ) -> Bool {
        guard !state.isCloudDataResetInProgress else {
            return false
        }
        guard state.cloudSyncAvailable else {
            state.cloudStatusMessage = "iCloud sync is disabled in this build."
            return false
        }

        state.isCloudSyncInProgress = true
        state.cloudStatusMessage = "Syncing with iCloud..."
        return true
    }

    static func setDataResetConfirmation(
        _ isPresented: Bool,
        state: inout SettingsCloudState
    ) {
        state.isCloudDataResetConfirmationPresented = isPresented
    }

    static func prepareDataReset(
        hasCloudContainerIdentifier: Bool,
        state: inout SettingsCloudState
    ) -> Bool {
        state.isCloudDataResetConfirmationPresented = false

        guard !state.isCloudSyncInProgress,
              !state.isCloudDataResetInProgress
        else {
            return false
        }

        guard state.cloudSyncAvailable, hasCloudContainerIdentifier else {
            state.cloudStatusMessage = "iCloud sync is disabled in this build."
            return false
        }

        state.isCloudDataResetInProgress = true
        state.cloudStatusMessage = "Deleting iCloud data..."
        return true
    }

    static func finishSync(
        message: String,
        state: inout SettingsCloudState
    ) {
        state.isCloudSyncInProgress = false
        state.cloudStatusMessage = message
    }

    static func finishDataReset(
        message: String,
        state: inout SettingsCloudState
    ) {
        state.isCloudDataResetInProgress = false
        state.cloudStatusMessage = message
    }
}
