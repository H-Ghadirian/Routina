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
        guard !shouldDeferRoutineUpdateRefresh else {
            hasDeferredRoutineUpdateRefresh = true
            return
        }
        guard !RoutinaMacScrollInteractionGate.isScrollActive else {
            hasDeferredRoutineUpdateRefresh = true
            scheduleDeferredRoutineUpdateRefreshRetry()
            return
        }
#endif
        requestRefresh()
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
    private func scheduleDeferredRoutineUpdateRefreshRetry() {
        deferredRoutineUpdateRefreshTask?.cancel()
        let delayMilliseconds = RoutinaMacScrollInteractionGate.quietRetryDelayMilliseconds
        deferredRoutineUpdateRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            guard !Task.isCancelled else { return }
            requestDeferredRoutineUpdateRefreshIfNeeded()
        }
    }
#endif
}
