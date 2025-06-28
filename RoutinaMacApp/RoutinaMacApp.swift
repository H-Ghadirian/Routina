import SwiftUI

@main
struct RoutinaMacApp: App {
    @NSApplicationDelegateAdaptor(RemoteNotificationMacDelegate.self) private var remoteNotificationDelegate

    var body: some Scene {
        RoutinaMacRootScene()
    }
}
