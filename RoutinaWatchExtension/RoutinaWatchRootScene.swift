import SwiftUI

struct RoutinaWatchRootScene: Scene {
    var body: some Scene {
        WindowGroup {
            RoutinaWatchRootView()
        }
    }
}

private struct RoutinaWatchRootView: View {
    @StateObject private var syncStore = WatchRoutineSyncStore()

    var body: some View {
        WatchHomeView(syncStore: syncStore)
    }
}
