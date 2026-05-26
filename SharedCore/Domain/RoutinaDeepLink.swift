import Foundation

enum RoutinaDeepLink: Equatable, Sendable {
    case task(UUID)
    case goal(UUID)
    case note(UUID)
    case sprint(UUID)

    init?(url: URL) {
        guard url.scheme?.lowercased() == "routina" else { return nil }

        let components = url.pathComponents.filter { $0 != "/" }
        if let taskID = Self.targetID(for: "task", url: url, components: components) {
            self = .task(taskID)
            return
        }

        if let goalID = Self.targetID(for: "goal", url: url, components: components) {
            self = .goal(goalID)
            return
        }

        if let noteID = Self.targetID(for: "note", url: url, components: components) {
            self = .note(noteID)
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
        case let .goal(goalID):
            return URL(string: "routina://goal/\(goalID.uuidString)")!
        case let .note(noteID):
            return URL(string: "routina://note/\(noteID.uuidString)")!
        case let .sprint(sprintID):
            return URL(string: "routina://sprint/\(sprintID.uuidString)")!
        }
    }
}

extension Notification.Name {
    static let routinaOpenDeepLink = Notification.Name("routinaOpenDeepLink")
    static let routinaOpenActiveFocus = Notification.Name("routinaOpenActiveFocus")
}

enum RoutinaDeepLinkNotificationKey: String {
    case deepLink
}

enum RoutinaDeepLinkUserInfoKey: String {
    case url = "routinaDeepLinkURL"
}

extension RoutinaDeepLink {
    init?(notificationUserInfo userInfo: [AnyHashable: Any]) {
        guard
            let rawURL = userInfo[RoutinaDeepLinkUserInfoKey.url.rawValue] as? String,
            let url = URL(string: rawURL)
        else {
            return nil
        }
        self.init(url: url)
    }

    var notificationUserInfo: [String: String] {
        [
            RoutinaDeepLinkUserInfoKey.url.rawValue: url.absoluteString
        ]
    }
}

@MainActor
enum RoutinaActiveFocusOpenDispatcher {
    private static let pendingOpenActiveFocusDefaultsKey = "routina.pendingOpenActiveFocus"
    private static let activeFocusDeepLinkDefaultsKey = "routina.activeFocusDeepLinkURL"

    static func requestOpen() {
        SharedDefaults.app.set(true, forKey: pendingOpenActiveFocusDefaultsKey)
        NotificationCenter.default.post(name: .routinaOpenActiveFocus, object: nil)
    }

    @discardableResult
    static func consumePendingRequest() -> Bool {
        let isPending = SharedDefaults.app.bool(forKey: pendingOpenActiveFocusDefaultsKey)
        SharedDefaults.app.removeObject(forKey: pendingOpenActiveFocusDefaultsKey)
        return isPending
    }

    static func recordActiveFocusDeepLink(_ deepLink: RoutinaDeepLink) {
        SharedDefaults.app.set(deepLink.url.absoluteString, forKey: activeFocusDeepLinkDefaultsKey)
    }

    static func clearActiveFocusDeepLink() {
        SharedDefaults.app.removeObject(forKey: activeFocusDeepLinkDefaultsKey)
    }

    static func recordedActiveFocusDeepLink() -> RoutinaDeepLink? {
        guard
            let rawURL = SharedDefaults.app.string(forKey: activeFocusDeepLinkDefaultsKey),
            let url = URL(string: rawURL)
        else {
            return nil
        }
        return RoutinaDeepLink(url: url)
    }

}

@MainActor
enum RoutinaDeepLinkDispatcher {
    private static let pendingDeepLinkDefaultsKey = "routina.pendingDeepLinkURL"
    private static var pendingDeepLink: RoutinaDeepLink?

    static func open(_ deepLink: RoutinaDeepLink) {
        pendingDeepLink = deepLink
        SharedDefaults.app.set(deepLink.url.absoluteString, forKey: pendingDeepLinkDefaultsKey)
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
        defer { clearPendingDeepLink() }
        if let pendingDeepLink {
            return pendingDeepLink
        }
        guard
            let rawURL = SharedDefaults.app.string(forKey: pendingDeepLinkDefaultsKey),
            let url = URL(string: rawURL)
        else {
            return nil
        }
        return RoutinaDeepLink(url: url)
    }

    static func markHandled(_ deepLink: RoutinaDeepLink) {
        if pendingDeepLink == deepLink {
            clearPendingDeepLink()
            return
        }

        guard
            let rawURL = SharedDefaults.app.string(forKey: pendingDeepLinkDefaultsKey),
            let url = URL(string: rawURL),
            RoutinaDeepLink(url: url) == deepLink
        else {
            return
        }
        clearPendingDeepLink()
    }

    private static func clearPendingDeepLink() {
        pendingDeepLink = nil
        SharedDefaults.app.removeObject(forKey: pendingDeepLinkDefaultsKey)
    }
}
