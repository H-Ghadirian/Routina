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
}
