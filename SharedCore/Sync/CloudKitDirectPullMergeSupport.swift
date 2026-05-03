import Foundation

enum CloudKitDirectPullMergeSupport {
    struct LogDeduplicationKey: Hashable {
        let taskID: UUID
        let timestampBucket: Int?

        init(taskID: UUID, timestamp: Date?) {
            self.taskID = taskID
            self.timestampBucket = timestamp.map { Int($0.timeIntervalSince1970.rounded()) }
        }
    }

    static func timestampsMatch(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return abs(lhs.timeIntervalSince1970 - rhs.timeIntervalSince1970) < 1
        default:
            return false
        }
    }

    static func preferredPlaceToKeep(
        from places: [RoutinePlace],
        linkedCounts: [UUID: Int]
    ) -> RoutinePlace {
        places.min { lhs, rhs in
            placeSelectionKey(lhs, linkedCounts: linkedCounts) < placeSelectionKey(rhs, linkedCounts: linkedCounts)
        } ?? places[0]
    }

    private static func placeSelectionKey(
        _ place: RoutinePlace,
        linkedCounts: [UUID: Int]
    ) -> (Int, Int, Date, String, String) {
        let rawName = place.name
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkedCountPenalty = -linkedCounts[place.id, default: 0]
        let whitespacePenalty = rawName == trimmedName ? 0 : 1
        let foldedName = trimmedName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return (
            linkedCountPenalty,
            whitespacePenalty,
            place.createdAt,
            foldedName,
            place.id.uuidString.lowercased()
        )
    }
}
