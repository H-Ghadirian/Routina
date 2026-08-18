import Combine
import Foundation
import SwiftUI

#if os(iOS)
@MainActor
enum RoutinaIOSHomeScrollInteractionGate {
    private static let quietWindowMilliseconds: Int64 = 1_200
    private static var lastScrollEventAt = Date.distantPast

    static func recordScrollEvent() {
        lastScrollEventAt = Date()
    }

    static var isScrollActive: Bool {
        Date().timeIntervalSince(lastScrollEventAt) < quietWindow
    }

    static var quietRetryDelayMilliseconds: Int64 {
        let elapsedMilliseconds = Int64(
            (Date().timeIntervalSince(lastScrollEventAt) * 1_000).rounded(.down)
        )
        return max(120, quietWindowMilliseconds - elapsedMilliseconds)
    }

    private static var quietWindow: TimeInterval {
        TimeInterval(quietWindowMilliseconds) / 1_000
    }
}
#endif

// Compiled by the app targets only. This keeps HomeTCAView from owning the
// notification fan-in directly while preserving the existing refresh throttling.
extension HomeTCAView {
    func applyHomeRefreshObservers<Content: View>(to content: Content) -> some View {
        content
            .onAppear {
#if os(macOS)
                RoutinaMacScrollInteractionGate.start()
#endif
#if os(iOS)
                guard isActive else { return }
#endif
                guard !store.hasLoadedTaskSnapshot else { return }
                requestRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .routineDidUpdate)
                    .receive(on: RunLoop.main)
            ) { _ in
#if os(iOS)
                guard isActive else {
                    needsRefreshWhenActive = true
                    return
                }
#endif
                requestRoutineUpdateRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: PlatformSupport.didBecomeActiveNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
#if os(iOS)
                guard isActive else {
                    needsRefreshWhenActive = true
                    return
                }
#endif
                requestRefresh()
            }
#if os(iOS)
            .onChange(of: isActive) { _, isActive in
                guard isActive else { return }
                guard needsRefreshWhenActive || !store.hasLoadedTaskSnapshot else { return }
                needsRefreshWhenActive = false
                requestRefresh()
            }
#endif
#if os(macOS)
            .onChange(of: shouldDeferRoutineUpdateRefresh) { _, shouldDefer in
                guard !shouldDefer else { return }
                scheduleDeferredRoutineUpdateRefreshRetry(
                    minimumDelayMilliseconds: taskDetailTransitionQuietDelayMilliseconds
                )
            }
#endif
    }

    @MainActor
    func requestRoutineUpdateRefresh() {
        hasDeferredRoutineUpdateRefresh = true
        scheduleDeferredRoutineUpdateRefreshRetry(
            minimumDelayMilliseconds: routineUpdateCoalescingDelayMilliseconds
        )
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
#if os(iOS)
            guard isActive else {
                needsRefreshWhenActive = true
                return
            }
            refreshFileAttachmentTaskIDs()
#endif
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

    private var taskDetailTransitionQuietDelayMilliseconds: Int64 {
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

#if os(iOS)
    @MainActor
    private func requestDeferredRoutineUpdateRefreshIfNeeded() {
        guard hasDeferredRoutineUpdateRefresh else { return }
        guard isActive else {
            hasDeferredRoutineUpdateRefresh = false
            deferredRoutineUpdateRefreshTask?.cancel()
            deferredRoutineUpdateRefreshTask = nil
            needsRefreshWhenActive = true
            return
        }
        guard !RoutinaIOSHomeScrollInteractionGate.isScrollActive else {
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

    @MainActor
    private func scheduleDeferredRoutineUpdateRefreshRetry(
        minimumDelayMilliseconds: Int64 = 0
    ) {
        deferredRoutineUpdateRefreshTask?.cancel()
        let delayMilliseconds = max(
            minimumDelayMilliseconds,
            RoutinaIOSHomeScrollInteractionGate.quietRetryDelayMilliseconds
        )
        deferredRoutineUpdateRefreshTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            guard !Task.isCancelled else { return }
            requestDeferredRoutineUpdateRefreshIfNeeded()
        }
    }
#endif
}
