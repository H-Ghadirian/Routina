import CoreData

extension RoutineTask {
    public static func == (lhs: RoutineTask, rhs: RoutineTask) -> Bool {
        lhs.objectID == rhs.objectID
    }
}
