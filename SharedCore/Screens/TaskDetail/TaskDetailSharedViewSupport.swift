import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif
import UniformTypeIdentifiers

struct TaskDetailHeaderBadgeItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let systemImage: String?
    let tint: Color
}

enum TaskDetailHeaderBadgePresentation {
    enum Layout {
        case mobile
        case desktop
    }

    static func durationText(for minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        switch (hours, remainingMinutes) {
        case (0, let minutes):
            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
        case (let hours, 0):
            return hours == 1 ? "1 hour" : "\(hours) hours"
        case (let hours, let minutes):
            let hourText = hours == 1 ? "1 hour" : "\(hours) hours"
            let minuteText = minutes == 1 ? "1 minute" : "\(minutes) minutes"
            return "\(hourText) \(minuteText)"
        }
    }

    static func storyPointsText(for points: Int) -> String {
        points == 1 ? "1 story point" : "\(points) story points"
    }

    static func totalLoggedActualDurationMinutes(from logs: [RoutineLog]) -> Int {
        logs.reduce(0) { partialResult, log in
            partialResult + (log.kind == .completed ? (log.actualDurationMinutes ?? 0) : 0)
        }
    }

    static func displayedActualDurationMinutes(task: RoutineTask, logs: [RoutineLog]) -> Int {
        task.isOneOffTask ? (task.actualDurationMinutes ?? 0) : totalLoggedActualDurationMinutes(from: logs)
    }

    static func latestCompletedLog(in logs: [RoutineLog]) -> RoutineLog? {
        logs
            .filter { $0.kind == .completed }
            .max { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
    }

    static func displayedActualDurationText(task: RoutineTask, logs: [RoutineLog]) -> String? {
        let minutes = displayedActualDurationMinutes(task: task, logs: logs)
        return minutes > 0 ? durationText(for: minutes) : nil
    }

    static func todoBadgeRows(
        state: TaskDetailFeature.State,
        summaryStatusColor: Color,
        dueDateMetadataDisplayText: String?,
        layout: Layout
    ) -> [[TaskDetailHeaderBadgeItem]] {
        var rows: [[TaskDetailHeaderBadgeItem]]

        switch layout {
        case .mobile:
            rows = [[
                TaskDetailHeaderBadgeItem(
                    title: "Status",
                    value: state.summaryStatusTitle,
                    systemImage: nil,
                    tint: summaryStatusColor
                ),
                TaskDetailHeaderBadgeItem(
                    title: "Selected",
                    value: state.selectedDateMetadataText,
                    systemImage: nil,
                    tint: .accentColor
                )
            ]]

        case .desktop:
            rows = []
        }

        if let locationRow = locationRow(for: state) {
            rows.append(locationRow)
        }

        appendDueReminderAndEstimationRows(
            to: &rows,
            state: state,
            dueDateMetadataDisplayText: dueDateMetadataDisplayText,
            layout: layout
        )

        return rows
    }

    static func routineBadgeRows(
        state: TaskDetailFeature.State,
        summaryStatusColor: Color,
        dueDateMetadataDisplayText: String?,
        layout: Layout
    ) -> [[TaskDetailHeaderBadgeItem]] {
        var rows: [[TaskDetailHeaderBadgeItem]] = [[
            TaskDetailHeaderBadgeItem(
                title: "Status",
                value: state.summaryStatusTitle,
                systemImage: nil,
                tint: summaryStatusColor
            ),
            TaskDetailHeaderBadgeItem(
                title: "Frequency",
                value: state.frequencyText,
                systemImage: nil,
                tint: .mint
            )
        ]]

        switch layout {
        case .mobile:
            if let dueDateMetadataDisplayText {
                rows.append([dueBadge(value: dueDateMetadataDisplayText)])
            }

            rows.append(mobileCompletedLocationRow(for: state))

            if state.canceledLogCount > 0 {
                rows.append([canceledBadge(for: state)])
            }

        case .desktop:
            rows.append(desktopRoutineSecondRow(
                for: state,
                dueDateMetadataDisplayText: dueDateMetadataDisplayText
            ))

            if dueDateMetadataDisplayText != nil, let locationRow = locationRow(for: state) {
                rows.append(locationRow)
            }
        }

        appendReminderAndEstimationRows(to: &rows, state: state, layout: layout)
        return rows
    }

    static func estimationBadges(
        task: RoutineTask,
        displayedActualDurationMinutes: Int,
        includeSpent: Bool,
        includeStoryPoints: Bool
    ) -> [TaskDetailHeaderBadgeItem] {
        var badges: [TaskDetailHeaderBadgeItem] = []

        if let estimatedDurationMinutes = task.estimatedDurationMinutes {
            badges.append(
                TaskDetailHeaderBadgeItem(
                    title: "Estimate",
                    value: durationText(for: estimatedDurationMinutes),
                    systemImage: nil,
                    tint: .teal
                )
            )
        }

        if includeSpent, displayedActualDurationMinutes > 0 {
            badges.append(
                TaskDetailHeaderBadgeItem(
                    title: "Spent",
                    value: durationText(for: displayedActualDurationMinutes),
                    systemImage: "clock.fill",
                    tint: .cyan
                )
            )
        }

        if includeStoryPoints, let storyPoints = task.storyPoints {
            badges.append(
                TaskDetailHeaderBadgeItem(
                    title: "Points",
                    value: storyPointsText(for: storyPoints),
                    systemImage: nil,
                    tint: .purple
                )
            )
        }

        return badges
    }

    private static func appendDueReminderAndEstimationRows(
        to rows: inout [[TaskDetailHeaderBadgeItem]],
        state: TaskDetailFeature.State,
        dueDateMetadataDisplayText: String?,
        layout: Layout
    ) {
        if let dueDateMetadataDisplayText {
            rows.append([dueBadge(value: dueDateMetadataDisplayText)])
        }

        appendReminderAndEstimationRows(to: &rows, state: state, layout: layout)
    }

    private static func appendReminderAndEstimationRows(
        to rows: inout [[TaskDetailHeaderBadgeItem]],
        state: TaskDetailFeature.State,
        layout: Layout
    ) {
        if let reminderMetadataText = state.reminderMetadataText {
            rows.append([
                TaskDetailHeaderBadgeItem(
                    title: "Reminder",
                    value: reminderMetadataText,
                    systemImage: "bell.fill",
                    tint: .indigo
                )
            ])
        }

        let estimationBadges = estimationBadges(
            task: state.task,
            displayedActualDurationMinutes: displayedActualDurationMinutes(
                task: state.task,
                logs: state.logs
            ),
            includeSpent: layout == .mobile,
            includeStoryPoints: layout == .mobile
        )
        if !estimationBadges.isEmpty {
            rows.append(estimationBadges)
        }
    }

    private static func locationRow(for state: TaskDetailFeature.State) -> [TaskDetailHeaderBadgeItem]? {
        guard let linkedPlace = state.linkedPlaceSummary else { return nil }
        return [
            TaskDetailHeaderBadgeItem(
                title: "Location",
                value: linkedPlace.name,
                systemImage: nil,
                tint: .blue
            )
        ]
    }

    private static func mobileCompletedLocationRow(for state: TaskDetailFeature.State) -> [TaskDetailHeaderBadgeItem] {
        var row = locationRow(for: state) ?? []
        row.append(completedBadge(for: state))
        return row
    }

    private static func desktopRoutineSecondRow(
        for state: TaskDetailFeature.State,
        dueDateMetadataDisplayText: String?
    ) -> [TaskDetailHeaderBadgeItem] {
        var row = [completedBadge(for: state)]

        if state.canceledLogCount > 0 {
            row.append(canceledBadge(for: state))
        }

        if let dueDateMetadataDisplayText {
            row.append(dueBadge(value: dueDateMetadataDisplayText))
        } else if let linkedPlace = state.linkedPlaceSummary {
            row.append(
                TaskDetailHeaderBadgeItem(
                    title: "Location",
                    value: linkedPlace.name,
                    systemImage: nil,
                    tint: .blue
                )
            )
        }

        return row
    }

    private static func dueBadge(value: String) -> TaskDetailHeaderBadgeItem {
        TaskDetailHeaderBadgeItem(
            title: "Due",
            value: value,
            systemImage: nil,
            tint: .orange
        )
    }

    private static func completedBadge(for state: TaskDetailFeature.State) -> TaskDetailHeaderBadgeItem {
        TaskDetailHeaderBadgeItem(
            title: "Completed",
            value: state.completedLogCountText,
            systemImage: nil,
            tint: .green
        )
    }

    private static func canceledBadge(for state: TaskDetailFeature.State) -> TaskDetailHeaderBadgeItem {
        TaskDetailHeaderBadgeItem(
            title: "Canceled",
            value: state.canceledLogCountText,
            systemImage: nil,
            tint: .orange
        )
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
    static func items(
        for state: TaskDetailFeature.State,
        showSelectedDate: Bool,
        displayedActualDurationText: String?,
        dueDateMetadataDisplayText: String?,
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

        if let pausedAt = state.task.pausedAt {
            items.append(.init(id: "paused", label: "Paused", value: pausedAt.formatted(date: .abbreviated, time: .omitted)))
        } else if let dueDateMetadataDisplayText {
            items.append(.init(id: "due", label: "Due", value: dueDateMetadataDisplayText))
        }

        if showSelectedDate && state.shouldShowSelectedDateMetadata {
            items.append(.init(id: "selectedDate", label: "Selected", value: state.selectedDateMetadataText))
        }

        if state.task.hasImage || !state.taskAttachments.isEmpty {
            items.append(
                .init(
                    id: "attachments",
                    label: "Attachment",
                    value: attachmentSummaryText(for: state),
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

    private static func attachmentSummaryText(for state: TaskDetailFeature.State) -> String {
        let fileCount = state.taskAttachments.count
        return [
            state.task.hasImage ? "1 image" : nil,
            fileCount > 0 ? "\(fileCount) \(fileCount == 1 ? "file" : "files")" : nil
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

    private static func appendChecklistAndStepItems(
        to items: inout [TaskDetailStatusMetadataItem],
        state: TaskDetailFeature.State,
        referenceDate: Date
    ) {
        if state.task.isChecklistDriven {
            items.append(
                .init(
                    id: "checklist",
                    label: "Checklist",
                    value: "\(state.task.checklistItems.count) \(state.task.checklistItems.count == 1 ? "item" : "items")"
                )
            )
            if let nextDueChecklistItemTitle = state.task.nextDueChecklistItem(referenceDate: referenceDate)?.title {
                items.append(.init(id: "nextDueChecklistItem", label: "Next Due", value: nextDueChecklistItemTitle))
            }
        } else if state.task.isChecklistCompletionRoutine {
            items.append(
                .init(
                    id: "checklist",
                    label: "Checklist",
                    value: "\(state.task.totalChecklistItemCount) \(state.task.totalChecklistItemCount == 1 ? "item" : "items")"
                )
            )
            items.append(.init(id: "checklistProgress", label: "Progress", value: state.checklistProgressText))
            if let nextPendingChecklistItemTitle = state.task.nextPendingChecklistItemTitle {
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

struct TaskDetailOverviewHeightsPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension Calendar {
    var orderedShortStandaloneWeekdaySymbols: [String] {
        let symbols = shortStandaloneWeekdaySymbols
        let startIndex = firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }

    func daysInMonthGrid(for monthStart: Date) -> [Date?] {
        guard
            let monthRange = range(of: .day, in: .month, for: monthStart),
            let monthInterval = dateInterval(of: .month, for: monthStart)
        else { return [] }

        let firstDay = monthInterval.start
        let firstWeekday = component(.weekday, from: firstDay)
        let leadingEmptyDays = (firstWeekday - self.firstWeekday + 7) % 7

        var result: [Date?] = Array(repeating: nil, count: leadingEmptyDays)
        for day in monthRange {
            if let date = date(byAdding: .day, value: day - 1, to: firstDay) {
                result.append(date)
            }
        }
        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }
}
