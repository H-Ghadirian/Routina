import Foundation

/// Sections shown in the add/edit task form (and its sidebar navigator).
///
/// Adding a new case here will fail to compile every exhaustive switch
/// (`icon`, `formSectionView`), forcing all call sites to be updated.
///
/// Declaration order is the default movable order shown in the sidebar.
/// `rawValue` doubles as the display title and the persistence key, so
/// changing it would invalidate users' saved section order.
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
    case image              = "Image"
    case attachment         = "Attachment"
    case dangerZone         = "Danger Zone"

    var title: String { rawValue }

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
        case .image:             return "photo.fill"
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
        sections.append(.image)
        sections.append(.attachment)
        if includesDangerZone {
            sections.append(.dangerZone)
        }
        return sections
    }
}

extension RoutineScheduleMode {
    var isTaskFormStepBased: Bool {
        self == .fixedInterval || self == .softInterval || self == .oneOff
    }
}
