import SwiftData
import SwiftUI

struct DayPlanCalendarFilterSidebar: View {
    let filters: Binding<DayPlanCalendarFilterState>
    let availability: DayPlanCalendarFilterAvailability
    let timelineSuggestionsAvailable: Bool
    let onDismiss: () -> Void

    private var currentFilters: DayPlanCalendarFilterState {
        filters.wrappedValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            VStack(alignment: .leading, spacing: 10) {
                filterToggle(
                    title: "Planned tasks",
                    systemImage: "checklist",
                    isOn: filterBinding(\.showsPlannedTasks)
                )
                filterToggle(
                    title: "All-day tasks",
                    systemImage: "calendar.badge.clock",
                    isOn: filterBinding(\.showsAllDayTasks)
                )
                filterToggle(
                    title: "Timeline suggestions",
                    systemImage: "clock.arrow.circlepath",
                    isOn: timelineSuggestionsBinding,
                    subtitle: timelineSuggestionsAvailable ? nil : "Off in Settings",
                    isEnabled: timelineSuggestionsAvailable
                )
                filterToggle(
                    title: "Assumed done",
                    systemImage: "checkmark.circle",
                    isOn: filterBinding(\.showsAssumedDone)
                )
                if availability.includesEvents {
                    filterToggle(
                        title: "Events",
                        systemImage: "calendar",
                        isOn: filterBinding(\.showsEvents)
                    )
                }
                filterToggle(
                    title: "Focus",
                    systemImage: "timer",
                    isOn: filterBinding(\.showsFocus)
                )
                if availability.includesAway {
                    filterToggle(
                        title: "Away",
                        systemImage: "figure.walk",
                        isOn: filterBinding(\.showsAway)
                    )
                }
                if availability.includesSleep {
                    filterToggle(
                        title: "Sleep",
                        systemImage: "bed.double",
                        isOn: filterBinding(\.showsSleep)
                    )
                }
            }

            Button {
                filters.wrappedValue.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!currentFilters.hasActiveFilters(availability: availability))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Calendar Filters")
                    .font(.headline.weight(.semibold))
                Text(currentFilters.summaryText(availability: availability))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Close")
            .contentShape(Circle())
        }
    }

    private func filterToggle(
        title: String,
        systemImage: String,
        isOn: Binding<Bool>,
        subtitle: String? = nil,
        isEnabled: Bool = true
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill((isEnabled ? Color.accentColor : Color.secondary).opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .toggleStyle(.switch)
        .disabled(!isEnabled)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.055))
        }
    }

    private func filterBinding(
        _ keyPath: WritableKeyPath<DayPlanCalendarFilterState, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: {
                filters.wrappedValue[keyPath: keyPath]
            },
            set: { isEnabled in
                filters.wrappedValue[keyPath: keyPath] = isEnabled
            }
        )
    }

    private var timelineSuggestionsBinding: Binding<Bool> {
        Binding(
            get: {
                timelineSuggestionsAvailable && filters.wrappedValue.showsTimelineSuggestions
            },
            set: { isEnabled in
                filters.wrappedValue.showsTimelineSuggestions = isEnabled
            }
        )
    }
}

struct DayPlanDayTaskListSidebar: View {
    let date: Date
    let items: [DayPlanDayTaskListItem]
    let taskTint: (UUID) -> Color
    let calendar: Calendar
    let isTaskOpenable: (UUID) -> Bool
    let onConfirmAssumedDayTask: (DayPlanDayTaskListItem, Date) -> Void
    let onMarkAssumedDayTaskMissed: (DayPlanDayTaskListItem, Date) -> Void
    let onOpenTaskDetails: (DayPlanDayTaskListItem, Date) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if items.isEmpty {
                ContentUnavailableView(
                    "No day tasks",
                    systemImage: "list.bullet.rectangle",
                    description: Text("No planned, assumed done, or done tasks for this day.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                DayPlanDayTaskListContentView(
                    items: items,
                    taskTint: taskTint,
                    date: date,
                    calendar: calendar,
                    isTaskOpenable: isTaskOpenable,
                    onOpenTaskDetails: onOpenTaskDetails,
                    onConfirmAssumedDayTask: onConfirmAssumedDayTask,
                    onMarkAssumedDayTaskMissed: onMarkAssumedDayTaskMissed,
                    onDragProvider: { item in
                        NSItemProvider(object: item.taskID.uuidString as NSString)
                    }
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Day Tasks")
                    .font(.headline.weight(.semibold))
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Close")
            .contentShape(Circle())
        }
    }

    private var headerSubtitle: String {
        let countText = taskCountText(items.count)
        let dateText = date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return "\(dateText) - \(countText)"
    }

    private func taskCountText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "task" : "tasks")"
    }
}

enum DayPlanAwayLogOption: Hashable, Identifiable {
    case away(AwaySessionPreset)
    case sleep

    static let options: [DayPlanAwayLogOption] = AwaySessionPreset.allCases.map(DayPlanAwayLogOption.away) + [.sleep]

    static func options(includingAway: Bool) -> [DayPlanAwayLogOption] {
        includingAway ? options : []
    }

    var id: String {
        switch self {
        case let .away(preset):
            return preset.rawValue
        case .sleep:
            return "sleep"
        }
    }

    var awayPreset: AwaySessionPreset? {
        guard case let .away(preset) = self else { return nil }
        return preset
    }

    var isSleep: Bool {
        self == .sleep
    }

    var title: String {
        switch self {
        case let .away(preset):
            return preset.title
        case .sleep:
            return "Sleep"
        }
    }

    var systemImage: String {
        switch self {
        case let .away(preset):
            return preset.systemImage
        case .sleep:
            return "bed.double.fill"
        }
    }

    var tint: Color {
        switch self {
        case let .away(preset):
            return preset.dayPlanTint
        case .sleep:
            return .orange
        }
    }

    var defaultDurationMinutes: Int {
        switch self {
        case let .away(preset):
            return preset.defaultDurationMinutes
        case .sleep:
            return 8 * 60
        }
    }

    var subtitle: String {
        switch self {
        case let .away(preset):
            return "\(preset.defaultDurationMinutes)m"
        case .sleep:
            return "8h"
        }
    }

    var durationTitle: String {
        isSleep ? "Sleep duration" : "Duration"
    }

    var logActionTitle: String {
        isSleep ? "Log Sleep" : "Log Away"
    }

    var logActionSystemImage: String {
        isSleep ? "bed.double.fill" : "lock.shield.fill"
    }

    var finishedIntervalMessage: String {
        isSleep ? "Sleep logs are for finished intervals." : "Away logs are for finished intervals."
    }
}
