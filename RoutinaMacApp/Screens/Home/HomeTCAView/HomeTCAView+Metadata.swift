import SwiftUI
import ComposableArchitecture

extension HomeTCAView {
    func rowMetadataText(for task: HomeFeature.RoutineDisplay) -> String? {
        if task.isOneOffTask {
            let items = todoRowMetadataItems(for: task)
            return items.isEmpty ? nil : items.joined(separator: " • ")
        }

        let prioritySegment = task.priority.metadataLabel.map { "\($0) • " } ?? ""

        if task.isPaused {
            return "\(cadenceDescription(for: task)) • \(prioritySegment)\(doneCountDescription(for: task.doneCount)) • \(pauseDescription(for: task))\(stepMetadataSuffix(for: task))\(placeMetadataSuffix(for: task))"
        }
        return "\(cadenceDescription(for: task)) • \(prioritySegment)\(doneCountDescription(for: task.doneCount)) • \(completionDescription(for: task))\(stepMetadataSuffix(for: task))\(placeMetadataSuffix(for: task))"
    }

    func todoRowMetadataItems(for task: HomeFeature.RoutineDisplay) -> [String] {
        var items: [String] = []

        if let deadlineText = conciseDeadlineText(for: task) {
            items.append(deadlineText)
        }

        if let priorityText = task.priority.metadataLabel {
            items.append(priorityText)
        }

        if task.isPaused {
            items.append(pauseDescription(for: task))
        } else if task.isCompletedOneOff || task.isCanceledOneOff || task.isInProgress {
            items.append(completionDescription(for: task))
        }

        if let stepText = conciseTodoStepText(for: task) {
            items.append(stepText)
        }

        if let placeText = concisePlaceMetadataText(for: task) {
            items.append(placeText)
        }

        return items
    }

    func pauseDescription(for task: HomeFeature.RoutineDisplay) -> String {
        if task.isSnoozed {
            return "Not today"
        }
        guard let pausedAt = task.pausedAt else { return "Paused" }
        let elapsedDays = RoutineDateMath.elapsedDaysSinceLastDone(from: pausedAt, referenceDate: Date())
        if elapsedDays == 0 { return "Paused today" }
        if elapsedDays == 1 { return "Paused yesterday" }
        return "Paused \(elapsedDays) days ago"
    }

    func doneCountDescription(for count: Int) -> String {
        count == 1 ? "1 done" : "\(count) dones"
    }

    func cadenceDescription(for task: HomeFeature.RoutineDisplay) -> String {
        if task.isOneOffTask {
            return "One-off todo"
        }
        if task.scheduleMode == .derivedFromChecklist {
            return "Checklist-driven"
        }
        return task.recurrenceRule.displayText()
    }

    func completionDescription(for task: HomeFeature.RoutineDisplay) -> String {
        if task.isOneOffTask {
            if task.isInProgress {
                let totalSteps = max(task.steps.count, 1)
                return "Step \(task.completedStepCount + 1) of \(totalSteps)"
            }
            if let canceledAt = task.canceledAt {
                let elapsedDays = daysSince(canceledAt)
                if elapsedDays == 0 { return "Canceled today" }
                if elapsedDays == 1 { return "Canceled yesterday" }
                return "Canceled \(elapsedDays) days ago"
            }
            guard task.lastDone != nil else { return "Not completed yet" }

            let elapsedDays = daysSinceLastRoutine(task)
            if elapsedDays == 0 { return "Completed today" }
            if elapsedDays == 1 { return "Completed yesterday" }
            return "Completed \(elapsedDays) days ago"
        }
        if task.scheduleMode == .derivedFromChecklist {
            if task.isDoneToday && overdueDays(for: task) == 0 {
                return "Updated today"
            }
            guard task.lastDone != nil else { return "Never updated" }

            let elapsedDays = daysSinceLastRoutine(task)
            if elapsedDays == 0 { return "Updated today" }
            if elapsedDays == 1 { return "Updated yesterday" }
            return "Updated \(elapsedDays) days ago"
        }
        if task.scheduleMode == .fixedIntervalChecklist && task.completedChecklistItemCount > 0 {
            return "Checklist \(task.completedChecklistItemCount) of \(max(task.checklistItemCount, 1))"
        }
        if task.isInProgress {
            let totalSteps = max(task.steps.count, 1)
            return "Step \(task.completedStepCount + 1) of \(totalSteps)"
        }
        guard task.lastDone != nil else { return "Never completed" }

        let elapsedDays = daysSinceLastRoutine(task)
        if elapsedDays == 0 { return "Completed today" }
        if elapsedDays == 1 { return "Completed yesterday" }
        return "Completed \(elapsedDays) days ago"
    }

    private func daysSince(_ date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
    }

    func badgeStyle(
        for task: HomeFeature.RoutineDisplay
    ) -> (title: String, systemImage: String, foregroundColor: Color, backgroundColor: Color) {
        if task.isPaused {
            return task.isSnoozed
                ? ("Not today", "moon.zzz.fill", .indigo, Color.indigo.opacity(0.16))
                : ("Paused", "pause.circle.fill", .teal, Color.teal.opacity(0.16))
        }
        if case .away = task.locationAvailability {
            return ("Away", "location.slash.fill", .blue, Color.blue.opacity(0.14))
        }
        if task.isInProgress {
            return ("Step \(task.completedStepCount + 1)/\(max(task.steps.count, 1))", "list.number", .orange, Color.orange.opacity(0.16))
        }
        if task.isOneOffTask {
            if task.isCompletedOneOff {
                return ("Done", "checkmark.circle.fill", .green, Color.green.opacity(0.14))
            }
            if task.isCanceledOneOff {
                return ("Canceled", "xmark.circle.fill", .orange, Color.orange.opacity(0.14))
            }
            return ("To Do", "circle", .blue, Color.blue.opacity(0.12))
        }
        let dueIn = dueInDays(for: task)

        if task.scheduleMode == .derivedFromChecklist {
            if dueIn < 0 {
                return ("Overdue \(abs(dueIn))d", "exclamationmark.circle.fill", .red, Color.red.opacity(0.14))
            }
            if dueIn == 0 {
                return ("Today", "clock.fill", .orange, Color.orange.opacity(0.16))
            }
            if task.isDoneToday {
                return ("Updated", "checkmark.circle.fill", .green, Color.green.opacity(0.14))
            }
            if dueIn == 1 {
                return ("Tomorrow", "calendar", .orange, Color.orange.opacity(0.14))
            }
            return ("On Track", "circle.fill", .secondary, Color.secondary.opacity(0.12))
        }

        if task.scheduleMode == .fixedIntervalChecklist
            && task.completedChecklistItemCount > 0
            && !task.isDoneToday {
            return (
                "\(task.completedChecklistItemCount)/\(max(task.checklistItemCount, 1)) done",
                "checklist.checked",
                .orange,
                Color.orange.opacity(0.16)
            )
        }

        if task.isDoneToday {
            return ("Done", "checkmark.circle.fill", .green, Color.green.opacity(0.14))
        }

        if dueIn < 0 {
            return ("Overdue \(abs(dueIn))d", "exclamationmark.circle.fill", .red, Color.red.opacity(0.14))
        }
        if dueIn == 0 {
            return ("Today", "clock.fill", .orange, Color.orange.opacity(0.16))
        }
        if dueIn == 1 {
            return ("Tomorrow", "calendar", .orange, Color.orange.opacity(0.14))
        }
        if isYellowUrgency(task) {
            return ("\(dueIn)d left", "calendar.badge.clock", .orange, Color.orange.opacity(0.12))
        }

        return ("On Track", "circle.fill", .secondary, Color.secondary.opacity(0.12))
    }

    func stepMetadataSuffix(for task: HomeFeature.RoutineDisplay) -> String {
        if task.scheduleMode == .derivedFromChecklist {
            if let nextDueChecklistItemTitle = task.nextDueChecklistItemTitle {
                if task.dueChecklistItemCount > 1 {
                    return " • Due: \(nextDueChecklistItemTitle) +\(task.dueChecklistItemCount - 1)"
                }
                return " • Due: \(nextDueChecklistItemTitle)"
            }
            let totalItems = task.checklistItemCount
            return totalItems == 0 ? "" : " • \(totalItems) \(totalItems == 1 ? "item" : "items")"
        }
        if task.scheduleMode == .fixedIntervalChecklist {
            if let nextPendingChecklistItemTitle = task.nextPendingChecklistItemTitle,
               task.completedChecklistItemCount < task.checklistItemCount {
                return " • Next: \(nextPendingChecklistItemTitle)"
            }
            let totalItems = task.checklistItemCount
            if totalItems == 0 { return "" }
            return " • Checklist \(task.completedChecklistItemCount)/\(totalItems)"
        }
        guard !task.steps.isEmpty else { return "" }
        if let nextStepTitle = task.nextStepTitle {
            return " • Next: \(nextStepTitle)"
        }
        let totalSteps = task.steps.count
        return " • \(totalSteps) \(totalSteps == 1 ? "step" : "steps")"
    }

    func conciseTodoStepText(for task: HomeFeature.RoutineDisplay) -> String? {
        guard !task.steps.isEmpty else { return nil }
        if task.isCompletedOneOff || task.isCanceledOneOff { return nil }
        if let nextStepTitle = task.nextStepTitle {
            return "Next: \(nextStepTitle)"
        }
        if task.steps.count > 1 {
            return "\(task.steps.count) steps"
        }
        return nil
    }

    func conciseDeadlineText(for task: HomeFeature.RoutineDisplay) -> String? {
        guard task.isOneOffTask, let dueDate = task.dueDate else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            return "Due today"
        }
        if calendar.isDateInTomorrow(dueDate) {
            return "Due tomorrow"
        }
        if dueDate < Date() {
            let days = max(
                abs(calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: dueDate),
                    to: calendar.startOfDay(for: Date())
                ).day ?? 0),
                1
            )
            return "Overdue \(days)d"
        }
        return "Due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
    }

    func markDoneLabel(for task: HomeFeature.RoutineDisplay) -> String {
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

    func isMarkDoneDisabled(_ task: HomeFeature.RoutineDisplay) -> Bool {
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
           dueDate > Date() {
            return true
        }
        return task.isDoneToday || task.isPaused
    }

    func placeMetadataSuffix(for task: HomeFeature.RoutineDisplay) -> String {
        switch task.locationAvailability {
        case .unrestricted:
            return ""
        case let .available(placeName):
            return " • At \(placeName)"
        case let .away(placeName, _):
            return " • Away from \(placeName)"
        case let .unknown(placeName):
            return " • \(placeName) task"
        }
    }

    func concisePlaceMetadataText(for task: HomeFeature.RoutineDisplay) -> String? {
        switch task.locationAvailability {
        case .unrestricted:
            return nil
        case let .available(placeName):
            return "At \(placeName)"
        case let .away(placeName, _):
            return "Away from \(placeName)"
        case let .unknown(placeName):
            return placeName
        }
    }
}
