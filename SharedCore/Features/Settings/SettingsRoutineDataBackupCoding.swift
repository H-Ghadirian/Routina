import Foundation

enum SettingsRoutineDataBackupCoding {
    static func encode(_ backup: SettingsRoutineDataPersistence.Backup) throws -> Data {
        try makeEncoder().encode(backup)
    }

    static func decodeBackup(from data: Data) throws -> SettingsRoutineDataPersistence.Backup {
        try makeDecoder().decode(SettingsRoutineDataPersistence.Backup.self, from: data)
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
