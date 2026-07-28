import Foundation

enum DayPlanCalendarListRowField: String, CaseIterable, Identifiable, Sendable {
    case icon
    case placement
    case rowColor

    var id: Self { self }

    var title: String {
        switch self {
        case .icon:
            return "Icon"
        case .placement:
            return "Time and Duration"
        case .rowColor:
            return "Row Color"
        }
    }

    var subtitle: String {
        switch self {
        case .icon:
            return "Task emoji or fallback marker."
        case .placement:
            return "Any-time, all-day, completion-time, and duration details."
        case .rowColor:
            return "Custom task tint on the row surface."
        }
    }

    static func decodedHiddenFields(from rawValue: String?) -> Set<Self> {
        guard let rawValue, !rawValue.isEmpty else { return [] }
        return Set(
            rawValue
                .split(separator: ",")
                .compactMap { DayPlanCalendarListRowField(rawValue: String($0)) }
        )
    }

    static func encodedHiddenFields(_ fields: Set<Self>) -> String? {
        let orderedValues = allCases
            .filter { fields.contains($0) }
            .map(\.rawValue)
        return orderedValues.isEmpty ? nil : orderedValues.joined(separator: ",")
    }
}

struct DayPlanCalendarListRowVisibility: Equatable, Sendable {
    static let defaultValue = DayPlanCalendarListRowVisibility()

    var hiddenFields: Set<DayPlanCalendarListRowField>

    init(hiddenFields: Set<DayPlanCalendarListRowField> = []) {
        self.hiddenFields = hiddenFields.intersection(Set(DayPlanCalendarListRowField.allCases))
    }

    init(storageRawValue: String?) {
        self.init(
            hiddenFields: DayPlanCalendarListRowField.decodedHiddenFields(
                from: storageRawValue
            )
        )
    }

    var storageRawValue: String? {
        DayPlanCalendarListRowField.encodedHiddenFields(hiddenFields)
    }

    var summaryText: String {
        guard !hiddenFields.isEmpty else { return "All fields" }
        let visibleCount = DayPlanCalendarListRowField.allCases.count - hiddenFields.count
        return "\(visibleCount) of \(DayPlanCalendarListRowField.allCases.count) fields"
    }

    func shows(_ field: DayPlanCalendarListRowField) -> Bool {
        !hiddenFields.contains(field)
    }

    func setting(
        _ field: DayPlanCalendarListRowField,
        visible isVisible: Bool
    ) -> DayPlanCalendarListRowVisibility {
        var updatedFields = hiddenFields
        if isVisible {
            updatedFields.remove(field)
        } else {
            updatedFields.insert(field)
        }
        return DayPlanCalendarListRowVisibility(hiddenFields: updatedFields)
    }
}
