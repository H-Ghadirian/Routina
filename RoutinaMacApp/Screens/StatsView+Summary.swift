import Foundation
import SwiftUI

extension StatsView {
    func heroSection(snapshot: DashboardSnapshot) -> some View {
        let metrics = snapshot.metrics

        return interactiveSummaryTaskListCard(
            StatsHeroSectionView(
                selectedRange: snapshot.selectedRange,
                totalCount: metrics.totalCount,
                activeDayCount: metrics.activeDayCount,
                averagePerDay: metrics.averagePerDay,
                highlightedBusiestDay: metrics.highlightedBusiestDay,
                sparklinePoints: metrics.sparklinePoints,
                sparklineMaxCount: metrics.sparklineMaxCount,
                periodDescription: StatsChartInsightBuilder.userActivityPeriodDescription(
                    selectedRange: snapshot.selectedRange,
                    chartPoints: metrics.chartPoints
                ),
                chartPresentation: snapshot.chartPresentation,
                colorScheme: colorScheme,
                heroGradient: heroGradient
            ),
            kind: .activityOverview,
            title: "Activities logged",
            cornerRadius: 30
        )
    }

    @ViewBuilder
    func summaryCards(
        snapshot: DashboardSnapshot,
        dashboardItems: [StatsMacDashboardItem]
    ) -> some View {
        let items = summaryCardItems(snapshot: snapshot, orderedBy: dashboardItems)
        if !items.isEmpty {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum: summaryCardMinimumWidth,
                            maximum: summaryCardMaximumWidth
                        ),
                        spacing: 14
                    )
                ],
                spacing: summaryCardSpacing
            ) {
                ForEach(items) { item in
                    editableDashboardSection(dashboardItem(for: item)) {
                        summaryCardView(for: item)
                    }
                }
            }
        }
    }

    private var summaryCardMinimumWidth: CGFloat {
        switch summaryDisplayMode {
        case .cards:
            return horizontalSizeClass == .compact ? 160 : 220
        case .compact:
            return 280
        }
    }

    private var summaryCardMaximumWidth: CGFloat {
        switch summaryDisplayMode {
        case .cards:
            return 280
        case .compact:
            return 360
        }
    }

    private var summaryCardSpacing: CGFloat {
        summaryDisplayMode == .compact ? 10 : 14
    }

    @ViewBuilder
    private func summaryCardView(for item: StatsSummaryCardItem) -> some View {
        if let kind = StatsSummaryTaskListKind(
            summaryAccessibilityIdentifier: item.accessibilityIdentifier
        ) {
            interactiveSummaryTaskListCard(
                summaryCardContent(for: item),
                kind: kind,
                title: item.title,
                cornerRadius: summaryDisplayMode == .cards ? 24 : 18
            )
        } else {
            summaryCardContent(for: item)
        }
    }

    @ViewBuilder
    private func summaryCardContent(for item: StatsSummaryCardItem) -> some View {
        switch summaryDisplayMode {
        case .cards:
            StatsSummaryCard(
                icon: item.icon,
                accent: item.accent,
                title: item.title,
                value: item.value,
                caption: item.caption,
                accessibilityIdentifier: item.accessibilityIdentifier,
                colorScheme: colorScheme,
                surfaceGradient: surfaceGradient,
                accessibilityChildren: item.showsAccessory ? .contain : .combine
            ) {
                summaryCardAccessory(for: item)
            }
        case .compact:
            StatsCompactSummaryCard(
                icon: item.icon,
                accent: item.accent,
                title: item.title,
                value: item.value,
                caption: item.caption,
                accessibilityIdentifier: item.accessibilityIdentifier,
                colorScheme: colorScheme,
                surfaceGradient: surfaceGradient,
                accessibilityChildren: item.showsAccessory ? .contain : .combine
            ) {
                summaryCardAccessory(for: item)
            }
        }
    }

    private func interactiveSummaryTaskListCard<Content: View>(
        _ content: Content,
        kind: StatsSummaryTaskListKind,
        title: String,
        cornerRadius: CGFloat
    ) -> some View {
        content
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onTapGesture {
                showSummaryTaskList(kind: kind, title: title)
            }
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(.return) {
                showSummaryTaskList(kind: kind, title: title)
                return .handled
            }
            .onKeyPress(SwiftUI.KeyEquivalent.space) {
                showSummaryTaskList(kind: kind, title: title)
                return .handled
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Shows the tasks and sources behind this statistic")
            .help("Show \(title) evidence")
            .popover(
                isPresented: summaryTaskListPopoverBinding(for: kind.rawValue),
                arrowEdge: .top
            ) {
                if let presentation = presentedSummaryTaskList {
                    StatsSummaryTaskListPopover(presentation: presentation)
                }
            }
    }

    private func showSummaryTaskList(
        kind: StatsSummaryTaskListKind,
        title: String
    ) {
        guard !isEditingDashboard, !isActiveItemsInfoPresented else { return }
        let referenceDate = selectedRange.referenceDate(relativeTo: Date())
        presentedSummaryTaskList = StatsSummaryTaskListPresentationBuilder.build(
            kind: kind,
            cardTitle: title,
            tasks: store.tasks,
            filteredTaskIDs: store.filteredTaskIDs,
            logs: store.logs,
            metrics: store.metrics,
            selectedRange: selectedRange,
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    private func summaryTaskListPopoverBinding(for presentationID: String) -> Binding<Bool> {
        Binding(
            get: { presentedSummaryTaskList?.id == presentationID },
            set: { isPresented in
                if !isPresented, presentedSummaryTaskList?.id == presentationID {
                    presentedSummaryTaskList = nil
                }
            }
        )
    }

    @ViewBuilder
    private func summaryCardAccessory(for item: StatsSummaryCardItem) -> some View {
        if item.showsAccessory {
            activeItemsInfoButton
        }
    }

    func summaryCardItems(
        snapshot: DashboardSnapshot,
        orderedBy dashboardItems: [StatsMacDashboardItem]
    ) -> [StatsSummaryCardItem] {
        let items = StatsSummaryCardItemBuilder.items(
            metrics: snapshot.metrics,
            selectedRange: snapshot.selectedRange,
            chartPresentation: snapshot.chartPresentation,
            taskTypeFilter: snapshot.selectedTaskTypeFilter,
            filteredTaskCount: snapshot.filteredTaskCount,
            showsActiveAccessory: true
        )
        let itemsByDashboardItem = Dictionary(
            uniqueKeysWithValues: items.map { (dashboardItem(for: $0), $0) }
        )

        return dashboardItems.compactMap { itemsByDashboardItem[$0] }
    }

    private var activeItemsInfoButton: some View {
        Button {
            presentedSummaryTaskList = nil
            isActiveItemsInfoPresented.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Show active items calculation")
        .accessibilityLabel("Show active items calculation")
        .popover(isPresented: $isActiveItemsInfoPresented, arrowEdge: .top) {
            StatsActiveItemsInfoPopover(breakdown: activeItemsBreakdown)
        }
    }

    private func dashboardItem(for item: StatsSummaryCardItem) -> StatsMacDashboardItem {
        StatsMacDashboardItem(summaryAccessibilityIdentifier: item.accessibilityIdentifier)
    }
}
