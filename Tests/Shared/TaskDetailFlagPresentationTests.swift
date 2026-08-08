import Foundation
import Testing

struct TaskDetailFlagPresentationTests {
    @Test
    func assignedFlagsUseTheirAvailableWidthBeforeTruncating() throws {
        let source = try sourceFile("SharedCore/Screens/TaskDetail/TaskDetailHeaderViews.swift")

        #expect(source.contains("if flags.count == 1, let flag = flags.first"))
        #expect(source.contains("columns: [GridItem(.adaptive(minimum: 160), spacing: 8)]"))
    }

    private func sourceFile(_ relativePath: String) throws -> String {
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
