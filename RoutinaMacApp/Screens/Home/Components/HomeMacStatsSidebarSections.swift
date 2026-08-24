import SwiftUI

struct HomeMacStatsQuerySection: View {
    @Binding var advancedQuery: String
    let queryOptions: HomeAdvancedQueryOptions

    var body: some View {
        HomeMacCollapsibleFilterSection(
            title: "Query",
            summaryText: summaryText,
            systemImage: "line.3.horizontal.decrease.circle",
            tint: .cyan
        ) {
            HomeAdvancedQueryBuilder(
                query: $advancedQuery,
                usesFlowLayout: true,
                options: queryOptions
            )
        }
    }

    private var summaryText: String {
        let trimmedQuery = advancedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedQuery.isEmpty ? "No query filter." : trimmedQuery
    }
}

struct HomeMacStatsTaskTypeSection: View {
    let selectedTaskTypeFilter: StatsTaskTypeFilter
    let onSelectTaskTypeFilter: (StatsTaskTypeFilter) -> Void
    @Binding var isExpanded: Bool
    let onSelectionComplete: () -> Void

    var body: some View {
        HomeMacCollapsibleFilterSection(
            title: "Show",
            summaryText: selectedTaskTypeFilter.title,
            systemImage: selectedTaskTypeFilter.macSidebarIconName,
            tint: .blue,
            isExpanded: $isExpanded
        ) {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Stats task type",
                options: StatsTaskTypeFilter.allCases,
                selection: selectedTaskTypeFilter,
                onSelect: { filter in
                    onSelectTaskTypeFilter(filter)
                    onSelectionComplete()
                },
                minimumSegmentWidth: 92,
                horizontalPadding: 10,
                fillsAvailableWidth: true,
                maximumSegmentsPerRow: 2
            ) { filter in
                Label(filter.title, systemImage: filter.macSidebarIconName)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HomeMacStatsDashboardScopeSection: View {
    let selectedDashboardScope: StatsDashboardScope
    let availableDashboardScopes: [StatsDashboardScope]
    let onSelectDashboardScope: (StatsDashboardScope) -> Void
    @Binding var isExpanded: Bool
    let onSelectionComplete: () -> Void

    var body: some View {
        HomeMacCollapsibleFilterSection(
            title: "Scope",
            summaryText: selectedDashboardScope.title,
            systemImage: selectedDashboardScope.macSidebarIconName,
            tint: .blue,
            isExpanded: $isExpanded
        ) {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: "Stats scope",
                options: availableDashboardScopes,
                selection: selectedDashboardScope,
                onSelect: { scope in
                    onSelectDashboardScope(scope)
                    onSelectionComplete()
                },
                minimumSegmentWidth: 92
            ) { scope in
                Label(scope.title, systemImage: scope.macSidebarIconName)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HomeMacStatsRangeSection: View {
    let selectedRange: DoneChartRange
    let onSelectRange: (DoneChartRange) -> Void
    @Binding var isExpanded: Bool
    let onPresetSelectionComplete: () -> Void
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var customEnd = Date()

    var body: some View {
        HomeMacCollapsibleFilterSection(
            title: "Time Range",
            summaryText: selectedRangeSummary,
            systemImage: selectedRange.macSidebarIconName,
            tint: .blue,
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Stats time range",
                    options: DoneChartRange.allCases,
                    selection: selectedRange,
                    onSelect: { range in
                        onSelectRange(range)
                        onPresetSelectionComplete()
                    },
                    minimumSegmentWidth: 112,
                    horizontalPadding: 10,
                    fillsAvailableWidth: true,
                    maximumSegmentsPerRow: 2
                ) { range in
                    Label(range.rawValue, systemImage: range.macSidebarIconName)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    onSelectRange(.custom(from: customStart, through: customEnd))
                } label: {
                    Label(
                        selectedRange.kind == .custom ? selectedRange.periodDescription : "Custom range",
                        systemImage: "calendar.badge.plus"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if selectedRange.kind == .custom {
                    DatePicker("From", selection: $customStart, in: ...customEnd, displayedComponents: .date)
                        .onChange(of: customStart) { _, _ in applyCustomDates() }
                    DatePicker("Through", selection: $customEnd, in: customStart..., displayedComponents: .date)
                        .onChange(of: customEnd) { _, _ in applyCustomDates() }
                }
            }
        }
        .onAppear(perform: syncCustomDates)
        .onChange(of: selectedRange) { _, _ in syncCustomDates() }
    }

    private var selectedRangeSummary: String {
        selectedRange.kind == .custom ? selectedRange.periodDescription : selectedRange.rawValue
    }

    private func applyCustomDates() {
        onSelectRange(.custom(from: customStart, through: customEnd))
    }

    private func syncCustomDates() {
        guard selectedRange.kind == .custom else { return }
        customStart = selectedRange.customStart ?? customStart
        customEnd = selectedRange.customEnd ?? customEnd
    }
}

struct HomeMacStatsImportanceFilterSection: View {
    @Binding var selectedFilter: ImportanceUrgencyFilterCell?
    @Binding var isExpanded: Bool
    let onSelectionComplete: () -> Void

    var body: some View {
        HomeMacCollapsibleFilterSection(
            title: "Importance",
            summaryText: minimumImportance.map { "\($0.title)+" } ?? "All",
            systemImage: "star.fill",
            tint: .orange,
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Minimum importance",
                    options: importanceOptions,
                    selection: minimumImportance,
                    onSelect: { importance in
                        minimumImportanceBinding.wrappedValue = importance
                        onSelectionComplete()
                    },
                    horizontalPadding: 10,
                    verticalPadding: 8,
                    fillsAvailableWidth: true,
                    maximumSegmentsPerRow: 2
                ) { importance in
                    Text(importance.map { "\($0.title)+" } ?? "All")
                }

                Text("All includes every importance level. Other choices set the minimum importance a task must have.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var importanceOptions: [RoutineTaskImportance?] {
        [nil] + RoutineTaskImportance.allCases.dropFirst().map(Optional.some)
    }

    private var minimumImportance: RoutineTaskImportance? {
        selectedFilter?.minimumImportance
    }

    private var minimumImportanceBinding: Binding<RoutineTaskImportance?> {
        Binding(
            get: { minimumImportance },
            set: {
                selectedFilter = ImportanceUrgencyFilterCell.updatingMinimumImportance(
                    $0,
                    in: selectedFilter
                )
            }
        )
    }
}

struct HomeMacStatsUrgencyFilterSection: View {
    @Binding var selectedFilter: ImportanceUrgencyFilterCell?
    @Binding var isExpanded: Bool
    let onSelectionComplete: () -> Void

    var body: some View {
        HomeMacCollapsibleFilterSection(
            title: "Urgency",
            summaryText: minimumUrgency.map { "\($0.title)+" } ?? "All",
            systemImage: "clock.badge.exclamationmark",
            tint: .red,
            isExpanded: $isExpanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Minimum urgency",
                    options: urgencyOptions,
                    selection: minimumUrgency,
                    onSelect: { urgency in
                        minimumUrgencyBinding.wrappedValue = urgency
                        onSelectionComplete()
                    },
                    horizontalPadding: 10,
                    verticalPadding: 8,
                    fillsAvailableWidth: true,
                    maximumSegmentsPerRow: 2
                ) { urgency in
                    Text(urgency.map { "\($0.title)+" } ?? "All")
                }

                Text("All includes every urgency level. Other choices set the minimum urgency a task must have.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var urgencyOptions: [RoutineTaskUrgency?] {
        [nil] + RoutineTaskUrgency.allCases.dropFirst().map(Optional.some)
    }

    private var minimumUrgency: RoutineTaskUrgency? {
        selectedFilter?.minimumUrgency
    }

    private var minimumUrgencyBinding: Binding<RoutineTaskUrgency?> {
        Binding(
            get: { minimumUrgency },
            set: {
                selectedFilter = ImportanceUrgencyFilterCell.updatingMinimumUrgency(
                    $0,
                    in: selectedFilter
                )
            }
        )
    }
}

struct HomeMacStatsSectionTitle: View {
    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }
}

private extension StatsTaskTypeFilter {
    var macSidebarIconName: String {
        switch self {
        case .all:
            return "square.grid.2x2"
        case .routines:
            return "repeat"
        case .todos:
            return "checklist"
        }
    }
}

private extension DoneChartRange {
    var macSidebarIconName: String {
        switch kind {
        case .today:
            return "calendar.badge.checkmark"
        case .week:
            return "calendar.badge.clock"
        case .month:
            return "calendar"
        case .year:
            return "calendar.badge.plus"
        case .custom:
            return "calendar.badge.plus"
        }
    }
}

private extension StatsDashboardScope {
    var macSidebarIconName: String {
        switch self {
        case .all:
            return "chart.bar"
        case .focus:
            return "timer"
        case .sleep:
            return "bed.double.fill"
        case .wins:
            return "trophy"
        case .achievements:
            return "medal"
        }
    }
}
