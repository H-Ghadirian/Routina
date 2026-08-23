enum TaskDetailMacTimeControlPresentation {
    static func canShowTimeControl(for taskType: RoutineTaskType) -> Bool {
        switch taskType {
        case .todo:
            return true
        case .routine:
            return false
        }
    }

    static func showsHeaderBox(
        for taskType: RoutineTaskType,
        isTimeControlVisible: Bool,
        hasEffortMetadata: Bool
    ) -> Bool {
        switch taskType {
        case .todo:
            return isTimeControlVisible || hasEffortMetadata
        case .routine:
            return false
        }
    }

    static func showsAddAction(
        for taskType: RoutineTaskType,
        isTimeControlVisible: Bool,
        hasEffortMetadata: Bool
    ) -> Bool {
        canShowTimeControl(for: taskType)
            && !showsHeaderBox(
                for: taskType,
                isTimeControlVisible: isTimeControlVisible,
                hasEffortMetadata: hasEffortMetadata
            )
    }
}
