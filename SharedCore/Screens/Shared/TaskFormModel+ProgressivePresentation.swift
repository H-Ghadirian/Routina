import Foundation

extension TaskFormModel {
    func visibleCompactSections(isShowingMoreDetails: Bool) -> [TaskFormCompactSection] {
        let availableSections = availableCompactSections
        guard visibilityMode.usesProgressiveDisclosure, !isShowingMoreDetails else {
            return availableSections
        }

        let primarySections = progressivePrimaryCompactSections
        let populatedSections = populatedCompactSections
        return availableSections.filter {
            primarySections.contains($0) || populatedSections.contains($0)
        }
    }

    var allowsOptionalChecklistReveal: Bool {
        true
    }

    var shouldShowChecklistSection: Bool {
        allowsOptionalChecklistReveal
            || hasChecklistSectionContent
            || scheduleMode.wrappedValue.isRoutineModeRequiringChecklistItems
    }

    private var availableCompactSections: [TaskFormCompactSection] {
        TaskFormCompactSection.defaultOrder.filter { section in
            switch section {
            case .steps:
                return scheduleMode.wrappedValue.isStandardRoutineMode
                    || scheduleMode.wrappedValue == .oneOff
            case .checklist:
                return shouldShowChecklistSection
            case .deadline:
                return taskType.wrappedValue == .todo
            case .reminder:
                return supportsExactDateReminder
            case .planning:
                return supportsPlanning
            default:
                return true
            }
        }
    }

    private var hasChecklistSectionContent: Bool {
        !routineChecklistItems.isEmpty || hasText(checklistItemDraftTitle.wrappedValue)
    }

    private var progressivePrimaryCompactSections: Set<TaskFormCompactSection> {
        var sections: Set<TaskFormCompactSection> = [
            .name,
            .taskType,
            .deadline,
            .taskLadderValues,
            .organization,
        ]

        if visibilityMode == .progressiveCreate {
            sections.insert(.goals)
        }

        if supportsExactDateReminder {
            sections.insert(.reminder)
        }

        if scheduleMode.wrappedValue.taskType == .routine {
            sections.insert(.scheduleType)
        }

        if scheduleMode.wrappedValue.usesRoutineCadence
            && (scheduleMode.wrappedValue.showsRoutineRepeatControls
                || scheduleMode.wrappedValue.routineFinishMode == .checklist)
        {
            sections.insert(.repeatPattern)
        }

        return sections
    }

    private var populatedCompactSections: Set<TaskFormCompactSection> {
        var sections = Set<TaskFormCompactSection>()

        if color.wrappedValue != .none {
            sections.insert(.color)
        }
        if hasText(taskDescription.wrappedValue) {
            sections.insert(.taskDescription)
        }
        if hasText(notes.wrappedValue) {
            sections.insert(.notes)
        }
        if voiceNote != nil {
            sections.insert(.voiceNote)
        }
        if hasText(link.wrappedValue) {
            sections.insert(.link)
        }
        if supportsPlanning, plannedDate.wrappedValue != nil {
            sections.insert(.planning)
        }
        if importance.wrappedValue != .level2
            || urgency.wrappedValue != .level2
            || pressure.wrappedValue != .none
            || thinkingNeeded.wrappedValue != .none
            || temporalWeightRule.wrappedValue != nil
            || taskLadderEntryWindow.wrappedValue != .throughoutCycle
        {
            sections.insert(.taskLadderValues)
        }
        if estimatedDurationMinutes.wrappedValue != nil
            || actualDurationMinutes?.wrappedValue != nil
            || storyPoints.wrappedValue != nil
            || focusModeEnabled.wrappedValue
        {
            sections.insert(.estimation)
        }
        if imageData != nil {
            sections.insert(.image)
        }
        if !attachments.isEmpty {
            sections.insert(.attachment)
        }
        if TaskFormTagFlagSectionPresentation.hasContent(
            routineTags: routineTags,
            tagDraft: tagDraft.wrappedValue,
            routineFlags: routineFlags,
            availableFlags: availableFlags,
            flagDraft: flagDraft.wrappedValue
        ) {
            sections.insert(.organization)
        }
        if customTaskSectionID.wrappedValue != nil || taskLadderGroupEnabled.wrappedValue {
            sections.insert(.organization)
        }
        if !selectedGoals.isEmpty || hasText(goalDraft.wrappedValue) {
            sections.insert(.goals)
        }
        if !selectedEventIDs.isEmpty {
            sections.insert(.events)
        }
        if !relationships.isEmpty {
            sections.insert(.relationships)
        }
        if !routineSteps.isEmpty || hasText(stepDraft.wrappedValue) {
            sections.insert(.steps)
        }
        if !routineChecklistItems.isEmpty
            || hasText(checklistItemDraftTitle.wrappedValue)
            || scheduleMode.wrappedValue.isRoutineModeRequiringChecklistItems
        {
            sections.insert(.checklist)
        }
        if !selectedPlaceIDsValue.isEmpty {
            sections.insert(.place)
        }
        if hasText(destinationAddress.wrappedValue) || destinationCoordinate.wrappedValue != nil {
            sections.insert(.destination)
        }

        return sections
    }

    private func hasText(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
