import Charts
import ComposableArchitecture
import SwiftData
import SwiftUI

struct StatsViewWrapper: View {
    let store: StoreOf<StatsFeature>

    var body: some View {
        StatsView(store: store)
    }
}

struct StatsView: View {
    let store: StoreOf<StatsFeature>
    @Environment(\.calendar) private var calendar
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var logs: [RoutineLog]
    @Query private var tasks: [RoutineTask]
    @State private var relatedFilterTagSuggestionAnchor: String?

    fileprivate struct Metrics {
        let chartPoints: [DoneChartPoint]
        let totalDoneCount: Int
        let totalCanceledCount: Int
        let activeRoutineCount: Int
        let archivedRoutineCount: Int
        let totalCount: Int
        let averagePerDay: Double
        let highlightedBusiestDay: DoneChartPoint?
        let activeDayCount: Int
        let chartUpperBound: Double
        let sparklinePoints: [DoneChartPoint]
        let sparklineMaxCount: Int
        let xAxisDates: [Date]
    }

    private var selectedRange: DoneChartRange {
        store.selectedRange
    }

    private var selectedRangeBinding: Binding<DoneChartRange> {
        Binding(
            get: { store.selectedRange },
            set: { store.send(.selectedRangeChanged($0)) }
        )
    }

    private var filterSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isFilterSheetPresented },
            set: { store.send(.setFilterSheet($0)) }
        )
    }

    private var taskTypeFilterBinding: Binding<StatsTaskTypeFilter> {
        Binding(
            get: { store.taskTypeFilter },
            set: { store.send(.taskTypeFilterChanged($0)) }
        )
    }

    private var metrics: Metrics {
        Metrics(store.metrics)
    }

    private var availableTags: [String] {
        store.availableTags
    }

    private var suggestedRelatedFilterTags: [String] {
        let selectedTags = store.effectiveSelectedTags
        guard !selectedTags.isEmpty else { return [] }
        let suggestionSource = relatedFilterTagSuggestionAnchor.map { [$0] } ?? Array(selectedTags)
        return RoutineTagRelations.relatedTags(
            for: suggestionSource,
            rules: store.relatedTagRules,
            availableTags: availableTags
        )
    }

    private var selectedTaskTypeFilter: StatsTaskTypeFilter {
        store.taskTypeFilter
    }

    private var availableExcludeTags: [String] {
        let baseTasks = store.tasks.filter { task in
            switch selectedTaskTypeFilter {
            case .all:
                return true
            case .routines:
                return !task.isOneOffTask
            case .todos:
                return task.isOneOffTask
            }
        }.filter { task in
            HomeFeature.matchesImportanceUrgencyFilter(
                store.selectedImportanceUrgencyFilter,
                importance: task.importance,
                urgency: task.urgency
            )
        }.filter { task in
            HomeFeature.matchesSelectedTags(
                store.effectiveSelectedTags,
                mode: store.includeTagMatchMode,
                in: task.tags
            )
        }

        return RoutineTag.allTags(from: baseTasks.map(\.tags)).filter { tag in
            !store.effectiveSelectedTags.contains { RoutineTag.contains($0, in: [tag]) }
        }
    }

    private var hasActiveFilters: Bool {
        store.hasActiveFilters
    }

    private var hasActiveSheetFilters: Bool {
        selectedTaskTypeFilter != .all || !store.effectiveSelectedTags.isEmpty || !store.excludedTags.isEmpty || store.selectedImportanceUrgencyFilter != nil
    }

    private var activeSheetFilterCount: Int {
        var count = 0
        if selectedTaskTypeFilter != .all { count += 1 }
        if !store.effectiveSelectedTags.isEmpty { count += 1 }
        count += store.excludedTags.count
        if store.selectedImportanceUrgencyFilter != nil { count += 1 }
        return count
    }

    private func isIncludedTagSelected(_ tag: String) -> Bool {
        store.effectiveSelectedTags.contains { RoutineTag.contains($0, in: [tag]) }
    }

    private func toggleIncludedTag(_ tag: String) {
        var selected = store.effectiveSelectedTags
        if selected.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
            selected = selected.filter { !RoutineTag.contains($0, in: [tag]) }
        } else {
            selected.insert(tag)
            relatedFilterTagSuggestionAnchor = tag
        }
        store.send(.selectedTagsChanged(selected))
        if selected.isEmpty {
            relatedFilterTagSuggestionAnchor = nil
        }
    }

    private func addIncludedTag(_ tag: String) {
        guard !isIncludedTagSelected(tag) else { return }
        var selected = store.effectiveSelectedTags
        selected.insert(tag)
        store.send(.selectedTagsChanged(selected))
    }

    private func toggleExcludedTag(_ tag: String) {
        var excluded = store.excludedTags
        if excluded.contains(where: { RoutineTag.contains($0, in: [tag]) }) {
            excluded = excluded.filter { !RoutineTag.contains($0, in: [tag]) }
        } else {
            excluded.insert(tag)
            var selected = store.effectiveSelectedTags
            selected = selected.filter { !RoutineTag.contains($0, in: [tag]) }
            store.send(.selectedTagsChanged(selected))
        }
        store.send(.excludedTagsChanged(excluded))
    }

    private var filteredTaskCount: Int {
        store.filteredTaskCount
    }

    private var gitHubConnection: GitHubConnectionStatus {
        store.gitHubConnection
    }

    private var gitHubStats: GitHubStatsSnapshot? {
        store.gitHubStats
    }

    private var isGitHubStatsLoading: Bool {
        store.isGitHubStatsLoading
    }

    private var gitHubStatsErrorMessage: String? {
        store.gitHubStatsErrorMessage
    }

    private var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.04)
                ]
                : [
                    Color.white.opacity(0.98),
                    Color.white.opacity(0.88)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.accentColor.opacity(0.95),
                    Color.blue.opacity(0.7),
                    Color.black.opacity(0.92)
                ]
                : [
                    Color.accentColor.opacity(0.9),
                    Color.blue.opacity(0.6),
                    Color.white.opacity(0.96)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var pageBackground: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.black,
                    Color(red: 0.05, green: 0.07, blue: 0.11),
                    Color.black
                ]
                : [
                    Color(red: 0.96, green: 0.97, blue: 0.99),
                    Color.white,
                    Color(red: 0.93, green: 0.96, blue: 0.99)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var selectorBackground: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color.white.opacity(0.06),
                    Color.white.opacity(0.03)
                ]
                : [
                    Color.white.opacity(0.96),
                    Color.white.opacity(0.82)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var selectorActiveFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.95),
                Color.blue.opacity(0.75)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var baseBarFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(colorScheme == .dark ? 0.75 : 0.6),
                Color.blue.opacity(colorScheme == .dark ? 0.55 : 0.45)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var selectorOutlineOpacity: Double {
        colorScheme == .dark ? 0.08 : 0.45
    }

    private var highlightBarFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.orange.opacity(0.95),
                Color.yellow.opacity(0.8)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        rangeSection
                        if hasActiveSheetFilters {
                            activeFilterChipBar
                        }
                        heroSection(metrics: metrics)
                        summaryCards(metrics: metrics)
                        if store.isGitFeaturesEnabled {
                            gitHubSection
                        }
                        chartSection(metrics: metrics)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, contentBottomPadding)
                    .frame(maxWidth: statsContentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .background(pageBackground.ignoresSafeArea())
                .navigationTitle("Stats")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        filterSheetButton
                    }
                }
                .sheet(isPresented: filterSheetBinding) {
                    statsFiltersSheet
                }
            }
            .task {
                store.send(.onAppear)
                store.send(.setData(tasks: tasks, logs: logs))
            }
            .onChange(of: tasks) { _, newValue in
                store.send(.setData(tasks: newValue, logs: logs))
            }
            .onChange(of: logs) { _, newValue in
                store.send(.setData(tasks: tasks, logs: newValue))
            }
        }
    }

    @ViewBuilder
    private var activeFilterChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("Clear All") {
                    store.send(.clearFilters)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                if selectedTaskTypeFilter != .all {
                    compactFilterChip(
                        title: selectedTaskTypeFilter.rawValue,
                        systemImage: statsTaskTypeIcon(for: selectedTaskTypeFilter)
                    ) {
                        store.send(.taskTypeFilterChanged(.all))
                    }
                }

                ForEach(store.effectiveSelectedTags.sorted(), id: \.self) { tag in
                    compactFilterChip(title: "#\(tag)") {
                        var selected = store.effectiveSelectedTags
                        selected = selected.filter { !RoutineTag.contains($0, in: [tag]) }
                        store.send(.selectedTagsChanged(selected))
                    }
                }

                if let selectedImportanceUrgencyFilterLabel {
                    compactFilterChip(title: selectedImportanceUrgencyFilterLabel) {
                        store.send(.selectedImportanceUrgencyFilterChanged(nil))
                    }
                }

                ForEach(store.excludedTags.sorted(), id: \.self) { tag in
                    compactFilterChip(title: "not #\(tag)", tintColor: .red) {
                        store.send(.excludedTagsChanged(store.excludedTags.filter { $0 != tag }))
                    }
                }
            }
        }
    }

    private func compactFilterChip(
        title: String,
        systemImage: String? = nil,
        tintColor: Color = .secondary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2)
                }

                Text(title)
                    .font(.caption.weight(.medium))

                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .foregroundStyle(tintColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tintColor.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    private var filterSheetButton: some View {
        Button {
            store.send(.setFilterSheet(true))
        } label: {
            Image(
                systemName: hasActiveFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .foregroundStyle(hasActiveFilters ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filters")
    }

    private var statsFiltersSheet: some View {
        NavigationStack {
            List {
                if tasks.contains(where: \.isOneOffTask) {
                    Section("Type") {
                        Picker("Type", selection: taskTypeFilterBinding) {
                            ForEach(StatsTaskTypeFilter.allCases) { filter in
                                Label(filter.rawValue, systemImage: statsTaskTypeIcon(for: filter))
                                    .tag(filter)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                }

                Section("Importance & Urgency") {
                    Button(store.selectedImportanceUrgencyFilter == nil ? "All levels selected" : "Show all levels") {
                        store.send(.selectedImportanceUrgencyFilterChanged(nil))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(store.selectedImportanceUrgencyFilter == nil ? Color.accentColor : Color.primary)

                    ImportanceUrgencyMatrixPicker(
                        selectedFilter: Binding(
                            get: { store.selectedImportanceUrgencyFilter },
                            set: { store.send(.selectedImportanceUrgencyFilterChanged($0)) }
                        )
                    )
                    .frame(maxWidth: 420, alignment: .leading)

                    Text(importanceUrgencyFilterSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !availableTags.isEmpty {
                    Section("Tag Rules") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Show stats with")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Picker("Show stats with", selection: Binding(
                                    get: { store.includeTagMatchMode },
                                    set: { store.send(.includeTagMatchModeChanged($0)) }
                                )) {
                                    ForEach(RoutineTagMatchMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 180)
                            }

                            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                                if store.effectiveSelectedTags.isEmpty {
                                    statsTagButton(title: "All Tags", isSelected: true) {
                                        relatedFilterTagSuggestionAnchor = nil
                                        store.send(.selectedTagsChanged([]))
                                    }
                                } else {
                                    ForEach(store.effectiveSelectedTags.sorted(), id: \.self) { tag in
                                        statsTagButton(title: "#\(tag)", isSelected: true) {
                                            toggleIncludedTag(tag)
                                        }
                                    }
                                }
                            }

                            if !suggestedRelatedFilterTags.isEmpty {
                                Text("Suggested")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                                    ForEach(suggestedRelatedFilterTags, id: \.self) { tag in
                                        statsTagButton(title: "#\(tag)", isSelected: false) {
                                            addIncludedTag(tag)
                                        }
                                    }
                                }
                            }

                            Text("Add more")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                                ForEach(availableTags.filter { !isIncludedTagSelected($0) }, id: \.self) { tag in
                                    statsTagButton(title: "#\(tag)", isSelected: false) {
                                        toggleIncludedTag(tag)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Hide stats with")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Picker("Hide stats with", selection: Binding(
                                    get: { store.excludeTagMatchMode },
                                    set: { store.send(.excludeTagMatchModeChanged($0)) }
                                )) {
                                    ForEach(RoutineTagMatchMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 180)
                            }

                            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                                if store.excludedTags.isEmpty {
                                    Text("No hidden tags")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(store.excludedTags.sorted(), id: \.self) { tag in
                                        statsTagButton(title: "#\(tag)", isSelected: true, selectedColor: .red) {
                                            toggleExcludedTag(tag)
                                        }
                                    }
                                }
                            }

                            if !availableExcludeTags.isEmpty {
                                Text("Add tags to hide")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                                    ForEach(availableExcludeTags.filter { tag in
                                        !store.excludedTags.contains { RoutineTag.contains($0, in: [tag]) }
                                    }, id: \.self) { tag in
                                        statsTagButton(title: "#\(tag)", isSelected: false, selectedColor: .red) {
                                            toggleExcludedTag(tag)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if hasActiveFilters {
                    Section {
                        Button("Clear Filters") {
                            store.send(.clearFilters)
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        store.send(.setFilterSheet(false))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: availableTags) { _, newValue in
            let selected = store.effectiveSelectedTags.filter { RoutineTag.contains($0, in: newValue) }
            store.send(.selectedTagsChanged(selected))
        }
    }

    private var selectedImportanceUrgencyFilterLabel: String? {
        guard let filter = store.selectedImportanceUrgencyFilter else { return nil }
        return "\(filter.importance.shortTitle)/\(filter.urgency.shortTitle)+"
    }

    private var importanceUrgencyFilterSummary: String {
        guard let filter = store.selectedImportanceUrgencyFilter else {
            return "Choose a cell to show stats only for tasks that meet or exceed that importance and urgency."
        }
        return "Showing stats for tasks with at least \(filter.importance.title.lowercased()) importance and \(filter.urgency.title.lowercased()) urgency."
    }

    private func statsTagButton(
        title: String,
        isSelected: Bool,
        selectedColor: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? selectedColor : Color.secondary.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    private func statsTaskTypeIcon(for filter: StatsTaskTypeFilter) -> String {
        switch filter {
        case .all:
            return "square.grid.2x2"
        case .routines:
            return "repeat"
        case .todos:
            return "checklist"
        }
    }

    private struct WrappingHStack: Layout {
        let horizontalSpacing: CGFloat
        let verticalSpacing: CGFloat

        init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
            self.horizontalSpacing = horizontalSpacing
            self.verticalSpacing = verticalSpacing
        }

        func sizeThatFits(
            proposal: ProposedViewSize,
            subviews: Subviews,
            cache: inout ()
        ) -> CGSize {
            let maxWidth = proposal.width ?? .infinity
            var currentRowWidth: CGFloat = 0
            var currentRowHeight: CGFloat = 0
            var totalHeight: CGFloat = 0
            var maxRowWidth: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                let spacing = currentRowWidth == 0 ? 0 : horizontalSpacing

                if currentRowWidth + spacing + size.width > maxWidth, currentRowWidth > 0 {
                    totalHeight += currentRowHeight + verticalSpacing
                    maxRowWidth = max(maxRowWidth, currentRowWidth)
                    currentRowWidth = size.width
                    currentRowHeight = size.height
                } else {
                    currentRowWidth += spacing + size.width
                    currentRowHeight = max(currentRowHeight, size.height)
                }
            }

            maxRowWidth = max(maxRowWidth, currentRowWidth)
            totalHeight += currentRowHeight

            return CGSize(width: maxRowWidth, height: totalHeight)
        }

        func placeSubviews(
            in bounds: CGRect,
            proposal: ProposedViewSize,
            subviews: Subviews,
            cache: inout ()
        ) {
            var x = bounds.minX
            var y = bounds.minY
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                let proposedX = x == bounds.minX ? x : x + horizontalSpacing

                if proposedX + size.width > bounds.maxX, x > bounds.minX {
                    x = bounds.minX
                    y += rowHeight + verticalSpacing
                    rowHeight = 0
                } else if x > bounds.minX {
                    x += horizontalSpacing
                }

                subview.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )

                x += size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
    }

    private var rangeSection: some View {
        HStack(spacing: 10) {
            ForEach(DoneChartRange.allCases) { range in
                rangeButton(for: range)
            }
        }
        .padding(6)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(selectorBackground)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white, lineWidth: 1)
                .opacity(selectorOutlineOpacity)
        )
    }

    private func rangeButton(for range: DoneChartRange) -> some View {
        let isSelected = selectedRange == range

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                _ = store.send(.selectedRangeChanged(range))
            }
        } label: {
            VStack(spacing: 4) {
                Text(range.rawValue)
                    .font(.subheadline.weight(.semibold))

                Text(rangeButtonSubtitle(for: range))
                    .font(.caption2.weight(.medium))
                    .opacity(isSelected ? 0.9 : 0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background {
                rangeButtonBackground(isSelected: isSelected)
            }
        }
        .buttonStyle(.plain)
    }

    private func heroSection(metrics: Metrics) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(rangeHeroLabel, systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.62), in: Capsule())

                    Text(metrics.totalCount.formatted())
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(metrics.totalCount == 1 ? "completion logged" : "completions logged")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))

                    Text(selectedRange.periodDescription)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(metrics.activeDayCount)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)

                    Text(metrics.activeDayCount == 1 ? "active day" : "active days")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            sparklinePreview(metrics: metrics)

            HStack(spacing: 12) {
                heroStatPill(
                    icon: "gauge.with.dots.needle.50percent",
                    title: "Daily avg",
                    value: averagePerDayText(for: metrics)
                )

                heroStatPill(
                    icon: "bolt.fill",
                    title: "Best day",
                    value: metrics.highlightedBusiestDay.map { "\($0.count)" } ?? "0"
                )
            }
        }
        .padding(22)
        .background(heroGradient, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.28), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.08), radius: 22, y: 14)
    }

    private func sparklinePreview(metrics: Metrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily rhythm")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Spacer()

                Text(sparklineCaption(metrics: metrics))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(metrics.sparklinePoints) { point in
                    Capsule(style: .continuous)
                        .fill(sparklineColor(for: point, metrics: metrics))
                        .frame(maxWidth: .infinity)
                        .frame(height: sparklineBarHeight(for: point, metrics: metrics))
                }
            }
            .frame(height: 74, alignment: .bottom)
        }
    }

    private func summaryCards(metrics: Metrics) -> some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: horizontalSizeClass == .compact ? 160 : 220,
                        maximum: 280
                    ),
                    spacing: 14
                )
            ],
            spacing: 14
        ) {
            summaryCard(
                icon: "gauge.with.dots.needle.50percent",
                accent: .mint,
                title: "Daily average",
                value: averagePerDayText(for: metrics),
                caption: "Across \(metrics.chartPoints.count) days",
                accessibilityIdentifier: "stats.summary.dailyAverage"
            )

            summaryCard(
                icon: "bolt.fill",
                accent: .orange,
                title: "Best day",
                value: metrics.highlightedBusiestDay.map { "\($0.count)" } ?? "0",
                caption: metrics.highlightedBusiestDay.map(bestDayCaption(for:)) ?? "No peak day yet",
                accessibilityIdentifier: "stats.summary.bestDay"
            )

            summaryCard(
                icon: "checkmark.seal.fill",
                accent: .blue,
                title: "Total dones",
                value: metrics.totalDoneCount.formatted(),
                caption: "All recorded completions",
                accessibilityIdentifier: "stats.summary.totalDones"
            )

            summaryCard(
                icon: "xmark.seal.fill",
                accent: .orange,
                title: "Total cancels",
                value: metrics.totalCanceledCount.formatted(),
                caption: "Canceled todos kept in timeline",
                accessibilityIdentifier: "stats.summary.totalCancels"
            )

            summaryCard(
                icon: "checklist.checked",
                accent: .green,
                title: "Active routines",
                value: metrics.activeRoutineCount.formatted(),
                caption: activeRoutineCardCaption(metrics: metrics),
                accessibilityIdentifier: "stats.summary.activeRoutines"
            )

            summaryCard(
                icon: "archivebox.fill",
                accent: .teal,
                title: "Archived routines",
                value: metrics.archivedRoutineCount.formatted(),
                caption: archivedRoutineCardCaption(metrics: metrics),
                accessibilityIdentifier: "stats.summary.archivedRoutines"
            )
        }
    }

    private var gitHubSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GitHub activity")
                        .font(.title3.weight(.semibold))

                    Text(gitHubSectionSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if gitHubConnection.isConnected {
                    Button {
                        store.send(.gitHubStatsRefreshRequested)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isGitHubStatsLoading)
                }
            }

            if isGitHubStatsLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading GitHub stats...")
                        .foregroundStyle(.secondary)
                }
            } else if let gitHubStats {
                switch gitHubStats {
                case let .repository(stats):
                    gitHubRepositoryContent(stats)
                case let .profile(stats):
                    gitHubProfileContent(stats)
                }
            } else if let gitHubStatsErrorMessage {
                VStack(alignment: .leading, spacing: 12) {
                    Text(gitHubStatsErrorMessage)
                        .foregroundStyle(.secondary)

                    Button {
                        store.send(.gitHubStatsRefreshRequested)
                    } label: {
                        Label("Try Again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!gitHubConnection.isConnected)
                }
            } else {
                Text(
                    gitHubConnection.scope == .profile
                        ? "Connect your GitHub profile in Settings to show overall contributions, commits, reviews, and issue activity here."
                        : "Connect a GitHub repository in Settings to show commits, pull requests, and contributor activity here."
                )
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(surfaceGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45), lineWidth: 1)
        )
    }

    private var gitHubSectionSubtitle: String {
        if let repository = gitHubConnection.repository {
            return "Repo: \(repository.fullName)"
        }
        if let viewerLogin = gitHubConnection.viewerLogin, !viewerLogin.isEmpty {
            return "Profile: @\(viewerLogin)"
        }

        if gitHubConnection.scope == .profile {
            return "No profile connected"
        }

        return "No repository connected"
    }

    @ViewBuilder
    private func gitHubRepositoryContent(_ stats: GitHubRepositoryStats) -> some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: horizontalSizeClass == .compact ? 160 : 220,
                        maximum: 280
                    ),
                    spacing: 14
                )
            ],
            spacing: 14
        ) {
            summaryCard(
                icon: "point.topleft.down.curvedto.point.bottomright.up.fill",
                accent: .indigo,
                title: "Commits",
                value: stats.totalCommitCount.formatted(),
                caption: stats.repository.fullName,
                accessibilityIdentifier: "stats.github.commits"
            )

            summaryCard(
                icon: "arrow.merge",
                accent: .green,
                title: "Merged PRs",
                value: stats.mergedPullRequestCount.formatted(),
                caption: selectedRange.periodDescription,
                accessibilityIdentifier: "stats.github.mergedPRs"
            )

            summaryCard(
                icon: "tray.full.fill",
                accent: .orange,
                title: "Open PRs",
                value: stats.openPullRequestCount.formatted(),
                caption: "Current open pull requests",
                accessibilityIdentifier: "stats.github.openPRs"
            )

            summaryCard(
                icon: "person.2.fill",
                accent: .blue,
                title: "Contributors",
                value: stats.contributorCount.formatted(),
                caption: "Active in this range",
                accessibilityIdentifier: "stats.github.contributors"
            )
        }

        gitHubChart(
            points: stats.commitPoints,
            averageCount: stats.averageCommitCount,
            busiestDay: stats.busiestCommitDay,
            yAxisLabel: "Commits",
            averageLabel: "Average"
        )

        HStack(spacing: 10) {
            bottomInsightPill(
                icon: "calendar",
                text: selectedRange.periodDescription
            )

            if let busiestCommitDay = stats.busiestCommitDay {
                bottomInsightPill(
                    icon: "sparkles",
                    text: "Best day: \(bestDayCaption(for: busiestCommitDay))"
                )
            } else {
                bottomInsightPill(
                    icon: "arrow.trianglehead.2.clockwise.rotate.90",
                    text: "No commits in this range"
                )
            }
        }
    }

    @ViewBuilder
    private func gitHubProfileContent(_ stats: GitHubProfileStats) -> some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(
                        minimum: horizontalSizeClass == .compact ? 160 : 220,
                        maximum: 280
                    ),
                    spacing: 14
                )
            ],
            spacing: 14
        ) {
            summaryCard(
                icon: "chart.bar.xaxis",
                accent: .indigo,
                title: "Contributions",
                value: stats.totalContributionCount.formatted(),
                caption: "@\(stats.login) across GitHub",
                accessibilityIdentifier: "stats.github.profile.contributions"
            )

            summaryCard(
                icon: "point.topleft.down.curvedto.point.bottomright.up.fill",
                accent: .blue,
                title: "Commits",
                value: stats.totalCommitCount.formatted(),
                caption: selectedRange.periodDescription,
                accessibilityIdentifier: "stats.github.profile.commits"
            )

            summaryCard(
                icon: "arrow.triangle.pull",
                accent: .green,
                title: "Pull Requests",
                value: stats.totalPullRequestCount.formatted(),
                caption: "Opened in this range",
                accessibilityIdentifier: "stats.github.profile.pullRequests"
            )

            summaryCard(
                icon: "text.bubble.fill",
                accent: .orange,
                title: "Reviews",
                value: stats.totalPullRequestReviewCount.formatted(),
                caption: "Review contributions",
                accessibilityIdentifier: "stats.github.profile.reviews"
            )

            summaryCard(
                icon: "exclamationmark.circle.fill",
                accent: .pink,
                title: "Issues",
                value: stats.totalIssueCount.formatted(),
                caption: "Issue contributions",
                accessibilityIdentifier: "stats.github.profile.issues"
            )

            summaryCard(
                icon: "shippingbox.fill",
                accent: .teal,
                title: "Repos",
                value: stats.contributedRepositoryCount.formatted(),
                caption: "Repos with commits",
                accessibilityIdentifier: "stats.github.profile.repositories"
            )
        }

        gitHubChart(
            points: stats.contributionPoints,
            averageCount: stats.averageContributionCount,
            busiestDay: stats.busiestContributionDay,
            yAxisLabel: "Contributions",
            averageLabel: "Average"
        )

        HStack(spacing: 10) {
            bottomInsightPill(
                icon: "calendar",
                text: selectedRange.periodDescription
            )

            if let busiestContributionDay = stats.busiestContributionDay {
                bottomInsightPill(
                    icon: "sparkles",
                    text: "Best day: \(bestDayCaption(for: busiestContributionDay))"
                )
            } else {
                bottomInsightPill(
                    icon: "arrow.trianglehead.2.clockwise.rotate.90",
                    text: "No contributions in this range"
                )
            }

            if stats.restrictedContributionCount > 0 {
                bottomInsightPill(
                    icon: "lock.fill",
                    text: "Private: \(stats.restrictedContributionCount.formatted()) hidden"
                )
            }
        }
    }

    private func gitHubChart(
        points: [DoneChartPoint],
        averageCount: Double,
        busiestDay: DoneChartPoint?,
        yAxisLabel: String,
        averageLabel: String
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Chart {
                ForEach(points) { point in
                    let isHighlighted = point.date == busiestDay?.date

                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value(yAxisLabel, point.count)
                    )
                    .cornerRadius(7)
                    .foregroundStyle(
                        isHighlighted
                            ? AnyShapeStyle(highlightBarFill)
                            : AnyShapeStyle(baseBarFill)
                    )
                    .opacity(point.count == 0 ? 0.35 : 1)
                }

                if averageCount > 0 {
                    RuleMark(y: .value(averageLabel, averageCount))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                        .foregroundStyle(Color.secondary.opacity(0.65))
                }
            }
            .chartYScale(domain: 0...gitHubChartUpperBound(points: points, averageCount: averageCount))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: makeXAxisDates(from: points)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                        .foregroundStyle(Color.secondary.opacity(0.12))
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(xAxisLabel(for: date))
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.04))
                    )
            }
            .frame(minWidth: chartMinWidth, minHeight: 220)
            .padding(.top, 4)
        }
        .defaultScrollAnchor(.trailing)
    }

    private func activeRoutineCardCaption(metrics: Metrics) -> String {
        if filteredTaskCount == 0 {
            return "No routines created yet"
        }

        if metrics.activeRoutineCount == 0 {
            return metrics.archivedRoutineCount == 1
                ? "Your only routine is paused"
                : "All routines are currently paused"
        }

        if metrics.archivedRoutineCount == 0 {
            return "Everything is currently in rotation"
        }

        return metrics.archivedRoutineCount == 1
            ? "1 paused routine excluded"
            : "\(metrics.archivedRoutineCount) paused routines excluded"
    }

    private func archivedRoutineCardCaption(metrics: Metrics) -> String {
        if filteredTaskCount == 0 {
            return "No routines created yet"
        }

        if metrics.archivedRoutineCount == 0 {
            return "No archived routines right now"
        }

        return metrics.archivedRoutineCount == 1
            ? "1 routine is paused and hidden from Home"
            : "\(metrics.archivedRoutineCount) routines are paused and hidden from Home"
    }

    private func chartSection(metrics: Metrics) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Completions per day")
                        .font(.title3.weight(.semibold))

                    Text(chartSectionSubtitle(metrics: metrics))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                smallHighlightBadge(
                    title: "Peak",
                    value: metrics.highlightedBusiestDay.map { "\($0.count)" } ?? "0"
                )
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Chart {
                    ForEach(metrics.chartPoints) { point in
                        let isHighlighted = point.date == metrics.highlightedBusiestDay?.date

                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Completions", point.count)
                        )
                        .cornerRadius(7)
                        .foregroundStyle(
                            isHighlighted
                                ? AnyShapeStyle(highlightBarFill)
                                : AnyShapeStyle(baseBarFill)
                        )
                        .opacity(point.count == 0 ? 0.35 : 1)
                    }

                    if metrics.averagePerDay > 0 {
                        RuleMark(y: .value("Average", metrics.averagePerDay))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                            .foregroundStyle(Color.secondary.opacity(0.65))
                            .annotation(position: .topLeading, alignment: .leading) {
                                Text("Avg \(averagePerDayText(for: metrics))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        surfaceGradient,
                                        in: Capsule(style: .continuous)
                                    )
                            }
                    }

                    if let highlightedBusiestDay = metrics.highlightedBusiestDay {
                        PointMark(
                            x: .value("Date", highlightedBusiestDay.date, unit: .day),
                            y: .value("Completions", highlightedBusiestDay.count)
                        )
                        .symbolSize(selectedRange == .year ? 46 : 64)
                        .foregroundStyle(Color.white)
                    }
                }
                .chartYScale(domain: 0...metrics.chartUpperBound)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let count = value.as(Int.self) {
                                Text(count.formatted())
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: metrics.xAxisDates) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                            .foregroundStyle(Color.secondary.opacity(0.12))
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(xAxisLabel(for: date))
                            }
                        }
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.04))
                        )
                }
                .frame(minWidth: chartMinWidth, minHeight: 260)
                .padding(.top, 4)
            }
            .defaultScrollAnchor(.trailing)

            HStack(spacing: 10) {
                bottomInsightPill(
                    icon: "calendar",
                    text: selectedRange.periodDescription
                )

                if let highlightedBusiestDay = metrics.highlightedBusiestDay {
                    bottomInsightPill(
                        icon: "star.fill",
                        text: "Best: \(bestDayCaption(for: highlightedBusiestDay))"
                    )
                } else {
                    bottomInsightPill(
                        icon: "waveform.path.ecg",
                        text: "Waiting for your first completion"
                    )
                }
            }
        }
        .padding(20)
        .background(surfaceGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45), lineWidth: 1)
        )
    }

    private func heroStatPill(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.24), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func summaryCard(
        icon: String,
        accent: Color,
        title: String,
        value: String,
        caption: String,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(colorScheme == .dark ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(surfaceGradient)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(accent.opacity(colorScheme == .dark ? 0.16 : 0.12))
                        .frame(width: 110, height: 110)
                        .blur(radius: 16)
                        .offset(x: 28, y: -32)
                }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(value). \(caption)")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func smallHighlightBadge(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(surfaceGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.35), lineWidth: 1)
        )
    }

    private func bottomInsightPill(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(colorScheme == .dark ? 0.14 : 0.04), in: Capsule(style: .continuous))
    }

    private var rangeHeroLabel: String {
        switch selectedRange {
        case .week:
            return "This week"
        case .month:
            return "This month"
        case .year:
            return "This year"
        }
    }

    private func rangeButtonSubtitle(for range: DoneChartRange) -> String {
        switch range {
        case .week:
            return "7 days"
        case .month:
            return "30 days"
        case .year:
            return "1 year"
        }
    }

    private func sampledSparklinePoints(from chartPoints: [DoneChartPoint]) -> [DoneChartPoint] {
        let targetCount: Int

        switch selectedRange {
        case .week:
            targetCount = 7
        case .month:
            targetCount = 15
        case .year:
            targetCount = 24
        }

        guard chartPoints.count > targetCount, targetCount > 1 else {
            return chartPoints
        }

        let step = Double(chartPoints.count - 1) / Double(targetCount - 1)

        return (0..<targetCount).map { index in
            let pointIndex = min(Int((Double(index) * step).rounded()), chartPoints.count - 1)
            return chartPoints[pointIndex]
        }
    }

    private func sparklineCaption(metrics: Metrics) -> String {
        guard let highlightedBusiestDay = metrics.highlightedBusiestDay else {
            return "No peak yet"
        }

        return "Peak \(highlightedBusiestDay.count)"
    }

    private func sparklineColor(for point: DoneChartPoint, metrics: Metrics) -> Color {
        if point.date == metrics.highlightedBusiestDay?.date {
            return Color.white.opacity(0.96)
        }

        return Color.white.opacity(point.count == 0 ? 0.12 : 0.3)
    }

    private func sparklineBarHeight(for point: DoneChartPoint, metrics: Metrics) -> CGFloat {
        let normalized = max(CGFloat(point.count) / CGFloat(metrics.sparklineMaxCount), 0.12)
        return 16 + (normalized * 54)
    }

    private func gitHubChartUpperBound(points: [DoneChartPoint], averageCount: Double) -> Double {
        let maxCount = points.map(\.count).max() ?? 0
        return Double(max(maxCount, Int(ceil(averageCount))) + 1)
    }

    private var chartMinWidth: CGFloat {
        switch selectedRange {
        case .week:
            return 340
        case .month:
            return 720
        case .year:
            return 2600
        }
    }

    private var statsContentMaxWidth: CGFloat? {
        horizontalSizeClass == .regular ? 980 : nil
    }

    private var contentBottomPadding: CGFloat {
        horizontalSizeClass == .compact ? 120 : 52
    }

    private func makeXAxisDates(from chartPoints: [DoneChartPoint]) -> [Date] {
        switch selectedRange {
        case .week:
            return chartPoints.map(\.date)

        case .month:
            return chartPoints.enumerated().compactMap { index, point in
                if index == 0 || index == chartPoints.count - 1 || index.isMultiple(of: 5) {
                    return point.date
                }
                return nil
            }

        case .year:
            let firstDate = chartPoints.first?.date
            let lastDate = chartPoints.last?.date

            return chartPoints.compactMap { point in
                let day = calendar.component(.day, from: point.date)
                if point.date == firstDate || point.date == lastDate || day == 1 {
                    return point.date
                }
                return nil
            }
        }
    }

    private func averagePerDayText(for metrics: Metrics) -> String {
        metrics.averagePerDay.formatted(.number.precision(.fractionLength(1)))
    }

    private func chartSectionSubtitle(metrics: Metrics) -> String {
        if metrics.totalCount == 0 {
            return "Your chart will fill in as you complete routines."
        }

        return "Average \(averagePerDayText(for: metrics)) per day across \(metrics.chartPoints.count) days."
    }

    private func xAxisLabel(for date: Date) -> String {
        switch selectedRange {
        case .week:
            return date.formatted(.dateTime.weekday(.abbreviated))
        case .month:
            return date.formatted(.dateTime.day())
        case .year:
            return date.formatted(.dateTime.month(.abbreviated))
        }
    }

    private func bestDayCaption(for point: DoneChartPoint) -> String {
        point.date.formatted(.dateTime.month(.abbreviated).day())
    }

    @ViewBuilder
    private func rangeButtonBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selectorActiveFill)
                .shadow(color: Color.accentColor.opacity(0.28), radius: 16, y: 8)
        }
    }
}

private extension StatsView.Metrics {
    init(_ source: StatsFeature.Metrics) {
        self.init(
            chartPoints: source.chartPoints,
            totalDoneCount: source.totalDoneCount,
            totalCanceledCount: source.totalCanceledCount,
            activeRoutineCount: source.activeRoutineCount,
            archivedRoutineCount: source.archivedRoutineCount,
            totalCount: source.totalCount,
            averagePerDay: source.averagePerDay,
            highlightedBusiestDay: source.highlightedBusiestDay,
            activeDayCount: source.activeDayCount,
            chartUpperBound: source.chartUpperBound,
            sparklinePoints: source.sparklinePoints,
            sparklineMaxCount: source.sparklineMaxCount,
            xAxisDates: source.xAxisDates
        )
    }
}
