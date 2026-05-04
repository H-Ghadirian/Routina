import Foundation

enum GitStatsFileStore {
    static func loadData(filename: String) -> Data? {
        guard
            let url = try? fileURL(filename: filename),
            FileManager.default.fileExists(atPath: url.path)
        else {
            return nil
        }

        return try? Data(contentsOf: url)
    }

    static func load<Value: Decodable>(
        _ type: Value.Type,
        filename: String,
        decoder: JSONDecoder = JSONDecoder()
    ) -> Value? {
        guard let data = loadData(filename: filename) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    static func save<Value: Encodable>(
        _ value: Value,
        filename: String,
        encoder: JSONEncoder = JSONEncoder()
    ) throws {
        let url = try fileURL(filename: filename)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    static func clear(filename: String) throws {
        let url = try fileURL(filename: filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private static func fileURL(filename: String) throws -> URL {
        let applicationSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let storesDirectory = applicationSupportDirectory.appendingPathComponent("RoutinaData", isDirectory: true)
        return storesDirectory.appendingPathComponent(filename)
    }
}
