import CloudKit
import Foundation

extension CloudKitDirectPullService {
    struct TaskPayload {
        var id: UUID
        var name: String?
        var emoji: String?
        var notes: String?
        var link: String?
        var deadline: Date?
        var reminderAt: Date?
        var placeID: UUID?
        var tags: [String]?
        var goalIDs: [UUID]?
        var steps: [RoutineStep]?
        var checklistItems: [RoutineChecklistItem]?
        var imageData: Data?
        var scheduleMode: RoutineScheduleMode?
        var interval: Int16
        var recurrenceRule: RoutineRecurrenceRule?
        var lastDone: Date?
        var canceledAt: Date?
        var scheduleAnchor: Date?
        var pausedAt: Date?
        var snoozedUntil: Date?
        var pinnedAt: Date?
        var completedStepCount: Int16
        var sequenceStartedAt: Date?
        var createdAt: Date?
        var todoStateRawValue: String?
        var activityStateRawValue: String?
        var ongoingSince: Date?
        var autoAssumeDailyDone: Bool?
        var estimatedDurationMinutes: Int?
        var actualDurationMinutes: Int?
        var storyPoints: Int?
        var pressure: RoutineTaskPressure?
        var pressureUpdatedAt: Date?
    }

    struct GoalPayload {
        var id: UUID
        var title: String?
        var emoji: String?
        var notes: String?
        var targetDate: Date?
        var status: RoutineGoalStatus?
        var color: RoutineTaskColor?
        var createdAt: Date?
        var sortOrder: Int?
    }

    struct PlacePayload {
        var id: UUID
        var name: String?
        var latitude: Double
        var longitude: Double
        var radiusMeters: Double
        var createdAt: Date?
    }

    struct LogPayload {
        var id: UUID
        var timestamp: Date?
        var taskID: UUID
        var kind: RoutineLogKind
        var actualDurationMinutes: Int?
    }

    static func stringValue(in record: CKRecord, keys: [String]) -> String? {
        for key in keys {
            if let value = record[key] as? String {
                return value
            }
        }

        let lowerLookup = Dictionary(uniqueKeysWithValues: record.allKeys().map { ($0.lowercased(), $0) })
        for key in keys {
            if let matchedKey = lowerLookup[key.lowercased()],
               let value = record[matchedKey] as? String {
                return value
            }
        }
        return nil
    }

    static func dataValue(in record: CKRecord, keys: [String]) -> Data? {
        for key in keys {
            if let value = record[key] as? Data {
                return value
            }
            if let asset = record[key] as? CKAsset,
               let fileURL = asset.fileURL,
               let data = try? Data(contentsOf: fileURL) {
                return data
            }
        }

        let lowerLookup = Dictionary(uniqueKeysWithValues: record.allKeys().map { ($0.lowercased(), $0) })
        for key in keys {
            guard let matchedKey = lowerLookup[key.lowercased()] else { continue }
            if let value = record[matchedKey] as? Data {
                return value
            }
            if let asset = record[matchedKey] as? CKAsset,
               let fileURL = asset.fileURL,
               let data = try? Data(contentsOf: fileURL) {
                return data
            }
        }
        return nil
    }

    static func intValue(in record: CKRecord, keys: [String]) -> Int? {
        for key in keys {
            if let value = record[key] as? NSNumber {
                return value.intValue
            }
            if let value = record[key] as? Int {
                return value
            }
            if let value = record[key] as? Int64 {
                return Int(value)
            }
        }

        let lowerLookup = Dictionary(uniqueKeysWithValues: record.allKeys().map { ($0.lowercased(), $0) })
        for key in keys {
            if let matchedKey = lowerLookup[key.lowercased()],
               let number = record[matchedKey] as? NSNumber {
                return number.intValue
            }
        }
        return nil
    }

    static func boolValue(in record: CKRecord, keys: [String]) -> Bool? {
        for key in keys {
            if let value = record[key] as? NSNumber {
                return value.boolValue
            }
            if let value = record[key] as? Bool {
                return value
            }
        }

        let lowerLookup = Dictionary(uniqueKeysWithValues: record.allKeys().map { ($0.lowercased(), $0) })
        for key in keys {
            if let matchedKey = lowerLookup[key.lowercased()],
               let number = record[matchedKey] as? NSNumber {
                return number.boolValue
            }
        }
        return nil
    }

    static func doubleValue(in record: CKRecord, keys: [String]) -> Double? {
        for key in keys {
            if let value = record[key] as? NSNumber {
                return value.doubleValue
            }
            if let value = record[key] as? Double {
                return value
            }
        }

        let lowerLookup = Dictionary(uniqueKeysWithValues: record.allKeys().map { ($0.lowercased(), $0) })
        for key in keys {
            if let matchedKey = lowerLookup[key.lowercased()],
               let number = record[matchedKey] as? NSNumber {
                return number.doubleValue
            }
        }
        return nil
    }

    static func dateValue(in record: CKRecord, keys: [String]) -> Date? {
        for key in keys {
            if let value = record[key] as? Date {
                return value
            }
            if let value = record[key] as? NSDate {
                return value as Date
            }
        }

        let lowerLookup = Dictionary(uniqueKeysWithValues: record.allKeys().map { ($0.lowercased(), $0) })
        for key in keys {
            if let matchedKey = lowerLookup[key.lowercased()],
               let value = record[matchedKey] as? Date {
                return value
            }
        }
        return nil
    }

    static func uuidValue(in record: CKRecord, keys: [String]) -> UUID? {
        for key in keys {
            if let uuid = record[key] as? UUID {
                return uuid
            }
            if let string = record[key] as? String, let uuid = UUID(uuidString: string) {
                return uuid
            }
        }

        let lowerLookup = Dictionary(uniqueKeysWithValues: record.allKeys().map { ($0.lowercased(), $0) })
        for key in keys {
            if let matchedKey = lowerLookup[key.lowercased()] {
                if let uuid = record[matchedKey] as? UUID {
                    return uuid
                }
                if let string = record[matchedKey] as? String, let uuid = UUID(uuidString: string) {
                    return uuid
                }
            }
        }
        return nil
    }

    static func isTaskRecordType(_ recordType: String) -> Bool {
        let normalized = recordType.lowercased()
        return normalized.contains("routinetask")
            || normalized.contains("routine_task")
    }

    static func isPlaceRecordType(_ recordType: String) -> Bool {
        let normalized = recordType.lowercased()
        return normalized.contains("routineplace")
            || normalized.contains("routine_place")
    }

    static func isGoalRecordType(_ recordType: String) -> Bool {
        let normalized = recordType.lowercased()
        return normalized.contains("routinegoal")
            || normalized.contains("routine_goal")
    }

    static func isLogRecordType(_ recordType: String) -> Bool {
        let normalized = recordType.lowercased()
        return normalized.contains("routinelog")
            || normalized.contains("routine_log")
    }
}
