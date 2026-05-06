import Foundation

struct RoutineTaskComment: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID
    var body: String
    var createdAt: Date
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.body = Self.sanitizedBody(body) ?? ""
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func sanitizedBody(_ body: String?) -> String? {
        guard let trimmed = body?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}

enum RoutineTaskCommentStorage {
    static func serialize(_ comments: [RoutineTaskComment]) -> String {
        let sanitizedComments = sanitized(comments)
        guard !sanitizedComments.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sanitizedComments),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> [RoutineTaskComment] {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([RoutineTaskComment].self, from: data) else {
            return []
        }
        return sanitized(decoded)
    }

    static func sanitized(_ comments: [RoutineTaskComment]) -> [RoutineTaskComment] {
        comments
            .compactMap { comment -> RoutineTaskComment? in
                guard let body = RoutineTaskComment.sanitizedBody(comment.body) else { return nil }
                var sanitizedComment = comment
                sanitizedComment.body = body
                return sanitizedComment
            }
    }
}
