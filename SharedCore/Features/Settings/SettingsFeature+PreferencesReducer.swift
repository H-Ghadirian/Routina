import ComposableArchitecture

extension SettingsFeature {
    func reduceDisplayPreferenceActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .appColorSchemeChanged(scheme):
            return SettingsAppearanceActionHandler.appColorSchemeChanged(
                scheme,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .routineListSectioningModeChanged(mode):
            return SettingsAppearanceActionHandler.routineListSectioningModeChanged(
                mode,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .tagCounterDisplayModeChanged(mode):
            return SettingsAppearanceActionHandler.tagCounterDisplayModeChanged(
                mode,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .taskRowFieldVisibilityChanged(field, isVisible):
            return SettingsAppearanceActionHandler.taskRowFieldVisibilityChanged(
                field,
                isVisible: isVisible,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .taskRowMultilineTitlesChanged(isEnabled):
            return SettingsAppearanceActionHandler.taskRowMultilineTitlesChanged(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .taskRowMultilineDetailsChanged(isEnabled):
            return SettingsAppearanceActionHandler.taskRowMultilineDetailsChanged(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .timelineRowFieldVisibilityChanged(field, isVisible):
            return SettingsAppearanceActionHandler.timelineRowFieldVisibilityChanged(
                field,
                isVisible: isVisible,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        default:
            return .none
        }
    }

    func reduceSecurityPreferenceActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .appLockToggled(isEnabled):
            return SettingsAppearanceActionHandler.appLockToggled(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient,
                deviceAuthenticationClient: deviceAuthenticationClient
            )
        case let .appLockEnableFinished(result):
            return SettingsAppearanceActionHandler.appLockEnableFinished(
                result,
                state: &state.appearance,
                appSettingsClient: appSettingsClient,
                deviceAuthenticationClient: deviceAuthenticationClient
            )
        case let .appLockDisableFinished(result):
            return SettingsAppearanceActionHandler.appLockDisableFinished(
                result,
                state: &state.appearance,
                appSettingsClient: appSettingsClient,
                deviceAuthenticationClient: deviceAuthenticationClient
            )
        case .resetAllSettingsToDefaultsTapped:
            return SettingsAppearanceActionHandler.resetAllSettingsToDefaultsTapped(
                state: &state.appearance,
                appSettingsClient: appSettingsClient,
                deviceAuthenticationClient: deviceAuthenticationClient
            )
        case let .settingsDefaultsResetAuthenticationFinished(result):
            return SettingsAppearanceActionHandler.settingsDefaultsResetAuthenticationFinished(
                result,
                state: &state,
                appSettingsClient: appSettingsClient,
                deviceAuthenticationClient: deviceAuthenticationClient,
                notificationClient: notificationClient,
                referenceDate: now
            )
        default:
            return .none
        }
    }

    func reduceFeatureAvailabilityPreferenceActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .gitFeaturesToggled(isEnabled):
            return SettingsAppearanceActionHandler.gitFeaturesToggled(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .taskSharingToggled(isEnabled):
            return SettingsAppearanceActionHandler.taskSharingToggled(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .taskRelationshipVisualizerToggled(isEnabled):
            return SettingsAppearanceActionHandler.taskRelationshipVisualizerToggled(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .placesToggled(isEnabled):
            return SettingsAppearanceActionHandler.placesToggled(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .notesToggled(isEnabled):
            return SettingsAppearanceActionHandler.notesToggled(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .awayToggled(isEnabled):
            return SettingsAppearanceActionHandler.awayToggled(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .filterQuerySectionsToggled(isEnabled):
            return SettingsAppearanceActionHandler.filterQuerySectionsToggled(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .showPersianDatesToggled(isEnabled):
            return SettingsAppearanceActionHandler.showPersianDatesToggled(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .showTimelineTasksInDayPlannerToggled(isEnabled):
            return SettingsAppearanceActionHandler.showTimelineTasksInDayPlannerToggled(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .separateDailyRoutinesInTaskListToggled(isEnabled):
            return SettingsAppearanceActionHandler.separateDailyRoutinesInTaskListToggled(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .showTomorrowInTaskListToggled(isEnabled):
            return SettingsAppearanceActionHandler.showTomorrowInTaskListToggled(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .showDoneCountInToolbarToggled(isEnabled):
            return SettingsAppearanceActionHandler.showDoneCountInToolbarToggled(
                isEnabled,
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        default:
            return .none
        }
    }

    func reduceNotificationAuthorizationActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .toggleNotifications(isOn):
            guard isOn else {
                SettingsNotificationsEditor.setNotificationsEnabled(
                    false,
                    state: &state.notifications
                )
                SettingsNotificationsEditor.clearScheduledNotifications(
                    state: &state.notifications
                )
                appSettingsClient.setNotificationsEnabled(false)
                return .run { _ in
                    await SettingsNotificationsExecution.disableNotifications(
                        notificationClient: notificationClient
                    )
                }
            }

            return .run { send in
                let granted = await SettingsNotificationsExecution.requestAuthorization(
                    notificationClient: notificationClient
                )
                await send(.notificationAuthorizationFinished(granted))
            }
        case let .notificationAuthorizationFinished(isGranted):
            SettingsNotificationsEditor.applyAuthorizationResult(
                isGranted,
                state: &state.notifications
            )
            appSettingsClient.setNotificationsEnabled(isGranted)

            guard isGranted else {
                SettingsNotificationsEditor.clearScheduledNotifications(
                    state: &state.notifications
                )
                return .none
            }
            state.notifications.hasLoadedScheduledNotifications = false
            return .run { @MainActor send in
                await SettingsNotificationsExecution.reconcileAuthorizationResult(
                    isGranted: isGranted,
                    modelContext: modelContext,
                    appSettingsClient: appSettingsClient,
                    notificationClient: notificationClient
                )
                let notifications = await notificationClient.pendingScheduledNotifications()
                send(.scheduledNotificationsLoaded(notifications))
            }
        default:
            return .none
        }
    }

    func reduceNotificationScheduleActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case let .notificationReminderTimeChanged(reminderTime):
            SettingsNotificationsEditor.updateReminderTime(
                reminderTime,
                state: &state.notifications
            )
            appSettingsClient.setNotificationReminderTime(reminderTime)

            let notificationsEnabled = state.notifications.notificationsEnabled
            guard notificationsEnabled else { return .none }
            state.notifications.hasLoadedScheduledNotifications = false
            return .run { @MainActor send in
                await SettingsNotificationsExecution.reconcileReminderChange(
                    notificationsEnabled: notificationsEnabled,
                    modelContext: modelContext,
                    appSettingsClient: appSettingsClient,
                    notificationClient: notificationClient
                )
                let notifications = await notificationClient.pendingScheduledNotifications()
                send(.scheduledNotificationsLoaded(notifications))
            }
        case let .scheduledNotificationsLoaded(notifications):
            SettingsNotificationsEditor.replaceScheduledNotifications(
                notifications,
                state: &state.notifications
            )
            return .none
        case let .removeScheduledNotificationTapped(notification):
            return .run { send in
                await notificationClient.removeScheduledNotification(notification)
                let notifications = await notificationClient.pendingScheduledNotifications()
                await send(.scheduledNotificationsLoaded(notifications))
            }
        case let .pauseScheduledNotificationTapped(notification, until):
            return .run { send in
                await notificationClient.pauseScheduledNotification(notification, until)
                let notifications = await notificationClient.pendingScheduledNotifications()
                await send(.scheduledNotificationsLoaded(notifications))
            }
        case let .systemNotificationPermissionChecked(value):
            SettingsNotificationsEditor.updateSystemPermission(
                value,
                state: &state.notifications
            )
            return .none
        default:
            return .none
        }
    }

    func reduceAppIconAndTemporaryStateActions(
        into state: inout State,
        action: Action
    ) -> Effect<Action> {
        switch action {
        case .resetTemporaryViewStateTapped:
            return SettingsAppearanceActionHandler.resetTemporaryViewStateTapped(
                state: &state.appearance,
                appSettingsClient: appSettingsClient
            )
        case let .appIconSelected(option):
            return SettingsAppIconActionHandler.appIconSelected(
                option,
                state: &state.appearance,
                appIconClient: appIconClient
            )
        case let .appIconChangeFinished(option, errorMessage):
            return SettingsAppIconActionHandler.appIconChangeFinished(
                requestedOption: option,
                errorMessage: errorMessage,
                state: &state.appearance
            )
        default:
            return .none
        }
    }
}
