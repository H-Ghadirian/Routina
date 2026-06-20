import Foundation
import SwiftUI

struct HomeRoutineDisplayMetadataPresenter<Display: HomeRoutineMetadataDisplay> {
    let filtering: HomeTaskListFiltering<Display>
    let showPersianDates: Bool
    let badgeMode: HomeRoutineMetadataBadgeMode
    var rowVisibility: HomeTaskRowVisibility = .defaultValue
    var showsRoutineCompletionCount = true

    func rowMetadataText(for task: Display) -> String? {
        let items = task.isOneOffTask
            ? todoRowMetadataItems(for: task)
            : routineRowMetadataItems(for: task)
        return items.isEmpty ? nil : items.joined(separator: " • ")
    }

    func routineRowMetadataItems(for task: Display) -> [String] {
        var items: [String] = []

        if rowVisibility.shows(.schedule) {
            items.append(cadenceDescription(for: task))
        }

        if rowVisibility.shows(.priority), let priorityText = task.priority.metadataLabel {
            items.append(priorityText)
        }

        if rowVisibility.shows(.progress) {
            if showsRoutineCompletionCount {
                items.append(doneCountDescription(for: task.doneCount))
            }
            items.append(task.isPaused ? pauseDescription(for: task) : completionDescription(for: task))
        }

        if rowVisibility.shows(.pressure), let pressureText = task.pressure.metadataLabel {
            items.append(pressureText)
        }

        if rowVisibility.shows(.steps), let stepText = stepMetadataText(for: task) {
            items.append(stepText)
        }

        if rowVisibility.shows(.place), let placeText = placeMetadataText(for: task) {
            items.append(placeText)
        }

        return items
    }

    func todoRowMetadataItems(for task: Display) -> [String] {
        var items: [String] = []

        if rowVisibility.shows(.schedule), let deadlineText = conciseDeadlineText(for: task) {
            items.append(deadlineText)
        }

        if rowVisibility.shows(.priority), let priorityText = task.priority.metadataLabel {
            items.append(priorityText)
        }

        if rowVisibility.shows(.pressure), let pressureText = task.pressure.metadataLabel {
            items.append(pressureText)
        }

        if rowVisibility.shows(.progress), task.isPaused {
            items.append(pauseDescription(for: task))
        } else if rowVisibility.shows(.progress),
                  task.isCompletedOneOff || task.isCanceledOneOff || task.isInProgress {
            items.append(completionDescription(for: task))
        }

        if rowVisibility.shows(.steps), let stepText = conciseTodoStepText(for: task) {
            items.append(stepText)
        }

        if rowVisibility.shows(.place), let placeText = concisePlaceMetadataText(for: task) {
            items.append(placeText)
        }

        return items
    }

    func pressureMetadataSuffix(for task: Display) -> String {
        guard rowVisibility.shows(.pressure),
              let pressureText = task.pressure.metadataLabel
        else { return "" }
        return " • \(pressureText)"
    }

    func pauseDescription(for task: Display) -> String {
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
        count == 1 ? "1 completion" : "\(count) completions"
    }

    func cadenceDescription(for task: Display) -> String {
        if task.isOneOffTask {
            return "One-off todo"
        }
        if task.scheduleMode.isChecklistDrivenMode {
            return "Checklist-driven"
        }
        return task.recurrenceRule.displayText()
    }

    func completionDescription(for task: Display) -> String {
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

            let elapsedDays = filtering.daysSinceLastRoutine(task)
            if elapsedDays == 0 { return "Completed today" }
            if elapsedDays == 1 { return "Completed yesterday" }
            return "Completed \(elapsedDays) days ago"
        }
        if task.scheduleMode.isChecklistDrivenMode {
            if task.isDoneToday && filtering.overdueDays(for: task) == 0 {
                return "Updated today"
            }
            guard task.lastDone != nil else { return "Never updated" }

            let elapsedDays = filtering.daysSinceLastRoutine(task)
            if elapsedDays == 0 { return "Updated today" }
            if elapsedDays == 1 { return "Updated yesterday" }
            return "Updated \(elapsedDays) days ago"
        }
        if task.scheduleMode.isChecklistCompletionMode && task.completedChecklistItemCount > 0 {
            return "Checklist \(task.completedChecklistItemCount) of \(max(task.checklistItemCount, 1))"
        }
        if task.isOngoing {
            return ongoingDescription(for: task)
        }
        if task.isSoftIntervalRoutine {
            if task.isDoneToday {
                return "Done today"
            }
            guard task.lastDone != nil else { return "Ready whenever" }
            return softElapsedDescription(for: task)
        }
        if task.isAssumedDoneToday {
            return "Assumed today"
        }
        if task.isInProgress {
            let totalSteps = max(task.steps.count, 1)
            return "Step \(task.completedStepCount + 1) of \(totalSteps)"
        }
        guard task.lastDone != nil else { return "Never completed" }

        let elapsedDays = filtering.daysSinceLastRoutine(task)
        if elapsedDays == 0 { return "Completed today" }
        if elapsedDays == 1 { return "Completed yesterday" }
        return "Completed \(elapsedDays) days ago"
    }

    func stepMetadataSuffix(for task: Display) -> String {
        guard rowVisibility.shows(.steps),
              let text = stepMetadataText(for: task)
        else { return "" }
        return " • \(text)"
    }

    func stepMetadataText(for task: Display) -> String? {
        if task.scheduleMode.isChecklistDrivenMode {
            if let nextDueChecklistItemTitle = task.nextDueChecklistItemTitle {
                if task.dueChecklistItemCount > 1 {
                    return "Due: \(nextDueChecklistItemTitle) +\(task.dueChecklistItemCount - 1)"
                }
                return "Due: \(nextDueChecklistItemTitle)"
            }
            let totalItems = task.checklistItemCount
            return totalItems == 0 ? nil : "\(totalItems) \(totalItems == 1 ? "item" : "items")"
        }
        if task.scheduleMode.isChecklistCompletionMode {
            if task.isAssumedDoneToday {
                return nil
            }
            if let nextPendingChecklistItemTitle = task.nextPendingChecklistItemTitle,
               task.completedChecklistItemCount < task.checklistItemCount {
                return "Next: \(nextPendingChecklistItemTitle)"
            }
            let totalItems = task.checklistItemCount
            if totalItems == 0 { return nil }
            return "Checklist \(task.completedChecklistItemCount)/\(totalItems)"
        }
        guard !task.steps.isEmpty else { return nil }
        if let nextStepTitle = task.nextStepTitle {
            return "Next: \(nextStepTitle)"
        }
        let totalSteps = task.steps.count
        return "\(totalSteps) \(totalSteps == 1 ? "step" : "steps")"
    }

    func conciseTodoStepText(for task: Display) -> String? {
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

    func conciseDeadlineText(for task: Display) -> String? {
        guard task.isOneOffTask, let dueDate = task.dueDate else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            return PersianDateDisplay.appendingSupplementaryDate(
                to: "Due today",
                for: dueDate,
                enabled: showPersianDates
            )
        }
        if calendar.isDateInTomorrow(dueDate) {
            return PersianDateDisplay.appendingSupplementaryDate(
                to: "Due tomorrow",
                for: dueDate,
                enabled: showPersianDates
            )
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
        let dueText = "Due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        return PersianDateDisplay.appendingSupplementaryDate(
            to: dueText,
            for: dueDate,
            enabled: showPersianDates
        )
    }

    func placeMetadataSuffix(for task: Display) -> String {
        guard rowVisibility.shows(.place),
              let text = placeMetadataText(for: task)
        else { return "" }
        return " • \(text)"
    }

    func placeMetadataText(for task: Display) -> String? {
        switch task.locationAvailability {
        case .unrestricted:
            return nil
        case let .available(placeName):
            return "At \(placeName)"
        case let .away(placeName, _):
            return "Away from \(placeName)"
        case let .unknown(placeName):
            return "\(placeName) task"
        }
    }

    func concisePlaceMetadataText(for task: Display) -> String? {
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

    func daysSince(_ date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
    }

    private func ongoingDescription(for task: Display) -> String {
        guard let ongoingSince = task.ongoingSince else { return "Ongoing" }
        let elapsedDays = daysSince(ongoingSince)
        if elapsedDays == 0 { return "Started today" }
        if elapsedDays == 1 { return "Started yesterday" }
        return "Started \(elapsedDays) days ago"
    }

    private func softElapsedDescription(for task: Display) -> String {
        guard let lastDone = task.lastDone else { return "Ready whenever" }
        let elapsedDays = daysSince(lastDone)
        let elapsedText = softElapsedText(forDays: elapsedDays)
        return "\(elapsedText) since last time"
    }

    func softElapsedText(forDays days: Int) -> String {
        if days < 14 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
        if days < 60 {
            let weeks = max(days / 7, 1)
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        }
        let months = max(days / 30, 1)
        return months == 1 ? "1 month ago" : "\(months) months ago"
    }

}
