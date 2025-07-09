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
        return "Routine reminders are turned off"
    }
}

extension SettingsAppearanceState {
    var overviewSubtitle: String {
        "Icon: \(selectedAppIcon.title) • List: \(routineListSectioningMode.summaryText) • Tags: \(tagCounterDisplayMode.summaryText)"
    }

    var routineListSectioningSubtitle: String {
        routineListSectioningMode.subtitle
    }
}

extension SettingsGitHubState {
    var overviewSubtitle: String {
        if let connectedRepository {
            return connectedRepository.fullName
        }

        return "Connect a repository to show commit and PR stats"
    }

    var repositorySummaryText: String {
        let owner = repositoryOwner.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = repositoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !owner.isEmpty, !name.isEmpty else {
            return "No repository selected"
        }

        return "\(owner)/\(name)"
    }

    var saveValidationMessage: String? {
        let owner = repositoryOwner.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = repositoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !owner.isEmpty || !name.isEmpty else {
            return nil
        }

        if owner.isEmpty || name.isEmpty {
            return "Enter both the repository owner and repository name."
        }

        return nil
    }

    var tokenStatusText: String {
        if hasSavedAccessToken {
            return accessTokenDraft.isEmpty
                ? "A token is already saved in Keychain. Leave the field empty to keep it."
                : "A new token will replace the saved one."
        }

        return "Optional for public repositories. Add a token for private repos or higher API limits."
    }

    var isSaveDisabled: Bool {
        isOperationInProgress || saveValidationMessage != nil || repositorySummaryText == "No repository selected"
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

extension SettingsTagsState {
    var overviewSubtitle: String {
        switch savedTags.count {
        case 0:
            return "Review and manage tags across routines"
        case 1:
            return "1 saved tag"
        default:
            return "\(savedTags.count) saved tags"
        }
    }

    var deleteConfirmationMessage: String {
        guard let tag = tagPendingDeletion else {
            return "This will remove the tag from every routine that uses it."
        }

        let linkedRoutinesText: String
        if tag.linkedRoutineCount == 1 {
            linkedRoutinesText = "1 routine will lose it"
        } else {
            linkedRoutinesText = "\(tag.linkedRoutineCount) routines will lose it"
        }

        return "Delete \(tag.name)? This cannot be undone, and \(linkedRoutinesText)."
    }

    var isSaveRenameDisabled: Bool {
        guard
            !isTagOperationInProgress,
            let cleanedTagName = RoutineTag.cleaned(tagRenameDraft)
        else {
            return true
        }

        guard let pendingTag = tagPendingRename else { return false }
        return cleanedTagName == pendingTag.name
    }
}

extension RoutineTagSummary {
    var settingsSubtitle: String {
        linkedRoutineCount == 1
            ? "Used by 1 routine"
            : "Used by \(linkedRoutineCount) routines"
    }
}
