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
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
