import SwiftUI

@main
struct RoutinaWatchExtensionApp: App {
    @StateObject private var syncStore = WatchRoutineSyncStore()

    var body: some Scene {
        WindowGroup {
            WatchHomeView(syncStore: syncStore)
        }
    }
}
