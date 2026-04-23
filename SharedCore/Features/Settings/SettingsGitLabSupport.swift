import Foundation

extension SettingsGitLabState {
    var overviewSubtitle: String {
        if let connectedUsername, !connectedUsername.isEmpty {
            return "@\(connectedUsername) profile activity"
        }
        return "Connect GitLab to show your contribution graph"
    }

    var detailSubtitle: String {
        "Connect your GitLab account to show your contribution activity, including private events."
    }

    var profileSummaryText: String {
        if let connectedUsername, !connectedUsername.isEmpty {
            return "@\(connectedUsername)"
        }
        return "Uses the authenticated GitLab account"
    }

    var tokenStatusText: String {
        if hasSavedAccessToken {
            return accessTokenDraft.isEmpty
                ? "A token is already saved in Keychain. Leave the field empty to keep it."
                : "A new token will replace the saved one."
        }
        return "Required. Create a token at gitlab.com with the read_api scope. Stored in Keychain."
    }

    var saveValidationMessage: String? {
        let trimmed = accessTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasSavedAccessToken || !trimmed.isEmpty {
            return nil
        }
        return "Add a personal access token to load profile activity."
    }

    var isSaveDisabled: Bool {
        isOperationInProgress || saveValidationMessage != nil
    }

    var removeButtonDisabled: Bool {
        isOperationInProgress || !isConnected
    }

    var infoText: String {
        "Profile mode reads the authenticated account's events over the past year. The personal access token needs the read_api scope and is stored in Keychain."
    }

    var saveButtonTitle: String { "Connect Profile" }
}
