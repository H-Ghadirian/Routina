import Foundation

struct RoutineVoiceNote: Codable, Equatable, Sendable {
    static let fileExtension = "m4a"
    static let mimeType = "audio/mp4"
    static let defaultFileName = "voice-note.m4a"

    var data: Data
    var durationSeconds: Double?
    var createdAt: Date?

    init?(
        data: Data?,
        durationSeconds: Double?,
        createdAt: Date?
    ) {
        guard let data, !data.isEmpty else { return nil }
        self.init(data: data, durationSeconds: durationSeconds, createdAt: createdAt)
    }

    init(
        data: Data,
        durationSeconds: Double? = nil,
        createdAt: Date? = nil
    ) {
        self.data = data
        self.durationSeconds = durationSeconds.flatMap(Self.sanitizedDurationSeconds)
        self.createdAt = createdAt
    }

    private static func sanitizedDurationSeconds(_ value: Double) -> Double? {
        guard value.isFinite, value > 0 else { return nil }
        return value
    }
}
