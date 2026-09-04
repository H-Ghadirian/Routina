import Foundation

/// Platform-neutral meaning used by every task-row surface that consumes the
/// shared semantic snapshot. Views remain free to render these tones using
/// platform-appropriate controls and density.
enum TaskRowSemanticTone: Equatable, Sendable {
    case secondary
    case blue
    case green
    case indigo
    case orange
    case red
    case teal
}

typealias BacklogTaskRowTone = TaskRowSemanticTone

struct BacklogTaskRowPresentationContext {
    let flagRules: [RoutineFlagRule]
    let relationshipBlockedTaskIDs: Set<UUID>
    let referenceDate: Date
    let calendar: Calendar
}

struct TaskRowSemanticPresentation: Equatable, Identifiable, Sendable {
    struct Status: Equatable, Sendable {
        let title: String
        let systemImage: String
        let tone: TaskRowSemanticTone
    }

    let id: UUID
    let name: String
    let emoji: String
    let hasImage: Bool
    let isPinned: Bool
    /// Nil is reserved for Task Ladder container groups, which are not tasks.
    let taskType: RoutineTaskType?
    let color: RoutineTaskColor
    let status: Status?
    let scheduleText: String?
    let pressureText: String?
    let progressText: String?
    let stepsText: String?
    let placeText: String?
    let tags: [String]
    let flags: [String]
    let hidingFlags: [String]

    var isOneOffTask: Bool {
        taskType == .todo
    }

    static func make(
        task: RoutineTask,
        flagRules: [RoutineFlagRule],
        referenceDate: Date,
        calendar: Calendar,
        isRelationshipBlocked: Bool = false
    ) -> Self {
        Self(
            id: task.id,
            name: RoutineTask.trimmedName(task.name) ?? "Untitled task",
            emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "✨",
            hasImage: task.hasImage,
            isPinned: task.isPinned,
            taskType: task.scheduleMode.taskType,
            color: task.color,
            status: status(
                for: task,
                isRelationshipBlocked: isRelationshipBlocked,
                referenceDate: referenceDate,
                calendar: calendar
            ),
            scheduleText: scheduleText(for: task, referenceDate: referenceDate, calendar: calendar),
            pressureText: task.pressure.metadataLabel,
            progressText: progressText(for: task, referenceDate: referenceDate, calendar: calendar),
            stepsText: stepsText(for: task, referenceDate: referenceDate, calendar: calendar),
            placeText: task.destinationAddress?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            tags: task.tags,
            flags: task.flags,
            hidingFlags: RoutineFlagRules.flagsHidingFromTaskLists(task.flags, rules: flagRules)
        )
    }

    func metadataText(for visibility: HomeTaskRowVisibility, showsPlaces: Bool) -> String? {
        let items: [String?] = [
            visibility.shows(.schedule) ? scheduleText : nil,
            visibility.shows(.pressure) ? pressureText : nil,
            visibility.shows(.progress) ? progressText : nil,
            visibility.shows(.steps) ? stepsText : nil,
            showsPlaces && visibility.shows(.place) ? placeText : nil,
        ]
        let visibleItems = items.compactMap { $0 }
        return visibleItems.isEmpty ? nil : visibleItems.joined(separator: " • ")
    }

    private static func status(
        for task: RoutineTask,
        isRelationshipBlocked: Bool,
        referenceDate: Date,
        calendar: Calendar
    ) -> Status? {
        if task.isArchived(referenceDate: referenceDate, calendar: calendar) {
            return task.isSnoozed(referenceDate: referenceDate, calendar: calendar)
                ? Status(title: "Not today", systemImage: "moon.zzz.fill", tone: .indigo)
                : Status(title: "Paused", systemImage: "pause.circle.fill", tone: .teal)
        }
        if task.isCompletedOneOff {
            return Status(title: "Done", systemImage: "checkmark.circle.fill", tone: .green)
        }
        if task.isCanceledOneOff {
            return Status(title: "Canceled", systemImage: "xmark.circle.fill", tone: .orange)
        }
        if isRelationshipBlocked {
            return Status(
                title: "Blocked",
                systemImage: "exclamationmark.circle.fill",
                tone: .orange
            )
        }

        if task.isOneOffTask {
            if task.isInProgress || task.todoState == .inProgress {
                return Status(title: "In Progress", systemImage: "arrow.clockwise.circle.fill", tone: .blue)
            }
            if task.todoState == .blocked {
                return Status(title: "Blocked", systemImage: "exclamationmark.circle.fill", tone: .orange)
            }
            return Status(title: "To Do", systemImage: "circle", tone: .secondary)
        }

        if task.isOngoing {
            return Status(title: "In Progress", systemImage: "play.circle.fill", tone: .orange)
        }
        guard task.cadenceEnabled,
            let dueDate = BacklogTaskListPresentation.sortableDueDate(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            )
        else {
            return Status(title: "Ready", systemImage: "circle", tone: .secondary)
        }

        let dueDay = calendar.startOfDay(for: dueDate)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let days = calendar.dateComponents([.day], from: referenceDay, to: dueDay).day ?? 0
        switch days {
        case ..<0:
            return Status(
                title: "Overdue \(abs(days))d",
                systemImage: "exclamationmark.circle.fill",
                tone: .red
            )
        case 0:
            return Status(title: "Today", systemImage: "clock.fill", tone: .orange)
        case 1:
            return Status(title: "Tomorrow", systemImage: "calendar", tone: .orange)
        default:
            return Status(title: "On Track", systemImage: "circle.fill", tone: .teal)
        }
    }

    private static func scheduleText(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> String? {
        if task.isOneOffTask {
            guard let deadline = task.deadline else { return nil }
            return dueText(for: deadline, referenceDate: referenceDate, calendar: calendar)
        }

        guard task.cadenceEnabled else { return "No cadence" }
        let cadence = task.recurrenceRule.displayText()
        guard
            let dueDate = BacklogTaskListPresentation.sortableDueDate(
                for: task,
                referenceDate: referenceDate,
                calendar: calendar
            )
        else {
            return cadence
        }
        return "\(cadence) • \(dueText(for: dueDate, referenceDate: referenceDate, calendar: calendar))"
    }

    private static func progressText(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> String? {
        if task.isInProgress || task.todoState == .inProgress {
            return "Step \(task.completedSteps + 1) of \(max(task.totalSteps, 1))"
        }
        if task.isChecklistCompletionRoutine {
            let completed = task.completedChecklistItemCount(
                referenceDate: referenceDate,
                calendar: calendar
            )
            if completed > 0 {
                return "Checklist \(completed)/\(max(task.totalChecklistItemCount, 1))"
            }
        }
        guard !task.isOneOffTask else { return nil }
        guard let lastDone = task.lastDone else { return "Never completed" }
        let days =
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: lastDone),
                to: calendar.startOfDay(for: referenceDate)
            ).day ?? 0
        switch days {
        case ...0:
            return "Completed today"
        case 1:
            return "Completed yesterday"
        default:
            return "Completed \(days)d ago"
        }
    }

    private static func stepsText(
        for task: RoutineTask,
        referenceDate: Date,
        calendar: Calendar
    ) -> String? {
        if task.isChecklistDriven {
            let dueItems = task.dueChecklistItems(referenceDate: referenceDate, calendar: calendar)
            guard let first = dueItems.first else {
                let count = task.totalChecklistItemCount
                return count == 0 ? nil : "\(count) \(count == 1 ? "item" : "items")"
            }
            return dueItems.count == 1 ? "Due: \(first.title)" : "Due: \(first.title) +\(dueItems.count - 1)"
        }
        if task.isChecklistCompletionRoutine {
            return task.nextPendingChecklistItemTitle(
                referenceDate: referenceDate,
                calendar: calendar
            ).map { "Next: \($0)" }
        }
        if let nextStepTitle = task.nextStepTitle {
            return "Next: \(nextStepTitle)"
        }
        let count = task.totalSteps
        return count > 1 ? "\(count) steps" : nil
    }

    private static func dueText(
        for date: Date,
        referenceDate: Date,
        calendar: Calendar
    ) -> String {
        if calendar.isDate(date, inSameDayAs: referenceDate) {
            return "Due today"
        }
        let isTomorrow =
            calendar.date(byAdding: .day, value: 1, to: referenceDate)
            .map { calendar.isDate(date, inSameDayAs: $0) } ?? false
        if isTomorrow {
            return "Due tomorrow"
        }
        return "Due \(date.formatted(date: .abbreviated, time: .omitted))"
    }
}

/// Backlog owns where and why a task is shown, while this shared value owns
/// what the task means. Keep the established name as a compatibility alias for
/// existing Mac row and presentation call sites.
typealias BacklogTaskRowPresentation = TaskRowSemanticPresentation

enum BacklogTaskRowPresentationCache {
    static func makeList(
        sections: [BacklogTaskListPresentation.Section],
        hiddenByFlagTasks: [RoutineTask],
        outsideBacklogResults: [BacklogTaskListPresentation.OutsideBacklogResult],
        hasAnySearchResult: Bool,
        filterCatalog: BacklogTaskListPresentation.FilterCatalog,
        context: BacklogTaskRowPresentationContext
    ) -> BacklogTaskListPresentation {
        let visibleTasks =
            sections.flatMap { section in
                section.tasks + section.subsections.flatMap(\.tasks)
            } + hiddenByFlagTasks
        let presentedTasks = visibleTasks + outsideBacklogResults.map(\.task)
        let presentations = Dictionary(
            presentedTasks.map { task in
                (
                    task.id,
                    BacklogTaskRowPresentation.make(
                        task: task,
                        flagRules: context.flagRules,
                        referenceDate: context.referenceDate,
                        calendar: context.calendar,
                        isRelationshipBlocked: context.relationshipBlockedTaskIDs.contains(task.id)
                    )
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
        let numbers = Dictionary(
            uniqueKeysWithValues: visibleTasks.enumerated().map { offset, task in
                (task.id, offset + 1)
            }
        )

        return BacklogTaskListPresentation(
            sections: sections,
            hiddenByFlagTasks: hiddenByFlagTasks,
            outsideBacklogResults: outsideBacklogResults,
            hasAnySearchResult: hasAnySearchResult,
            filterCatalog: filterCatalog,
            rowPresentationsByTaskID: presentations,
            rowNumbersByTaskID: numbers
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
