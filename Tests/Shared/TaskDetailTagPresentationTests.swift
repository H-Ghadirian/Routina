import Foundation
import Testing

struct TaskDetailTagPresentationTests {
    @Test
    func taskDetailTagsUseIntrinsicWidthBeforeWrapping() throws {
        let source = try sourceFile("SharedCore/Screens/TaskDetail/TaskDetailHeaderViews.swift")

        #expect(source.contains("HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8)"))
        #expect(!source.contains("GridItem(.adaptive(minimum: 88)"))
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
