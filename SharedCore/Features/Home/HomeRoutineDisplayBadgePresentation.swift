import SwiftUI

struct HomeRoutineMetadataBadgeStyle {
    let title: String
    let systemImage: String
    let foregroundColor: Color
    let backgroundColor: Color

    var tuple: (
        title: String,
        systemImage: String,
        foregroundColor: Color,
        backgroundColor: Color
    ) {
        (title, systemImage, foregroundColor, backgroundColor)
    }
}

enum HomeRoutineMetadataBadgeMode {
    case complete
    case compact
}

extension HomeRoutineDisplayMetadataPresenter {
    func badgeStyle(for task: Display) -> HomeRoutineMetadataBadgeStyle? {
        if task.isPaused {
            return task.isSnoozed
                ? badge("Not today", "moon.zzz.fill", .indigo, Color.indigo.opacity(0.16))
                : badge("Paused", "pause.circle.fill", .teal, Color.teal.opacity(0.16))
        }
        if case .away = task.locationAvailability {
            return badge("Away", "location.slash.fill", .blue, Color.blue.opacity(0.14))
        }
        if task.isSoftIntervalRoutine {
            if task.isOngoing {
                return badge("Ongoing", "airplane.circle.fill", .teal, Color.teal.opacity(0.16))
            }
            if task.isDoneToday {
                return badge("Done", "checkmark.circle.fill", .green, Color.green.opacity(0.14))
            }
            if task.hasPassedSoftThreshold, task.lastDone != nil {
                return badge(softElapsedBadgeTitle(for: task), "clock.arrow.circlepath", .teal, Color.teal.opacity(0.12))
            }
            return badgeMode == .complete
                ? badge("Ready", "sparkles", .secondary, Color.secondary.opacity(0.10))
                : nil
        }
        if task.isInProgress {
            return badge("Step \(task.completedStepCount + 1)/\(max(task.steps.count, 1))", "list.number", .orange, Color.orange.opacity(0.16))
        }
        if task.isOneOffTask {
            if task.isCompletedOneOff {
                return badge("Done", "checkmark.circle.fill", .green, Color.green.opacity(0.14))
            }
            if task.isCanceledOneOff {
                return badge("Canceled", "xmark.circle.fill", .orange, Color.orange.opacity(0.14))
            }
            switch task.todoState {
            case .inProgress:
                return badge("In Progress", "arrow.clockwise.circle.fill", .blue, Color.blue.opacity(0.14))
            case .blocked:
                return badge("Blocked", "exclamationmark.circle.fill", .orange, Color.orange.opacity(0.14))
            case .ready, .done, .paused, nil:
                return badgeMode == .complete
                    ? badge("To Do", "circle", .secondary, Color.secondary.opacity(0.12))
                    : nil
            }
        }
        let dueIn = filtering.dueInDays(for: task)

        if task.scheduleMode == .derivedFromChecklist {
            if dueIn < 0 {
                return badge("Overdue \(abs(dueIn))d", "exclamationmark.circle.fill", .red, Color.red.opacity(0.14))
            }
            if dueIn == 0 {
                return badge("Today", "clock.fill", .orange, Color.orange.opacity(0.16))
            }
            if task.isDoneToday {
                return badge("Updated", "checkmark.circle.fill", .green, Color.green.opacity(0.14))
            }
            if dueIn == 1 {
                return badge("Tomorrow", "calendar", .orange, Color.orange.opacity(0.14))
            }
            return badge("On Track", "circle.fill", .secondary, Color.secondary.opacity(0.12))
        }

        if task.scheduleMode == .fixedIntervalChecklist
            && task.completedChecklistItemCount > 0
            && !task.isDoneToday {
            return badge(
                "\(task.completedChecklistItemCount)/\(max(task.checklistItemCount, 1)) done",
                "checklist.checked",
                .orange,
                Color.orange.opacity(0.16)
            )
        }

        if task.isAssumedDoneToday {
            return badge("Assumed", "checkmark.circle", .mint, Color.mint.opacity(0.18))
        }

        if task.isDoneToday {
            return badge("Done", "checkmark.circle.fill", .green, Color.green.opacity(0.14))
        }

        if dueIn < 0 {
            return badge("Overdue \(abs(dueIn))d", "exclamationmark.circle.fill", .red, Color.red.opacity(0.14))
        }
        if dueIn == 0 {
            return badge("Today", "clock.fill", .orange, Color.orange.opacity(0.16))
        }
        if dueIn == 1 {
            return badge("Tomorrow", "calendar", .orange, Color.orange.opacity(0.14))
        }
        if filtering.isYellowUrgency(task) {
            return badge("\(dueIn)d left", "calendar.badge.clock", .orange, Color.orange.opacity(0.12))
        }

        return badge("On Track", "circle.fill", .secondary, Color.secondary.opacity(0.12))
    }

    private func softElapsedBadgeTitle(for task: Display) -> String {
        guard let lastDone = task.lastDone else { return "Ready whenever" }
        return softElapsedText(forDays: daysSince(lastDone))
    }

    private func badge(
        _ title: String,
        _ systemImage: String,
        _ foregroundColor: Color,
        _ backgroundColor: Color
    ) -> HomeRoutineMetadataBadgeStyle {
        HomeRoutineMetadataBadgeStyle(
            title: title,
            systemImage: systemImage,
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor
        )
    }
}
