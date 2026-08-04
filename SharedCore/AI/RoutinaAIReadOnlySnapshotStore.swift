import Foundation
import SwiftData

public struct RoutinaAIReadOnlyCatalog: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var generatedAt: Date
    public var tasks: [RoutinaAITaskSummary]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        generatedAt: Date,
        tasks: [RoutinaAITaskSummary]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.tasks = tasks
    }
}

public enum RoutinaAIReadOnlySnapshotError: LocalizedError {
    case appGroupUnavailable
    case unsupportedSchemaVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "Routina's shared app container is unavailable."
        case let .unsupportedSchemaVersion(version):
            return "The Routina AI snapshot uses unsupported schema version \(version)."
        }
    }
}

public enum RoutinaAIReadOnlySnapshotStore {
    public static let appGroupIdentifier = "group.ir.hamedgh.Routinam"
    public static let productionFileName = "routina_ai_read_only_snapshot.json"
    public static let sandboxFileName = "routina_ai_read_only_snapshot_sandbox.json"

    public static func defaultFileURL(fileManager: FileManager = .default) throws -> URL {
        try defaultFileURL(
            sandboxMode: AppEnvironment.isSandboxDataMode,
            fileManager: fileManager
        )
    }

    public static func defaultFileURL(
        sandboxMode: Bool,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw RoutinaAIReadOnlySnapshotError.appGroupUnavailable
        }
        let fileName = sandboxMode ? sandboxFileName : productionFileName
        return containerURL.appendingPathComponent(fileName, isDirectory: false)
    }

    @MainActor
    public static func refresh(
        using context: ModelContext,
        at fileURL: URL? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> RoutinaAIReadOnlyCatalog {
        let snapshot = try RoutinaAIQueryService.snapshot(
            in: context,
            query: RoutinaAITaskQuery(
                searchText: nil,
                includeArchived: true,
                includeCompleted: true,
                limit: nil
            ),
            now: now,
            calendar: calendar
        )
        let catalog = RoutinaAIReadOnlyCatalog(
            generatedAt: snapshot.generatedAt,
            tasks: snapshot.tasks
        )
        try write(catalog, to: fileURL ?? defaultFileURL())
        return catalog
    }

    public static func load(from fileURL: URL? = nil) throws -> RoutinaAIReadOnlyCatalog {
        let data = try Data(contentsOf: fileURL ?? defaultFileURL())
        let catalog = try decoder.decode(RoutinaAIReadOnlyCatalog.self, from: data)
        guard catalog.schemaVersion == RoutinaAIReadOnlyCatalog.currentSchemaVersion else {
            throw RoutinaAIReadOnlySnapshotError.unsupportedSchemaVersion(catalog.schemaVersion)
        }
        return catalog
    }

    public static func write(
        _ catalog: RoutinaAIReadOnlyCatalog,
        to fileURL: URL? = nil
    ) throws {
        let resolvedURL = try fileURL ?? defaultFileURL()
        let data = try encoder.encode(catalog)
        try data.write(to: resolvedURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: resolvedURL.path
        )
    }

    public static func remove(at fileURL: URL? = nil) throws {
        let resolvedURL = try fileURL ?? defaultFileURL()
        guard FileManager.default.fileExists(atPath: resolvedURL.path) else { return }
        try FileManager.default.removeItem(at: resolvedURL)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
