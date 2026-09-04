import SwiftUI

struct DayPlanSlotTaskChoiceRow: View {
    let task: RoutineTask
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "*")
                .font(.callout)
                .frame(width: 26, height: 26)
                .background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(DayPlanTaskSorting.title(for: task))
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if let estimatedDurationMinutes = task.estimatedDurationMinutes {
                    Text(DayPlanFormatting.durationText(estimatedDurationMinutes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 46)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }

    private var rowBackground: some ShapeStyle {
        isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08)
    }
}

struct DayPlanSlotCreateTaskRow: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(title)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 46)
        .background(
            isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.accentColor.opacity(0.24), lineWidth: 1)
        }
    }
}

struct DayPlanAwayOptionCard: View {
    let option: DayPlanAwayLogOption
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: option.systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(option.tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(option.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(option.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.caption2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? option.tint : .secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .routinaGlassPanel(cornerRadius: 10, tint: option.tint, tintOpacity: isSelected ? 0.16 : 0.06, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(option.tint.opacity(isSelected ? 0.9 : 0.22), lineWidth: isSelected ? 1.2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct DayPlanSlotDurationControl: View {
    let title: String
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    let step: Int
    let presets: [Int]
    let tint: Color

    private var visiblePresets: [Int] {
        presets.filter { range.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(DayPlanFormatting.durationText(minutes))
                        .font(.headline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    durationButton(systemImage: "minus", isEnabled: minutes > range.lowerBound) {
                        setMinutes(minutes - step)
                    }

                    durationButton(systemImage: "plus", isEnabled: minutes < range.upperBound) {
                        setMinutes(minutes + step)
                    }
                }
            }

            if !visiblePresets.isEmpty {
                LazyVGrid(columns: presetColumns, spacing: 6) {
                    ForEach(visiblePresets, id: \.self) { preset in
                        Button {
                            setMinutes(preset)
                        } label: {
                            Text(DayPlanFormatting.durationText(preset))
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(tint.opacity(minutes == preset ? 0.24 : 0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(tint.opacity(minutes == preset ? 0.85 : 0.22), lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                }
            }
        }
        .padding(10)
        .routinaGlassPanel(cornerRadius: 10, tint: tint, tintOpacity: 0.06, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private var presetColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: max(visiblePresets.count, 1))
    }

    private func durationButton(
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .frame(width: 30, height: 28)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? Color.primary : Color.secondary.opacity(0.6))
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(isEnabled ? 0.14 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(isEnabled ? 0.28 : 0.12), lineWidth: 1)
        )
        .disabled(!isEnabled)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func setMinutes(_ newValue: Int) {
        minutes = min(max(newValue, range.lowerBound), range.upperBound)
    }
}

enum DayPlanSlotActionPresentation {
    static let awayOptionColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]
    static let taskDurationPresets = [15, 30, 45, 60, 90, 120]

    static func taskDurationRange(startMinute: Int) -> ClosedRange<Int> {
        DayPlanBlock.minimumDurationMinutes...maximumDuration(startMinute: startMinute)
    }

    static func awayDurationRange(
        for option: DayPlanAwayLogOption,
        startMinute: Int
    ) -> ClosedRange<Int> {
        guard !option.isSleep else { return 5...(16 * 60) }
        return 5...max(5, maximumDuration(startMinute: startMinute))
    }

    static func awayDurationPresets(for option: DayPlanAwayLogOption) -> [Int] {
        option.isSleep
            ? [30, 60, 120, 240, 360, 480]
            : [10, 15, 20, 30, 45, 60]
    }

    static func clampedTaskDuration(_ durationMinutes: Int, startMinute: Int) -> Int {
        DayPlanBlock.clampedDuration(
            durationMinutes,
            startMinute: startMinute,
            minimumDurationMinutes: DayPlanBlock.minimumDurationMinutes
        )
    }

    static func clampedAwayDuration(
        _ durationMinutes: Int,
        option: DayPlanAwayLogOption,
        startMinute: Int
    ) -> Int {
        if option.isSleep {
            return min(max(durationMinutes, 5), 16 * 60)
        }
        return DayPlanBlock.clampedDuration(
            durationMinutes,
            startMinute: startMinute,
            minimumDurationMinutes: 5
        )
    }

    static func intervalTitle(
        date: Date,
        startMinute: Int,
        durationMinutes: Int,
        calendar: Calendar
    ) -> String {
        guard
            let startedAt = calendar.date(
                byAdding: .minute,
                value: startMinute,
                to: calendar.startOfDay(for: date)
            ),
            let endedAt = calendar.date(byAdding: .minute, value: durationMinutes, to: startedAt)
        else {
            return
                "\(DayPlanFormatting.timeText(for: startMinute, on: date, calendar: calendar)) - \(DayPlanFormatting.timeText(for: startMinute + durationMinutes, on: date, calendar: calendar))"
        }

        return "\(timeText(startedAt)) - \(endTimeText(endedAt, relativeTo: startedAt, calendar: calendar))"
    }

    private static func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private static func maximumDuration(startMinute: Int) -> Int {
        max(
            DayPlanBlock.minimumDurationMinutes,
            DayPlanBlock.minutesPerDay - startMinute
        )
    }

    private static func endTimeText(
        _ endDate: Date,
        relativeTo startDate: Date,
        calendar: Calendar
    ) -> String {
        if calendar.isDate(endDate, inSameDayAs: startDate) {
            return timeText(endDate)
        }
        return endDate.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}

extension AwaySessionPreset {
    var dayPlanTint: Color {
        switch self {
        case .wake:
            return .orange
        case .reset:
            return .teal
        case .outside:
            return .green
        case .windDown:
            return .indigo
        case .meal:
            return .pink
        case .custom:
            return .cyan
        }
    }
}
