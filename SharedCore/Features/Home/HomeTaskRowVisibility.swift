import Foundation

enum HomeTaskRowField: String, CaseIterable, Identifiable, Sendable {
    case icon
    case rowColor
    case colorBadge
    case rowNumber
    case taskTypeBadge
    case statusBadge
    case schedule
    case priority
    case pressure
    case progress
    case steps
    case place
    case tags
    case goals

    var id: Self { self }

    var title: String {
        switch self {
        case .icon:
            return "Icon"
        case .rowColor:
            return "Row Color"
        case .colorBadge:
            return "Color Badge"
        case .rowNumber:
            return "Row Number"
        case .taskTypeBadge:
            return "Routine / Todo Badge"
        case .statusBadge:
            return "Status Badge"
        case .schedule:
            return "Schedule and Due Dates"
        case .priority:
            return "Priority"
        case .pressure:
            return "Pressure"
        case .progress:
            return "Progress"
        case .steps:
            return "Steps and Checklist"
        case .place:
            return "Places"
        case .tags:
            return "Tags"
        case .goals:
            return "Goals"
        }
    }

    var subtitle: String? {
        switch self {
        case .icon:
            return "Emoji, image marker, and color block."
        case .rowColor:
            return "Custom task tint and row background."
        case .colorBadge:
            return "Small custom color marker at the row edge."
        case .rowNumber:
            return "Visible position in the current list."
        case .taskTypeBadge:
            return "Routine or todo label in All mode."
        case .statusBadge:
            return "Due, overdue, done, paused, and todo state."
        case .schedule:
            return "Recurrence cadence and todo deadlines."
        case .priority:
            return "Low, medium, high, and urgent labels."
        case .pressure:
            return "Low, medium, and high pressure labels."
        case .progress:
            return "Completion counts, last activity, and current step."
        case .steps:
            return "Next step or checklist summary."
        case .place:
            return "Linked place availability."
        case .tags:
            return nil
        case .goals:
            return "Linked goals."
        }
    }

    static func decodedHiddenFields(from rawValue: String?) -> Set<Self> {
        guard let rawValue, !rawValue.isEmpty else { return [] }
        return Set(
            rawValue
                .split(separator: ",")
                .compactMap { HomeTaskRowField(rawValue: String($0)) }
        )
    }

    static func encodedHiddenFields(_ fields: Set<Self>) -> String? {
        let orderedValues = allCases
            .filter { fields.contains($0) }
            .map(\.rawValue)
        return orderedValues.isEmpty ? nil : orderedValues.joined(separator: ",")
    }
}

struct HomeTaskRowVisibility: Equatable, Sendable {
    static let defaultValue = HomeTaskRowVisibility()

    var hiddenFields: Set<HomeTaskRowField>

    init(hiddenFields: Set<HomeTaskRowField> = []) {
        self.hiddenFields = hiddenFields.intersection(Set(HomeTaskRowField.allCases))
    }

    init(storageRawValue: String?) {
        self.init(hiddenFields: HomeTaskRowField.decodedHiddenFields(from: storageRawValue))
    }

    var storageRawValue: String? {
        HomeTaskRowField.encodedHiddenFields(hiddenFields)
    }

    var summaryText: String {
        guard !hiddenFields.isEmpty else { return "All fields" }
        let visibleCount = HomeTaskRowField.allCases.count - hiddenFields.count
        return "\(visibleCount) of \(HomeTaskRowField.allCases.count) fields"
    }

    func shows(_ field: HomeTaskRowField) -> Bool {
        !hiddenFields.contains(field)
    }

    func setting(_ field: HomeTaskRowField, visible isVisible: Bool) -> HomeTaskRowVisibility {
        var updatedFields = hiddenFields
        if isVisible {
            updatedFields.remove(field)
        } else {
            updatedFields.insert(field)
        }
        return HomeTaskRowVisibility(hiddenFields: updatedFields)
    }
}
