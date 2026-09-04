import Testing
#if SWIFT_PACKAGE
    @testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
    @testable @preconcurrency import RoutinaMacOSDev
#else
    @testable @preconcurrency import Routina
#endif

struct TaskRankingWorkspaceControlStateTests {
    @Test
    func defaultViewAndSortAreNotCustomized() {
        let state = TaskRankingFeature.State()

        #expect(!state.hasNonDefaultViewControls)
        #expect(!state.hasNonDefaultSortControls)
        #expect(!state.hasNonDefaultWorkspaceControls)
    }

    @Test
    func viewAndSortCustomizationRemainIndependent() {
        var state = TaskRankingFeature.State()
        state.metric = .importance

        #expect(state.hasNonDefaultViewControls)
        #expect(!state.hasNonDefaultSortControls)
        #expect(state.hasNonDefaultWorkspaceControls)

        state.metric = .pressure
        state.reversedMetrics = [.urgency]

        #expect(!state.hasNonDefaultViewControls)
        #expect(state.hasNonDefaultSortControls)
        #expect(state.hasNonDefaultWorkspaceControls)
    }

    @Test
    func summaryNamesTheCurrentLadderViewAndOrder() {
        var state = TaskRankingFeature.State()
        state.metric = .importance
        state.valueMode = .now
        state.reversedMetrics = [.importance]

        #expect(state.workspaceControlSummary.items.map(\.category) == [.view, .view, .sort])
        #expect(
            state.workspaceControlSummary.text(maximumItemCount: 3)
                == "Importance • Now • Least important"
        )
    }

    @Test
    func defaultLadderDoesNotClaimActiveControls() {
        let state = TaskRankingFeature.State()

        #expect(state.workspaceControlSummary.isEmpty)
        #expect(state.workspaceControlSummary.text(maximumItemCount: 3) == nil)
    }
}
