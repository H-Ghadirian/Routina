#if os(macOS)
    import AppKit
    import Foundation

    @MainActor
    enum RoutinaMacScrollInteractionGate {
        private static let quietWindowMilliseconds: Int64 = 1_200
        private static var eventMonitor: Any?
        private static var lastScrollEventAt = Date.distantPast

        static func start() {
            guard eventMonitor == nil else { return }

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                lastScrollEventAt = Date()
                RoutinaPerformanceProfiler.shared.recordInteraction(.macScrollWheel)
                return event
            }
        }

        static var isScrollActive: Bool {
            start()
            return Date().timeIntervalSince(lastScrollEventAt) < quietWindow
        }

        static var quietRetryDelayMilliseconds: Int64 {
            start()
            let elapsedMilliseconds = Int64((Date().timeIntervalSince(lastScrollEventAt) * 1_000).rounded(.down))
            return max(120, quietWindowMilliseconds - elapsedMilliseconds)
        }

        private static var quietWindow: TimeInterval {
            TimeInterval(quietWindowMilliseconds) / 1_000
        }
    }
#endif
