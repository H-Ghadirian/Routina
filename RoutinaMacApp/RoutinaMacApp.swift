import SwiftUI
import RoutinaAppSupport
import RoutinaMacSupport

@main
struct RoutinaMacApp: App {
    @NSApplicationDelegateAdaptor(RemoteNotificationMacDelegate.self) private var remoteNotificationDelegate

    var body: some Scene {
        RoutinaMacRootScene()
    }
}
