import CoreData

extension RoutineLog {
    public static func == (lhs: RoutineLog, rhs: RoutineLog) -> Bool {
        lhs.objectID == rhs.objectID
    }
}
