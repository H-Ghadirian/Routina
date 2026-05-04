import ComposableArchitecture
import Foundation

enum SettingsGitConnectionActionHandler {
    static func gitHubScopeChanged(
        _ scope: GitHubStatsScope,
        state: inout SettingsGitHubState
    ) -> Effect<SettingsFeature.Action> {
        state.scope = scope
        state.statusMessage = ""
        return .none
    }

    static func gitHubOwnerChanged(
        _ owner: String,
        state: inout SettingsGitHubState
    ) -> Effect<SettingsFeature.Action> {
        state.repositoryOwner = owner
        return .none
    }

    static func gitHubRepositoryChanged(
        _ name: String,
        state: inout SettingsGitHubState
    ) -> Effect<SettingsFeature.Action> {
        state.repositoryName = name
        return .none
    }

    static func gitHubTokenChanged(
        _ token: String,
        state: inout SettingsGitHubState
    ) -> Effect<SettingsFeature.Action> {
        state.accessTokenDraft = token
        return .none
    }

    static func saveGitHubConnectionTapped(
        state: inout SettingsGitHubState,
        gitHubStatsClient: GitHubStatsClient
    ) -> Effect<SettingsFeature.Action> {
        guard !state.isSaveDisabled else {
            if let validationMessage = state.saveValidationMessage {
                state.statusMessage = validationMessage
            }
            return .none
        }

        state.isOperationInProgress = true
        state.statusMessage = ""

        let configuration = GitHubStatsConfiguration(
            scope: state.scope,
            repository: state.scope == .repository
                ? GitHubRepositoryReference(
                    owner: state.repositoryOwner,
                    name: state.repositoryName
                )
                : nil,
            viewerLogin: nil
        )
        let accessToken = state.accessTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        return .run { send in
            do {
                let connection = try await gitHubStatsClient.saveConnection(
                    configuration,
                    accessToken.isEmpty ? nil : accessToken
                )
                let message: String = switch connection.scope {
                case .repository:
                    "Connected to \(connection.repository?.fullName ?? "repository")."
                case .profile:
                    "Connected to @\(connection.viewerLogin ?? "viewer") GitHub profile."
                }
                await send(
                    .gitHubConnectionUpdateFinished(
                        connection: connection,
                        success: true,
                        message: message
                    )
                )
            } catch {
                await send(
                    .gitHubConnectionUpdateFinished(
                        connection: gitHubStatsClient.loadConnectionStatus(),
                        success: false,
                        message: error.localizedDescription
                    )
                )
            }
        }
    }

    static func clearGitHubConnectionTapped(
        state: inout SettingsGitHubState,
        gitHubStatsClient: GitHubStatsClient
    ) -> Effect<SettingsFeature.Action> {
        state.isOperationInProgress = true
        state.statusMessage = ""
        let draftScope = state.scope

        return .run { send in
            do {
                try gitHubStatsClient.clearConnection()
                await send(
                    .gitHubConnectionUpdateFinished(
                        connection: .disconnected(scope: draftScope),
                        success: true,
                        message: "GitHub connection removed."
                    )
                )
            } catch {
                await send(
                    .gitHubConnectionUpdateFinished(
                        connection: gitHubStatsClient.loadConnectionStatus(),
                        success: false,
                        message: error.localizedDescription
                    )
                )
            }
        }
    }

    static func gitHubConnectionUpdateFinished(
        connection: GitHubConnectionStatus,
        message: String,
        state: inout SettingsGitHubState
    ) -> Effect<SettingsFeature.Action> {
        state.isOperationInProgress = false
        state.scope = connection.scope
        state.connectedScope = connection.scope
        state.connectedRepository = connection.repository
        state.connectedViewerLogin = connection.viewerLogin
        state.hasSavedAccessToken = connection.hasAccessToken
        state.statusMessage = message
        state.accessTokenDraft = ""
        state.repositoryOwner = connection.repository?.owner ?? ""
        state.repositoryName = connection.repository?.name ?? ""
        return .none
    }

    static func gitLabTokenChanged(
        _ token: String,
        state: inout SettingsGitLabState
    ) -> Effect<SettingsFeature.Action> {
        state.accessTokenDraft = token
        return .none
    }

    static func saveGitLabConnectionTapped(
        state: inout SettingsGitLabState,
        gitLabStatsClient: GitLabStatsClient
    ) -> Effect<SettingsFeature.Action> {
        guard !state.isSaveDisabled else {
            if let validationMessage = state.saveValidationMessage {
                state.statusMessage = validationMessage
            }
            return .none
        }

        state.isOperationInProgress = true
        state.statusMessage = ""
        let accessToken = state.accessTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)

        return .run { send in
            do {
                let connection = try await gitLabStatsClient.saveConnection(accessToken)
                let message = "Connected to @\(connection.username ?? "viewer") GitLab profile."
                await send(
                    .gitLabConnectionUpdateFinished(
                        connection: connection,
                        success: true,
                        message: message
                    )
                )
            } catch {
                await send(
                    .gitLabConnectionUpdateFinished(
                        connection: gitLabStatsClient.loadConnectionStatus(),
                        success: false,
                        message: error.localizedDescription
                    )
                )
            }
        }
    }

    static func clearGitLabConnectionTapped(
        state: inout SettingsGitLabState,
        gitLabStatsClient: GitLabStatsClient
    ) -> Effect<SettingsFeature.Action> {
        state.isOperationInProgress = true
        state.statusMessage = ""

        return .run { send in
            do {
                try gitLabStatsClient.clearConnection()
                await send(
                    .gitLabConnectionUpdateFinished(
                        connection: .disconnected,
                        success: true,
                        message: "GitLab connection removed."
                    )
                )
            } catch {
                await send(
                    .gitLabConnectionUpdateFinished(
                        connection: gitLabStatsClient.loadConnectionStatus(),
                        success: false,
                        message: error.localizedDescription
                    )
                )
            }
        }
    }

    static func gitLabConnectionUpdateFinished(
        connection: GitLabConnectionStatus,
        message: String,
        state: inout SettingsGitLabState
    ) -> Effect<SettingsFeature.Action> {
        state.isOperationInProgress = false
        state.connectedUsername = connection.username
        state.hasSavedAccessToken = connection.hasAccessToken
        state.statusMessage = message
        state.accessTokenDraft = ""
        return .none
    }
}
