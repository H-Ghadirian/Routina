import Foundation

struct RoutinePauseArchivePresentation: Equatable {
    enum Context: Equatable {
        case detail
        case editSheet
    }

    let actionTitle: String
    let description: String?
    let secondaryActionTitle: String?
    let secondaryActionDescription: String?

    static func make(
        isPaused: Bool,
        isOneOffTask: Bool = false,
        context: Context
    ) -> Self {
        let actionTitle: String
        if isOneOffTask {
            actionTitle = isPaused ? "Restore Task" : "Archive Task"
        } else {
            actionTitle = isPaused ? "Resume Routine" : "Pause Routine"
        }
        let secondaryActionTitle = isPaused || isOneOffTask ? nil : "Not today!"

        switch context {
        case .detail:
            return Self(
                actionTitle: actionTitle,
                description: isPaused
                    ? isOneOffTask
                        ? "Archived tasks stay out of the main list and won't send reminders until restored."
                        : "Archived routines stay out of the main list and won't send reminders until resumed."
                    : nil,
                secondaryActionTitle: secondaryActionTitle,
                secondaryActionDescription: isPaused || isOneOffTask
                    ? nil
                    : "Hides this routine until tomorrow and restores it automatically."
            )

        case .editSheet:
            return Self(
                actionTitle: actionTitle,
                description: isPaused
                    ? isOneOffTask
                        ? "This task is archived right now. Restore it to bring it back to the main list and notifications."
                        : "This routine is archived right now. Resume it to bring it back to the main list and notifications."
                    : isOneOffTask
                        ? "Archiving moves this task into the archived list, hides it from the main list, and stops notifications."
                        : "Pausing moves this routine into the archived list, hides it from the main list, and stops notifications.",
                secondaryActionTitle: secondaryActionTitle,
                secondaryActionDescription: isPaused || isOneOffTask
                    ? nil
                    : "Use Not today! to archive it only until tomorrow."
            )
        }
    }
}
