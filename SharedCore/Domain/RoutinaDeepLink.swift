import Foundation

enum RoutinaDeepLink: Equatable {
    case task(UUID)

    init?(url: URL) {
        guard url.scheme?.lowercased() == "routina" else { return nil }

        let components = url.pathComponents.filter { $0 != "/" }
        if url.host?.lowercased() == "task",
           let rawTaskID = components.first,
           let taskID = UUID(uuidString: rawTaskID) {
            self = .task(taskID)
            return
        }

        if components.first?.lowercased() == "task",
           components.count > 1,
           let taskID = UUID(uuidString: components[1]) {
            self = .task(taskID)
            return
        }

        return nil
    }

    var url: URL {
        switch self {
        case let .task(taskID):
            return URL(string: "routina://task/\(taskID.uuidString)")!
        }
    }
}

extension Notification.Name {
    static let routinaOpenDeepLink = Notification.Name("routinaOpenDeepLink")
}

enum RoutinaDeepLinkNotificationKey: String {
    case deepLink
}

@MainActor
enum RoutinaDeepLinkDispatcher {
    private static var pendingDeepLink: RoutinaDeepLink?

    static func open(_ deepLink: RoutinaDeepLink) {
        pendingDeepLink = deepLink
        NotificationCenter.default.post(
            name: .routinaOpenDeepLink,
            object: nil,
            userInfo: [
                RoutinaDeepLinkNotificationKey.deepLink.rawValue: deepLink
            ]
        )
    }

    static func deepLink(from notification: Notification) -> RoutinaDeepLink? {
        notification.userInfo?[RoutinaDeepLinkNotificationKey.deepLink.rawValue] as? RoutinaDeepLink
    }

    static func consumePendingDeepLink() -> RoutinaDeepLink? {
        defer { pendingDeepLink = nil }
        return pendingDeepLink
    }

    static func markHandled(_ deepLink: RoutinaDeepLink) {
        guard pendingDeepLink == deepLink else { return }
        pendingDeepLink = nil
    }
}
