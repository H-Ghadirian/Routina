import Foundation

enum SettingsRoutineDataBackupFileNaming {
    static func defaultBackupFileName(
        now: Date = Date(),
        fileExtension: String,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.timeZone = timeZone
        return "routina-backup-\(formatter.string(from: now)).\(fileExtension)"
    }

    static func packageAttachmentFileName(for attachment: RoutineAttachment) -> String {
        packageAttachmentFileName(id: attachment.id, fileName: attachment.fileName)
    }

    static func packageAttachmentFileName(id: UUID, fileName: String) -> String {
        "\(id.uuidString)-\(sanitizedFileName(fileName, fallback: "attachment"))"
    }

    static func sanitizedFileName(_ fileName: String, fallback: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:")
            .union(.newlines)
            .union(.controlCharacters)
        let cleaned = fileName
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? fallback : cleaned
    }
}
