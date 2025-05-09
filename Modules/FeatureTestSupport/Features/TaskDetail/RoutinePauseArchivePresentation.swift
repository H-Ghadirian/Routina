import Foundation

struct RoutinePauseArchivePresentation: Equatable {
    enum Context: Equatable {
        case detail
        case editSheet
    }

    let actionTitle: String
    let description: String?

    static func make(isPaused: Bool, context: Context) -> Self {
        let actionTitle = isPaused ? "Resume Routine" : "Pause Routine"

        switch context {
        case .detail:
            return Self(
                actionTitle: actionTitle,
                description: isPaused
                    ? "Archived routines stay out of the main list and won't send reminders until resumed."
                    : nil
            )

        case .editSheet:
            return Self(
                actionTitle: actionTitle,
                description: isPaused
                    ? "This routine is archived right now. Resume it to bring it back to the main list and notifications."
                    : "Pausing moves this routine into the archived list, hides it from the main list, and stops notifications."
            )
        }
    }
}
