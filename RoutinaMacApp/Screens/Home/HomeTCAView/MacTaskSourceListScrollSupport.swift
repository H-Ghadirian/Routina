@preconcurrency import AppKit
import SwiftUI

enum MacTaskSourceListScrollAnchor: Hashable {
    case top
    case section(String)
    case group(sectionID: String, groupID: String)
}

enum MacTaskSourceListScrollContainerIdentity: Hashable {
    case normal(Int)
    case searchReveal
}

struct MacTaskSourceListTaskLocation {
    let section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    let groups: [HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>]
}

@MainActor
final class MacTaskSourceListScrollViewReference {
    weak var scrollView: NSScrollView?

    private var boundsObserver: NSObjectProtocol?
    private var preservedOrigin: NSPoint?
    private var isRestoringPreservedOrigin = false

    func startPreservingScrollPosition(in scrollView: NSScrollView) {
        stopPreservingScrollPosition()

        self.scrollView = scrollView
        preservedOrigin = scrollView.contentView.bounds.origin

        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.restorePreservedScrollPosition()
            }
        }
    }

    func restorePreservedScrollPosition() {
        guard
            !isRestoringPreservedOrigin,
            let scrollView,
            let preservedOrigin
        else { return }

        let clipView = scrollView.contentView
        let targetY = MacTaskSourceListScrollPreservation.verticalOrigin(
            preserving: preservedOrigin.y,
            documentHeight: scrollView.documentView?.bounds.height ?? 0,
            viewportHeight: clipView.bounds.height
        )
        let targetOrigin = NSPoint(x: preservedOrigin.x, y: targetY)
        guard clipView.bounds.origin != targetOrigin else { return }

        isRestoringPreservedOrigin = true
        clipView.scroll(to: targetOrigin)
        scrollView.reflectScrolledClipView(clipView)
        isRestoringPreservedOrigin = false
    }

    func stopPreservingScrollPosition() {
        if let boundsObserver {
            NotificationCenter.default.removeObserver(boundsObserver)
        }
        boundsObserver = nil
        preservedOrigin = nil
        isRestoringPreservedOrigin = false
    }
}

struct MacTaskSourceListScrollViewResolver: NSViewRepresentable {
    let reference: MacTaskSourceListScrollViewReference

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            reference.scrollView = nsView.enclosingTaskSourceScrollView
        }
    }
}

struct MacTaskSourceListScrollResetView: NSViewRepresentable {
    let requestID: Int

    final class Coordinator {
        var handledRequestID = 0
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard requestID > 0, context.coordinator.handledRequestID != requestID else { return }
        context.coordinator.handledRequestID = requestID

        resetScrollPosition(from: nsView)
        DispatchQueue.main.async {
            resetScrollPosition(from: nsView)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                resetScrollPosition(from: nsView)
            }
        }
    }

    private func resetScrollPosition(from nsView: NSView) {
        guard let scrollView = nsView.enclosingTaskSourceScrollView else { return }

        scrollView.layoutSubtreeIfNeeded()
        scrollView.documentView?.layoutSubtreeIfNeeded()

        let clipView = scrollView.contentView
        let documentView = scrollView.documentView
        let targetY: CGFloat
        if documentView?.isFlipped == false {
            targetY = max(0, (documentView?.bounds.height ?? 0) - clipView.bounds.height)
        } else {
            targetY = 0
        }

        clipView.scroll(to: NSPoint(x: clipView.bounds.origin.x, y: targetY))
        scrollView.reflectScrolledClipView(clipView)
    }
}

private extension NSView {
    var enclosingTaskSourceScrollView: NSScrollView? {
        sequence(first: superview, next: { $0?.superview })
            .compactMap { $0 as? NSScrollView }
            .first
    }
}

extension HomeTCAView {
    func handleMacTaskSourceScrollEvent(
        _ event: MacTaskSourceListScrollEvent,
        with proxy: ScrollViewProxy,
        visibleTaskIDs: [UUID]
    ) {
        guard
            let taskID = MacTaskSourceListScrollPolicy.scrollTarget(
                for: event,
                selectedTaskID: store.selectedTaskID,
                pendingRequest: macSidebarTaskScrollRequest,
                visibleTaskIDs: visibleTaskIDs
            )
        else { return }

        guard let request = macSidebarTaskScrollRequest else { return }

        if scrollMacTaskSourceList(
            to: taskID,
            with: proxy,
            visibleTaskIDs: visibleTaskIDs,
            request: request
        ) {
            macSidebarTaskScrollRequest = nil
        }
    }

    @discardableResult
    private func scrollMacTaskSourceList(
        to taskID: UUID,
        with proxy: ScrollViewProxy,
        visibleTaskIDs: [UUID],
        request: MacSidebarTaskScrollRequest
    ) -> Bool {
        guard visibleTaskIDs.contains(taskID) else { return false }

        let steps = MacTaskSourceListScrollPolicy.stagedScrollSteps(for: request)
        DispatchQueue.main.async {
            performMacTaskSourceListScroll(
                steps[...],
                with: proxy,
                rowAnchor: request.unitPointAnchor
            )
        }
        return true
    }

    private func performMacTaskSourceListScroll(
        _ steps: ArraySlice<MacTaskSourceListScrollStep>,
        with proxy: ScrollViewProxy,
        rowAnchor: UnitPoint?
    ) {
        guard let step = steps.first else { return }

        switch step {
        case let .section(sectionID):
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo(
                    MacTaskSourceListScrollAnchor.section(sectionID),
                    anchor: .top
                )
            }
        case let .group(sectionID, groupID):
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo(
                    MacTaskSourceListScrollAnchor.group(
                        sectionID: sectionID,
                        groupID: groupID
                    ),
                    anchor: .top
                )
            }
        case let .task(taskID):
            proxy.scrollTo(taskID, anchor: rowAnchor)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(taskID, anchor: rowAnchor)
                }
            }
            return
        }

        DispatchQueue.main.async {
            performMacTaskSourceListScroll(
                steps.dropFirst(),
                with: proxy,
                rowAnchor: rowAnchor
            )
        }
    }

    func restoreMacTaskSourceListTopPosition(with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withTransaction(Transaction(animation: nil)) {
                proxy.scrollTo(MacTaskSourceListScrollAnchor.top, anchor: .top)
            }

            DispatchQueue.main.async {
                withTransaction(Transaction(animation: nil)) {
                    proxy.scrollTo(MacTaskSourceListScrollAnchor.top, anchor: .top)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withTransaction(Transaction(animation: nil)) {
                        proxy.scrollTo(MacTaskSourceListScrollAnchor.top, anchor: .top)
                    }
                }
            }
        }
    }

}

private extension MacSidebarTaskScrollRequest {
    var unitPointAnchor: UnitPoint? {
        switch anchor {
        case .center:
            return .center
        case .minimalReveal:
            return nil
        }
    }
}
