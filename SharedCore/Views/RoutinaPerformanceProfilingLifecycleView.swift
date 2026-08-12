import SwiftUI

/// Keeps the development performance profile aligned with the active scene.
/// It has no layout or hit-test surface and is inert outside Debug builds.
struct RoutinaPerformanceProfilingLifecycleView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                RoutinaPerformanceProfiler.shared.startIfNeeded()
                RoutinaPerformanceProfiler.shared.recordScenePhase("appeared")
            }
            .onChange(of: scenePhase) { _, newPhase in
                RoutinaPerformanceProfiler.shared.recordScenePhase(
                    String(describing: newPhase)
                )
            }
            .onDisappear {
                RoutinaPerformanceProfiler.shared.recordScenePhase("disappeared")
            }
    }
}
