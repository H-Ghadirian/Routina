import Testing
@testable @preconcurrency import RoutinaAppSupport

struct RoutineTagTests {
    @Test
    func parseDraft_splitsCommaAndNewlineSeparatedTags() {
        #expect(
            RoutineTag.parseDraft("  Deep   Work, Health\nmindful focus ,health ")
            == ["Deep Work", "Health", "mindful focus"]
        )
    }

    @Test
    func appendingRemovingAndContains_areCaseAndAccentInsensitive() {
        let appended = RoutineTag.appending("cafe,  CAFE  , Recovery", to: ["Café"])
        #expect(appended == ["Café", "Recovery"])
        #expect(RoutineTag.contains("CAFE", in: appended))
        #expect(RoutineTag.contains("café", in: appended))

        let removed = RoutineTag.removing("cafe", from: appended)
        #expect(removed == ["Recovery"])
    }

    @Test
    func serializeDeserializeAndQuery_roundTripNormalizedTags() {
        let storage = RoutineTag.serialize([" Focus ", "focus", "Deep Work"])
        #expect(storage == "Focus\nDeep Work")
        #expect(RoutineTag.deserialize(storage) == ["Focus", "Deep Work"])
        #expect(RoutineTag.matchesQuery("deep", in: ["Focus", "Deep Work"]))
        #expect(!RoutineTag.matchesQuery("sleep", in: ["Focus", "Deep Work"]))
    }

    @Test
    func allTags_deduplicatesAndSortsAcrossCollections() {
        let tags = RoutineTag.allTags(from: [["Health", "focus"], ["Focus", "Learning"], []])
        #expect(tags == ["focus", "Health", "Learning"])
    }
}
