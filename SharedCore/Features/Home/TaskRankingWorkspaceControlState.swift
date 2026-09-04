extension TaskRankingFeature.State {
    var hasNonDefaultViewControls: Bool {
        metric != .pressure || valueMode != .base
    }

    var hasNonDefaultSortControls: Bool {
        !reversedMetrics.isEmpty
    }

    var hasNonDefaultWorkspaceControls: Bool {
        hasNonDefaultViewControls || hasNonDefaultSortControls
    }

    var workspaceControlSummary: WorkspaceControlSummary {
        guard hasNonDefaultWorkspaceControls else { return .empty }

        var items = [
            WorkspaceControlSummaryItem(category: .view, title: metric.title),
        ]
        if metric.supportsTemporalWeight {
            items.append(.init(category: .view, title: valueMode.title))
        }
        items.append(.init(
            category: .sort,
            title: metric.directionTitle(isReversed: reversedMetrics.contains(metric))
        ))
        return WorkspaceControlSummary(items: items)
    }
}
