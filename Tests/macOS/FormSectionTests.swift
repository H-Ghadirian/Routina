import Foundation
import Testing
@testable @preconcurrency import RoutinaMacOSDev

@MainActor
struct FormSectionTests {
    @Test
    func behaviorCardTitleMatchesSidebarSectionTitle() {
        #expect(TaskFormMacBehaviorCard.sectionTitle == FormSection.behavior.title)
        #expect(TaskFormMacBehaviorCard.sectionTitle == "Behavior & Schedule")
    }

    @Test
    func wideTaskFormsKeepReadableContentBounds() {
        #expect(TaskFormMacLayoutMetrics.maximumFullFormWidth == 1_280)
        #expect(TaskFormMacLayoutMetrics.behaviorMainColumnWidth == 760)
        #expect(TaskFormMacLayoutMetrics.behaviorSupportColumnWidth == 320)
        #expect(
            TaskFormMacLayoutMetrics.maximumBehaviorContentWidth
                < TaskFormMacLayoutMetrics.maximumFullFormWidth
        )
        #expect(TaskFormMacLayoutMetrics.schedulePreviewWidth < TaskFormMacLayoutMetrics.behaviorMainColumnWidth)
    }

    @Test
    func routineBehaviorKeepsCadenceDependenciesAfterTheRepeatControl() {
        #expect(
            TaskFormMacRoutineBehaviorModule.stableOrder
                == [.completion, .repeatPattern, .scheduleDetails]
        )
        #expect(
            TaskFormMacScheduleDetailsPresentation.summary(
                duration: .multiDay,
                timing: .none,
                behavior: .fixed
            ) == "Multi-day · Any time · Due"
        )
        #expect(
            TaskFormMacScheduleDetailsPresentation.summary(
                duration: .oneDay,
                timing: .none,
                behavior: nil,
                includesCadenceDetails: false
            ) == "Planning"
        )
    }

    @Test
    func routinePlanningStaysOutOfTheOptionalSectionCatalog() {
        #expect(
            TaskFormMacPlanningPlacement.resolve(
                taskType: .routine,
                supportsPlanning: false
            ) == .unavailable
        )
        #expect(
            TaskFormMacPlanningPlacement.resolve(
                taskType: .routine,
                supportsPlanning: true
            ) == .scheduleDetails
        )
        #expect(
            TaskFormMacPlanningPlacement.resolve(
                taskType: .routine,
                supportsPlanning: true
            ) == .scheduleDetails
        )
        #expect(
            TaskFormMacPlanningPlacement.resolve(
                taskType: .todo,
                supportsPlanning: true
            ) == .standaloneSection
        )
    }

    @Test
    func desktopRecurrenceControlsUseNaturalWidthWithoutForcedRows() {
        #expect(!UnifiedRecurrenceEditorLayout.desktop.fillsSegmentedControlWidth)
        #expect(UnifiedRecurrenceEditorLayout.desktop.cadenceMaximumSegmentsPerRow == nil)
        #expect(UnifiedRecurrenceEditorLayout.desktop.frequencyMaximumSegmentsPerRow == nil)
        #expect(UnifiedRecurrenceEditorLayout.desktop.fixedDetailsMaximumWidth == 520)

        #expect(UnifiedRecurrenceEditorLayout.compact.fillsSegmentedControlWidth)
        #expect(UnifiedRecurrenceEditorLayout.compact.cadenceMaximumSegmentsPerRow == 2)
        #expect(UnifiedRecurrenceEditorLayout.compact.frequencyMaximumSegmentsPerRow == 3)
    }

    @Test
    func afterCompletionRecurrenceDoesNotRepeatItsEditableRuleAsASummary() {
        #expect(!UnifiedRecurrenceSummaryPolicy.showsSummary(for: .afterCompletion))
        #expect(UnifiedRecurrenceSummaryPolicy.showsSummary(for: .scheduled))
        #expect(UnifiedRecurrenceSummaryPolicy.showsSummary(for: .none))
        #expect(UnifiedRecurrenceSummaryPolicy.showsSummary(for: .itemRunout))
    }

    @Test
    func taskFormSectionsIncludeIdentityAndDangerZoneWhenRequested() {
        let sections = FormSection.taskFormSections(
            scheduleMode: .fixedInterval,
            includesIdentity: true,
            includesDangerZone: true
        )
        let valuesIndex = sections.firstIndex(of: .taskLadderValues)
        let organizationIndex = sections.firstIndex(of: .organization)
        let estimationIndex = sections.firstIndex(of: .estimation)

        #expect(sections.first == .identity)
        #expect(sections.contains(.emoji))
        #expect(sections.contains(.taskLadderValues))
        #expect(organizationIndex == valuesIndex.map { sections.index(after: $0) })
        #expect(estimationIndex != nil)
        #expect(sections.contains(.steps))
        #expect(sections.contains(.checklist))
        #expect(Array(sections.suffix(5)) == [.checklist, .image, .voiceNote, .attachment, .dangerZone])
    }

    @Test
    func taskFormSectionsHideStepsForChecklistDerivedRoutines() {
        let sections = FormSection.taskFormSections(
            scheduleMode: .derivedFromChecklist,
            includesIdentity: false,
            includesDangerZone: false
        )

        #expect(!sections.contains(.identity))
        #expect(sections.contains(.emoji))
        #expect(!sections.contains(.steps))
        #expect(sections.contains(.checklist))
        #expect(Array(sections.suffix(4)) == [.checklist, .image, .voiceNote, .attachment])
    }

    @Test
    func progressiveTaskFormSectionsKeepCoreAndPopulatedSectionsCollapsed() {
        let sections = FormSection.taskFormSections(
            scheduleMode: .oneOff,
            includesIdentity: true,
            includesDangerZone: true
        )

        let collapsed = FormSection.visibleTaskFormSections(
            from: sections,
            mode: .progressiveCreate,
            revealedSections: [],
            populatedSections: [.notes, .organization]
        )
        let expanded = FormSection.visibleTaskFormSections(
            from: sections,
            mode: .progressiveCreate,
            revealedSections: Set(sections),
            populatedSections: [.notes, .organization]
        )

        #expect(collapsed == [.identity, .behavior, .taskLadderValues, .organization, .notes, .dangerZone])
        #expect(!collapsed.contains(.emoji))
        #expect(!collapsed.contains(.image))
        #expect(expanded == sections)
    }

    @Test
    func progressiveTaskFormRevealsPopulatedEmojiAndImageOutsideIdentity() {
        let sections = FormSection.taskFormSections(
            scheduleMode: .oneOff,
            includesIdentity: true,
            includesDangerZone: false
        )

        let visible = FormSection.visibleTaskFormSections(
            from: sections,
            mode: .progressiveEdit,
            revealedSections: [],
            populatedSections: [.emoji, .image]
        )

        #expect(visible.contains(.identity))
        #expect(visible.contains(.emoji))
        #expect(visible.contains(.image))
    }

    @Test
    func progressiveTaskFormSectionsDoNotRevealEmptyRoutineChecklistDetails() {
        let sections = FormSection.taskFormSections(
            scheduleMode: .fixedInterval,
            includesIdentity: true,
            includesDangerZone: false
        )

        let revealed = FormSection.visibleTaskFormSections(
            from: sections,
            mode: .progressiveCreate,
            revealedSections: [.checklist],
            populatedSections: [],
            allowsOptionalChecklistReveal: false
        )
        let populated = FormSection.visibleTaskFormSections(
            from: sections,
            mode: .progressiveCreate,
            revealedSections: [],
            populatedSections: [.checklist],
            allowsOptionalChecklistReveal: false
        )

        #expect(!revealed.contains(.checklist))
        #expect(populated.contains(.checklist))
    }

    @Test
    func progressiveTaskFormSectionsKeepTodoChecklistRevealAvailable() {
        let sections = FormSection.taskFormSections(
            scheduleMode: .oneOff,
            includesIdentity: true,
            includesDangerZone: false
        )

        let visible = FormSection.visibleTaskFormSections(
            from: sections,
            mode: .progressiveCreate,
            revealedSections: [.checklist],
            populatedSections: [],
            allowsOptionalChecklistReveal: true
        )

        #expect(visible.contains(.checklist))
    }
}
