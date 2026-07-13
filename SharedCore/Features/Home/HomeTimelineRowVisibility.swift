import Foundation

enum HomeTimelineRowField: String, CaseIterable, Identifiable, Sendable {
    case icon
    case rowNumber
    case subtitle
    case kindBadge

    var id: Self { self }

    var title: String {
        switch self {
        case .icon:
            return "Icon"
        case .rowNumber:
            return "Row Number"
        case .subtitle:
            return "Subtitle"
        case .kindBadge:
            return "Type"
        }
    }

    var subtitle: String {
        switch self {
        case .icon:
            return "Timeline task emoji and source marker."
        case .rowNumber:
            return "Visible row index in the current timeline list."
        case .subtitle:
            return "Completion and metadata summary text."
        case .kindBadge:
            return "Routine, Todo, Tracking, Event, Note, or type label at the right side."
        }
    }

    static func decodedHiddenFields(from rawValue: String?) -> Set<Self> {
        guard let rawValue, !rawValue.isEmpty else { return [] }
        return Set(
            rawValue
                .split(separator: ",")
                .compactMap { HomeTimelineRowField(rawValue: String($0)) }
        )
    }

    static func encodedHiddenFields(_ fields: Set<Self>) -> String? {
        let orderedValues = allCases
            .filter { fields.contains($0) }
            .map(\.rawValue)
        return orderedValues.isEmpty ? nil : orderedValues.joined(separator: ",")
    }
}

struct HomeTimelineRowVisibility: Equatable, Sendable {
    static let defaultValue = HomeTimelineRowVisibility()

    var hiddenFields: Set<HomeTimelineRowField>

    init(hiddenFields: Set<HomeTimelineRowField> = []) {
        self.hiddenFields = hiddenFields.intersection(Set(HomeTimelineRowField.allCases))
    }

    init(storageRawValue: String?) {
        self.init(hiddenFields: HomeTimelineRowField.decodedHiddenFields(from: storageRawValue))
    }

    var storageRawValue: String? {
        HomeTimelineRowField.encodedHiddenFields(hiddenFields)
    }

    var summaryText: String {
        guard !hiddenFields.isEmpty else { return "All fields" }
        let visibleCount = HomeTimelineRowField.allCases.count - hiddenFields.count
        return "\(visibleCount) of \(HomeTimelineRowField.allCases.count) fields"
    }

    func shows(_ field: HomeTimelineRowField) -> Bool {
        !hiddenFields.contains(field)
    }

    func setting(_ field: HomeTimelineRowField, visible isVisible: Bool) -> HomeTimelineRowVisibility {
        var updatedFields = hiddenFields
        if isVisible {
            updatedFields.remove(field)
        } else {
            updatedFields.insert(field)
        }
        return HomeTimelineRowVisibility(hiddenFields: updatedFields)
    }
}
