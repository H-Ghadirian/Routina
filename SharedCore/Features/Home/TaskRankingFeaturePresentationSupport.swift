import ComposableArchitecture
import Foundation

extension TaskRankingFeature {
    func rebuildSearchPresentation(_ state: inout State) {
        let effectiveValueMode = state.metric.supportsTemporalWeight ? state.valueMode : .base
        state.searchPresentation = TaskRankingSearchPresentation.make(
            tasks: state.tasks,
            organization: state.organization,
            eligibleTaskIDs: state.presentation.eligibleTaskIDs,
            flagRules: state.flagRules,
            metric: state.metric,
            valueMode: effectiveValueMode,
            searchText: state.searchText,
            referenceDate: now,
            calendar: calendar
        )
        let scopePath = state.scopePath
        let matches = state.searchPresentation.matches
        state.currentScopeSearchMatchTaskIDs = Set(
            matches.lazy.filter { $0.scopePath == scopePath }.map(\.task.id)
        )
    }

    func scheduleTemporalRefresh(for state: State) -> Effect<Action> {
        let needsTemporalWeightRefresh =
            state.valueMode == .now
            && state.metric.supportsTemporalWeight
            && state.tasks.contains(where: {
                RoutineTaskTemporalWeightResolver.supportsTemporalWeight($0)
                    && $0.temporalWeightRule != nil
            })
        let needsEntryWindowRefresh = state.tasks.contains(where: {
            RoutineTaskLadderEntryResolver.supportsEntryWindow($0)
                && $0.taskLadderEntryWindow != .throughoutCycle
        })
        guard needsTemporalWeightRefresh || needsEntryWindowRefresh,
            let nextDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: now)
            )
        else {
            return .cancel(id: CancelID.temporalRefresh)
        }
        let seconds = max(nextDay.timeIntervalSince(now), 1)
        return .run { send in
            try await continuousClock.sleep(for: .seconds(seconds))
            await send(.temporalBoundaryReached)
        }
        .cancellable(id: CancelID.temporalRefresh, cancelInFlight: true)
    }

    func selectTask(_ task: RoutineTask, state: inout State) {
        state.selectedGroupID = nil
        state.selectedTaskID = task.id
        state.taskDetailState = HomeTaskSupport.makeTaskDetailState(
            for: task,
            now: now,
            calendar: calendar
        )
    }
}
