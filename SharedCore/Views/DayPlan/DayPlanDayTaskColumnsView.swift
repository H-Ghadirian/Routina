import SwiftUI

struct DayPlanDayTaskColumnsView: View {
    var dates: [Date]
    var selectedDate: Date
    var calendar: Calendar
    var timeColumnWidth: CGFloat
    var isExternalInspectorPresented: Bool
    var dayTaskListItems: (Date) -> [DayPlanDayTaskListItem]
    var taskTint: (UUID) -> Color
    var isTaskOpenable: (UUID) -> Bool
    var onOpenTaskDetails: (DayPlanDayTaskListItem, Date) -> Void
    var onCompletePlannedDayTask: (DayPlanDayTaskListItem, Date) -> Void
    var onConfirmAssumedDayTask: (DayPlanDayTaskListItem, Date) -> Void
    var onMarkAssumedDayTaskMissed: (DayPlanDayTaskListItem, Date) -> Void

    var body: some View {
        GeometryReader { proxy in
            let dayWidth = DayPlanWeekCalendarSizing.dayWidth(
                availableWidth: proxy.size.width,
                dayCount: max(dates.count, 1),
                isExternalInspectorPresented: isExternalInspectorPresented
            )
            let contentWidth = timeColumnWidth + (CGFloat(dates.count) * dayWidth)

            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    Color.clear
                        .frame(width: timeColumnWidth)
                        .frame(minHeight: proxy.size.height)
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.18))
                                .frame(width: 1)
                        }

                    ForEach(dates, id: \.self) { date in
                        DayPlanDayTaskColumnView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            columnWidth: dayWidth,
                            items: dayTaskListItems(date),
                            taskTint: taskTint,
                            calendar: calendar,
                            isTaskOpenable: isTaskOpenable,
                            onOpenTaskDetails: onOpenTaskDetails,
                            onCompletePlannedDayTask: onCompletePlannedDayTask,
                            onConfirmAssumedDayTask: onConfirmAssumedDayTask,
                            onMarkAssumedDayTaskMissed: onMarkAssumedDayTaskMissed
                        )
                        .frame(width: dayWidth, alignment: .topLeading)
                        .frame(minHeight: proxy.size.height, alignment: .topLeading)
                    }
                }
                .frame(width: contentWidth, alignment: .topLeading)
                .frame(minHeight: proxy.size.height, alignment: .topLeading)
            }
            .background(Color.secondary.opacity(0.035))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DayPlanDayTaskColumnView: View {
    var date: Date
    var isSelected: Bool
    var columnWidth: CGFloat
    var items: [DayPlanDayTaskListItem]
    var taskTint: (UUID) -> Color
    var calendar: Calendar
    var isTaskOpenable: (UUID) -> Bool
    var onOpenTaskDetails: (DayPlanDayTaskListItem, Date) -> Void
    var onCompletePlannedDayTask: (DayPlanDayTaskListItem, Date) -> Void
    var onConfirmAssumedDayTask: (DayPlanDayTaskListItem, Date) -> Void
    var onMarkAssumedDayTaskMissed: (DayPlanDayTaskListItem, Date) -> Void
    @AppStorage(
        UserDefaultBoolValueKey.appSettingDayPlanCalendarListAssumedDoneCollapsedByDefault.rawValue,
        store: SharedDefaults.app
    ) private var areCalendarListTaskSectionsCollapsedByDefault = true
    @State private var plannedTasksSectionCollapsedOverride: Bool?
    @State private var assumedDoneSectionCollapsedOverride: Bool?
    @State private var confirmedAssumedDoneSectionCollapsedOverride: Bool?
    @State private var doneSectionCollapsedOverride: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if items.isEmpty {
                emptyState
            } else {
                DayPlanDayTaskListContentView(
                    items: items,
                    taskTint: taskTint,
                    date: date,
                    calendar: calendar,
                    isTaskOpenable: isTaskOpenable,
                    onOpenTaskDetails: onOpenTaskDetails,
                    onCompletePlannedDayTask: onCompletePlannedDayTask,
                    onConfirmAssumedDayTask: onConfirmAssumedDayTask,
                    onMarkAssumedDayTaskMissed: onMarkAssumedDayTaskMissed,
                    availableRowWidth: availableRowWidth,
                    sectionSpacing: 12,
                    plannedTasksSectionCollapsed: plannedTasksSectionCollapsed,
                    assumedDoneSectionCollapsed: assumedDoneSectionCollapsed,
                    confirmedAssumedDoneSectionCollapsed: confirmedAssumedDoneSectionCollapsed,
                    doneSectionCollapsed: doneSectionCollapsed,
                    separatesConfirmedAssumedDone: true
                )
            }
        }
        .padding(DayPlanWeekCalendarSizing.dayTaskListColumnPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isSelected ? Color.secondary.opacity(0.045) : Color.clear)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 1)
        }
    }

    private var availableRowWidth: CGFloat {
        max(columnWidth - (DayPlanWeekCalendarSizing.dayTaskListColumnPadding * 2), 0)
    }

    private var assumedDoneSectionCollapsed: Binding<Bool> {
        Binding(
            get: {
                assumedDoneSectionCollapsedOverride
                    ?? areCalendarListTaskSectionsCollapsedByDefault
            },
            set: { isCollapsed in
                assumedDoneSectionCollapsedOverride = isCollapsed
            }
        )
    }

    private var plannedTasksSectionCollapsed: Binding<Bool> {
        Binding(
            get: {
                plannedTasksSectionCollapsedOverride
                    ?? areCalendarListTaskSectionsCollapsedByDefault
            },
            set: { isCollapsed in
                plannedTasksSectionCollapsedOverride = isCollapsed
            }
        )
    }

    private var confirmedAssumedDoneSectionCollapsed: Binding<Bool> {
        Binding(
            get: {
                confirmedAssumedDoneSectionCollapsedOverride
                    ?? areCalendarListTaskSectionsCollapsedByDefault
            },
            set: { isCollapsed in
                confirmedAssumedDoneSectionCollapsedOverride = isCollapsed
            }
        )
    }

    private var doneSectionCollapsed: Binding<Bool> {
        Binding(
            get: {
                doneSectionCollapsedOverride
                    ?? areCalendarListTaskSectionsCollapsedByDefault
            },
            set: { isCollapsed in
                doneSectionCollapsedOverride = isCollapsed
            }
        )
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.title3)
                .foregroundStyle(.tertiary)

            Text("No tasks")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }
}
