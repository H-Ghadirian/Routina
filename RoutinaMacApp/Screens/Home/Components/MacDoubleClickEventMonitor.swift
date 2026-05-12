import AppKit
import SwiftUI

extension View {
    func onMacDoubleClick(enabled: Bool = true, perform action: @escaping () -> Void) -> some View {
        background(
            MacDoubleClickEventMonitor(enabled: enabled, action: action)
                .allowsHitTesting(false)
        )
    }
}

private struct MacDoubleClickEventMonitor: NSViewRepresentable {
    var enabled: Bool
    var action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(enabled: enabled, action: action)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.update(enabled: enabled, action: action, view: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(enabled: enabled, action: action, view: nsView)
    }

    final class Coordinator: @unchecked Sendable {
        private var enabled: Bool
        private var action: () -> Void
        private weak var view: NSView?
        private var monitor: Any?

        init(enabled: Bool, action: @escaping () -> Void) {
            self.enabled = enabled
            self.action = action
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func update(enabled: Bool, action: @escaping () -> Void, view: NSView) {
            self.enabled = enabled
            self.action = action
            self.view = view

            if monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                    let clickCount = event.clickCount
                    let locationInWindow = event.locationInWindow
                    let windowNumber = event.windowNumber

                    MainActor.assumeIsolated {
                        self?.handle(
                            clickCount: clickCount,
                            locationInWindow: locationInWindow,
                            windowNumber: windowNumber
                        )
                    }
                    return event
                }
            }
        }

        @MainActor
        private func handle(
            clickCount: Int,
            locationInWindow: CGPoint,
            windowNumber: Int
        ) {
            guard enabled,
                  clickCount == 2,
                  let view,
                  view.window?.windowNumber == windowNumber else {
                return
            }

            let location = view.convert(locationInWindow, from: nil)
            guard view.bounds.contains(location) else { return }

            action()
        }
    }
}
