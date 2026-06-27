import SwiftUI

struct DayPlanWeekDayHeader: View {
    var date: Date
    var isSelected: Bool
    var isFocusedForUnplannedCompleted: Bool
    var isFocusedForPlannedTasks: Bool
    var isToday: Bool
    var plannedTaskCount: Int
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
                Button(action: onSelectPlannedTasks) {
                    Label(plannedTaskCountText, systemImage: "list.bullet")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isFocusedForPlannedTasks ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .routinaGlassPill(
                    tint: isFocusedForPlannedTasks ? .accentColor : .secondary,
                    tintOpacity: isFocusedForPlannedTasks ? 0.14 : 0.10,
                    interactive: true
                )
                .help("Show planned tasks for \(date.formatted(date: .abbreviated, time: .omitted))")
                .accessibilityLabel("\(plannedTaskCountText) planned for \(date.formatted(date: .abbreviated, time: .omitted))")

                if unplannedCompletedCount > 0 {
                    Button(action: onSelectUnplannedCompleted) {
                        Label(timelineTaskCountText, systemImage: "clock.arrow.circlepath")
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isFocusedForUnplannedCompleted ? Color.accentColor : Color.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .routinaGlassPill(
                        tint: isFocusedForUnplannedCompleted ? .accentColor : .secondary,
                        tintOpacity: isFocusedForUnplannedCompleted ? 0.14 : 0.10,
                        interactive: true
                    )
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

    private var plannedTaskCountText: String {
        "\(plannedTaskCount)"
    }

    private var selectedBackgroundTint: Color {
        isFocusedForUnplannedCompleted || isFocusedForPlannedTasks ? .accentColor : .secondary
    }

    private var selectedBackgroundTintOpacity: Double {
        isFocusedForUnplannedCompleted || isFocusedForPlannedTasks ? 0.20 : 0.10
    }
}
