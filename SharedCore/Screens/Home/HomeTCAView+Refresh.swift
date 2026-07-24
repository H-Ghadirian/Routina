import Combine
import SwiftUI

// Compiled by the app targets only. This keeps HomeTCAView from owning the
// notification fan-in directly while preserving the existing refresh throttling.
extension HomeTCAView {
    func applyHomeRefreshObservers<Content: View>(to content: Content) -> some View {
        content
            .onAppear {
#if os(macOS)
                RoutinaMacScrollInteractionGate.start()
#endif
                guard !store.hasLoadedTaskSnapshot else { return }
                requestRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .routineDidUpdate)
                    .receive(on: RunLoop.main)
            ) { _ in
                requestRoutineUpdateRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: PlatformSupport.didBecomeActiveNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                requestRefresh()
            }
#if os(macOS)
            .onChange(of: shouldDeferRoutineUpdateRefresh) { _, shouldDefer in
                guard !shouldDefer else { return }
                requestDeferredRoutineUpdateRefreshIfNeeded()
            }
#endif
    }

    @MainActor
    func requestRoutineUpdateRefresh() {
#if os(macOS)
        hasDeferredRoutineUpdateRefresh = true
        scheduleDeferredRoutineUpdateRefreshRetry(
            minimumDelayMilliseconds: routineUpdateCoalescingDelayMilliseconds
        )
#else
        requestRefresh()
#endif
    }

    @MainActor
    func requestRefresh() {
        guard !isRefreshScheduled else { return }
#if os(macOS)
        macTimelinePresentationCache.invalidate()
#endif
        isRefreshScheduled = true

        Task { @MainActor in
            defer { isRefreshScheduled = false }
            await Task.yield()
            store.send(.onAppear)
        }
    }

#if os(macOS)
    private var shouldDeferRoutineUpdateRefresh: Bool {
        store.selectedTaskID != nil
            && (
                taskDetailPanePlacement != nil
                    || fullscreenTaskDetailReturnMode != nil
                    || fullscreenTaskDetailReturnPlacement != nil
            )
    }

    @MainActor
    private func requestDeferredRoutineUpdateRefreshIfNeeded() {
        guard hasDeferredRoutineUpdateRefresh else { return }
        guard !shouldDeferRoutineUpdateRefresh else { return }
        guard !RoutinaMacScrollInteractionGate.isScrollActive else {
            scheduleDeferredRoutineUpdateRefreshRetry()
            return
        }

        hasDeferredRoutineUpdateRefresh = false
        deferredRoutineUpdateRefreshTask?.cancel()
        deferredRoutineUpdateRefreshTask = nil
        requestRefresh()
    }

    @MainActor
    private var routineUpdateCoalescingDelayMilliseconds: Int64 {
        450
    }

    private func scheduleDeferredRoutineUpdateRefreshRetry(
        minimumDelayMilliseconds: Int64 = 0
    ) {
        deferredRoutineUpdateRefreshTask?.cancel()
        let delayMilliseconds = max(
            minimumDelayMilliseconds,
            RoutinaMacScrollInteractionGate.quietRetryDelayMilliseconds
        )
        deferredRoutineUpdateRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            guard !Task.isCancelled else { return }
            requestDeferredRoutineUpdateRefreshIfNeeded()
        }
    }
#endif
}
