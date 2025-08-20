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
