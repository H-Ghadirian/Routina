import SwiftUI

struct TaskDetailHeaderBadgeItem: Identifiable {
    let id: UUID
    let title: String
    let value: String
    let systemImage: String?
    let tint: Color
    let heightReservationValue: String?

    init(
        id: UUID = UUID(),
        title: String,
        value: String,
        systemImage: String?,
        tint: Color,
        heightReservationValue: String? = nil
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
        self.heightReservationValue = heightReservationValue
    }
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
        layout: Layout,
        showsPlaces: Bool = true
    ) -> [[TaskDetailHeaderBadgeItem]] {
        var rows: [[TaskDetailHeaderBadgeItem]]

        switch layout {
        case .mobile:
            var statusRow = [
                TaskDetailHeaderBadgeItem(
                    title: "Status",
                    value: state.summaryStatusTitle,
                    systemImage: nil,
                    tint: summaryStatusColor
                )
            ]

            if state.shouldShowSelectedDateMetadata {
                statusRow.append(
                    TaskDetailHeaderBadgeItem(
                        title: "Viewing",
                        value: state.selectedDateMetadataText,
                        systemImage: nil,
                        tint: .accentColor
                    )
                )
            }

            rows = [statusRow]

        case .desktop:
            rows = []
        }

        if showsPlaces, let locationRow = locationRow(for: state) {
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
        summaryStatusTitle: String? = nil,
        summaryStatusColor: Color,
        dueDateMetadataDisplayText: String?,
        layout: Layout,
        showsPlaces: Bool = true
    ) -> [[TaskDetailHeaderBadgeItem]] {
        var rows: [[TaskDetailHeaderBadgeItem]] = [
            [
                TaskDetailHeaderBadgeItem(
                    title: "Status",
                    value: summaryStatusTitle ?? state.summaryStatusTitle,
                    systemImage: nil,
                    tint: summaryStatusColor,
                    heightReservationValue: state.assumedCompletionStatusHeightReservationText
                ),
                TaskDetailHeaderBadgeItem(
                    title: "Frequency",
                    value: state.frequencyText,
                    systemImage: nil,
                    tint: .mint
                ),
            ]
        ]

        switch layout {
        case .mobile:
            if let dueDateMetadataDisplayText {
                rows.append([dueBadge(value: dueDateMetadataDisplayText)])
            }

            rows.append(mobileCompletedLocationRow(for: state, showsPlaces: showsPlaces))

            if state.canceledLogCount > 0 {
                rows.append([canceledBadge(for: state)])
            }

        case .desktop:
            rows.append(
                desktopRoutineSecondRow(
                    for: state,
                    dueDateMetadataDisplayText: dueDateMetadataDisplayText,
                    showsPlaces: showsPlaces
                ))

            if showsPlaces, dueDateMetadataDisplayText != nil, let locationRow = locationRow(for: state) {
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
        if let scheduledTimeBlockMetadataText = state.scheduledTimeBlockMetadataText {
            rows.append([
                TaskDetailHeaderBadgeItem(
                    title: "Schedule",
                    value: scheduledTimeBlockMetadataText,
                    systemImage: "calendar.badge.clock",
                    tint: .blue
                )
            ])
        }

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

        if layout == .mobile || !state.task.isOneOffTask {
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

    private static func mobileCompletedLocationRow(
        for state: TaskDetailFeature.State,
        showsPlaces: Bool
    ) -> [TaskDetailHeaderBadgeItem] {
        var row = showsPlaces ? locationRow(for: state) ?? [] : []
        row.append(completedBadge(for: state))
        return row
    }

    private static func desktopRoutineSecondRow(
        for state: TaskDetailFeature.State,
        dueDateMetadataDisplayText: String?,
        showsPlaces: Bool
    ) -> [TaskDetailHeaderBadgeItem] {
        var row = [completedBadge(for: state)]

        if state.canceledLogCount > 0 {
            row.append(canceledBadge(for: state))
        }

        if let dueDateMetadataDisplayText {
            row.append(dueBadge(value: dueDateMetadataDisplayText))
        } else if showsPlaces, let linkedPlace = state.linkedPlaceSummary {
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
            tint: TaskDetailStatusPalette.canceled
        )
    }
}
