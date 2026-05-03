import SwiftUI

struct TaskDetailStatusSummaryHeaderView: View {
    let title: String
    let titleColor: Color
    let statusContextMessage: String?
    let titleFont: Font

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(titleFont)
                .foregroundColor(titleColor)

            if let statusContextMessage {
                Text(statusContextMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct TaskDetailStatusActionSectionView<CompletionLabel: View, TimeSpentButton: View>: View {
    let pauseArchivePresentation: RoutinePauseArchivePresentation
    let isOneOffTask: Bool
    let isArchived: Bool
    let isCompletionButtonDisabled: Bool
    let isStepRoutineOffToday: Bool
    let isChecklistCompletionRoutine: Bool
    let canUndoSelectedDate: Bool
    let shouldShowBulkConfirmAssumedDays: Bool
    let bulkConfirmAssumedDaysTitle: String
    let hasBlockingRelationships: Bool
    let blockerSummaryText: String
    let useLargePrimaryControl: Bool
    let completionLabel: () -> CompletionLabel
    let timeSpentButton: () -> TimeSpentButton
    let onComplete: () -> Void
    let onPauseResume: () -> Void
    let onNotToday: () -> Void
    let onConfirmAssumedPastDays: () -> Void

    init(
        pauseArchivePresentation: RoutinePauseArchivePresentation,
        isOneOffTask: Bool,
        isArchived: Bool,
        isCompletionButtonDisabled: Bool,
        isStepRoutineOffToday: Bool,
        isChecklistCompletionRoutine: Bool,
        canUndoSelectedDate: Bool,
        shouldShowBulkConfirmAssumedDays: Bool = false,
        bulkConfirmAssumedDaysTitle: String = "",
        hasBlockingRelationships: Bool,
        blockerSummaryText: String,
        useLargePrimaryControl: Bool = false,
        @ViewBuilder completionLabel: @escaping () -> CompletionLabel,
        @ViewBuilder timeSpentButton: @escaping () -> TimeSpentButton,
        onComplete: @escaping () -> Void,
        onPauseResume: @escaping () -> Void,
        onNotToday: @escaping () -> Void,
        onConfirmAssumedPastDays: @escaping () -> Void
    ) {
        self.pauseArchivePresentation = pauseArchivePresentation
        self.isOneOffTask = isOneOffTask
        self.isArchived = isArchived
        self.isCompletionButtonDisabled = isCompletionButtonDisabled
        self.isStepRoutineOffToday = isStepRoutineOffToday
        self.isChecklistCompletionRoutine = isChecklistCompletionRoutine
        self.canUndoSelectedDate = canUndoSelectedDate
        self.shouldShowBulkConfirmAssumedDays = shouldShowBulkConfirmAssumedDays
        self.bulkConfirmAssumedDaysTitle = bulkConfirmAssumedDaysTitle
        self.hasBlockingRelationships = hasBlockingRelationships
        self.blockerSummaryText = blockerSummaryText
        self.useLargePrimaryControl = useLargePrimaryControl
        self.completionLabel = completionLabel
        self.timeSpentButton = timeSpentButton
        self.onComplete = onComplete
        self.onPauseResume = onPauseResume
        self.onNotToday = onNotToday
        self.onConfirmAssumedPastDays = onConfirmAssumedPastDays
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onComplete) {
                completionLabel()
                    .routinaPlatformPrimaryActionLabelLayout()
            }
            .buttonStyle(.borderedProminent)
            .routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: useLargePrimaryControl)
            .routinaPlatformPrimaryActionButtonLayout(alignment: .leading)
            .disabled(isCompletionButtonDisabled)

            timeSpentButton()

            if !isOneOffTask {
                Button(pauseArchivePresentation.actionTitle, action: onPauseResume)
                    .buttonStyle(.bordered)
                    .tint(isArchived ? .teal : .orange)
                    .routinaPlatformSecondaryActionControlSize()
                    .routinaPlatformSecondaryActionButtonLayout(alignment: .leading)

                if let secondaryActionTitle = pauseArchivePresentation.secondaryActionTitle {
                    Button(secondaryActionTitle, action: onNotToday)
                        .buttonStyle(.bordered)
                        .tint(.indigo)
                        .routinaPlatformSecondaryActionControlSize()
                        .routinaPlatformSecondaryActionButtonLayout(alignment: .leading)
                }

                if shouldShowBulkConfirmAssumedDays {
                    Button(bulkConfirmAssumedDaysTitle, action: onConfirmAssumedPastDays)
                        .buttonStyle(.bordered)
                        .tint(.mint)
                        .routinaPlatformSecondaryActionControlSize()
                        .routinaPlatformSecondaryActionButtonLayout(alignment: .leading)
                }
            }

            helperMessages
        }
    }

    @ViewBuilder
    private var helperMessages: some View {
        if isStepRoutineOffToday {
            helperText("Step-based routines can only be progressed for today.")
        }

        if isChecklistCompletionRoutine && !canUndoSelectedDate {
            helperText("Complete checklist items below to finish this routine.")
        }

        if let pauseDescription = pauseArchivePresentation.description {
            helperText(pauseDescription)
        }

        if let secondaryActionDescription = pauseArchivePresentation.secondaryActionDescription {
            helperText(secondaryActionDescription)
        }

        if hasBlockingRelationships {
            helperText(blockerSummaryText)
        }
    }

    private func helperText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
