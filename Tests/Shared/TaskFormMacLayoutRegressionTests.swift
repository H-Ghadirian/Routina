import Foundation
import Testing

struct TaskFormMacLayoutRegressionTests {
    @Test
    func taskLadderValuesShareOneMacCardWithIndependentControlsAndTimeRules() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Shared/TaskFormContentPlatform.swift"
        )
        let valuesCard = try Self.sourceSection(
            startingAt: "private var taskLadderValuesCard: some View",
            endingAt: "private func taskLadderControl",
            in: source
        )

        for label in ["Importance", "Urgency", "Pressure", "Thinking needed"] {
            #expect(valuesCard.contains("accessibilityLabel: \"\(label)\""))
        }
        #expect(valuesCard.contains("Label(\"Changes over time\""))
        #expect(valuesCard.contains("TaskTemporalWeightRuleEditor("))
        #expect(valuesCard.contains("model.temporalWeightAvailabilityMessage"))
        #expect(!valuesCard.contains("ImportanceUrgencyMatrixPicker"))
    }

    @Test
    func eligibleOneOffTasksShowAutoAssumeDoneBesideTheirAvailabilityControls() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Shared/TaskFormMacCards.swift"
        )
        let schedulingMainColumn = try Self.sourceSection(
            startingAt: "private var schedulingMainColumn: some View",
            endingAt: "private var schedulingSupportColumn: some View",
            in: source
        )

        #expect(
            schedulingMainColumn.contains(
                """
                if model.taskType.wrappedValue == .todo {
                                availabilityControl

                                if showsAssumedDoneControl {
                                    assumedDoneControl
                                }
                """
            )
        )
    }

    @Test
    func repeatingTaskFormsExposePathTagsFlagsAndTaskLadderGroupInOrganization() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Shared/TaskFormContentPlatform.swift"
        )
        let organization = try Self.sourceSection(
            startingAt: "private var organizationCard: some View",
            endingAt: "private var estimationCard: some View",
            in: source
        )

        #expect(organization.contains("TaskFormMacPathControl(model: model)"))
        #expect(organization.contains("TaskFormMacTagsContent(model: model)"))
        #expect(organization.contains("TaskFormMacTaskLadderGroupControl(model: model)"))
        #expect(organization.contains("model.taskType.wrappedValue == .routine"))
    }

    @Test
    func macProgressiveFormsCountFlagsWhenDerivingVisibleSections() throws {
        let source = try Self.sourceFile("RoutinaMacApp/FormSection.swift")
        let sharedPredicateCall = "TaskFormTagFlagSectionPresentation.hasContent("
        let callCount = source.components(separatedBy: sharedPredicateCall).count - 1

        #expect(callCount == 3)
        #expect(source.contains("routineFlags: routineFlags"))
        #expect(source.contains("routineFlags: organization.routineFlags"))
        #expect(source.contains("routineFlags: editRoutineFlags"))
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
