import Testing
@testable @preconcurrency import RoutinaMacOSDev

struct FormSectionTests {
    @Test
    func taskFormSectionsIncludeIdentityAndDangerZoneWhenRequested() {
        let sections = FormSection.taskFormSections(
            scheduleMode: .fixedInterval,
            includesIdentity: true,
            includesDangerZone: true
        )

        #expect(sections.first == .identity)
        #expect(sections.contains(.steps))
        #expect(Array(sections.suffix(4)) == [.image, .voiceNote, .attachment, .dangerZone])
    }

    @Test
    func taskFormSectionsHideStepsForChecklistDerivedRoutines() {
        let sections = FormSection.taskFormSections(
            scheduleMode: .derivedFromChecklist,
            includesIdentity: false,
            includesDangerZone: false
        )

        #expect(!sections.contains(.identity))
        #expect(!sections.contains(.steps))
        #expect(Array(sections.suffix(3)) == [.image, .voiceNote, .attachment])
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
            isShowingMoreDetails: false,
            populatedSections: [.notes, .tags]
        )
        let expanded = FormSection.visibleTaskFormSections(
            from: sections,
            mode: .progressiveCreate,
            isShowingMoreDetails: true,
            populatedSections: [.notes, .tags]
        )

        #expect(collapsed == [.identity, .behavior, .tags, .notes])
        #expect(expanded == sections)
    }
}
