import Foundation

struct PlaceDeduplicationKey: Comparable {
    let linkedCountPenalty: Int
    let whitespacePenalty: Int
    let createdAt: Date
    let foldedName: String
    let normalizedID: String

    init(place: RoutinePlace, linkedCount: Int) {
        let rawName = place.name
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        linkedCountPenalty = -linkedCount
        whitespacePenalty = rawName == trimmedName ? 0 : 1
        createdAt = place.createdAt
        foldedName = trimmedName.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        normalizedID = place.id.uuidString.lowercased()
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.linkedCountPenalty != rhs.linkedCountPenalty {
            return lhs.linkedCountPenalty < rhs.linkedCountPenalty
        }
        if lhs.whitespacePenalty != rhs.whitespacePenalty {
            return lhs.whitespacePenalty < rhs.whitespacePenalty
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        if lhs.foldedName != rhs.foldedName {
            return lhs.foldedName < rhs.foldedName
        }
        return lhs.normalizedID < rhs.normalizedID
    }
}
