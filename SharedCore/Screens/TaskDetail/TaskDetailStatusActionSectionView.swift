import SwiftUI

struct TaskDetailOccurrenceSectionView: View {
    let occurrences: [TaskDetailOccurrencePresentation]
    let onSelect: (Date) -> Void
    let onComplete: (Date) -> Void
    let onMarkMissed: (Date) -> Void
    let onCancel: (Date) -> Void
    let onClearResolution: (Date) -> Void

    private var selectedOccurrence: TaskDetailOccurrencePresentation? {
        occurrences.first(where: \.isSelected)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Occurrences")
                    .font(.headline)

                Text("Choose a scheduled time to view or update that occurrence.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(occurrences) { occurrence in
                        occurrenceButton(occurrence)
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)

            if let selectedOccurrence {
                selectedOccurrenceActions(selectedOccurrence)
            }
        }
        .padding(16)
        .taskDetailScrollCardSurface(
            cornerRadius: 16,
            tint: .secondary,
            tintOpacity: 0.06,
            stroke: .secondary.opacity(0.18)
        )
    }

    private func occurrenceButton(
        _ occurrence: TaskDetailOccurrencePresentation
    ) -> some View {
        let tint = statusTint(occurrence.status)
        return Button {
            onSelect(occurrence.occurrence)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(occurrence.occurrence.formatted(date: .omitted, time: .shortened))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)

                Label(
                    statusTitle(occurrence.status),
                    systemImage: statusSystemImage(occurrence.status)
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            }
            .frame(minWidth: 104, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(occurrence.isSelected ? 0.16 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        occurrence.isSelected ? tint : tint.opacity(0.28),
                        lineWidth: occurrence.isSelected ? 2 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(occurrence.occurrence.formatted(date: .omitted, time: .shortened)), \(statusTitle(occurrence.status))"
        )
        .accessibilityAddTraits(occurrence.isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func selectedOccurrenceActions(
        _ occurrence: TaskDetailOccurrencePresentation
    ) -> some View {
        Divider()

        VStack(alignment: .leading, spacing: 10) {
            Text("Selected: \(occurrence.occurrence.formatted(date: .omitted, time: .shortened))")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                if occurrence.canComplete {
                    Button {
                        onComplete(occurrence.occurrence)
                    } label: {
                        Label("Done", systemImage: "checkmark")
                            .frame(minHeight: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }

                if occurrence.canMarkMissed {
                    Button {
                        onMarkMissed(occurrence.occurrence)
                    } label: {
                        Label("Confirm missed", systemImage: "xmark")
                            .frame(minHeight: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                if occurrence.canCancel {
                    Button {
                        onCancel(occurrence.occurrence)
                    } label: {
                        Label("Cancel", systemImage: "slash.circle")
                            .frame(minHeight: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }

                if occurrence.canClearResolution {
                    Button {
                        onClearResolution(occurrence.resolutionTimestamp ?? occurrence.occurrence)
                    } label: {
                        Label("Clear status", systemImage: "arrow.uturn.backward")
                            .frame(minHeight: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func statusTitle(
        _ status: TaskDetailOccurrencePresentation.Status
    ) -> String {
        switch status {
        case .done:
            return "Done"
        case .missed:
            return "Missed"
        case .canceled:
            return "Canceled"
        case .due:
            return "Ready"
        case .upcoming:
            return "Upcoming"
        }
    }

    private func statusSystemImage(
        _ status: TaskDetailOccurrencePresentation.Status
    ) -> String {
        switch status {
        case .done:
            return "checkmark.circle.fill"
        case .missed:
            return "exclamationmark.circle.fill"
        case .canceled:
            return "slash.circle.fill"
        case .due:
            return "clock.fill"
        case .upcoming:
            return "clock"
        }
    }

    private func statusTint(
        _ status: TaskDetailOccurrencePresentation.Status
    ) -> Color {
        switch status {
        case .done:
            return .green
        case .missed:
            return .red
        case .canceled:
            return .gray
        case .due:
            return .orange
        case .upcoming:
            return .blue
        }
    }
}

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

struct TaskDetailCompletionButtonLabel: View {
    let title: String
    let systemImage: String?

    var body: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

struct TaskDetailStatusSectionView<TimeSpentButton: View>: View {
    let title: String
    let titleColor: Color
    let statusContextMessage: String?
    let titleFont: Font
    let showsMetadata: Bool
    let metadataItems: [TaskDetailStatusMetadataItem]
    let pauseArchivePresentation: RoutinePauseArchivePresentation
    let completionButtonTitle: String
    let completionButtonSystemImage: String?
    let isOneOffTask: Bool
    let isArchived: Bool
    let isCompletionButtonDisabled: Bool
    let isStepRoutineOffToday: Bool
    let isChecklistCompletionRoutine: Bool
    let canUndoSelectedDate: Bool
    let isSelectedDateAssumedDone: Bool
    let shouldShowBulkConfirmAssumedDays: Bool
    let bulkConfirmAssumedDaysTitle: String
    let hasBlockingRelationships: Bool
    let blockerSummaryText: String
    let useLargePrimaryControl: Bool
    let contentPadding: CGFloat
    let cardBackground: Color?
    let cardStroke: Color?
    let missedOccurrenceReview: TaskDetailMissedOccurrenceReviewPresentation?
    let timeSpentButton: () -> TimeSpentButton
    let onComplete: () -> Void
    let onResolveMissedAsDone: (Date) -> Void
    let onResolveMissedAsMissed: (Date) -> Void
    let onResolveMissedAsCanceled: (Date) -> Void
    let onPauseResume: () -> Void
    let onNotToday: () -> Void
    let onConfirmAssumedPastDays: () -> Void

    var body: some View {
        styledContent
    }

    @ViewBuilder
    private var styledContent: some View {
        if let cardBackground {
            content
                .padding(contentPadding)
                .taskDetailScrollCardSurface(
                    cornerRadius: 12,
                    tint: cardBackground,
                    tintOpacity: 0.18,
                    stroke: cardStroke ?? .clear
                )
        } else {
            content
                .padding(contentPadding)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            TaskDetailStatusSummaryHeaderView(
                title: title,
                titleColor: titleColor,
                statusContextMessage: statusContextMessage,
                titleFont: titleFont
            )

            if showsMetadata {
                Divider()
                TaskDetailStatusMetadataSectionView(items: metadataItems)
                Divider()
            }

            TaskDetailStatusActionSectionView(
                pauseArchivePresentation: pauseArchivePresentation,
                isOneOffTask: isOneOffTask,
                isArchived: isArchived,
                isCompletionButtonDisabled: isCompletionButtonDisabled,
                isStepRoutineOffToday: isStepRoutineOffToday,
                isChecklistCompletionRoutine: isChecklistCompletionRoutine,
                canUndoSelectedDate: canUndoSelectedDate,
                isSelectedDateAssumedDone: isSelectedDateAssumedDone,
                shouldShowBulkConfirmAssumedDays: shouldShowBulkConfirmAssumedDays,
                bulkConfirmAssumedDaysTitle: bulkConfirmAssumedDaysTitle,
                hasBlockingRelationships: hasBlockingRelationships,
                blockerSummaryText: blockerSummaryText,
                useLargePrimaryControl: useLargePrimaryControl,
                missedOccurrenceReview: missedOccurrenceReview
            ) {
                TaskDetailCompletionButtonLabel(
                    title: completionButtonTitle,
                    systemImage: completionButtonSystemImage
                )
            } timeSpentButton: {
                timeSpentButton()
            } onComplete: {
                onComplete()
            } onResolveMissedAsDone: {
                onResolveMissedAsDone($0)
            } onResolveMissedAsMissed: {
                onResolveMissedAsMissed($0)
            } onResolveMissedAsCanceled: {
                onResolveMissedAsCanceled($0)
            } onPauseResume: {
                onPauseResume()
            } onNotToday: {
                onNotToday()
            } onConfirmAssumedPastDays: {
                onConfirmAssumedPastDays()
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
    let isSelectedDateAssumedDone: Bool
    let shouldShowBulkConfirmAssumedDays: Bool
    let bulkConfirmAssumedDaysTitle: String
    let hasBlockingRelationships: Bool
    let blockerSummaryText: String
    let useLargePrimaryControl: Bool
    let missedOccurrenceReview: TaskDetailMissedOccurrenceReviewPresentation?
    let completionLabel: () -> CompletionLabel
    let timeSpentButton: () -> TimeSpentButton
    let onComplete: () -> Void
    let onResolveMissedAsDone: (Date) -> Void
    let onResolveMissedAsMissed: (Date) -> Void
    let onResolveMissedAsCanceled: (Date) -> Void
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
        isSelectedDateAssumedDone: Bool = false,
        shouldShowBulkConfirmAssumedDays: Bool = false,
        bulkConfirmAssumedDaysTitle: String = "",
        hasBlockingRelationships: Bool,
        blockerSummaryText: String,
        useLargePrimaryControl: Bool = false,
        missedOccurrenceReview: TaskDetailMissedOccurrenceReviewPresentation? = nil,
        @ViewBuilder completionLabel: @escaping () -> CompletionLabel,
        @ViewBuilder timeSpentButton: @escaping () -> TimeSpentButton,
        onComplete: @escaping () -> Void,
        onResolveMissedAsDone: @escaping (Date) -> Void = { _ in },
        onResolveMissedAsMissed: @escaping (Date) -> Void = { _ in },
        onResolveMissedAsCanceled: @escaping (Date) -> Void = { _ in },
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
        self.isSelectedDateAssumedDone = isSelectedDateAssumedDone
        self.shouldShowBulkConfirmAssumedDays = shouldShowBulkConfirmAssumedDays
        self.bulkConfirmAssumedDaysTitle = bulkConfirmAssumedDaysTitle
        self.hasBlockingRelationships = hasBlockingRelationships
        self.blockerSummaryText = blockerSummaryText
        self.useLargePrimaryControl = useLargePrimaryControl
        self.missedOccurrenceReview = missedOccurrenceReview
        self.completionLabel = completionLabel
        self.timeSpentButton = timeSpentButton
        self.onComplete = onComplete
        self.onResolveMissedAsDone = onResolveMissedAsDone
        self.onResolveMissedAsMissed = onResolveMissedAsMissed
        self.onResolveMissedAsCanceled = onResolveMissedAsCanceled
        self.onPauseResume = onPauseResume
        self.onNotToday = onNotToday
        self.onConfirmAssumedPastDays = onConfirmAssumedPastDays
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let missedOccurrenceReview {
                TaskDetailMissedOccurrenceReviewView(
                    presentation: missedOccurrenceReview,
                    onDone: { onResolveMissedAsDone(missedOccurrenceReview.occurrence) },
                    onMissed: { onResolveMissedAsMissed(missedOccurrenceReview.occurrence) },
                    onCanceled: { onResolveMissedAsCanceled(missedOccurrenceReview.occurrence) }
                )
            } else {
                Button(action: onComplete) {
                    completionLabel()
                        .routinaPlatformPrimaryActionLabelLayout()
                }
                .buttonStyle(.borderedProminent)
                .routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: useLargePrimaryControl)
                .routinaPlatformPrimaryActionButtonLayout(alignment: .leading)
                .disabled(isCompletionButtonDisabled)
            }

            timeSpentButton()

            Button(pauseArchivePresentation.actionTitle, action: onPauseResume)
                .buttonStyle(.bordered)
                .tint(isArchived ? .teal : .orange)
                .routinaPlatformSecondaryActionControlSize()
                .routinaPlatformSecondaryActionButtonLayout(alignment: .leading)

            if !isOneOffTask, let secondaryActionTitle = pauseArchivePresentation.secondaryActionTitle {
                Button(secondaryActionTitle, action: onNotToday)
                    .buttonStyle(.bordered)
                    .tint(.indigo)
                    .routinaPlatformSecondaryActionControlSize()
                    .routinaPlatformSecondaryActionButtonLayout(alignment: .leading)
            }

            if !isOneOffTask, shouldShowBulkConfirmAssumedDays {
                Button(bulkConfirmAssumedDaysTitle, action: onConfirmAssumedPastDays)
                    .buttonStyle(.bordered)
                    .tint(.mint)
                    .routinaPlatformSecondaryActionControlSize()
                    .routinaPlatformSecondaryActionButtonLayout(alignment: .leading)
            }

            helperMessages
        }
    }

    @ViewBuilder
    private var helperMessages: some View {
        if !isOneOffTask, isStepRoutineOffToday {
            helperText("Step-based repeating tasks can only be progressed for today.")
        }

        if !isOneOffTask,
           isChecklistCompletionRoutine,
           !canUndoSelectedDate,
           !isSelectedDateAssumedDone {
            helperText("Complete checklist items below to finish this repeating task.")
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

private struct TaskDetailMissedOccurrenceReviewView: View {
    let presentation: TaskDetailMissedOccurrenceReviewPresentation
    let onDone: () -> Void
    let onMissed: () -> Void
    let onCanceled: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(occurrenceText, systemImage: "clock.badge.exclamationmark")
                .font(.subheadline.weight(.semibold))

            Text("What happened?")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                resolutionButton("It happened", tint: .green, action: onDone)
                resolutionButton("Missed", tint: .orange, action: onMissed)
                resolutionButton("Canceled", tint: .secondary, action: onCanceled)
            }

            if let nextOccurrence = presentation.nextOccurrence {
                Text("Next: \(nextOccurrence.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.orange.opacity(0.35), lineWidth: 1)
        }
    }

    private var occurrenceText: String {
        let start = presentation.occurrence.formatted(date: .abbreviated, time: .shortened)
        guard let timeRange = presentation.timeRange else { return start }
        let end = timeRange.endDate(on: presentation.occurrence).formatted(date: .omitted, time: .shortened)
        return "\(start)–\(end)"
    }

    private func resolutionButton(
        _ title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .tint(tint)
    }
}
