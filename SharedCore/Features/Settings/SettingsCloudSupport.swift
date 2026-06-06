import Foundation

enum SettingsCloudEditor {
    static let recentBackupRequiredMessage = "Save a backup within the last 24 hours before deleting iCloud data."

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

    static func beginDataResetAuthentication(
        appLockEnabled: Bool,
        hasRecentBackup: Bool,
        state: inout SettingsCloudState
    ) -> Bool {
        guard !state.isCloudSyncInProgress,
              !state.isCloudDataResetInProgress,
              !state.isCloudDataResetAuthenticationInProgress
        else {
            return false
        }

        guard state.cloudSyncAvailable else {
            state.cloudStatusMessage = "iCloud sync is disabled in this build."
            return false
        }

        guard hasRecentBackup else {
            state.cloudStatusMessage = recentBackupRequiredMessage
            return false
        }

        guard appLockEnabled else {
            state.cloudStatusMessage = "Turn on App Lock before deleting iCloud data."
            return false
        }

        state.isCloudDataResetAuthenticationInProgress = true
        state.cloudStatusMessage = "Confirming App Lock..."
        return true
    }

    static func finishDataResetAuthentication(
        _ result: DeviceAuthenticationResult,
        state: inout SettingsCloudState
    ) -> Bool {
        state.isCloudDataResetAuthenticationInProgress = false

        switch result {
        case .success:
            state.cloudStatusMessage = ""
            return true
        case let .failure(message):
            state.cloudStatusMessage = message
            return false
        }
    }

    static func prepareDataReset(
        hasCloudContainerIdentifier: Bool,
        state: inout SettingsCloudState
    ) -> Bool {
        guard !state.isCloudSyncInProgress,
              !state.isCloudDataResetInProgress
        else {
            return false
        }

        guard state.cloudSyncAvailable, hasCloudContainerIdentifier else {
            state.cloudStatusMessage = "iCloud sync is disabled in this build."
            return false
        }

        state.isCloudDataResetConfirmationPresented = false
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
