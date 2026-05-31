import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct StatsDashboardOrderSupportTests {
    @Test
    func orderedItems_preservesStoredOrderAndAppendsNewDefaults() {
        let ordered = StatsDashboardOrderSupport.normalizedItemIDs(
            defaultItemIDs: ["hero", "average", "chart", "focus"],
            storedRawValue: "chart,hero,unknown,chart"
        )

        #expect(ordered == ["chart", "hero", "average", "focus"])
    }

    @Test
    func movedItemIDs_movesDraggedItemBeforeDropTarget() {
        let movedDown = StatsDashboardOrderSupport.movedItemIDs(
            draggedItemID: "hero",
            before: "focus",
            in: ["hero", "average", "chart", "focus"]
        )
        let movedUp = StatsDashboardOrderSupport.movedItemIDs(
            draggedItemID: "focus",
            before: "average",
            in: ["hero", "average", "chart", "focus"]
        )

        #expect(movedDown == ["average", "chart", "hero", "focus"])
        #expect(movedUp == ["hero", "focus", "average", "chart"])
    }

    @Test
    func storedRawValue_returnsNilWhenOrderMatchesDefault() {
        let defaultIDs = ["hero", "average", "chart"]

        #expect(StatsDashboardOrderSupport.storedRawValue(
            for: defaultIDs,
            defaultItemIDs: defaultIDs
        ) == nil)
        #expect(StatsDashboardOrderSupport.storedRawValue(
            for: ["chart", "hero", "average"],
            defaultItemIDs: defaultIDs
        ) == "chart,hero,average")
    }
}
