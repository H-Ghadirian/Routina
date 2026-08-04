import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct RoutinaAIReadOnlySnapshotStoreTests {
    @Test
    func productionAndSandboxExportsUseDifferentNames() {
        #expect(
            RoutinaAIReadOnlySnapshotStore.productionFileName !=
                RoutinaAIReadOnlySnapshotStore.sandboxFileName
        )
        #expect(RoutinaAIReadOnlySnapshotStore.productionFileName.hasSuffix("snapshot.json"))
        #expect(RoutinaAIReadOnlySnapshotStore.sandboxFileName.contains("sandbox"))
    }

    @Test
    func catalogRoundTripsThroughAnExplicitFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("snapshot.json")
        let generatedAt = Date(timeIntervalSince1970: 1_777_777_777)
        let catalog = RoutinaAIReadOnlyCatalog(generatedAt: generatedAt, tasks: [])

        try RoutinaAIReadOnlySnapshotStore.write(catalog, to: fileURL)
        let loaded = try RoutinaAIReadOnlySnapshotStore.load(from: fileURL)

        #expect(loaded == catalog)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        #expect(attributes[.posixPermissions] as? Int == 0o600)
    }

    @Test
    func unsupportedCatalogSchemaIsRejected() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("snapshot.json")
        let catalog = RoutinaAIReadOnlyCatalog(
            schemaVersion: RoutinaAIReadOnlyCatalog.currentSchemaVersion + 1,
            generatedAt: Date(),
            tasks: []
        )
        try RoutinaAIReadOnlySnapshotStore.write(catalog, to: fileURL)

        #expect(throws: RoutinaAIReadOnlySnapshotError.self) {
            _ = try RoutinaAIReadOnlySnapshotStore.load(from: fileURL)
        }
    }

    @Test
    func mcpServerDoesNotOpenRoutinasPersistenceStore() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let serverDirectory = projectRoot
            .appendingPathComponent("Tools/RoutinaAIMCPServer", isDirectory: true)
        let source = try FileManager.default
            .contentsOfDirectory(at: serverDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")

        #expect(!source.contains("PersistenceController"))
        #expect(!source.contains("makeLocalOnlyContainer"))
        #expect(!source.contains("SwiftData"))
        #expect(source.contains("MCPReadOnlySnapshotStore.load"))
        #expect(source.contains(RoutinaAIReadOnlySnapshotStore.productionFileName))
        #expect(source.contains(RoutinaAIReadOnlySnapshotStore.sandboxFileName))
    }
}
