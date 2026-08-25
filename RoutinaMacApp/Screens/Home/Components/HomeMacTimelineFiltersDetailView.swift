import SwiftUI

struct HomeMacTimelineFiltersDetailView: View {
    @State private var selectedTab: HomeMacTimelineFilterDetailTab = .filter

    @Binding var selectedType: TimelineFilterType
    @Binding var selectedStatus: TimelineStatusFilter
    @Binding var selectedMediaFilter: TaskMediaFilter
    @Binding var selectedFlags: Set<String>
    @Binding var includeFlagMatchMode: RoutineTagMatchMode
    let availableFlags: [String]
    let timelineRowVisibility: HomeTimelineRowVisibility
    let showsTypeSection: Bool
    let onTimelineRowFieldVisibilityChanged: (HomeTimelineRowField, Bool) -> Void
    let includesEventEmotionFilters: Bool
    let includesPlaceFilters: Bool
    let includesNoteFilters: Bool
    let includesAwayFilters: Bool
    let includesSleepFilters: Bool

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
        HomeMacTimelineFilterDetailTabStrip(selection: $selectedTab)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var filterTabContent: some View {
        Group {
            HomeMacSidebarSectionCard {
                VStack(alignment: .leading, spacing: 18) {
                    if showsTypeSection {
                        filterControlSection("Type") {
                            typePicker
                        }

                        filterControlSection("Status") {
                            statusPicker
                        }
                    }

                    filterControlSection("Media") {
                        mediaPicker
                    }
                }
            }

            if !availableFlags.isEmpty || !selectedFlags.isEmpty {
                HomeMacTimelineFlagFiltersView(
                    availableFlags: availableFlags,
                    selectedFlags: $selectedFlags,
                    includeFlagMatchMode: $includeFlagMatchMode
                )
            }
        }
    }

    private var appearanceTabContent: some View {
        HomeMacSidebarSectionCard(title: "Timeline Row") {
            ForEach(HomeTimelineRowField.allCases) { field in
                Toggle(isOn: timelineRowFieldVisibilityBinding(field)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(field.title)
                        Text(field.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }

            Text("Shown: \(macTimelineRowSummaryText)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func filterControlSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
        }
    }

    private var typePicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Type",
            options: TimelineFilterType.visibleContentTypeCases(
                includingEventEmotion: includesEventEmotionFilters,
                includingPlaces: includesPlaceFilters,
                includingNotes: includesNoteFilters,
                includingAway: includesAwayFilters,
                includingSleep: includesSleepFilters
            ),
            selection: $selectedType
        ) { type in
            Text(type.title)
        }
    }

    private var statusPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Status",
            options: TimelineStatusFilter.allCases,
            selection: $selectedStatus
        ) { status in
            Text(status.title)
        }
    }

    private var mediaPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Media",
            options: TaskMediaFilter.allCases,
            selection: $selectedMediaFilter
        ) { filter in
            Text(filter.title)
        }
    }

    private func timelineRowFieldVisibilityBinding(_ field: HomeTimelineRowField) -> Binding<Bool> {
        Binding(
            get: { timelineRowVisibility.shows(field) },
            set: { onTimelineRowFieldVisibilityChanged(field, $0) }
        )
    }

    private var macTimelineRowSummaryText: String {
        let hiddenCount = HomeTimelineRowField.allCases.filter {
            !timelineRowVisibility.shows($0)
        }.count
        guard hiddenCount > 0 else { return "All fields" }
        return "\(HomeTimelineRowField.allCases.count - hiddenCount) of \(HomeTimelineRowField.allCases.count) fields"
    }
}

private struct HomeMacTimelineFlagFiltersView: View {
    let availableFlags: [String]
    @Binding var selectedFlags: Set<String>
    @Binding var includeFlagMatchMode: RoutineTagMatchMode

    var body: some View {
        HomeMacCollapsibleFilterSection(
            title: "Flags",
            summaryText: summaryText,
            systemImage: "flag.fill",
            tint: .orange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Show activity with flags")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Show Timeline activity with flags",
                    options: RoutineTagMatchMode.allCases,
                    selection: $includeFlagMatchMode,
                    fillsAvailableWidth: true
                ) { mode in
                    Text(mode.rawValue)
                }

                WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                    if selectedFlags.isEmpty {
                        flagButton("Default Timeline", isSelected: true) {
                            selectedFlags = []
                        }
                    } else {
                        ForEach(sortedSelectedFlags, id: \.self) { flag in
                            flagButton(flag, isSelected: true) {
                                toggle(flag)
                            }
                        }
                    }
                }

                let unselectedFlags = availableFlags.filter {
                    !HomeFlagFilterMutationSupport.contains($0, in: selectedFlags)
                }
                if !unselectedFlags.isEmpty {
                    Text("Reveal by Flag")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(unselectedFlags, id: \.self) { flag in
                            flagButton(flag, isSelected: false) {
                                toggle(flag)
                            }
                        }
                    }
                }

                Text("Selecting a Flag reveals matching task activity, including activity hidden by that Flag's Timeline rule.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sortedSelectedFlags: [String] {
        selectedFlags.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    private var summaryText: String {
        guard !selectedFlags.isEmpty else {
            return "Default visibility · \(availableFlags.count) available"
        }
        return "\(includeFlagMatchMode.rawValue) \(selectedFlags.count) \(selectedFlags.count == 1 ? "Flag" : "Flags")"
    }

    private func toggle(_ flag: String) {
        selectedFlags = HomeFlagFilterMutationSupport.toggled(flag, in: selectedFlags)
    }

    private func flagButton(
        _ title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: isSelected ? "flag.fill" : "flag")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.orange : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .routinaGlassPill(
                    tint: .orange,
                    tintOpacity: isSelected ? 0.16 : 0.08,
                    interactive: true
                )
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct HomeMacTimelineFilterDetailTabStrip: View {
    @Binding var selection: HomeMacTimelineFilterDetailTab
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 5) {
            HStack(spacing: 5) {
                ForEach(HomeMacTimelineFilterDetailTab.allCases) { tab in
                    segmentButton(for: tab)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(5)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline tabs")
    }

    private func segmentButton(for tab: HomeMacTimelineFilterDetailTab) -> some View {
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
                    .glassEffectID("HomeMacTimelineFilterDetailTabSelection", in: glassNamespace)
            }
        }
        .accessibilityLabel(tab.title)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

private enum HomeMacTimelineFilterDetailTab: String, CaseIterable, Identifiable {
    case filter
    case appearance

    var id: Self { self }

    var title: String {
        switch self {
        case .filter: return "Filter"
        case .appearance: return "Appearance"
        }
    }
}
