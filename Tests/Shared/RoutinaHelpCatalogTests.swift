import Testing
#if SWIFT_PACKAGE
@testable import RoutinaHelpSupport
#elseif os(macOS)
@testable import RoutinaMacOSDev
#else
@testable import Routina
#endif

struct RoutinaHelpCatalogTests {
    @Test
    func topicIDsAreUniqueAndResolveBackToTheirTopics() {
        let ids = RoutinaHelpCatalog.topics.map(\.id)

        #expect(Set(ids).count == ids.count)
        for topic in RoutinaHelpCatalog.topics {
            #expect(RoutinaHelpCatalog.topic(id: topic.id) == topic)
        }
    }

    @Test
    func taskLadderQuestionFindsTaskLadderFirst() {
        let results = RoutinaHelpCatalog.search("What is Task Ladder?")

        #expect(results.first?.id == "task-ladder")
        #expect(results.first?.platforms == ["macOS"])
    }

    @Test
    func naturalCalendarCountQuestionFindsDayCountExplanationFirst() {
        let results = RoutinaHelpCatalog.search(
            "What are the numbers on top of each day columns in calendar?"
        )

        #expect(results.first?.id == "planner-day-counts")
        #expect(results.first?.details.contains(where: { $0.contains("Planned tasks") }) == true)
        #expect(results.first?.details.contains(where: { $0.contains("Assumed done") }) == true)
        #expect(results.first?.details.contains(where: { $0.contains("Dones") }) == true)
    }

    @Test
    func helpSearchHonorsItsLimit() {
        let results = RoutinaHelpCatalog.search("task calendar planner", limit: 2)

        #expect(results.count == 2)
    }

    @Test
    func starterQuestionsAreCoveredByTheCatalog() {
        for question in RoutinaHelpCatalog.starterQuestions {
            #expect(
                !RoutinaHelpCatalog.search(question, limit: 1).isEmpty,
                "Missing help coverage for: \(question)"
            )
        }
    }
}
