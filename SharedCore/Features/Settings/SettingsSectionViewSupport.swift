import Foundation

enum SettingsSectionID: String, CaseIterable, Identifiable, Hashable {
    case notifications
    case calendar
    case places
    case tags
    case appearance
    case iCloud
    case git
    case backup
    case quickAdd
    case shortcuts
    case support
    case about

    var id: String { rawValue }

    static func visibleSections(isGitFeaturesEnabled: Bool) -> [SettingsSectionID] {
        allCases.filter { section in
            if section == .git {
                return isGitFeaturesEnabled
            }
            #if os(macOS)
            return true
            #else
            return section != .shortcuts
            #endif
        }
    }

    var title: String {
        switch self {
        case .notifications: return "Notifications"
        case .calendar:      return "Calendar"
        case .places:        return "Places"
        case .tags:          return "Tags"
        case .appearance:    return "Appearance"
        case .iCloud:        return "iCloud"
        case .git:           return "Git"
        case .backup:        return "Data Backup"
        case .quickAdd:      return "Quick Add"
        case .shortcuts:     return "Shortcuts"
        case .support:       return "Support"
        case .about:         return "About"
        }
    }

    var icon: String {
        switch self {
        case .notifications: return "bell.badge.fill"
        case .calendar:      return "calendar.badge.plus"
        case .places:        return "mappin.and.ellipse"
        case .tags:          return "tag.fill"
        case .appearance:    return "app.badge.fill"
        case .iCloud:        return "icloud.fill"
        case .git:           return "arrow.triangle.branch"
        case .backup:        return "externaldrive.fill"
        case .quickAdd:      return "text.badge.plus"
        case .shortcuts:     return "keyboard.fill"
        case .support:       return "envelope.fill"
        case .about:         return "info.circle.fill"
        }
    }

    func rowPresentation(in state: SettingsFeatureState) -> SettingsSectionRowPresentation {
        switch self {
        case .notifications:
            return SettingsSectionRowPresentation(
                subtitle: state.notifications.overviewSubtitle,
                value: state.notifications.notificationsEnabled ? "On" : "Off"
            )

        case .calendar:
            return SettingsSectionRowPresentation(
                subtitle: state.appearance.showPersianDates
                    ? "Review tasks and show Persian dates"
                    : "Review tasks and date display",
                value: state.appearance.showPersianDates ? "Persian" : nil
            )

        case .places:
            return SettingsSectionRowPresentation(subtitle: state.places.overviewSubtitle)

        case .tags:
            return SettingsSectionRowPresentation(subtitle: state.tags.overviewSubtitle)

        case .appearance:
            return SettingsSectionRowPresentation(subtitle: state.appearance.overviewSubtitle)

        case .iCloud:
            return SettingsSectionRowPresentation(
                subtitle: state.cloud.overviewSubtitle,
                value: state.cloud.cloudSyncAvailable ? nil : "Off"
            )

        case .git:
            let ghConnected = state.github.connectedRepository != nil
            let glConnected = state.gitlab.isConnected
            let subtitle: String
            if ghConnected && glConnected {
                subtitle = "GitHub & GitLab connected"
            } else if glConnected {
                subtitle = state.gitlab.overviewSubtitle
            } else {
                subtitle = state.github.overviewSubtitle
            }

            return SettingsSectionRowPresentation(
                subtitle: subtitle,
                value: (ghConnected || glConnected) ? "Live" : nil
            )

        case .backup:
            return SettingsSectionRowPresentation(subtitle: state.dataTransfer.overviewSubtitle)

        case .quickAdd:
            return SettingsSectionRowPresentation(subtitle: "Supported syntax and examples")

        case .shortcuts:
            return SettingsSectionRowPresentation(subtitle: "Keyboard, Siri, and Apple Shortcuts")

        case .support:
            return SettingsSectionRowPresentation(subtitle: "Contact us by email")

        case .about:
            return SettingsSectionRowPresentation(subtitle: state.diagnostics.aboutOverviewSubtitle)
        }
    }
}

struct SettingsSectionRowPresentation: Equatable {
    var subtitle: String
    var value: String?

    init(subtitle: String, value: String? = nil) {
        self.subtitle = subtitle
        self.value = value
    }
}

struct SettingsQuickAddExample: Identifiable, Equatable {
    var phrase: String
    var result: String

    var id: String { phrase }
}

struct SettingsQuickAddSyntaxGroup: Identifiable, Equatable {
    var title: String
    var rows: [SettingsQuickAddSyntaxItem]

    var id: String { title }
}

struct SettingsQuickAddSyntaxItem: Identifiable, Equatable {
    var syntax: String
    var detail: String

    var id: String { syntax }
}

enum SettingsQuickAddSyntaxGuide {
    static let examples: [SettingsQuickAddExample] = [
        SettingsQuickAddExample(
            phrase: "Water plants every Saturday at 9am #home",
            result: "Creates a weekly routine on Saturday at 9:00 AM with #home."
        ),
        SettingsQuickAddExample(
            phrase: "Submit report tomorrow at 5pm !high #work",
            result: "Creates a high-priority todo due tomorrow at 5:00 PM."
        ),
        SettingsQuickAddExample(
            phrase: "Clean desk every 2 days softly @Home",
            result: "Creates a soft routine every 2 days and links it to Home."
        ),
        SettingsQuickAddExample(
            phrase: "Pay rent monthly on 1st at 8am #finance",
            result: "Creates a monthly routine on the 1st at 8:00 AM."
        ),
        SettingsQuickAddExample(
            phrase: "Read for 25m today",
            result: "Creates a todo due today and enables a 25-minute focus estimate."
        )
    ]

    static let syntaxGroups: [SettingsQuickAddSyntaxGroup] = [
        SettingsQuickAddSyntaxGroup(
            title: "Dates",
            rows: [
                SettingsQuickAddSyntaxItem(syntax: "today", detail: "Due today."),
                SettingsQuickAddSyntaxItem(syntax: "tomorrow", detail: "Due tomorrow."),
                SettingsQuickAddSyntaxItem(syntax: "due Friday", detail: "Due on the next Friday."),
                SettingsQuickAddSyntaxItem(syntax: "by Friday", detail: "Also sets the next Friday deadline.")
            ]
        ),
        SettingsQuickAddSyntaxGroup(
            title: "Times",
            rows: [
                SettingsQuickAddSyntaxItem(syntax: "at 9am", detail: "Sets a morning time."),
                SettingsQuickAddSyntaxItem(syntax: "at 9:30pm", detail: "Sets an evening time."),
                SettingsQuickAddSyntaxItem(syntax: "at 14:30", detail: "Uses 24-hour time.")
            ]
        ),
        SettingsQuickAddSyntaxGroup(
            title: "Routines",
            rows: [
                SettingsQuickAddSyntaxItem(syntax: "daily", detail: "Creates a daily routine."),
                SettingsQuickAddSyntaxItem(syntax: "every day", detail: "Also creates a daily routine."),
                SettingsQuickAddSyntaxItem(syntax: "every 2 days", detail: "Creates an interval routine."),
                SettingsQuickAddSyntaxItem(syntax: "every Monday", detail: "Creates a weekly routine."),
                SettingsQuickAddSyntaxItem(syntax: "weekly on Monday", detail: "Also creates a weekly routine."),
                SettingsQuickAddSyntaxItem(syntax: "monthly on 15th", detail: "Creates a monthly routine.")
            ]
        ),
        SettingsQuickAddSyntaxGroup(
            title: "Metadata",
            rows: [
                SettingsQuickAddSyntaxItem(syntax: "#home", detail: "Adds a one-word tag."),
                SettingsQuickAddSyntaxItem(syntax: "@Office", detail: "Links a one-word place when it exists."),
                SettingsQuickAddSyntaxItem(syntax: "!urgent", detail: "Sets urgent priority."),
                SettingsQuickAddSyntaxItem(syntax: "!high / !medium / !low", detail: "Sets priority."),
                SettingsQuickAddSyntaxItem(syntax: "25m / 45 min / 1h", detail: "Adds an estimated focus duration."),
                SettingsQuickAddSyntaxItem(syntax: "soft / softly", detail: "Creates a soft routine when used with recurrence.")
            ]
        )
    ]

    static let notes: [String] = [
        "No date or recurrence creates a normal todo.",
        "Recurrence phrases create routines.",
        "Times apply to the due date or recurrence in the same phrase.",
        "Tags and places stop at spaces, so use one-word names.",
        "Optional starters like add, create, new, task, todo, routine, and remind me to are removed from the final title."
    ]
}

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
        "Theme: \(appColorScheme.title) • Lock: \(isAppLockEnabled ? "On" : "Off") • Icon: \(selectedAppIcon.title) • List: \(routineListSectioningMode.summaryText)"
    }

    var routineListSectioningSubtitle: String {
        routineListSectioningMode.subtitle
    }

    var appLockDetailText: String {
        if let appLockUnavailableReason, isAppLockEnabled == false {
            return appLockUnavailableReason
        }

        if isAppLockEnabled {
            return "Routina will ask for \(appLockMethodDescription) whenever the app becomes active."
        }

        return "Require \(appLockMethodDescription) before showing your routines."
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
        let savedTokenStatus = if hasSavedAccessToken {
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
            return "Use a fine-grained or classic GitHub personal access token with read access to the repository if it is private. The token is stored in Keychain."
        case .profile:
            return "Profile mode reads the authenticated account's contribution calendar and totals. A GitHub personal access token is required and stored in Keychain."
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

extension SettingsTagsState {
    var overviewSubtitle: String {
        let fastFilterSuffix = fastFilterTags.isEmpty ? "" : " • \(fastFilterTags.count) fast"

        switch savedTags.count {
        case 0:
            return "Review and manage tags across routines\(fastFilterSuffix)"
        case 1:
            return "1 saved tag\(fastFilterSuffix)"
        default:
            return "\(savedTags.count) saved tags\(fastFilterSuffix)"
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
        let routinesOnly = max(0, linkedRoutineCount - linkedTodoCount)
        var parts: [String] = []
        if routinesOnly > 0 {
            parts.append(routinesOnly == 1 ? "1 routine" : "\(routinesOnly) routines")
        }
        if linkedTodoCount > 0 {
            parts.append(linkedTodoCount == 1 ? "1 todo" : "\(linkedTodoCount) todos")
        }
        if doneCount > 0 {
            parts.append(doneCount == 1 ? "1 done" : "\(doneCount) done")
        }
        guard !parts.isEmpty else { return "" }
        return "Used by " + parts.joined(separator: " · ")
    }
}
