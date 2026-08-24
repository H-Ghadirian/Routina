import Foundation
import Testing

struct TaskFormMacLayoutRegressionTests {
    @Test
    func effortUsesIndependentValueActionsAndOnlyFocusIsAToggle() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Shared/TaskFormMacEstimationCard.swift"
        )

        #expect(source.contains("TaskFormMacSectionCard(title: TaskFormEffortPresentation.sectionTitle)"))
        #expect(source.components(separatedBy: "TaskFormEffortValueHeader(").count - 1 == 3)
        #expect(source.contains("model.addEstimatedDuration()"))
        #expect(source.contains("model.addActualDuration()"))
        #expect(source.contains("model.addStoryPoints()"))
        #expect(source.contains("Toggle(isOn: model.focusModeEnabled)"))
        #expect(!source.contains("Toggle(\"Set duration estimate\""))
        #expect(!source.contains("Toggle(\"Set actual time spent\""))
        #expect(!source.contains("Toggle(\"Set story points\""))
        #expect(!source.contains("Toggle(\"Show focus timer\""))
    }

    @Test
    func taskLadderValuesShareOneMacCardWithIndependentControlsAndTimeRules() throws {
        let source = try Self.sourceFile(
            "RoutinaMacApp/Screens/Shared/TaskFormContentPlatform.swift"
        )
        let valuesCard = try Self.sourceSection(
            startingAt: "private var taskLadderValuesCard: some View",
            endingAt: "// MARK: Organization",
            in: source
        )

        #expect(valuesCard.contains("TaskTemporalWeightRuleEditor("))
        #expect(valuesCard.contains("importance: model.importance"))
        #expect(valuesCard.contains("urgency: model.urgency"))
        #expect(valuesCard.contains("pressure: model.pressure"))
        #expect(valuesCard.contains("TaskTemporalThinkingSentenceEditor("))
        #expect(valuesCard.contains("maximumBeforeDueDays: model.maximumTemporalWeightBeforeDueDays"))
        #expect(valuesCard.contains("model.temporalWeightAvailabilityMessage"))
        #expect(!valuesCard.contains("RoutinaGlassSegmentedControl"))
        #expect(!valuesCard.contains("ImportanceUrgencyMatrixPicker"))
    }

    @Test
    func changesOverTimeUsesIndependentSentencePickersOnBothPlatforms() throws {
        let source = try Self.sourceFile(
            "SharedCore/Screens/Shared/TaskTemporalWeightRuleEditor.swift"
        )

        #expect(source.contains("Text(\"After done,\")"))
        #expect(source.contains("Text(\"does not change\").tag(false)"))
        #expect(source.contains("Text(\"changes\").tag(true)"))
        #expect(source.contains("ForEach(RoutineTaskTemporalWeightTiming.allCases)"))
        #expect(source.contains("case .gradualBeforeDue:"))
        #expect(source.contains("case .gradualWhileOverdue:"))
        #expect(source.contains("daysPicker("))
        #expect(source.contains(".pickerStyle(.menu)"))
        #expect(source.contains("resets each changing metric to its After done value"))
        #expect(source.contains("maximumBeforeDueDays"))
        #expect(!source.contains(".pickerStyle(.segmented)"))
        #expect(!source.contains("Stepper("))
        #expect(!source.contains("Toggle("))
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
