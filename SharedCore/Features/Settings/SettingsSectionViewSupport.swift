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
