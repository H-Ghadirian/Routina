import SwiftUI

extension StatsView {
    func dashboardBody(snapshot: DashboardSnapshot) -> some View {
        NavigationStack {
            StatsDashboardScrollContainer(
                pageBackground: pageBackground,
                bottomPadding: contentBottomPadding,
                maxContentWidth: nil
            ) {
                let blocks = dashboardBlocks(snapshot: snapshot)
                VStack(alignment: .leading, spacing: 24) {
                    if isEditingDashboard {
                        dashboardEditControls
                    }

                    if blocks.isEmpty {
                        StatsEmptyDashboardStateView(
                            hasActiveFilters: store.hasActiveFilters,
                            isSleepEnabled: isAwayEnabled && isStatsSleepTabEnabled,
                            colorScheme: colorScheme
                        )
                    } else {
                        ForEach(blocks) { block in
                            dashboardBlockView(block, snapshot: snapshot)
                        }
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                if showsFocusTimerToolbarItem {
                    RoutinaMacFocusTimerToolbarItem()
                }

                if areMacStatsDashboardControlsEnabled {
                    ToolbarItemGroup(placement: .primaryAction) {
                        summaryDisplayModeMenu
                        dashboardEditButton
                    }
                }
            }
        }
        .onChange(of: areMacStatsDashboardControlsEnabled) { _, isEnabled in
            guard !isEnabled else { return }
            isEditingDashboard = false
            isAddDashboardItemSheetPresented = false
        }
        .sheet(isPresented: $isAddDashboardItemSheetPresented) {
            addDashboardItemSheet
        }
    }

    private var contentBottomPadding: CGFloat {
        36
    }

    private func dashboardBlocks(snapshot: DashboardSnapshot) -> [StatsMacDashboardBlock] {
        var blocks: [StatsMacDashboardBlock] = []
        let visibleItems = scopedVisibleOrderedDashboardItems

        for scope in [StatsMetricScope.general, .dateRange] {
            let scopedItems = visibleItems.filter { $0.metricScope == scope }
            guard !scopedItems.isEmpty else { continue }

            blocks.append(.scopeHeader(scope))
            var pendingSummaryItems: [StatsMacDashboardItem] = []

            func flushSummaryItems() {
                guard !pendingSummaryItems.isEmpty else { return }
                blocks.append(.summaryCards(pendingSummaryItems))
                pendingSummaryItems.removeAll()
            }

            for item in scopedItems {
                if item.isSummaryCard {
                    pendingSummaryItems.append(item)
                } else {
                    flushSummaryItems()
                    blocks.append(.section(item))
                }
            }

            flushSummaryItems()
        }

        return blocks.filter { block in
            switch block {
            case .scopeHeader, .section:
                return true
            case let .summaryCards(items):
                return !summaryCardItems(snapshot: snapshot, orderedBy: items).isEmpty
            }
        }
    }

    @ViewBuilder
    private func dashboardBlockView(_ block: StatsMacDashboardBlock, snapshot: DashboardSnapshot) -> some View {
        switch block {
        case let .scopeHeader(scope):
            statsMetricScopeHeader(scope, selectedRange: snapshot.selectedRange)
        case let .section(item):
            dashboardSection(item, snapshot: snapshot)
        case let .summaryCards(items):
            summaryCards(snapshot: snapshot, dashboardItems: items)
        }
    }

    private func statsMetricScopeHeader(
        _ scope: StatsMetricScope,
        selectedRange: DoneChartRange
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scope.title)
                .font(.title2.weight(.bold))

            Text(
                scope == .general
                    ? "Current totals; the selected date range does not change them."
                    : selectedRange.periodDescription
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("stats.scope.\(scope.rawValue)")
    }

    @ViewBuilder
    private func dashboardSection(_ item: StatsMacDashboardItem, snapshot: DashboardSnapshot) -> some View {
        switch item {
        case .hero:
            editableDashboardSection(.hero) {
                heroSection(snapshot: snapshot)
            }
        case .unassignedFocus:
            editableDashboardSection(.unassignedFocus) {
                UnassignedFocusSessionsCard(
                    focusSessions: store.unassignedFocusSessions,
                    assignableTasks: store.assignableFocusTasks,
                    activeSprints: store.activeFocusSprints
                )
            }
        case .createdTasksChart,
            .completionChart,
            .hourlyActivity,
            .tagUsage,
            .focusChart,
            .focus2048,
            .recentWins,
            .focusAchievements,
            .focusWorkChart,
            .estimateActual,
            .goalProgress,
            .emotionTrend,
            .gitHub:
            dashboardMetricSection(item, snapshot: snapshot)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func dashboardMetricSection(
        _ item: StatsMacDashboardItem,
        snapshot: DashboardSnapshot
    ) -> some View {
        switch item {
        case .createdTasksChart:
            editableDashboardSection(.createdTasksChart) {
                createdTasksChartSection(snapshot: snapshot)
            }
        case .completionChart:
            editableDashboardSection(.completionChart) {
                chartSection(snapshot: snapshot)
            }
        case .hourlyActivity:
            editableDashboardSection(.hourlyActivity) {
                hourlyActivitySection(snapshot: snapshot)
            }
        case .tagUsage:
            editableDashboardSection(.tagUsage) {
                tagUsageSection(snapshot: snapshot)
            }
        case .focusChart:
            editableDashboardSection(.focusChart) {
                focusChartSection(snapshot: snapshot)
            }
        case .focus2048:
            editableDashboardSection(.focus2048) {
                focus2048Section(snapshot: snapshot)
            }
        case .recentWins:
            editableDashboardSection(.recentWins) {
                recentWinsSection()
            }
        case .focusAchievements:
            editableDashboardSection(.focusAchievements) {
                achievementsSection()
            }
        case .focusWorkChart:
            editableDashboardSection(.focusWorkChart) {
                focusWorkChartSection(snapshot: snapshot)
            }
        case .estimateActual:
            editableDashboardSection(.estimateActual) {
                estimateActualChartSection(snapshot: snapshot)
            }
        case .goalProgress:
            editableDashboardSection(.goalProgress) {
                goalProgressSection(snapshot: snapshot)
            }
        case .emotionTrend:
            editableDashboardSection(.emotionTrend) {
                emotionTrendSection(snapshot: snapshot)
            }
        case .gitHub:
            editableDashboardSection(.gitHub) {
                gitHubSection(snapshot: snapshot)
            }
        default:
            EmptyView()
        }
    }
}
