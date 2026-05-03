import Foundation

enum TaskDetailAttachmentPresentation {
    static func taskImageFileName(for task: RoutineTask, data: Data) -> String {
        let baseName = sanitizedAttachmentBaseName(task.name ?? "Routine Image")
        let fileExtension = detectedImageFileExtension(for: data)
        return "\(baseName).\(fileExtension)"
    }

    static func sanitizedAttachmentBaseName(_ rawValue: String) -> String {
        let sanitizedScalars = rawValue.unicodeScalars.map { scalar -> String in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "-"
        }
        let sanitized = sanitizedScalars.joined()
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return sanitized.isEmpty ? "attachment" : sanitized
    }

    static func detectedImageFileExtension(for data: Data) -> String {
        if data.range(of: Data("ftypheic".utf8)) != nil || data.range(of: Data("ftypheix".utf8)) != nil {
            return "heic"
        }

        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }

        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }

        if data.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return "gif"
        }

        if data.starts(with: [0x42, 0x4D]) {
            return "bmp"
        }

        if data.starts(with: [0x52, 0x49, 0x46, 0x46]),
           data.dropFirst(8).starts(with: [0x57, 0x45, 0x42, 0x50]) {
            return "webp"
        }

        if data.starts(with: [0x00, 0x00, 0x01, 0x00]) {
            return "ico"
        }

        if data.starts(with: [0x49, 0x49, 0x2A, 0x00])
            || data.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) {
            return "tiff"
        }

        return "png"
    }
}
