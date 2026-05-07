import Foundation

enum RoutinaDeepLink: Equatable, Sendable {
    case task(UUID)
    case sprint(UUID)

    init?(url: URL) {
        guard url.scheme?.lowercased() == "routina" else { return nil }

        let components = url.pathComponents.filter { $0 != "/" }
        if let taskID = Self.targetID(for: "task", url: url, components: components) {
            self = .task(taskID)
            return
        }

        if let sprintID = Self.targetID(for: "sprint", url: url, components: components) {
            self = .sprint(sprintID)
            return
        }

        return nil
    }

    private static func targetID(
        for kind: String,
        url: URL,
        components: [String]
    ) -> UUID? {
        if url.host?.lowercased() == kind,
           let rawID = components.first,
           let id = UUID(uuidString: rawID) {
            return id
        }

        if components.first?.lowercased() == kind,
           components.count > 1,
           let id = UUID(uuidString: components[1]) {
            return id
        }

        return nil
    }

    var url: URL {
        switch self {
        case let .task(taskID):
            return URL(string: "routina://task/\(taskID.uuidString)")!
        case let .sprint(sprintID):
            return URL(string: "routina://sprint/\(sprintID.uuidString)")!
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
