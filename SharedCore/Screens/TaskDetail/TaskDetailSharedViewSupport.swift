import SwiftUI
#if os(macOS)
    import AppKit
#elseif os(iOS)
    import UIKit
#endif
import UniformTypeIdentifiers

enum TaskDetailEventActionVisibility {
    static func shouldShowAddEventsAction(
        hasLinkedEvents: Bool,
        areEventActionsEnabled: Bool
    ) -> Bool {
        areEventActionsEnabled && !hasLinkedEvents
    }
}

struct TaskDetailStatusMetadataItem: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let systemImage: String?

    init(id: String, label: String, value: String, systemImage: String? = nil) {
        self.id = id
        self.label = label
        self.value = value
        self.systemImage = systemImage
    }
}

enum TaskDetailStatusMetadataPresentation {
    enum ContextStyle {
        case mobile
        case desktop
    }

    static func statusContextMessage(
        for state: TaskDetailFeature.State,
        showPersianDates: Bool,
        style: ContextStyle,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        if state.task.isArchived(referenceDate: referenceDate, calendar: calendar) {
            return "Resume it anytime to put it back in rotation."
        }

        if state.task.isOneOffTask { return nil }

        if state.isSelectedDateAssumedDone {
            let isSelectedDateToday = calendar.isDate(state.resolvedSelectedDate, inSameDayAs: referenceDate)
            switch (style, isSelectedDateToday) {
            case (.mobile, true):
                return "Today is assumed done. Confirm it to count it in your history, or use Not Today if plans changed."
            case (.mobile, false):
                return "This day is assumed done. Confirm it to count it in stats and history."
            case (.desktop, true):
                return "Today is assumed done. Confirm it if you want it counted in history and stats."
            case (.desktop, false):
                return "This day is assumed done. Confirm it if you want it counted in history and stats."
            }
        }

        if calendar.isDate(state.resolvedSelectedDate, inSameDayAs: referenceDate) {
            return nil
        }

        let dateText = PersianDateDisplay.appendingSupplementaryDate(
            to: state.resolvedSelectedDate.formatted(date: .abbreviated, time: .omitted),
            for: state.resolvedSelectedDate,
            enabled: showPersianDates
        )
        return "Reviewing \(dateText)."
    }

    static func dueDateMetadataDisplayText(
        rawText: String?,
        dueDate: Date?,
        showPersianDates: Bool
    ) -> String? {
        guard let rawText else { return nil }
        guard let dueDate else { return rawText }
        return PersianDateDisplay.appendingSupplementaryDate(
            to: rawText,
            for: dueDate,
            enabled: showPersianDates
        )
    }

    static func hasVisibleMetadata(
        for state: TaskDetailFeature.State,
        showsPlaces: Bool = true,
        showsNotes: Bool = true
    ) -> Bool {
        !state.task.isOneOffTask
            || shouldShowCompletionCount(for: state)
            || (showsPlaces && state.linkedPlaceSummary != nil)
            || state.task.pausedAt != nil
            || state.dueDateMetadataText != nil
            || state.reminderMetadataText != nil
            || state.scheduledTimeBlockMetadataText != nil
            || state.shouldShowSelectedDateMetadata
            || !state.task.tags.isEmpty
            || state.task.hasImage
            || (showsNotes && state.task.hasVoiceNote)
            || !state.taskAttachments.isEmpty
            || state.hasStoredChecklistItems
            || state.task.hasSequentialSteps
    }

    static func items(
        for state: TaskDetailFeature.State,
        showSelectedDate: Bool,
        displayedActualDurationText: String?,
        dueDateMetadataDisplayText: String?,
        showsNotes: Bool = true,
        referenceDate: Date = Date()
    ) -> [TaskDetailStatusMetadataItem] {
        var items: [TaskDetailStatusMetadataItem] = []

        if !state.task.isOneOffTask {
            items.append(.init(id: "frequency", label: "Frequency", value: state.frequencyText))
        }

        if shouldShowCompletionCount(for: state) {
            items.append(.init(id: "completed", label: "Completed", value: state.completedLogCountText))
        }

        if let displayedActualDurationText {
            items.append(.init(id: "timeSpent", label: "Time Spent", value: displayedActualDurationText, systemImage: "clock"))
        }

        if state.canceledLogCount > 0 {
            items.append(.init(id: "canceled", label: "Canceled", value: state.canceledLogCountText, systemImage: "xmark.circle"))
        }

        if state.task.isPaused(referenceDate: referenceDate), let pausedAt = state.task.pausedAt {
            let pauseValue =
                state.task.pauseUntil?
                .formatted(date: .abbreviated, time: .shortened)
                ?? pausedAt.formatted(date: .abbreviated, time: .omitted)
            items.append(
                .init(
                    id: "paused",
                    label: state.task.pauseUntil == nil ? "Paused" : "Paused Until",
                    value: pauseValue
                )
            )
        } else if let dueDateMetadataDisplayText {
            items.append(.init(id: "due", label: "Due", value: dueDateMetadataDisplayText))
        }

        if let reminderMetadataText = state.reminderMetadataText {
            items.append(
                .init(
                    id: "reminder",
                    label: "Reminder",
                    value: reminderMetadataText,
                    systemImage: "bell.fill"
                )
            )
        }

        if showSelectedDate && state.shouldShowSelectedDateMetadata {
            items.append(.init(id: "selectedDate", label: "Selected", value: state.selectedDateMetadataText))
        }

        if state.task.hasImage || (showsNotes && state.task.hasVoiceNote) || !state.taskAttachments.isEmpty {
            items.append(
                .init(
                    id: "attachments",
                    label: "Attachment",
                    value: attachmentSummaryText(for: state, showsNotes: showsNotes),
                    systemImage: "paperclip"
                )
            )
        }

        appendChecklistAndStepItems(to: &items, state: state, referenceDate: referenceDate)
        return items
    }

    static func shouldShowCompletionCount(for state: TaskDetailFeature.State) -> Bool {
        if state.task.isOneOffTask {
            return state.completedLogCount > 0 || state.canceledLogCount > 0
        }
        return true
    }

    private static func attachmentSummaryText(
        for state: TaskDetailFeature.State,
        showsNotes: Bool
    ) -> String {
        let fileCount = state.taskAttachments.count
        return [
            state.task.hasImage ? "1 image" : nil,
            (showsNotes && state.task.hasVoiceNote) ? "1 voice note" : nil,
            fileCount > 0 ? "\(fileCount) \(fileCount == 1 ? "file" : "files")" : nil,
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

    private static func appendChecklistAndStepItems(
        to items: inout [TaskDetailStatusMetadataItem],
        state: TaskDetailFeature.State,
        referenceDate: Date
    ) {
        if state.isChecklistDrivenFromStoredItems {
            let checklistItemCount = state.totalChecklistItemCount
            items.append(
                .init(
                    id: "checklist",
                    label: "Checklist",
                    value: "\(checklistItemCount) \(checklistItemCount == 1 ? "item" : "items")"
                )
            )
            if let nextDueChecklistItemTitle = state.nextDueChecklistItem(referenceDate: referenceDate)?.title {
                items.append(.init(id: "nextDueChecklistItem", label: "Next Due", value: nextDueChecklistItemTitle))
            }
        } else if state.isChecklistCompletionFromStoredItems || state.supportsOptionalChecklistProgressFromStoredItems {
            let checklistItemCount = state.totalChecklistItemCount
            items.append(
                .init(
                    id: "checklist",
                    label: "Checklist",
                    value: "\(checklistItemCount) \(checklistItemCount == 1 ? "item" : "items")"
                )
            )
            items.append(.init(id: "checklistProgress", label: "Progress", value: state.checklistProgressText))
            if state.isChecklistCompletionFromStoredItems,
                !state.isDoneToday,
                let nextPendingChecklistItemTitle = state.nextPendingChecklistItemTitle(referenceDate: referenceDate)
            {
                items.append(.init(id: "nextChecklistItem", label: "Next Item", value: nextPendingChecklistItemTitle))
            }
        } else if state.task.hasSequentialSteps {
            items.append(.init(id: "stepProgress", label: "Progress", value: state.stepProgressText))
            if let nextStepTitle = state.task.nextStepTitle {
                items.append(.init(id: "nextStep", label: "Next Step", value: nextStepTitle))
            }
        }
    }
}

struct TaskDetailStatusMetadataSectionView: View {
    let items: [TaskDetailStatusMetadataItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(items) { item in
                TaskDetailStatusMetadataRow(
                    label: item.label,
                    value: item.value,
                    systemImage: item.systemImage
                )
            }
        }
    }
}

struct TaskDetailNotificationDisabledWarningView: View {
    let warningText: String
    let actionTitle: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "bell.slash.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text("No notification will fire")
                        .font(.subheadline.weight(.semibold))
                    Text(warningText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(actionTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange.opacity(0.8))
            }
        }
        .buttonStyle(.plain)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.orange.opacity(0.25), lineWidth: 1)
        )
    }
}

struct TaskDetailStatusMetadataRow: View {
    let label: String
    let value: String
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct RoutineAttachmentFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private enum TaskDetailCopyTextSupport {
    static func copy(_ text: String) {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        #elseif os(iOS)
            UIPasteboard.general.string = text
        #endif
    }
}

extension View {
    func taskDetailCopyableText(_ text: String) -> some View {
        contextMenu {
            Button {
                TaskDetailCopyTextSupport.copy(text)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }
    }
}
