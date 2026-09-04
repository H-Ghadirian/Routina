import Foundation
import SwiftUI

enum HomeMacToolbarSearchReminderChoice: String, CaseIterable, Identifiable {
    case none
    case oneHour
    case twoHours
    case oneDay
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "No reminder"
        case .oneHour: return "1 hour before"
        case .twoHours: return "2 hours before"
        case .oneDay: return "1 day before"
        case .custom: return "Custom date/time"
        }
    }

    func reminderDate(eventDate: Date?, customDate: Date) -> Date? {
        switch self {
        case .none:
            return nil
        case .oneHour:
            return eventDate?.addingTimeInterval(-60 * 60)
        case .twoHours:
            return eventDate?.addingTimeInterval(-2 * 60 * 60)
        case .oneDay:
            return eventDate?.addingTimeInterval(-24 * 60 * 60)
        case .custom:
            return eventDate == nil ? nil : customDate
        }
    }
}

struct HomeMacToolbarQuickAddSubmission: Equatable {
    let taskTitle: String
    let reminderAt: Date?

    init(
        draft: RoutinaQuickAddDraft,
        taskTitle: String,
        reminderChoice: HomeMacToolbarSearchReminderChoice,
        customReminderAt: Date,
        calendar: Calendar
    ) {
        let trimmedTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        self.taskTitle = trimmedTitle.isEmpty ? draft.name : trimmedTitle
        self.reminderAt = reminderChoice.reminderDate(
            eventDate: draft.exactAvailabilityDate(calendar: calendar),
            customDate: customReminderAt
        )
    }
}

enum HomeMacToolbarLinkMetadataStatus: Equatable {
    case idle
    case loading
    case resolved
    case unavailable
}

struct HomeMacToolbarSearchParserPreview: View {
    @Environment(\.calendar) private var calendar
    let draft: RoutinaQuickAddDraft
    @Binding var taskTitle: String
    @Binding var isTaskTitleFocused: Bool
    @Binding var reminderChoice: HomeMacToolbarSearchReminderChoice
    @Binding var customReminderAt: Date
    let linkMetadataStatus: HomeMacToolbarLinkMetadataStatus
    let isUpdating: Bool
    let onSubmit: (HomeMacToolbarQuickAddSubmission) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(HomeMacToolbarSearchCopy.parserPreviewTitle, systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if isUpdating {
                updatingDetailsRow
            } else {
                detectedDetailsContent
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.96))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .background {
            HomeMacSearchInteractionRegionView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var detectedDetailsContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "textformat")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)

            TextField("Task title", text: $taskTitle) { isEditing in
                isTaskTitleFocused = isEditing
            }
            .textFieldStyle(.roundedBorder)
            .font(.headline)
            .accessibilityLabel("Task title")
            .onSubmit {
                onSubmit(
                    HomeMacToolbarQuickAddSubmission(
                        draft: draft,
                        taskTitle: taskTitle,
                        reminderChoice: reminderChoice,
                        customReminderAt: customReminderAt,
                        calendar: calendar
                    ))
            }
            .onExitCommand {
                isTaskTitleFocused = false
            }

            if linkMetadataStatus == .loading {
                ProgressView()
                    .controlSize(.small)
                    .help("Fetching the link title")
            }
        }

        VStack(alignment: .leading, spacing: 6) {
            if parsedRows.isEmpty {
                updatingDetailsRow
            } else {
                ForEach(parsedRows) { row in
                    parsedRow(row)
                }
            }
        }

        if let eventDate = draft.exactAvailabilityDate(calendar: calendar) {
            Divider()

            HStack(spacing: 10) {
                Label("Reminder?", systemImage: "bell")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Reminder", selection: $reminderChoice) {
                    ForEach(HomeMacToolbarSearchReminderChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 170)

                if reminderChoice == .custom {
                    DatePicker(
                        "Custom reminder",
                        selection: $customReminderAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .fixedSize()
                }

                Spacer(minLength: 0)
            }
            .onChange(of: reminderChoice) { _, choice in
                if choice == .custom {
                    customReminderAt = eventDate
                }
            }
        }
    }

    private var updatingDetailsRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "ellipsis")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)

            Text("Updating details…")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
    }

    private var parsedRows: [ParsedRow] {
        var rows: [ParsedRow] = []

        if draft.scheduleMode != .oneOff {
            rows.append(
                ParsedRow(
                    title: draft.scheduleMode.isSoftIntervalRoutine ? "Gentle repeating" : "Repeats",
                    value: draft.recurrenceRule.displayText(calendar: calendar),
                    systemImage: "calendar"
                ))
        } else if let availabilityDate = draft.exactAvailabilityDate(calendar: calendar) {
            rows.append(
                ParsedRow(
                    title: "Available",
                    value: availabilityDate.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "calendar"
                ))
        } else if let availabilityStartDate = draft.availabilityStartDate {
            rows.append(
                ParsedRow(
                    title: "Available",
                    value: availabilityStartDate.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar"
                ))
        } else if let deadline = draft.deadline {
            rows.append(
                ParsedRow(
                    title: "Due",
                    value: deadline.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "calendar"
                ))
        }

        if !draft.tags.isEmpty {
            rows.append(
                ParsedRow(
                    title: "Tags",
                    value: draft.tags.map { "#\($0)" }.joined(separator: " "),
                    systemImage: "tag"
                ))
        }

        if let placeName = draft.placeName {
            rows.append(
                ParsedRow(
                    title: "Place",
                    value: "@\(placeName)",
                    systemImage: "mappin.and.ellipse"
                ))
        }

        if draft.hasExplicitPriority {
            rows.append(
                ParsedRow(
                    title: "Priority",
                    value: "\(draft.importance.title) / \(draft.urgency.title)",
                    systemImage: "exclamationmark.triangle"
                ))
        }

        if let estimatedDurationMinutes = draft.estimatedDurationMinutes {
            rows.append(
                ParsedRow(
                    title: "Focus",
                    value: "\(estimatedDurationMinutes)m",
                    systemImage: "timer"
                ))
        }

        if let primaryLinkURL = draft.primaryLinkURL {
            let statusText = linkMetadataStatus == .loading ? " · Fetching title…" : ""
            rows.append(
                ParsedRow(
                    title: "Link",
                    value: "\(RoutinaQuickAddLinkSupport.sourceName(for: primaryLinkURL))\(statusText)",
                    systemImage: "link"
                ))
        }

        return rows
    }

    private func parsedRow(_ row: ParsedRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: row.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)

            Text(row.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)

            Text(row.value)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
    }

    private struct ParsedRow: Identifiable {
        let title: String
        let value: String
        let systemImage: String

        var id: String { "\(title):\(value)" }
    }
}
