import Foundation

extension SettingsNotificationsState {
    var overviewSubtitle: String {
        if notificationsEnabled {
            let time = notificationReminderTime.formatted(date: .omitted, time: .shortened)
            return "Daily reminder at \(time)"
        }
        if systemSettingsNotificationsEnabled == false {
            return "Disabled in System Settings"
        }
        return "Repeating-task reminders are turned off"
    }
}

extension SettingsAppearanceState {
    var overviewSubtitle: String {
        #if os(macOS)
            "Theme: \(appColorScheme.title) • Icon: \(selectedAppIcon.title) • List: \(routineListSectioningMode.summaryText)"
        #else
            "Theme: \(appColorScheme.title) • Icon: \(selectedAppIcon.title) • List: \(routineListSectioningMode.summaryText) • Rows: \(taskRowVisibility.summaryText) • Timeline: \(timelineRowVisibility.summaryText)"
        #endif
    }

    var routineListSectioningSubtitle: String {
        routineListSectioningMode.subtitle
    }

    var calendarOverviewSubtitle: String {
        #if os(macOS)
            let plannerText =
                showsTimelineTasksInDayPlanner
                ? "Automatic timeline activity"
                : "Timeline badges"

            if showPersianDates {
                return "\(plannerText) • Persian dates"
            }

            return plannerText
        #else
            let calendarTaskText = "Review events before adding tasks"
            if showPersianDates {
                return "\(calendarTaskText) • Persian dates"
            }
            return calendarTaskText
        #endif
    }

    var appLockDetailText: String {
        if let appLockUnavailableReason, isAppLockEnabled == false {
            return appLockUnavailableReason
        }

        if isAppLockEnabled {
            return "Routina will ask for \(appLockMethodDescription) whenever the app becomes active."
        }

        return "Require \(appLockMethodDescription) before showing your tasks."
    }
}

extension SettingsGitHubState {
    var overviewSubtitle: String {
        if let connectedRepository {
            return connectedRepository.fullName
        }
        if let connectedViewerLogin, !connectedViewerLogin.isEmpty {
            return "@\(connectedViewerLogin) profile activity"
        }

        return "Connect GitHub to show repository or profile activity"
    }

    var repositorySummaryText: String {
        let owner = repositoryOwner.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = repositoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !owner.isEmpty, !name.isEmpty else {
            return "No repository selected"
        }

        return "\(owner)/\(name)"
    }

    var profileSummaryText: String {
        if let connectedViewerLogin, !connectedViewerLogin.isEmpty {
            return "@\(connectedViewerLogin)"
        }

        return "Uses the authenticated GitHub account"
    }

    var saveValidationMessage: String? {
        switch scope {
        case .repository:
            let owner = repositoryOwner.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = repositoryName.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !owner.isEmpty || !name.isEmpty else {
                return nil
            }

            if owner.isEmpty || name.isEmpty {
                return "Enter both the repository owner and repository name."
            }

            return nil

        case .profile:
            let trimmedToken = accessTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if hasSavedAccessToken || !trimmedToken.isEmpty {
                return nil
            }
            return "Add a personal access token to load profile activity."
        }
    }

    var tokenStatusText: String {
        let savedTokenStatus =
            if hasSavedAccessToken {
                accessTokenDraft.isEmpty
                    ? "A token is already saved in Keychain. Leave the field empty to keep it."
                    : "A new token will replace the saved one."
            } else {
                "The token is stored securely in Keychain."
            }

        switch scope {
        case .repository:
            if hasSavedAccessToken {
                return savedTokenStatus
            }
            return "Optional for public repositories. Add a token for private repos or higher API limits."

        case .profile:
            if hasSavedAccessToken {
                return savedTokenStatus
            }
            return "Required for profile activity. Use a personal access token that can read your contribution data."
        }
    }

    var detailSubtitle: String {
        switch scope {
        case .repository:
            return "Connect one repository to show commits, merged pull requests, and contributor counts in Stats."
        case .profile:
            return "Connect your GitHub account to show your full contribution activity across repositories."
        }
    }

    var infoText: String {
        switch scope {
        case .repository:
            return "Use a fine-grained or classic GitHub personal access token with read access "
                + "to the repository if it is private. The token is stored in Keychain."
        case .profile:
            return "Profile mode reads the authenticated account's contribution calendar and totals. "
                + "A GitHub personal access token is required and stored in Keychain."
        }
    }

    var saveButtonTitle: String {
        switch scope {
        case .repository:
            return "Save Connection"
        case .profile:
            return "Connect Profile"
        }
    }

    var removeButtonDisabled: Bool {
        isOperationInProgress || !hasConnectedConfiguration
    }

    var activeModeSummary: String {
        switch scope {
        case .repository:
            return repositorySummaryText
        case .profile:
            return profileSummaryText
        }
    }

    var isSaveDisabled: Bool {
        switch scope {
        case .repository:
            return isOperationInProgress
                || saveValidationMessage != nil
                || repositorySummaryText == "No repository selected"
        case .profile:
            return isOperationInProgress || saveValidationMessage != nil
        }
    }
}

extension SettingsDiagnosticsState {
    var aboutOverviewSubtitle: String {
        if isDebugSectionVisible {
            return "Version \(appVersion) • Diagnostics unlocked"
        }
        if appVersion.isEmpty {
            return "App details"
        }
        return "Version \(appVersion)"
    }
}
