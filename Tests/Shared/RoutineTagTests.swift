import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

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

    @Test
    func summaries_withDoneCounts_aggregateUsageAndCompletionCountsAcrossTaggedTasks() {
        let taskA = RoutineTask(name: "Read", emoji: "📚", tags: ["Focus", "Learning"], scheduleMode: .fixedInterval)
        let taskB = RoutineTask(name: "Write", emoji: "✍️", tags: ["focus"], scheduleMode: .fixedInterval)
        let taskC = RoutineTask(name: "Walk", emoji: "🚶", tags: ["Health"], scheduleMode: .fixedInterval)

        let summaries = RoutineTag.summaries(
            from: [taskA, taskB, taskC],
            countsByTaskID: [
                taskA.id: 3,
                taskB.id: 2
            ]
        )

        #expect(summaries == [
            RoutineTagSummary(name: "Focus", linkedRoutineCount: 2, doneCount: 5),
            RoutineTagSummary(name: "Health", linkedRoutineCount: 1, doneCount: 0),
            RoutineTagSummary(name: "Learning", linkedRoutineCount: 1, doneCount: 3)
        ])
    }
}
