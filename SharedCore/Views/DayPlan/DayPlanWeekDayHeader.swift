import SwiftUI

struct DayPlanWeekDayHeader: View {
    var date: Date
    var isSelected: Bool
    var isFocusedForUnplannedCompleted: Bool
    var isFocusedForPlannedTasks: Bool
    var isToday: Bool
    var dayTaskCounts: DayPlanDayTaskCounts
    var unplannedCompletedCount: Int
    var onSelectPlannedTasks: () -> Void
    var onSelectUnplannedCompleted: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(date.formatted(.dateTime.day()))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isToday ? Color.white : Color.primary)
                    .padding(.horizontal, isToday ? 8 : 0)
                    .padding(.vertical, isToday ? 3 : 0)
                    .background {
                        if isToday {
                            Capsule()
                                .fill(Color.accentColor)
                        }
                    }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                if dayTaskCounts.total > 0 {
                    Button(action: onSelectPlannedTasks) {
                        Label(dayTaskTotalText, systemImage: "list.bullet")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(plannedTaskButtonTint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .frame(minWidth: 48, minHeight: 28)
                            .routinaGlassPill(
                                tint: plannedTaskButtonTint,
                                tintOpacity: isFocusedForPlannedTasks ? 0.14 : 0.10,
                                interactive: true
                            )
                            .contentShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help(dayTaskButtonHelpText)
                    .accessibilityLabel(dayTasksAccessibilityLabel)
                }

                if unplannedCompletedCount > 0 {
                    Button(action: onSelectUnplannedCompleted) {
                        Label(timelineTaskCountText, systemImage: "clock.arrow.circlepath")
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(unplannedCompletedButtonTint)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .frame(minWidth: 44, minHeight: 28)
                            .routinaGlassPill(
                                tint: unplannedCompletedButtonTint,
                                tintOpacity: isFocusedForUnplannedCompleted ? 0.14 : 0.10,
                                interactive: true
                            )
                            .contentShape(Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Show timeline tasks not planned for \(date.formatted(date: .abbreviated, time: .omitted))")
                    .accessibilityLabel("\(timelineTaskCountText) from the timeline not planned for \(date.formatted(date: .abbreviated, time: .omitted))")
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.horizontal, 10)
        .routinaIf(isSelected || isFocusedForUnplannedCompleted || isFocusedForPlannedTasks) { view in
            view.routinaGlassCard(
                cornerRadius: 0,
                tint: selectedBackgroundTint,
                tintOpacity: selectedBackgroundTintOpacity
            )
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 1)
        }
    }

    private var timelineTaskCountText: String {
        "\(unplannedCompletedCount) \(unplannedCompletedCount == 1 ? "task" : "tasks")"
    }

    private var dayTaskTotalText: String {
        compactCountText(for: dayTaskCounts.total)
    }

    private var plannedTaskButtonTint: Color {
        isFocusedForPlannedTasks ? .accentColor : .secondary
    }

    private var unplannedCompletedButtonTint: Color {
        isFocusedForUnplannedCompleted ? .accentColor : .secondary
    }

    private var selectedBackgroundTint: Color {
        isFocusedForUnplannedCompleted || isFocusedForPlannedTasks ? .accentColor : .secondary
    }

    private var selectedBackgroundTintOpacity: Double {
        isFocusedForUnplannedCompleted || isFocusedForPlannedTasks ? 0.20 : 0.10
    }

    private var dayTaskButtonHelpText: String {
        let dateText = date.formatted(date: .abbreviated, time: .omitted)
        return "Show day tasks for \(dateText): \(dayTaskBreakdownText)"
    }

    private var dayTasksAccessibilityLabel: String {
        let dateText = date.formatted(date: .abbreviated, time: .omitted)
        return "\(dayTaskCounts.total) day tasks for \(dateText): \(dayTaskBreakdownText)"
    }

    private var dayTaskBreakdownText: String {
        [
            dayTaskCounts.planned > 0 ? "\(dayTaskCounts.planned) planned" : nil,
            dayTaskCounts.assumedDone > 0 ? "\(dayTaskCounts.assumedDone) assumed done" : nil,
            dayTaskCounts.done > 0 ? "\(dayTaskCounts.done) done" : nil,
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

    private func compactCountText(for count: Int) -> String {
        count > 99 ? "99+" : "\(count)"
    }
}
