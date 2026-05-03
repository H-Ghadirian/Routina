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
        #expect(Array(sections.suffix(3)) == [.image, .attachment, .dangerZone])
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
        #expect(Array(sections.suffix(2)) == [.image, .attachment])
    }
}
