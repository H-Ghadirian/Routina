import Foundation

enum SettingsCloudEditor {
    static let dataResetMinimumPasswordLength = 8

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
        clearDataResetPasswordDrafts(state: &state)
    }

    static func setDataResetPassword(
        _ password: String,
        state: inout SettingsCloudState
    ) {
        state.cloudDataResetPasswordDraft = password
    }

    static func setDataResetPasswordConfirmation(
        _ password: String,
        state: inout SettingsCloudState
    ) {
        state.cloudDataResetPasswordConfirmationDraft = password
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

        guard state.isCloudDataResetPasswordReady else {
            state.cloudStatusMessage = "Create and re-enter a matching deletion password first."
            return false
        }

        guard state.cloudSyncAvailable, hasCloudContainerIdentifier else {
            state.cloudStatusMessage = "iCloud sync is disabled in this build."
            return false
        }

        state.isCloudDataResetConfirmationPresented = false
        clearDataResetPasswordDrafts(state: &state)
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
        clearDataResetPasswordDrafts(state: &state)
        state.cloudStatusMessage = message
    }

    private static func clearDataResetPasswordDrafts(
        state: inout SettingsCloudState
    ) {
        state.cloudDataResetPasswordDraft = ""
        state.cloudDataResetPasswordConfirmationDraft = ""
    }
}
