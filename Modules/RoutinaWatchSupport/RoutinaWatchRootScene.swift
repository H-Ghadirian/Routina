import SwiftUI

public struct RoutinaWatchRootScene: Scene {
    public init() {}

    public var body: some Scene {
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
