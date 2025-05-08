import SwiftUI

@main
struct RoutinaTCAApp: App {
    @UIApplicationDelegateAdaptor(RemoteNotificationIOSDelegate.self) private var remoteNotificationDelegate

    var body: some Scene {
        RoutinaIOSRootScene()
    }
}
