import SwiftUI

struct HomeMacCalendarFiltersDetailView: View {
    @State private var selectedTab: HomeMacCalendarFilterDetailTab = .filter
    @Binding var filters: DayPlanCalendarFilterState
    let availability: DayPlanCalendarFilterAvailability
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowTimelineTasksInDayPlanner.rawValue,
        store: SharedDefaults.app
    ) private var timelineSuggestionsAvailable = true
    @AppStorage(
        UserDefaultStringValueKey.appSettingDayPlanCalendarListRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) private var calendarListRowHiddenFieldsRawValue = ""

    private var currentFilters: DayPlanCalendarFilterState {
        filters
    }

    var body: some View {
        Group {
            tabPicker

            switch selectedTab {
            case .filter:
                filterTabContent
            case .appearance:
                appearanceTabContent
            }
        }
    }

    private var tabPicker: some View {
        HomeMacCalendarFilterDetailTabStrip(selection: $selectedTab)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var filterTabContent: some View {
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

    private var appearanceTabContent: some View {
        HomeMacSidebarSectionCard(title: "Calendar Task Row") {
            ForEach(DayPlanCalendarListRowField.allCases) { field in
                Toggle(isOn: rowFieldVisibilityBinding(field)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(field.title)
                        Text(field.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }

            Text("Shown: \(calendarListRowVisibility.summaryText)")
                .font(.footnote)
                .foregroundStyle(.secondary)
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

    private var calendarListRowVisibility: DayPlanCalendarListRowVisibility {
        DayPlanCalendarListRowVisibility(
            storageRawValue: calendarListRowHiddenFieldsRawValue
        )
    }

    private func rowFieldVisibilityBinding(
        _ field: DayPlanCalendarListRowField
    ) -> Binding<Bool> {
        Binding(
            get: {
                calendarListRowVisibility.shows(field)
            },
            set: { isVisible in
                let updatedVisibility = calendarListRowVisibility.setting(
                    field,
                    visible: isVisible
                )
                calendarListRowHiddenFieldsRawValue = updatedVisibility.storageRawValue ?? ""
                AppSettingsPersistenceMirror.schedule()
            }
        )
    }
}

private struct HomeMacCalendarFilterDetailTabStrip: View {
    @Binding var selection: HomeMacCalendarFilterDetailTab
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 5) {
            HStack(spacing: 5) {
                ForEach(HomeMacCalendarFilterDetailTab.allCases) { tab in
                    segmentButton(for: tab)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(5)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Calendar tabs")
    }

    private func segmentButton(for tab: HomeMacCalendarFilterDetailTab) -> some View {
        let isSelected = selection == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = tab
            }
        } label: {
            Text(tab.title)
                .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .glassEffect(
                        .regular.tint(Color.accentColor.opacity(0.34)).interactive(),
                        in: .rect(cornerRadius: 11)
                    )
                    .glassEffectID("HomeMacCalendarFilterDetailTabSelection", in: glassNamespace)
            }
        }
        .accessibilityLabel(tab.title)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

private enum HomeMacCalendarFilterDetailTab: String, CaseIterable, Identifiable {
    case filter
    case appearance

    var id: Self { self }

    var title: String {
        switch self {
        case .filter:
            return "Filter"
        case .appearance:
            return "Appearance"
        }
    }
}
