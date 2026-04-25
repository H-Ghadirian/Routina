import Foundation

protocol HomeTaskRowDisplay: HomeTaskListDisplay {
    var steps: [String] { get }
    var dueChecklistItemCount: Int { get }
}

enum HomeTaskRowCompletionPresentation {
    static func markDoneLabel<Display: HomeTaskRowDisplay>(for task: Display) -> String {
        if task.scheduleMode == .derivedFromChecklist {
            if task.dueChecklistItemCount == 0 {
                return "No Due Items"
            }
            if task.dueChecklistItemCount == 1 {
                return "Buy Due Item"
            }
            return "Buy Due Items"
        }
        if task.scheduleMode == .fixedIntervalChecklist {
            return "Checklist"
        }
        return task.steps.isEmpty ? "Mark Done" : "Complete Next Step"
    }

    static func isMarkDoneDisabled<Display: HomeTaskRowDisplay>(
        _ task: Display,
        referenceDate: Date = Date()
    ) -> Bool {
        if task.isOneOffTask {
            return task.isCompletedOneOff || task.isCanceledOneOff || task.isPaused
        }
        if task.scheduleMode == .derivedFromChecklist {
            return task.isPaused || task.dueChecklistItemCount == 0
        }
        if task.scheduleMode == .fixedIntervalChecklist {
            return true
        }
        if task.recurrenceRule.isFixedCalendar,
           let dueDate = task.dueDate,
           dueDate > referenceDate {
            return true
        }
        return task.isDoneToday || task.isPaused
    }
}

enum HomeTaskRowCommand: Equatable {
    case open(UUID)
    case resume(UUID)
    case markDone(UUID)
    case notToday(UUID)
    case pause(UUID)
    case moveTaskInSection(taskID: UUID, sectionKey: String, orderedTaskIDs: [UUID], direction: HomeTaskMoveDirection)
    case pin(UUID)
    case unpin(UUID)
    case delete(UUID)
}

struct HomeTaskRowCommandHandler {
    var open: (UUID) -> Void
    var resume: (UUID) -> Void
    var markDone: (UUID) -> Void
    var notToday: (UUID) -> Void
    var pause: (UUID) -> Void
    var moveTaskInSection: (UUID, String, [UUID], HomeTaskMoveDirection) -> Void
    var pin: (UUID) -> Void
    var unpin: (UUID) -> Void
    var delete: (UUID) -> Void

    func handle(_ command: HomeTaskRowCommand) {
        switch command {
        case let .open(taskID):
            open(taskID)
        case let .resume(taskID):
            resume(taskID)
        case let .markDone(taskID):
            markDone(taskID)
        case let .notToday(taskID):
            notToday(taskID)
        case let .pause(taskID):
            pause(taskID)
        case let .moveTaskInSection(taskID, sectionKey, orderedTaskIDs, direction):
            moveTaskInSection(taskID, sectionKey, orderedTaskIDs, direction)
        case let .pin(taskID):
            pin(taskID)
        case let .unpin(taskID):
            unpin(taskID)
        case let .delete(taskID):
            delete(taskID)
        }
    }
}

enum HomeTaskRowLifecycleAction: Equatable, Identifiable {
    case resume
    case markDone(title: String, isDisabled: Bool)
    case notToday
    case pause

    var id: String {
        switch self {
        case .resume:
            return "resume"
        case .markDone:
            return "markDone"
        case .notToday:
            return "notToday"
        case .pause:
            return "pause"
        }
    }

    var title: String {
        switch self {
        case .resume:
            return "Resume"
        case let .markDone(title, _):
            return title
        case .notToday:
            return "Not today!"
        case .pause:
            return "Pause"
        }
    }

    var systemImage: String {
        switch self {
        case .resume:
            return "play.circle"
        case .markDone:
            return "checkmark.circle"
        case .notToday:
            return "moon.zzz"
        case .pause:
            return "pause.circle"
        }
    }

    var isDisabled: Bool {
        guard case let .markDone(_, isDisabled) = self else { return false }
        return isDisabled
    }

    func command(taskID: UUID) -> HomeTaskRowCommand {
        switch self {
        case .resume:
            return .resume(taskID)
        case .markDone:
            return .markDone(taskID)
        case .notToday:
            return .notToday(taskID)
        case .pause:
            return .pause(taskID)
        }
    }
}

struct HomeTaskRowMoveActionPresentation: Equatable, Identifiable {
    let direction: HomeTaskMoveDirection
    let title: String
    let systemImage: String
    let isDisabled: Bool
    let moveContext: HomeTaskListMoveContext

    var id: String {
        direction.rawValue
    }

    func command(taskID: UUID) -> HomeTaskRowCommand {
        .moveTaskInSection(
            taskID: taskID,
            sectionKey: moveContext.sectionKey,
            orderedTaskIDs: moveContext.orderedTaskIDs,
            direction: direction
        )
    }
}

struct HomeTaskRowPinActionPresentation: Equatable {
    let title: String
    let systemImage: String
    let command: HomeTaskRowCommand

    init(taskID: UUID, isPinned: Bool) {
        title = isPinned ? "Unpin from Top" : "Pin to Top"
        systemImage = isPinned ? "pin.slash" : "pin"
        command = isPinned ? .unpin(taskID) : .pin(taskID)
    }
}

struct HomeTaskRowActionPresentation: Equatable {
    let taskID: UUID
    let lifecycleActions: [HomeTaskRowLifecycleAction]
    let moveActions: [HomeTaskRowMoveActionPresentation]
    let pinAction: HomeTaskRowPinActionPresentation?

    var openCommand: HomeTaskRowCommand {
        .open(taskID)
    }

    var deleteCommand: HomeTaskRowCommand {
        .delete(taskID)
    }

    static func make<Display: HomeTaskRowDisplay>(
        for task: Display,
        includeMarkDone: Bool,
        moveContext: HomeTaskListMoveContext? = nil,
        allowsPinning: Bool,
        referenceDate: Date = Date()
    ) -> HomeTaskRowActionPresentation {
        HomeTaskRowActionPresentation(
            taskID: task.taskID,
            lifecycleActions: lifecycleActions(
                for: task,
                includeMarkDone: includeMarkDone,
                referenceDate: referenceDate
            ),
            moveActions: moveActions(
                taskID: task.taskID,
                moveContext: moveContext
            ),
            pinAction: allowsPinning
                ? HomeTaskRowPinActionPresentation(taskID: task.taskID, isPinned: task.isPinned)
                : nil
        )
    }

    private static func lifecycleActions<Display: HomeTaskRowDisplay>(
        for task: Display,
        includeMarkDone: Bool,
        referenceDate: Date
    ) -> [HomeTaskRowLifecycleAction] {
        if task.isPaused {
            return [.resume]
        }
        if task.isCompletedOneOff || task.isCanceledOneOff {
            return []
        }

        var actions: [HomeTaskRowLifecycleAction] = []

        if includeMarkDone {
            actions.append(
                .markDone(
                    title: HomeTaskRowCompletionPresentation.markDoneLabel(for: task),
                    isDisabled: HomeTaskRowCompletionPresentation.isMarkDoneDisabled(
                        task,
                        referenceDate: referenceDate
                    )
                )
            )
        }

        if !task.isOneOffTask {
            actions.append(.notToday)
            actions.append(.pause)
        }

        return actions
    }

    private static func moveActions(
        taskID: UUID,
        moveContext: HomeTaskListMoveContext?
    ) -> [HomeTaskRowMoveActionPresentation] {
        guard let moveContext,
              let currentIndex = moveContext.orderedTaskIDs.firstIndex(of: taskID) else {
            return []
        }

        let isFirst = currentIndex == 0
        let isLast = currentIndex == moveContext.orderedTaskIDs.count - 1

        return [
            HomeTaskRowMoveActionPresentation(
                direction: .top,
                title: "Move to Top",
                systemImage: "arrow.up.to.line",
                isDisabled: isFirst,
                moveContext: moveContext
            ),
            HomeTaskRowMoveActionPresentation(
                direction: .up,
                title: "Move Up",
                systemImage: "arrow.up",
                isDisabled: isFirst,
                moveContext: moveContext
            ),
            HomeTaskRowMoveActionPresentation(
                direction: .down,
                title: "Move Down",
                systemImage: "arrow.down",
                isDisabled: isLast,
                moveContext: moveContext
            ),
            HomeTaskRowMoveActionPresentation(
                direction: .bottom,
                title: "Move to Bottom",
                systemImage: "arrow.down.to.line",
                isDisabled: isLast,
                moveContext: moveContext
            )
        ]
    }
}
