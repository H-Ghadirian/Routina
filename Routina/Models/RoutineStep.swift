import Foundation

struct RoutineStep: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }

    static func sanitized(_ steps: [RoutineStep]) -> [RoutineStep] {
        steps.compactMap { step in
            guard let title = normalizedTitle(step.title) else { return nil }
            return RoutineStep(id: step.id, title: title)
        }
    }

    static func normalizedTitle(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
