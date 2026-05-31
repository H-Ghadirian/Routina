import Foundation

/// Sections shown in the add/edit task form (and its sidebar navigator).
///
/// Adding a new case here will fail to compile every exhaustive switch
/// (`icon`, `formSectionView`), forcing all call sites to be updated.
///
/// Declaration order is the default movable order shown in the sidebar.
/// `rawValue` is the persistence key, so changing it would invalidate users'
/// saved section order. Use `title` for display copy.
enum FormSection: String, CaseIterable, Hashable, Codable {
    case identity           = "Identity"
    case color              = "Color"
    case behavior           = "Behavior"
    case pressure           = "Pressure"
    case estimation         = "Estimation"
    case places             = "Places"
    case importanceUrgency  = "Importance & Urgency"
    case tags               = "Tags"
    case goals              = "Goals"
    case linkedTasks        = "Linked tasks"
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
        case .importanceUrgency:
            return "Priority"
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
        case .identity:          return "person.fill"
        case .color:             return "paintpalette.fill"
        case .behavior:          return "repeat"
        case .pressure:          return "brain"
        case .estimation:        return "clock.fill"
        case .places:            return "mappin.and.ellipse"
        case .importanceUrgency: return "flag.fill"
        case .tags:              return "tag.fill"
        case .goals:             return "target"
        case .linkedTasks:       return "link"
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
        sections += [.color, .behavior, .pressure, .estimation, .places, .importanceUrgency, .tags, .goals, .linkedTasks, .linkURL, .notes]
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
        populatedSections: Set<FormSection>
    ) -> [FormSection] {
        guard mode.usesProgressiveDisclosure else {
            return sections
        }

        let primarySections: Set<FormSection> = [.identity, .behavior]
        return sections.filter {
            primarySections.contains($0)
                || populatedSections.contains($0)
                || revealedSections.contains($0)
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

        if color.wrappedValue != .none {
            sections.insert(.color)
        }
        if pressure.wrappedValue != .none {
            sections.insert(.pressure)
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
        if importance.wrappedValue != .level2 || urgency.wrappedValue != .level2 {
            sections.insert(.importanceUrgency)
        }
        if !routineTags.isEmpty || hasText(tagDraft.wrappedValue) {
            sections.insert(.tags)
        }
        if !selectedGoals.isEmpty || hasText(goalDraft.wrappedValue) {
            sections.insert(.goals)
        }
        if !relationships.isEmpty {
            sections.insert(.linkedTasks)
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

        if basics.routineColor != .none {
            sections.insert(.color)
        }
        if basics.pressure != .none {
            sections.insert(.pressure)
        }
        if basics.estimatedDurationMinutes != nil || basics.storyPoints != nil || basics.focusModeEnabled {
            sections.insert(.estimation)
        }
        if basics.selectedPlaceID != nil {
            sections.insert(.places)
        }
        if basics.importance != .level2 || basics.urgency != .level2 {
            sections.insert(.importanceUrgency)
        }
        if !organization.routineTags.isEmpty || hasText(organization.tagDraft) {
            sections.insert(.tags)
        }
        if !organization.routineGoals.isEmpty || hasText(organization.goalDraft) {
            sections.insert(.goals)
        }
        if !organization.relationships.isEmpty {
            sections.insert(.linkedTasks)
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

extension TaskDetailFeature.State {
    var populatedMacFormSections: Set<FormSection> {
        var sections = Set<FormSection>()

        if editColor != .none {
            sections.insert(.color)
        }
        if editPressure != .none {
            sections.insert(.pressure)
        }
        if editEstimatedDurationMinutes != nil
            || editActualDurationMinutes != nil
            || editStoryPoints != nil
            || editFocusModeEnabled {
            sections.insert(.estimation)
        }
        if editSelectedPlaceID != nil {
            sections.insert(.places)
        }
        if editImportance != .level2 || editUrgency != .level2 {
            sections.insert(.importanceUrgency)
        }
        if !editRoutineTags.isEmpty || hasText(editTagDraft) {
            sections.insert(.tags)
        }
        if !editRoutineGoals.isEmpty || hasText(editGoalDraft) {
            sections.insert(.goals)
        }
        if !editRelationships.isEmpty {
            sections.insert(.linkedTasks)
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
