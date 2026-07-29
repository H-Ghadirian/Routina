import Foundation
import Testing

struct TaskDetailPlatformActionParityTests {
    @Test
    func iosOneDayRoutineActionsOmitTheMacAbsentOngoingStart() throws {
        let source = try Self.sourceFile(
            "iOS/Screens/TaskDetail/TaskDetailActionControls.swift"
        )
        let routineActions = try Self.sourceSection(
            startingAt: "struct TaskDetailRoutinePrimaryActionSection",
            endingAt: "struct TaskDetailPrimaryActionButton",
            in: source
        )

        #expect(!routineActions.contains("Start ongoing"))
        #expect(!routineActions.contains("startOngoingButton"))
        #expect(!routineActions.contains(".startOngoingTapped"))
        #expect(routineActions.contains("pauseResumeButton"))
        #expect(routineActions.contains("notTodayButton"))
    }

    @Test
    func multiDayPrimaryActionKeepsStartAndStopLifecycle() throws {
        let source = try Self.sourceFile(
            "SharedCore/Features/TaskDetail/TaskDetailFeature+Presentation.swift"
        )

        #expect(source.contains("if task.isMultiDayRoutine"))
        #expect(source.contains("return .startOngoingTapped"))
        #expect(source.contains("return .finishOngoingTapped"))
        #expect(source.contains("return \"play.circle.fill\""))
        #expect(source.contains("return \"stop.circle.fill\""))
    }

    private static func sourceSection(
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
