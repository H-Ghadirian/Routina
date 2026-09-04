import AppKit
import Foundation
import LinkPresentation
import SwiftUI

@MainActor
enum HomeMacLinkMetadataResolver {
    static func title(for url: URL) async -> String? {
        guard RoutinaQuickAddLinkSupport.canFetchMetadata(for: url) else { return nil }

        let provider = LPMetadataProvider()
        provider.timeout = 8
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            guard let title = metadata.title else { return nil }
            return RoutinaQuickAddLinkSupport.resolvedLinkTitle(from: title, url: url)
        } catch {
            return nil
        }
    }
}

enum HomeMacToolbarSearchCopy {
    static let placeholder = "Search or create a task"
    static let help = "Search tasks and timeline, or press Return to create a task when there are no results"
    static let accessibilityLabel = "Search or create a task"
    static let returnKeyHint = "Return"
    static let createHint = "Create task"
    static let creatingHint = "Creating task"
    static let parserPreviewTitle = "Detected details"
    static let closeAccessibilityLabel = "Dismiss search focus"
    static let closeHelp = "Dismiss search focus"
    static let clearAccessibilityLabel = "Clear search"
    static let clearHelp = "Clear search"
}

extension Notification.Name {
    static let routinaMacToolbarSearchDismissFocus = Notification.Name("routina.mac.toolbarSearchDismissFocus")
}

struct HomeMacSearchOutsideDismissView: NSViewRepresentable {
    @Binding var isFocused: Bool
    @Binding var focusRequestID: Int
    @Binding var focusDismissRequestID: Int

    @MainActor
    final class Coordinator {
        var parent: HomeMacSearchOutsideDismissView
        weak var view: HomeMacSearchOutsideDismissNSView?
        private var mouseDownMonitor: Any?
        private var keyDownMonitor: Any?

        init(parent: HomeMacSearchOutsideDismissView) {
            self.parent = parent
        }

        func installMouseDownMonitorIfNeeded() {
            guard mouseDownMonitor == nil else { return }
            mouseDownMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                MainActor.assumeIsolated {
                    self?.handleMouseDown(event)
                }
                return event
            }
            installKeyDownMonitorIfNeeded()
        }

        private func installKeyDownMonitorIfNeeded() {
            guard keyDownMonitor == nil else { return }
            keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                var didConsumeEvent = false
                MainActor.assumeIsolated {
                    didConsumeEvent = self?.handleKeyDown(event) ?? false
                }
                return didConsumeEvent ? nil : event
            }
        }

        private func handleMouseDown(_ event: NSEvent) {
            guard let view,
                let window = view.window,
                event.window === window
            else {
                return
            }

            if clickIsInsideVisiblePill(event, in: view) {
                parent.isFocused = true
                parent.focusRequestID += 1
                return
            }

            guard parent.isFocused else { return }

            if HomeMacToolbarSearchInteractionBoundary.clickIsInsideParserPreview(
                event,
                relativeTo: view
            ) {
                return
            }

            dismissFocusedSearch(in: window)
        }

        private func handleKeyDown(_ event: NSEvent) -> Bool {
            guard event.keyCode == 53,
                parent.isFocused,
                let window = view?.window
            else {
                return false
            }

            dismissFocusedSearch(in: window)
            return true
        }

        private func dismissFocusedSearch(in window: NSWindow) {
            parent.isFocused = false
            parent.focusDismissRequestID += 1
            NotificationCenter.default.post(
                name: .routinaMacToolbarSearchDismissFocus,
                object: window
            )
        }

        private func clickIsInsideVisiblePill(
            _ event: NSEvent,
            in view: HomeMacSearchOutsideDismissNSView
        ) -> Bool {
            guard let viewWindow = view.window,
                let eventWindow = event.window
            else {
                return false
            }

            let screenLocation = eventWindow.convertPoint(toScreen: event.locationInWindow)
            let viewWindowLocation = viewWindow.convertPoint(fromScreen: screenLocation)
            let viewLocation = view.convert(viewWindowLocation, from: nil)
            return view.bounds.insetBy(dx: -2, dy: -2).contains(viewLocation)
        }

        func removeMouseDownMonitor() {
            if let mouseDownMonitor {
                NSEvent.removeMonitor(mouseDownMonitor)
            }
            if let keyDownMonitor {
                NSEvent.removeMonitor(keyDownMonitor)
            }
            self.mouseDownMonitor = nil
            self.keyDownMonitor = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> HomeMacSearchOutsideDismissNSView {
        let view = HomeMacSearchOutsideDismissNSView()
        view.setPrefersIBeamCursor(isFocused)
        context.coordinator.view = view
        context.coordinator.installMouseDownMonitorIfNeeded()
        return view
    }

    func updateNSView(
        _ nsView: HomeMacSearchOutsideDismissNSView,
        context: Context
    ) {
        context.coordinator.parent = self
        context.coordinator.view = nsView
        nsView.setPrefersIBeamCursor(isFocused)
        context.coordinator.installMouseDownMonitorIfNeeded()
    }

    @MainActor
    static func dismantleNSView(
        _ nsView: HomeMacSearchOutsideDismissNSView,
        coordinator: Coordinator
    ) {
        coordinator.removeMouseDownMonitor()
    }
}

struct HomeMacSearchInteractionRegionView: NSViewRepresentable {
    func makeNSView(context: Context) -> HomeMacSearchInteractionRegionNSView {
        HomeMacSearchInteractionRegionNSView()
    }

    func updateNSView(
        _ nsView: HomeMacSearchInteractionRegionNSView,
        context: Context
    ) {}
}

final class HomeMacSearchInteractionRegionNSView: NSView {
    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

@MainActor
enum HomeMacToolbarSearchInteractionBoundary {
    static func clickIsInsideParserPreview(
        _ event: NSEvent,
        relativeTo referenceView: NSView
    ) -> Bool {
        guard let window = referenceView.window,
            event.window === window,
            let contentView = window.contentView
        else {
            return false
        }

        return containsParserPreview(
            event.locationInWindow,
            in: contentView
        )
    }

    static func currentMouseDownIsInsideParserPreview(
        relativeTo referenceView: NSView
    ) -> Bool {
        guard let event = NSApp.currentEvent,
            event.type == .leftMouseDown
                || event.type == .rightMouseDown
                || event.type == .otherMouseDown
        else {
            return false
        }

        return clickIsInsideParserPreview(event, relativeTo: referenceView)
    }

    private static func containsParserPreview(
        _ windowLocation: NSPoint,
        in view: NSView
    ) -> Bool {
        if let region = view as? HomeMacSearchInteractionRegionNSView {
            let regionLocation = region.convert(windowLocation, from: nil)
            return region.bounds.insetBy(dx: -2, dy: -2).contains(regionLocation)
        }

        return view.subviews.contains { subview in
            containsParserPreview(windowLocation, in: subview)
        }
    }
}

final class HomeMacSearchOutsideDismissNSView: NSView {
    private var prefersIBeamCursor = false

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func setPrefersIBeamCursor(_ nextValue: Bool) {
        guard prefersIBeamCursor != nextValue else { return }
        prefersIBeamCursor = nextValue

        if let window {
            window.invalidateCursorRects(for: self)
            let pointerLocation = convert(window.mouseLocationOutsideOfEventStream, from: nil)
            if bounds.contains(pointerLocation) {
                (nextValue ? NSCursor.iBeam : NSCursor.arrow).set()
            }
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard prefersIBeamCursor else { return }
        addCursorRect(bounds, cursor: .iBeam)
    }
}
