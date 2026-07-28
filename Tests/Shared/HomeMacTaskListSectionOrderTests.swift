import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct HomeMacTaskListSectionOrderTests {
    @Test
    func codingRemovesBlankAndDuplicateSectionIDs() {
        let decoded = HomeMacTaskListSectionOrder.decoded(
            from: "plannedToday:plannedToday\n\nfuture:future\nplannedToday:plannedToday\n"
        )

        #expect(decoded == ["plannedToday:plannedToday", "future:future"])
        #expect(
            HomeMacTaskListSectionOrder.encoded(decoded)
                == "plannedToday:plannedToday\nfuture:future"
        )
    }

    @Test
    func newlyAvailableSectionUsesItsCanonicalNeighbors() {
        let resolved = HomeMacTaskListSectionOrder.visibleSectionIDs(
            preferredIDs: [
                "plannedToday:plannedToday",
                "custom:work",
                "future:future",
            ],
            defaultIDs: [
                "plannedToday:plannedToday",
                "plannedTomorrow:plannedTomorrow",
                "custom:work",
                "future:future",
            ]
        )

        #expect(resolved == [
            "plannedToday:plannedToday",
            "plannedTomorrow:plannedTomorrow",
            "custom:work",
            "future:future",
        ])
    }

    @Test
    func movingVisibleSectionPreservesTemporarilyHiddenPreferenceIDs() {
        let moved = HomeMacTaskListSectionOrder.moving(
            "future:future",
            relativeTo: "plannedToday:plannedToday",
            placement: .before,
            preferredIDs: [
                "plannedToday:plannedToday",
                "custom:hidden",
                "future:future",
            ],
            visibleIDs: [
                "plannedToday:plannedToday",
                "custom:work",
                "future:future",
            ]
        )

        #expect(moved == [
            "future:future",
            "plannedToday:plannedToday",
            "custom:hidden",
            "custom:work",
        ])
    }
}
