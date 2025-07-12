import SwiftUI
import RoutinaAppSupport

@main
struct RoutinaTCAApp: App {
    @UIApplicationDelegateAdaptor(RemoteNotificationIOSDelegate.self) private var remoteNotificationDelegate

    var body: some Scene {
        RoutinaIOSRootScene()
    }
}
