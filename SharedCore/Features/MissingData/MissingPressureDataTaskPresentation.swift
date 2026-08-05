import Foundation

enum MissingPressureDataTaskPresentation {
    struct Context: Equatable {
        var tags: [String]
        var additionalTagCount: Int
        var path: [String]
        var labels: [Label]
    }

    struct Label: Equatable, Identifiable {
        let title: String
        let systemImage: String

        var id: String { "\(systemImage)-\(title)" }
    }

    static func context(
        for task: RoutineTask,
        customTaskSections: [HomeCustomTaskSection],
        referenceDate: Date,
        calendar: Calendar
    ) -> Context {
        let tags = task.tags
        return Context(
            tags: Array(tags.prefix(3)),
            additionalTagCount: max(tags.count - 3, 0),
            path: task.customTaskSectionID.flatMap {
                HomeCustomTaskSectionStorage.pathTitles(
                    for: $0,
                    in: customTaskSections
                )
            } ?? [],
            labels: Array(
                labels(
                    for: task,
                    referenceDate: referenceDate,
                    calendar: calendar
                ).prefix(3)
            )
        )
    }

    private static func labels(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> [Label] {
        var labels: [Label] = []

        if let plannedDate = task.plannedDate {
            labels.append(
                Label(
                    title: planningTitle(for: plannedDate, referenceDate: referenceDate, calendar: calendar),
                    systemImage: "calendar"
                )
            )
        }

        if let deadline = task.deadline {
            labels.append(
                Label(
                    title: deadlineTitle(for: deadline, referenceDate: referenceDate, calendar: calendar),
                    systemImage: "calendar.badge.clock"
                )
            )
        }

        if task.isOneOffTask, let todoState = task.todoState, todoState != .ready {
            labels.append(Label(title: todoState.displayTitle, systemImage: todoState.systemImage))
        } else if task.isPaused {
            labels.append(Label(title: "Paused", systemImage: "pause.circle.fill"))
        } else if task.isOngoing {
            labels.append(Label(title: "Ongoing", systemImage: "play.circle.fill"))
        }

        return labels
    }

    private static func planningTitle(
        for date: Date,
        referenceDate: Date,
        calendar: Calendar
    ) -> String {
        switch dayOffset(for: date, referenceDate: referenceDate, calendar: calendar) {
        case 0:
            return "Planned today"
        case 1:
            return "Planned tomorrow"
        default:
            return "Planned \(date.formatted(.dateTime.month(.abbreviated).day()))"
        }
    }

    private static func deadlineTitle(
        for date: Date,
        referenceDate: Date,
        calendar: Calendar
    ) -> String {
        let offset = dayOffset(for: date, referenceDate: referenceDate, calendar: calendar)
        switch offset {
        case ..<0:
            return "Overdue \(abs(offset))d"
        case 0:
            return "Due today"
        case 1:
            return "Due tomorrow"
        default:
            return "Due \(date.formatted(.dateTime.month(.abbreviated).day()))"
        }
    }

    private static func dayOffset(
        for date: Date,
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: referenceDate),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
    }
}
