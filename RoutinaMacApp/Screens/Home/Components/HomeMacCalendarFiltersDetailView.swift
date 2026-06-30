import SwiftUI

struct HomeMacCalendarFiltersDetailView: View {
    @Binding var filters: DayPlanCalendarFilterState
    let availability: DayPlanCalendarFilterAvailability
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowTimelineTasksInDayPlanner.rawValue,
        store: SharedDefaults.app
    ) private var timelineSuggestionsAvailable = true

    private var currentFilters: DayPlanCalendarFilterState {
        filters
    }

    var body: some View {
        HomeMacSidebarSectionCard(title: "Calendar Layers") {
            VStack(alignment: .leading, spacing: 12) {
                Text(currentFilters.summaryText(availability: availability))
                    .font(.caption)
                    .foregroundStyle(.secondary)

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
                    filters.reset()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!currentFilters.hasActiveFilters(availability: availability))
            }
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
                    .background {
                        Circle()
                            .fill((isEnabled ? Color.accentColor : Color.secondary).opacity(0.12))
                    }

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
                filters[keyPath: keyPath]
            },
            set: { isEnabled in
                filters[keyPath: keyPath] = isEnabled
            }
        )
    }

    private var timelineSuggestionsBinding: Binding<Bool> {
        Binding(
            get: {
                timelineSuggestionsAvailable && filters.showsTimelineSuggestions
            },
            set: { isEnabled in
                filters.showsTimelineSuggestions = isEnabled
            }
        )
    }
}
