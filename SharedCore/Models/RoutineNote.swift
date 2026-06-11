import Foundation
import SwiftData

@Model
final class RoutineNote {
    var id: UUID = UUID()
    var title: String?
    var body: String?
    var tagsStorage: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var voiceNoteData: Data?
    var voiceNoteDurationSeconds: Double?
    var voiceNoteCreatedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    var displayTitle: String {
        if let title = Self.cleanedText(title) {
            return title
        }
        if let firstLine = body?
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .compactMap(Self.cleanedText)
            .first {
            return firstLine
        }
        return "Untitled note"
    }

    var isStatusNote: Bool {
        RoutineTag.contains("Status", in: tags)
    }

    var detailDisplayTitle: String {
        if isStatusNote, Self.cleanedText(title) == nil {
            return "Status update"
        }

        return displayTitle
    }

    var hasImage: Bool {
        imageData?.isEmpty == false
    }

    var tags: [String] {
        get { RoutineTag.deserialize(tagsStorage) }
        set { tagsStorage = RoutineTag.serialize(newValue) }
    }

    var hasVoiceNote: Bool {
        voiceNoteData?.isEmpty == false
    }

    var voiceNote: RoutineVoiceNote? {
        get {
            RoutineVoiceNote(
                data: voiceNoteData,
                durationSeconds: voiceNoteDurationSeconds,
                createdAt: voiceNoteCreatedAt
            )
        }
        set {
            voiceNoteData = newValue?.data
            voiceNoteDurationSeconds = newValue?.durationSeconds
            voiceNoteCreatedAt = newValue?.createdAt
            updatedAt = Date()
        }
    }

    var hasContent: Bool {
        Self.cleanedText(title) != nil
            || Self.cleanedText(body) != nil
            || hasImage
            || hasVoiceNote
    }

    init(
        id: UUID = UUID(),
        title: String? = nil,
        body: String? = nil,
        tags: [String] = [],
        imageData: Data? = nil,
        voiceNoteData: Data? = nil,
        voiceNoteDurationSeconds: Double? = nil,
        voiceNoteCreatedAt: Date? = nil,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date()
    ) {
        self.id = id
        self.title = Self.cleanedText(title)
        self.body = Self.cleanedText(body)
        self.tagsStorage = RoutineTag.serialize(tags)
        self.imageData = imageData?.isEmpty == false ? imageData : nil
        let sanitizedVoiceNote = RoutineVoiceNote(
            data: voiceNoteData,
            durationSeconds: voiceNoteDurationSeconds,
            createdAt: voiceNoteCreatedAt
        )
        self.voiceNoteData = sanitizedVoiceNote?.data
        self.voiceNoteDurationSeconds = sanitizedVoiceNote?.durationSeconds
        self.voiceNoteCreatedAt = sanitizedVoiceNote?.createdAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func detachedCopy() -> RoutineNote {
        RoutineNote(
            id: id,
            title: title,
            body: body,
            tags: tags,
            imageData: imageData,
            voiceNoteData: voiceNoteData,
            voiceNoteDurationSeconds: voiceNoteDurationSeconds,
            voiceNoteCreatedAt: voiceNoteCreatedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func cleanedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension RoutineNote: Equatable {
    static func == (lhs: RoutineNote, rhs: RoutineNote) -> Bool {
        lhs.id == rhs.id
    }
}

@Model
final class RoutineNoteAttachment {
    var id: UUID = UUID()
    var noteID: UUID = UUID()
    var fileName: String = ""
    @Attribute(.externalStorage) var data: Data = Data()
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        noteID: UUID,
        fileName: String,
        data: Data,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.noteID = noteID
        self.fileName = RoutineNoteAttachment.cleanedFileName(fileName)
        self.data = data
        self.createdAt = createdAt
    }

    static func cleanedFileName(_ value: String) -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "attachment" : cleaned
    }
}

extension RoutineNoteAttachment: Equatable {
    static func == (lhs: RoutineNoteAttachment, rhs: RoutineNoteAttachment) -> Bool {
        lhs.id == rhs.id
    }
}

enum RoutineNoteMediaSummary {
    static func text(
        hasImage: Bool,
        hasFileAttachment: Bool,
        hasVoiceNote: Bool
    ) -> String? {
        var parts: [String] = []
        if hasImage {
            parts.append("image")
        }
        if hasFileAttachment {
            parts.append("file")
        }
        if hasVoiceNote {
            parts.append("voice")
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
