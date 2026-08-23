import Foundation

/// Sections shown in the add/edit task form (and its sidebar navigator).
///
/// Adding a new case here will fail to compile every exhaustive switch
/// (`icon`, `formSectionView`), forcing all call sites to be updated.
///
/// Declaration order is the default movable order shown in the sidebar.
/// `rawValue` is the persistence key for the current pre-release form layout.
enum FormSection: String, CaseIterable, Hashable, Codable {
    case identity           = "Identity"
    case taskDescription    = "Description"
    case emoji              = "Emoji"
    case color              = "Color"
    case behavior           = "Behavior & Schedule"
    case taskLadderValues   = "Task Ladder values"
    case organization       = "Organization"
    case estimation         = "Estimation"
    case places             = "Places"
    case destination        = "Address"
    case goals              = "Goals"
    case events             = "Events"
    case linkedTasks        = "Linked tasks"
    case planning           = "Planning"
    case linkURL            = "Link URL"
    case notes              = "Notes"
    case steps              = "Steps"
    case checklist          = "Checklist"
    case image              = "Image"
    case voiceNote          = "Voice Note"
    case attachment         = "Attachment"
    case dangerZone         = "Danger Zone"

    var title: String {
        switch self {
        case .linkURL:
            return "Links"
        default:
            return rawValue
        }
    }

    var addButtonTitle: String {
        switch self {
        case .linkURL:
            return "Links"
        case .attachment:
            return "File"
        default:
            return title
        }
    }

    var icon: String {
        switch self {
        case .taskDescription:  return "text.alignleft"
        case .identity:          return "person.fill"
        case .emoji:             return "face.smiling.fill"
        case .color:             return "paintpalette.fill"
        case .behavior:          return "calendar.badge.clock"
        case .taskLadderValues:  return "square.grid.2x2.fill"
        case .organization:      return "tray.full.fill"
        case .estimation:        return "clock.fill"
        case .places:            return "mappin.and.ellipse"
        case .destination:       return "mappin.and.ellipse"
        case .goals:             return "target"
        case .events:            return "calendar"
        case .linkedTasks:       return "link"
        case .planning:          return "calendar.badge.clock"
        case .linkURL:           return "globe"
        case .notes:             return "note.text"
        case .steps:             return "list.number"
        case .checklist:         return "checklist"
        case .image:             return "photo.fill"
        case .voiceNote:         return "mic.fill"
        case .attachment:        return "paperclip"
        case .dangerZone:        return "exclamationmark.triangle.fill"
        }
    }

    /// Sections that participate in the user-customisable order. Identity is
    /// always pinned first (not movable); Danger Zone is appended only when
    /// the form context warrants it.
    static var defaultMovableOrder: [FormSection] {
        allCases.filter { $0 != .identity && $0 != .dangerZone }
    }

    static func taskFormSections(
        scheduleMode: RoutineScheduleMode,
        includesIdentity: Bool,
        includesDangerZone: Bool
    ) -> [FormSection] {
        var sections: [FormSection] = includesIdentity ? [.identity] : []
        sections += [.behavior, .taskLadderValues, .organization, .taskDescription, .emoji, .color, .estimation, .places, .destination, .goals, .events, .linkedTasks, .planning, .linkURL, .notes]
        if scheduleMode.isTaskFormStepBased {
            sections.append(.steps)
        }
        sections.append(.checklist)
        sections.append(.image)
        sections.append(.voiceNote)
        sections.append(.attachment)
        if includesDangerZone {
            sections.append(.dangerZone)
        }
        return sections
    }

    static func visibleTaskFormSections(
        from sections: [FormSection],
        mode: TaskFormVisibilityMode,
        revealedSections: Set<FormSection>,
        populatedSections: Set<FormSection>,
        allowsOptionalChecklistReveal: Bool = true
    ) -> [FormSection] {
        guard mode.usesProgressiveDisclosure else {
            return sections
        }

        let primarySections: Set<FormSection> = [
            .identity,
            .behavior,
            .taskLadderValues,
            .organization,
            .dangerZone
        ]
        let effectiveRevealedSections = allowsOptionalChecklistReveal
            ? revealedSections
            : revealedSections.subtracting([.checklist])
        return sections.filter {
            primarySections.contains($0)
                || populatedSections.contains($0)
                || effectiveRevealedSections.contains($0)
        }
    }
}

extension RoutineScheduleMode {
    var isTaskFormStepBased: Bool {
        isStandardRoutineMode || self == .oneOff
    }
}

extension TaskFormModel {
    var populatedMacFormSections: Set<FormSection> {
        var sections = Set<FormSection>()

        if hasText(taskDescription.wrappedValue) {
            sections.insert(.taskDescription)
        }
        if emoji.wrappedValue != "✨" {
            sections.insert(.emoji)
        }
        if color.wrappedValue != .none {
            sections.insert(.color)
        }
        if importance.wrappedValue != .level2
            || urgency.wrappedValue != .level2
            || pressure.wrappedValue != .none
            || thinkingNeeded.wrappedValue != .none
            || temporalWeightRule.wrappedValue != nil {
            sections.insert(.taskLadderValues)
        }
        if estimatedDurationMinutes.wrappedValue != nil
            || actualDurationMinutes?.wrappedValue != nil
            || storyPoints.wrappedValue != nil
            || focusModeEnabled.wrappedValue {
            sections.insert(.estimation)
        }
        if selectedPlaceID.wrappedValue != nil {
            sections.insert(.places)
        }
        if !destinationAddress.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || destinationCoordinate.wrappedValue != nil {
            sections.insert(.destination)
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
            sections.insert(.linkedTasks)
        }
        if supportsPlanning, plannedDate.wrappedValue != nil {
            sections.insert(.planning)
        }
        if hasText(link.wrappedValue) {
            sections.insert(.linkURL)
        }
        if hasText(notes.wrappedValue) {
            sections.insert(.notes)
        }
        if !routineSteps.isEmpty || hasText(stepDraft.wrappedValue) {
            sections.insert(.steps)
        }
        if !routineChecklistItems.isEmpty
            || hasText(checklistItemDraftTitle.wrappedValue)
            || scheduleMode.wrappedValue.isRoutineModeRequiringChecklistItems {
            sections.insert(.checklist)
        }
        if imageData != nil {
            sections.insert(.image)
        }
        if voiceNote != nil {
            sections.insert(.voiceNote)
        }
        if !attachments.isEmpty {
            sections.insert(.attachment)
        }

        return sections
    }

    private func hasText(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension AddRoutineFeature.State {
    var populatedMacFormSections: Set<FormSection> {
        var sections = Set<FormSection>()

        if hasText(basics.taskDescription) {
            sections.insert(.taskDescription)
        }
        if basics.routineEmoji != "✨" {
            sections.insert(.emoji)
        }
        if basics.routineColor != .none {
            sections.insert(.color)
        }
        if basics.importance != .level2
            || basics.urgency != .level2
            || basics.pressure != .none
            || basics.thinkingNeeded != .none
            || basics.temporalWeightRule != nil {
            sections.insert(.taskLadderValues)
        }
        if basics.estimatedDurationMinutes != nil || basics.storyPoints != nil || basics.focusModeEnabled {
            sections.insert(.estimation)
        }
        if !basics.selectedPlaceIDs.isEmpty || basics.selectedPlaceID != nil {
            sections.insert(.places)
        }
        if TaskFormTagFlagSectionPresentation.hasContent(
            routineTags: organization.routineTags,
            tagDraft: organization.tagDraft,
            routineFlags: organization.routineFlags,
            availableFlags: organization.availableFlags,
            flagDraft: organization.flagDraft
        ) {
            sections.insert(.organization)
        }
        if organization.customTaskSectionID != nil || basics.taskLadderGroupEnabled {
            sections.insert(.organization)
        }
        if !organization.routineGoals.isEmpty || hasText(organization.goalDraft) {
            sections.insert(.goals)
        }
        if !organization.eventIDs.isEmpty {
            sections.insert(.events)
        }
        if !organization.relationships.isEmpty {
            sections.insert(.linkedTasks)
        }
        if supportsPlanning, basics.plannedDate != nil {
            sections.insert(.planning)
        }
        if hasText(basics.routineLink) {
            sections.insert(.linkURL)
        }
        if hasText(basics.routineNotes) {
            sections.insert(.notes)
        }
        if !checklist.routineSteps.isEmpty || hasText(checklist.stepDraft) {
            sections.insert(.steps)
        }
        if !checklist.routineChecklistItems.isEmpty
            || hasText(checklist.checklistItemDraftTitle)
            || schedule.scheduleMode.isRoutineModeRequiringChecklistItems {
            sections.insert(.checklist)
        }
        if basics.imageData != nil {
            sections.insert(.image)
        }
        if basics.voiceNote != nil {
            sections.insert(.voiceNote)
        }
        if !basics.attachments.isEmpty {
            sections.insert(.attachment)
        }

        return sections
    }

    private func hasText(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension AddRoutineFeature.State {
    var supportsPlanning: Bool {
        RoutineTaskPlanningSupport.supportsStoredPlanning(
            scheduleMode: schedule.scheduleMode,
            recurrenceRule: candidateRecurrenceRule,
            checklistItems: candidateChecklistItems,
            cadenceEnabled: schedule.scheduleMode.taskType == .todo
                ? true
                : basics.cadenceEnabled
        )
    }
}

extension TaskDetailFeature.State {
    var populatedMacFormSections: Set<FormSection> {
        var sections = Set<FormSection>()

        if hasText(editTaskDescription) {
            sections.insert(.taskDescription)
        }
        if editRoutineEmoji != "✨" {
            sections.insert(.emoji)
        }
        if editColor != .none {
            sections.insert(.color)
        }
        if editImportance != .level2
            || editUrgency != .level2
            || editPressure != .none
            || editThinkingNeeded != .none
            || editTemporalWeightRule != nil {
            sections.insert(.taskLadderValues)
        }
        if editEstimatedDurationMinutes != nil
            || editActualDurationMinutes != nil
            || editStoryPoints != nil
            || editFocusModeEnabled {
            sections.insert(.estimation)
        }
        if !editSelectedPlaceIDs.isEmpty || editSelectedPlaceID != nil {
            sections.insert(.places)
        }
        if TaskFormTagFlagSectionPresentation.hasContent(
            routineTags: editRoutineTags,
            tagDraft: editTagDraft,
            routineFlags: editRoutineFlags,
            availableFlags: availableFlags,
            flagDraft: editFlagDraft
        ) {
            sections.insert(.organization)
        }
        if editCustomTaskSectionID != nil || editTaskLadderGroupEnabled {
            sections.insert(.organization)
        }
        if !editRoutineGoals.isEmpty || hasText(editGoalDraft) {
            sections.insert(.goals)
        }
        if !editEventIDs.isEmpty {
            sections.insert(.events)
        }
        if !editRelationships.isEmpty {
            sections.insert(.linkedTasks)
        }
        if supportsPlanning, editPlannedDate != nil {
            sections.insert(.planning)
        }
        if hasText(editRoutineLink) {
            sections.insert(.linkURL)
        }
        if hasText(editRoutineNotes) {
            sections.insert(.notes)
        }
        if !editRoutineSteps.isEmpty || hasText(editStepDraft) {
            sections.insert(.steps)
        }
        if !editRoutineChecklistItems.isEmpty
            || hasText(editChecklistItemDraftTitle)
            || editScheduleMode.isRoutineModeRequiringChecklistItems {
            sections.insert(.checklist)
        }
        if editImageData != nil {
            sections.insert(.image)
        }
        if editVoiceNote != nil {
            sections.insert(.voiceNote)
        }
        if !editAttachments.isEmpty {
            sections.insert(.attachment)
        }

        return sections
    }

    private func hasText(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension TaskDetailFeature.State {
    var supportsPlanning: Bool {
        RoutineTaskPlanningSupport.supportsStoredPlanning(
            scheduleMode: editScheduleMode,
            recurrenceRule: candidateRecurrenceRule,
            checklistItems: candidateChecklistItems,
            cadenceEnabled: editScheduleMode.taskType == .todo
                ? true
                : editCadenceEnabled
        )
    }

    private var candidateChecklistItems: [RoutineChecklistItem] {
        if let pendingTitle = RoutineChecklistItem.normalizedTitle(editChecklistItemDraftTitle) {
            return editRoutineChecklistItems + [
                RoutineChecklistItem(
                    title: pendingTitle,
                    intervalDays: editChecklistItemDraftInterval
                )
            ]
        }
        return editRoutineChecklistItems
    }
}
