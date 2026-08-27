import SwiftUI

struct HomeMacStatsInlinePickerSection<PickerContent: View, DetailContent: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let picker: () -> PickerContent
    @ViewBuilder let detail: () -> DetailContent

    init(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder picker: @escaping () -> PickerContent,
        @ViewBuilder detail: @escaping () -> DetailContent
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.picker = picker
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(tint.opacity(0.16))
                    )

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                picker()
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .controlSize(.large)
                    .frame(width: 124)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)

            detail()
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .routinaGlassPanel(
            cornerRadius: 18,
            tint: tint,
            tintOpacity: 0.08
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

extension HomeMacStatsInlinePickerSection where DetailContent == EmptyView {
    init(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder picker: @escaping () -> PickerContent
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            tint: tint,
            picker: picker,
            detail: { EmptyView() }
        )
    }
}

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

    var body: some View {
        HomeMacStatsInlinePickerSection(
            title: "Show",
            systemImage: selectedTaskTypeFilter.macSidebarIconName,
            tint: .blue
        ) {
            Picker("Stats task type", selection: selectionBinding) {
                ForEach(StatsTaskTypeFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
        }
    }

    private var selectionBinding: Binding<StatsTaskTypeFilter> {
        Binding(
            get: { selectedTaskTypeFilter },
            set: { filter in
                onSelectTaskTypeFilter(filter)
            }
        )
    }
}

struct HomeMacStatsDashboardScopeSection: View {
    let selectedDashboardScope: StatsDashboardScope
    let availableDashboardScopes: [StatsDashboardScope]
    let onSelectDashboardScope: (StatsDashboardScope) -> Void

    var body: some View {
        HomeMacStatsInlinePickerSection(
            title: "Scope",
            systemImage: selectedDashboardScope.macSidebarIconName,
            tint: .blue
        ) {
            Picker("Stats scope", selection: selectionBinding) {
                ForEach(availableDashboardScopes) { scope in
                    Text(scope.title).tag(scope)
                }
            }
        }
    }

    private var selectionBinding: Binding<StatsDashboardScope> {
        Binding(
            get: { selectedDashboardScope },
            set: { scope in
                onSelectDashboardScope(scope)
            }
        )
    }
}

struct HomeMacStatsRangeSection: View {
    let selectedRange: DoneChartRange
    let onSelectRange: (DoneChartRange) -> Void
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var customEnd = Date()

    var body: some View {
        HomeMacStatsInlinePickerSection(
            title: "Time Range",
            systemImage: selectedRange.macSidebarIconName,
            tint: .blue
        ) {
            Picker("Stats time range", selection: rangeKindBinding) {
                ForEach(DoneChartRange.allCases) { range in
                    Text(range.rawValue).tag(range.kind.rawValue)
                }
                Divider()
                Text("Custom…").tag(DoneChartRange.Kind.custom.rawValue)
            }
        } detail: {
            if selectedRange.kind == .custom {
                VStack(alignment: .leading, spacing: 12) {
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

    private var rangeKindBinding: Binding<String> {
        Binding(
            get: { selectedRange.kind.rawValue },
            set: { rawValue in
                selectRangeKind(rawValue)
            }
        )
    }

    private func selectRangeKind(_ rawValue: String) {
        if rawValue == DoneChartRange.Kind.custom.rawValue {
            onSelectRange(.custom(from: customStart, through: customEnd))
            return
        }

        guard let range = DoneChartRange.allCases.first(where: { $0.kind.rawValue == rawValue }) else {
            return
        }
        onSelectRange(range)
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

    var body: some View {
        HomeMacStatsInlinePickerSection(
            title: "Importance",
            systemImage: "star.fill",
            tint: .orange
        ) {
            Picker("Minimum importance", selection: minimumImportanceBinding) {
                ForEach(importanceOptions, id: \.self) { importance in
                    Text(importance.map { "\($0.title)+" } ?? "All").tag(importance)
                }
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

    var body: some View {
        HomeMacStatsInlinePickerSection(
            title: "Urgency",
            systemImage: "clock.badge.exclamationmark",
            tint: .red
        ) {
            Picker("Minimum urgency", selection: minimumUrgencyBinding) {
                ForEach(urgencyOptions, id: \.self) { urgency in
                    Text(urgency.map { "\($0.title)+" } ?? "All").tag(urgency)
                }
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
