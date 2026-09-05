import SwiftUI

extension HomeTCAView {
    func macSharedFilterState(preferredTags: [String]) -> HomeSharedFilterState {
        HomeSharedFilterStateResolver.resolvedState(
            taskSelectedTags: store.selectedTags,
            timelineSelectedTags: store.selectedTimelineTags,
            taskExcludedTags: store.excludedTags,
            timelineExcludedTags: store.selectedTimelineExcludedTags,
            taskIncludeTagMatchMode: store.includeTagMatchMode,
            timelineIncludeTagMatchMode: store.selectedTimelineIncludeTagMatchMode,
            taskExcludeTagMatchMode: store.excludeTagMatchMode,
            timelineExcludeTagMatchMode: store.selectedTimelineExcludeTagMatchMode,
            taskSelectedFlags: store.selectedFlags,
            timelineSelectedFlags: store.selectedTimelineFlags,
            taskExcludedFlags: store.excludedFlags,
            taskIncludeFlagMatchMode: store.includeFlagMatchMode,
            timelineIncludeFlagMatchMode: store.selectedTimelineIncludeFlagMatchMode,
            taskExcludeFlagMatchMode: store.excludeFlagMatchMode,
            taskImportanceUrgencyFilter: store.selectedImportanceUrgencyFilter,
            timelineImportanceUrgencyFilter: store.selectedTimelineImportanceUrgencyFilter,
            taskPressureFilter: store.selectedPressureFilter,
            timelinePressureFilter: store.selectedTimelinePressureFilter,
            taskThinkingNeededFilter: store.selectedThinkingNeededFilter,
            timelineThinkingNeededFilter: store.selectedTimelineThinkingNeededFilter,
            taskEstimationFilter: store.selectedEstimationFilter,
            timelineEstimationFilter: store.selectedTimelineEstimationFilter,
            preferredTags: preferredTags
        )
    }

    var macSharedFiltersPresentationSignature: HomeMacSharedFiltersPresentationSignature {
        HomeMacSharedFiltersPresentationSignature(
            components: macSharedFilterStateSignature
                + macSharedHomeDisplaySignature
                + macSharedTimelineSourceSignature
        )
    }

    private var macSharedFilterStateSignature: [String] {
        [
            "taskListMode:\(store.taskListMode.rawValue)",
            "taskTags:\(macSignatureString(store.selectedTags))",
            "timelineTags:\(macSignatureString(store.selectedTimelineTags))",
            "taskExcluded:\(macSignatureString(store.excludedTags))",
            "timelineExcluded:\(macSignatureString(store.selectedTimelineExcludedTags))",
            "taskIncludeMode:\(store.includeTagMatchMode.rawValue)",
            "timelineIncludeMode:\(store.selectedTimelineIncludeTagMatchMode.rawValue)",
            "taskExcludeMode:\(store.excludeTagMatchMode.rawValue)",
            "timelineExcludeMode:\(store.selectedTimelineExcludeTagMatchMode.rawValue)",
            "taskFlags:\(macSignatureString(store.selectedFlags))",
            "timelineFlags:\(macSignatureString(store.selectedTimelineFlags))",
            "excludedFlags:\(macSignatureString(store.excludedFlags))",
            "taskFlagIncludeMode:\(store.includeFlagMatchMode.rawValue)",
            "timelineFlagIncludeMode:\(store.selectedTimelineIncludeFlagMatchMode.rawValue)",
            "flagExcludeMode:\(store.excludeFlagMatchMode.rawValue)",
            "taskPriority:\(macSignatureString(store.selectedImportanceUrgencyFilter))",
            "timelinePriority:\(macSignatureString(store.selectedTimelineImportanceUrgencyFilter))",
            "taskPressure:\(store.selectedPressureFilter?.rawValue ?? "")",
            "timelinePressure:\(store.selectedTimelinePressureFilter?.rawValue ?? "")",
            "taskThinking:\(store.selectedThinkingNeededFilter?.rawValue ?? "")",
            "timelineThinking:\(store.selectedTimelineThinkingNeededFilter?.rawValue ?? "")",
            "taskEstimate:\(store.selectedEstimationFilter.rawValue)",
            "timelineEstimate:\(store.selectedTimelineEstimationFilter.rawValue)",
            "timelineType:\(store.selectedTimelineFilterType.normalized(includingEventEmotion: areMacEventEmotionActionsEnabled, includingPlaces: isPlacesEnabled, includingNotes: isNotesEnabled, includingAway: isAwayEnabled, includingSleep: includesMacSleepTimelineFilters).rawValue)",
            "timelineStatus:\(store.selectedTimelineStatusFilter.rawValue)",
            "timelineMedia:\(store.selectedTimelineMediaFilter.rawValue)",
            "eventsEmotions:\(areMacEventEmotionActionsEnabled)",
            "places:\(isPlacesEnabled)",
            "notes:\(isNotesEnabled)",
            "away:\(isAwayEnabled)",
            "sleep:\(includesMacSleepTimelineFilters)",
            "filterAnchor:\(relatedFilterTagSuggestionAnchor ?? "")",
            "timelineAnchor:\(relatedTimelineTagSuggestionAnchor ?? "")",
            "tagColors:\(macSignatureString(store.tagColors))",
            "relatedRules:\(macRelatedTagRulesSignature)",
            "fileAttachments:\(macSignatureString(store.fileAttachmentTaskIDs))",
            "noteAttachments:\(macSignatureString(Set(noteAttachments.map(\.noteID))))",
        ]
    }

    private var macSharedHomeDisplaySignature: [String] {
        (store.routineDisplays + store.awayRoutineDisplays + store.archivedRoutineDisplays)
            .map { display in
                [
                    "home",
                    display.taskID.uuidString,
                    display.isOneOffTask.description,
                    macSignatureString(display.tags),
                    macSignatureString(display.flags),
                    display.importance.rawValue,
                    display.urgency.rawValue,
                    display.currentTaskLadderImportance.rawValue,
                    display.currentTaskLadderUrgency.rawValue,
                    display.currentTaskLadderPressure.rawValue,
                    display.thinkingNeeded.rawValue,
                    display.estimatedDurationMinutes?.description ?? "",
                ].joined(separator: "|")
            }
            .sorted()
    }

    private var macSharedTimelineSourceSignature: [String] {
        var components: [String] = []

        components += store.routineTasks.map { task in
            [
                "task",
                task.id.uuidString,
                task.tagsStorage,
                task.flagsStorage,
                task.importanceRawValue,
                task.urgencyRawValue,
                task.pressureRawValue,
                task.thinkingNeededRawValue,
                task.estimatedDurationMinutes?.description ?? "",
                task.temporalWeightRuleStorage,
                task.scheduleAnchor?.timeIntervalSinceReferenceDate.description ?? "",
                task.deadline?.timeIntervalSinceReferenceDate.description ?? "",
                task.plannedDate?.timeIntervalSinceReferenceDate.description ?? "",
                task.recurrenceKindRawValue,
                task.recurrenceRuleStorage,
                task.interval.description,
                task.scheduleModeRawValue,
                task.lastDone?.timeIntervalSinceReferenceDate.description ?? "",
                task.canceledAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += store.timelineLogs.map { log in
            [
                "log",
                log.id.uuidString,
                log.taskID.uuidString,
                log.timestamp?.timeIntervalSinceReferenceDate.description ?? "",
                log.kindRawValue,
            ].joined(separator: "|")
        }

        components += events.map { event in
            [
                "event",
                event.id.uuidString,
                event.tagsStorage,
                event.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                event.endedAt?.timeIntervalSinceReferenceDate.description ?? "",
                event.updatedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += emotionLogs.map { emotion in
            [
                "emotion",
                emotion.id.uuidString,
                emotion.createdAt?.timeIntervalSinceReferenceDate.description ?? "",
                emotion.updatedAt?.timeIntervalSinceReferenceDate.description ?? "",
                emotion.linkedTaskID?.uuidString ?? "",
                emotion.linkedSleepSessionID?.uuidString ?? "",
            ].joined(separator: "|")
        }

        components += notes.map { note in
            [
                "note",
                note.id.uuidString,
                note.tagsStorage,
                note.createdAt?.timeIntervalSinceReferenceDate.description ?? "",
                note.updatedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += focusSessions.map { session in
            [
                "focus",
                session.id.uuidString,
                session.taskID.uuidString,
                session.tagName ?? "",
                session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.completedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.abandonedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += sprintFocusSessions.map { session in
            [
                "sprintFocus",
                session.id.uuidString,
                session.startedAt.timeIntervalSinceReferenceDate.description,
                session.stoppedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.pausedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += boardSprints.map { sprint in
            [
                "boardSprint",
                sprint.id.uuidString,
                sprint.createdAt.timeIntervalSinceReferenceDate.description,
                sprint.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                sprint.finishedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += sleepSessions.map { session in
            [
                "sleep",
                session.id.uuidString,
                session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.endedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.updatedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += awaySessions.map { session in
            [
                "away",
                session.id.uuidString,
                session.linkedTaskID?.uuidString ?? "",
                session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.completedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.endedEarlyAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += placeCheckInSessions.map { session in
            [
                "place",
                session.id.uuidString,
                session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.endedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.updatedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        return components.sorted()
    }

    private var macRelatedTagRulesSignature: String {
        store.relatedTagRules
            .map { rule in
                "\(rule.id):\(macSignatureString(rule.relatedTags))"
            }
            .sorted()
            .joined(separator: ";")
    }

    func macMergedTagSet(_ sets: Set<String>..., preferredTags: [String]) -> Set<String> {
        Set(RoutineTag.deduplicated(sets.flatMap { Array($0) }, preferredTags: preferredTags))
    }

    func macMergedTagList(_ lists: [String]...) -> [String] {
        RoutineTag.deduplicated(lists.flatMap { $0 })
            .sorted { lhs, rhs in
                lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
    }

    func macMergedFlagSet(_ sets: Set<String>..., preferredFlags: [String]) -> Set<String> {
        Set(RoutineFlag.deduplicated(sets.flatMap { Array($0) }, preferredFlags: preferredFlags))
    }

    func macMergedFlagList(_ lists: [String]...) -> [String] {
        RoutineFlag.deduplicated(lists.flatMap { $0 })
            .sorted { lhs, rhs in
                lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
    }

    private func macSignatureString(_ values: [String]) -> String {
        values.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        .joined(separator: ",")
    }

    private func macSignatureString(_ values: Set<String>) -> String {
        macSignatureString(Array(values))
    }

    private func macSignatureString(_ values: Set<UUID>) -> String {
        values
            .map(\.uuidString)
            .sorted()
            .joined(separator: ",")
    }

    private func macSignatureString(_ values: [String: String]) -> String {
        values
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: ",")
    }

    private func macSignatureString(_ filter: ImportanceUrgencyFilterCell?) -> String {
        guard let filter = ImportanceUrgencyFilterCell.normalized(filter) else { return "" }
        return "\(filter.importance.rawValue):\(filter.urgency.rawValue)"
    }
}

struct HomeMacSharedFiltersPresentationCache {
    let signature: HomeMacSharedFiltersPresentationSignature
    let presentation: HomeMacSharedFiltersPresentation
}

struct HomeMacSharedFiltersPresentationSignature: Hashable {
    let components: [String]
}

struct HomeMacSharedFiltersPresentation {
    let availableFlags: [String]
    let selectedFlags: Set<String>
    let excludedFlags: Set<String>
    let includeFlagMatchMode: RoutineTagMatchMode
    let excludeFlagMatchMode: RoutineTagMatchMode
    let availableTags: [String]
    let availableExcludeTags: [String]
    let suggestedRelatedTags: [String]
    let selectedTags: Set<String>
    let selectedExcludedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let excludeTagMatchMode: RoutineTagMatchMode
    let tagCountsByNormalizedName: [String: Int]
    let tagColorsByNormalizedName: [String: Color]

    func tagCount(for tag: String) -> Int {
        guard let key = RoutineTag.normalized(tag) else { return 0 }
        return tagCountsByNormalizedName[key, default: 0]
    }

    func tagColor(for tag: String) -> Color? {
        guard let key = RoutineTag.normalized(tag) else { return nil }
        return tagColorsByNormalizedName[key]
    }
}
