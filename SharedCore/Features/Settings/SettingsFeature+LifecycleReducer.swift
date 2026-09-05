import ComposableArchitecture

extension SettingsFeature {
    func reduceAppInteractionActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .openAppSettingsTapped:
            return .run { @MainActor _ in
                SettingsAppInteractionExecution.openNotificationSettings(
                    urlOpenerClient: urlOpenerClient
                )
            }
        case .openLocationSettingsTapped:
            return .run { @MainActor _ in
                SettingsAppInteractionExecution.openLocationSettings(
                    urlOpenerClient: urlOpenerClient
                )
            }
        case .contactUsTapped:
            return .run { @MainActor _ in
                SettingsAppInteractionExecution.contactSupport(
                    urlOpenerClient: urlOpenerClient
                )
            }
        case .aboutSectionLongPressed:
            state.diagnostics.isDebugSectionVisible = true
            return .none
        default:
            return .none
        }
    }

    func reduceRefreshActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .onAppear:
            SettingsRefreshEditor.hydrateOnAppear(
                SettingsDiagnosticsLoader.makeOnAppearSnapshot(
                    appInfoClient: appInfoClient,
                    appSettingsClient: appSettingsClient,
                    deviceAuthenticationClient: deviceAuthenticationClient,
                    gitHubConnection: gitHubStatsClient.loadConnectionStatus(),
                    gitLabConnection: gitLabStatsClient.loadConnectionStatus()
                ),
                state: &state
            )
            return .merge(
                SettingsRefreshActionExecution.refreshContext(
                    reconcileNotificationsIfEnabled: false,
                    modelContext: modelContext,
                    notificationClient: notificationClient,
                    locationClient: locationClient,
                    appSettingsClient: appSettingsClient
                ),
                SettingsRoutineDataTransferActionExecution.loadRecoveryPoints(
                    routineDataTransferClient: routineDataTransferClient
                )
            )
        case .tagManagerAppeared:
            return SettingsTagManagerRefreshActionExecution.tagManagerAppeared(
                modelContext: modelContext,
                appSettingsClient: appSettingsClient
            )
        case .onAppBecameActive:
            let notificationsEnabled = state.notifications.notificationsEnabled
            SettingsRefreshEditor.refreshOnAppBecameActive(
                hasTemporaryViewStateToReset: SettingsExecutionSupport.hasTemporaryViewStateToReset(
                    appSettingsClient: appSettingsClient
                ),
                appLockEnabled: appSettingsClient.appLockEnabled(),
                gitFeaturesEnabled: appSettingsClient.gitFeaturesEnabled(),
                taskSharingEnabled: appSettingsClient.taskSharingEnabled(),
                taskRelationshipVisualizerEnabled: appSettingsClient.taskRelationshipVisualizerEnabled(),
                placesEnabled: appSettingsClient.placesEnabled(),
                notesEnabled: appSettingsClient.notesEnabled(),
                awayEnabled: appSettingsClient.awayEnabled(),
                filterQuerySectionsEnabled: appSettingsClient.filterQuerySectionsEnabled(),
                lastRoutineDataBackupDate: appSettingsClient.lastRoutineDataBackupDate(),
                deviceAuthenticationStatus: deviceAuthenticationClient.status(),
                state: &state
            )
            return SettingsRefreshActionExecution.refreshContext(
                reconcileNotificationsIfEnabled: notificationsEnabled,
                modelContext: modelContext,
                notificationClient: notificationClient,
                locationClient: locationClient,
                appSettingsClient: appSettingsClient
            )
        default:
            return .none
        }
    }

    func reduceGitHubConnectionActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .gitHubScopeChanged(scope):
            return SettingsGitConnectionActionHandler.gitHubScopeChanged(
                scope,
                state: &state.github
            )
        case let .gitHubOwnerChanged(owner):
            return SettingsGitConnectionActionHandler.gitHubOwnerChanged(
                owner,
                state: &state.github
            )
        case let .gitHubRepositoryChanged(name):
            return SettingsGitConnectionActionHandler.gitHubRepositoryChanged(
                name,
                state: &state.github
            )
        case let .gitHubTokenChanged(token):
            return SettingsGitConnectionActionHandler.gitHubTokenChanged(
                token,
                state: &state.github
            )
        case .saveGitHubConnectionTapped:
            return SettingsGitConnectionActionHandler.saveGitHubConnectionTapped(
                state: &state.github,
                gitHubStatsClient: gitHubStatsClient
            )
        case .clearGitHubConnectionTapped:
            return SettingsGitConnectionActionHandler.clearGitHubConnectionTapped(
                state: &state.github,
                gitHubStatsClient: gitHubStatsClient
            )
        case let .gitHubConnectionUpdateFinished(connection, _, message):
            return SettingsGitConnectionActionHandler.gitHubConnectionUpdateFinished(
                connection: connection,
                message: message,
                state: &state.github
            )
        default:
            return .none
        }
    }

    func reduceGitLabConnectionActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .gitLabTokenChanged(token):
            return SettingsGitConnectionActionHandler.gitLabTokenChanged(
                token,
                state: &state.gitlab
            )
        case .saveGitLabConnectionTapped:
            return SettingsGitConnectionActionHandler.saveGitLabConnectionTapped(
                state: &state.gitlab,
                gitLabStatsClient: gitLabStatsClient
            )
        case .clearGitLabConnectionTapped:
            return SettingsGitConnectionActionHandler.clearGitLabConnectionTapped(
                state: &state.gitlab,
                gitLabStatsClient: gitLabStatsClient
            )
        case let .gitLabConnectionUpdateFinished(connection, _, message):
            return SettingsGitConnectionActionHandler.gitLabConnectionUpdateFinished(
                connection: connection,
                message: message,
                state: &state.gitlab
            )
        default:
            return .none
        }
    }

    func reduceCloudDiagnosticsActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .cloudDiagnosticsUpdated:
            let displayMessage = SettingsDiagnosticsLoader.refreshCloudDiagnostics(
                state: &state.diagnostics
            )
            if state.cloud.isCloudSyncInProgress, !displayMessage.isEmpty {
                state.cloud.cloudStatusMessage = displayMessage
            }
            return .none
        case let .cloudUsageEstimateLoaded(estimate):
            state.cloud.cloudUsageEstimate = estimate
            return .none
        case let .deviceSessionsLoaded(sessions):
            state.devices.sessions = sessions
            return .none
        default:
            return .none
        }
    }

    func reduceCloudActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .syncNowTapped:
            return SettingsCloudActionExecution.beginSync(
                state: &state.cloud,
                modelContext: modelContext,
                cloudSyncClient: cloudSyncClient
            )
        case let .setCloudDataResetConfirmation(isPresented):
            SettingsCloudEditor.setDataResetConfirmation(isPresented, state: &state.cloud)
            return .none
        case .resetCloudDataConfirmed:
            return SettingsCloudActionExecution.beginDataResetAuthentication(
                state: &state.cloud,
                dataTransferState: state.dataTransfer,
                referenceDate: now,
                appLockEnabled: appSettingsClient.appLockEnabled(),
                deviceAuthenticationClient: deviceAuthenticationClient
            )
        case let .cloudDataResetAuthenticationFinished(result):
            return SettingsCloudActionExecution.dataResetAuthenticationFinished(
                result,
                cloudContainerIdentifier: AppEnvironment.cloudKitContainerIdentifier,
                state: &state.cloud,
                dataTransferState: state.dataTransfer,
                referenceDate: now,
                modelContext: modelContext
            )
        case let .cloudSyncFinished(_, message):
            SettingsCloudEditor.finishSync(message: message, state: &state.cloud)
            return .none
        case let .cloudDataResetFinished(_, message):
            SettingsCloudEditor.finishDataReset(message: message, state: &state.cloud)
            return .none
        default:
            return .none
        }
    }
}
