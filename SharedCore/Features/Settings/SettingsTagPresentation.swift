import Foundation

enum SettingsTagSourcePresentation {
    private struct SourceNames {
        let task: String
        let goal: String
        let note: String
        let event: String
    }

    static var goalsAreAvailableOnCurrentPlatform: Bool {
        return SharedDefaults.app[.appSettingGoalsTabEnabled]
    }

    static var eventsAreAvailableOnCurrentPlatform: Bool {
        return SharedDefaults.app[.appSettingMacEventEmotionActionsEnabled]
    }

    static func pluralSourceList(
        includesGoals: Bool,
        includesNotes: Bool,
        includesEvents: Bool,
        conjunction: String
    ) -> String {
        sourceList(
            names: SourceNames(task: "tasks", goal: "goals", note: "notes", event: "events"),
            includesGoals: includesGoals,
            includesNotes: includesNotes,
            includesEvents: includesEvents,
            conjunction: conjunction
        )
    }

    static func singularSourceList(
        includesGoals: Bool,
        includesNotes: Bool,
        includesEvents: Bool,
        conjunction: String
    ) -> String {
        sourceList(
            names: SourceNames(task: "task", goal: "goal", note: "note", event: "event"),
            includesGoals: includesGoals,
            includesNotes: includesNotes,
            includesEvents: includesEvents,
            conjunction: conjunction
        )
    }

    private static func sourceList(
        names: SourceNames,
        includesGoals: Bool,
        includesNotes: Bool,
        includesEvents: Bool,
        conjunction: String
    ) -> String {
        var sources = [names.task]
        if includesGoals {
            sources.append(names.goal)
        }
        if includesNotes {
            sources.append(names.note)
        }
        if includesEvents {
            sources.append(names.event)
        }
        guard sources.count > 2 else {
            return sources.joined(separator: " \(conjunction) ")
        }
        return "\(sources.dropLast().joined(separator: ", ")), \(conjunction) \(sources.last ?? "")"
    }
}

extension SettingsTagsState {
    var overviewSubtitle: String {
        switch savedTags.count {
        case 0:
            let sources = SettingsTagSourcePresentation.pluralSourceList(
                includesGoals: SettingsTagSourcePresentation.goalsAreAvailableOnCurrentPlatform,
                includesNotes: SharedDefaults.app[.appSettingNotesEnabled],
                includesEvents: SettingsTagSourcePresentation.eventsAreAvailableOnCurrentPlatform,
                conjunction: "and"
            )
            return "Review and manage tags across \(sources)"
        case 1:
            return "1 saved tag"
        default:
            return "\(savedTags.count) saved tags"
        }
    }

    var deleteConfirmationMessage: String {
        guard let tag = tagPendingDeletion else {
            let sources = SettingsTagSourcePresentation.singularSourceList(
                includesGoals: SettingsTagSourcePresentation.goalsAreAvailableOnCurrentPlatform,
                includesNotes: SharedDefaults.app[.appSettingNotesEnabled],
                includesEvents: SettingsTagSourcePresentation.eventsAreAvailableOnCurrentPlatform,
                conjunction: "or"
            )
            return "This will remove the tag from every \(sources) that uses it."
        }

        let affectedParts = tag.settingsAffectedDeletionParts
        let affectedText =
            affectedParts.isEmpty
            ? "no saved items will lose it"
            : "\(affectedParts.joined(separator: " and ")) will lose it"

        return "Delete \(tag.name)? This cannot be undone, and \(affectedText)."
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
            parts.append(routinesOnly == 1 ? "1 repeating task" : "\(routinesOnly) repeating tasks")
        }
        if linkedTodoCount > 0 {
            parts.append(linkedTodoCount == 1 ? "1 one-time task" : "\(linkedTodoCount) one-time tasks")
        }
        if linkedGoalCount > 0 {
            parts.append(linkedGoalCount == 1 ? "1 goal" : "\(linkedGoalCount) goals")
        }
        if SharedDefaults.app[.appSettingNotesEnabled], linkedNoteCount > 0 {
            parts.append(linkedNoteCount == 1 ? "1 note" : "\(linkedNoteCount) notes")
        }
        if SettingsTagSourcePresentation.eventsAreAvailableOnCurrentPlatform, linkedEventCount > 0 {
            parts.append(linkedEventCount == 1 ? "1 event" : "\(linkedEventCount) events")
        }
        if doneCount > 0 {
            parts.append(doneCount == 1 ? "1 done" : "\(doneCount) done")
        }
        guard !parts.isEmpty else { return "" }
        return "Used by " + parts.joined(separator: " · ")
    }

    var settingsAffectedDeletionParts: [String] {
        let routinesOnly = max(0, linkedRoutineCount - linkedTodoCount)
        var parts: [String] = []
        if routinesOnly > 0 {
            parts.append(routinesOnly == 1 ? "1 repeating task" : "\(routinesOnly) repeating tasks")
        }
        if linkedTodoCount > 0 {
            parts.append(linkedTodoCount == 1 ? "1 one-time task" : "\(linkedTodoCount) one-time tasks")
        }
        if linkedGoalCount > 0 {
            parts.append(linkedGoalCount == 1 ? "1 goal" : "\(linkedGoalCount) goals")
        }
        if SharedDefaults.app[.appSettingNotesEnabled], linkedNoteCount > 0 {
            parts.append(linkedNoteCount == 1 ? "1 note" : "\(linkedNoteCount) notes")
        }
        if SettingsTagSourcePresentation.eventsAreAvailableOnCurrentPlatform, linkedEventCount > 0 {
            parts.append(linkedEventCount == 1 ? "1 event" : "\(linkedEventCount) events")
        }
        return parts
    }
}
