import SwiftUI

struct DayPlanWeekDayHeader: View {
    var date: Date
    var isSelected: Bool
    var isFocusedForUnplannedCompleted: Bool
    var isToday: Bool
    var unplannedCompletedCount: Int
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

            if unplannedCompletedCount > 0 {
                Button(action: onSelectUnplannedCompleted) {
                    Label("\(unplannedCompletedCount) done", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isFocusedForUnplannedCompleted ? Color.accentColor : Color.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(isFocusedForUnplannedCompleted ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.10))
                )
                .help("Show completed tasks not planned for \(date.formatted(date: .abbreviated, time: .omitted))")
                .accessibilityLabel("\(unplannedCompletedCount) completed tasks not planned for \(date.formatted(date: .abbreviated, time: .omitted))")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.horizontal, 10)
        .background(headerBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 1)
        }
    }

    private var headerBackground: Color {
        if isFocusedForUnplannedCompleted {
            return Color.accentColor.opacity(0.20)
        }
        if isSelected {
            return Color.accentColor.opacity(0.14)
        }
        return Color.clear
    }
}
