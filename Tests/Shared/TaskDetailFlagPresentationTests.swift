import Foundation
import Testing

struct TaskDetailFlagPresentationTests {
    @Test
    func assignedFlagsUseIntrinsicWidthBeforeWrapping() throws {
        let source = try sourceFile("SharedCore/Screens/TaskDetail/TaskDetailHeaderViews.swift")
        let flagsView = try sourceSection(
            startingAt: "struct TaskDetailHeaderFlagsView",
            endingAt: "struct TaskDetailFlagChip",
            in: source
        )

        #expect(flagsView.contains("HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8)"))
        #expect(!flagsView.contains("LazyVGrid"))
        #expect(!flagsView.contains("GridItem(.adaptive(minimum: 160)"))
    }

    private func sourceSection(
        startingAt startMarker: String,
        endingAt endMarker: String,
        in source: String
    ) throws -> String {
        let start = try #require(source.range(of: startMarker))
        let end = try #require(
            source.range(
                of: endMarker,
                range: start.upperBound..<source.endIndex
            )
        )
        return String(source[start.lowerBound..<end.lowerBound])
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
