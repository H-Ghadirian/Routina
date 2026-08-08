import Foundation
import Testing

struct MacSleepMenuAvailabilityTests {
    @Test
    func applicationMenuHidesSleepWhenAwayIsDisabled() throws {
        let commands = try Self.sourceFile("RoutinaMacApp/Commands/RoutineCommands.swift")

        #expect(commands.contains("private var isAwayEnabled = false"))
        #expect(commands.contains("if isAwayEnabled {\n                Button(\"Going to Sleep\") {"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectRoot = testsDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
