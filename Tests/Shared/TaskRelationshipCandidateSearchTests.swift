import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TaskRelationshipCandidateSearchTests {
    @Test
    func filtersCandidatesByCopiedTaskDeepLink() throws {
        let matchingID = try #require(UUID(uuidString: "F2DA44B9-924A-417F-BE62-2B81DF209A75"))
        let otherID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let candidates = [
            candidate(id: otherID, name: "Plan errands"),
            candidate(id: matchingID, name: "Write review"),
        ]

        let matches = TaskRelationshipCandidateSearch.filteredCandidates(
            candidates,
            matching: " routina://task/\(matchingID.uuidString) "
        )

        #expect(matches.map(\.id) == [matchingID])
    }

    @Test
    func filtersCandidatesByCopiedDevTaskDeepLink() throws {
        let matchingID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let otherID = try #require(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let candidates = [
            candidate(id: matchingID, name: "Draft notes"),
            candidate(id: otherID, name: "Inbox"),
        ]

        let matches = TaskRelationshipCandidateSearch.filteredCandidates(
            candidates,
            matching: "routina-dev://task/\(matchingID.uuidString)"
        )

        #expect(matches.map(\.id) == [matchingID])
    }

    @Test
    func keepsExistingNameAndEmojiSearch() {
        let firstID = UUID()
        let secondID = UUID()
        let candidates = [
            candidate(id: firstID, name: "Résumé cleanup", emoji: "🧹"),
            candidate(id: secondID, name: "Groceries", emoji: "🛒"),
        ]

        #expect(TaskRelationshipCandidateSearch.filteredCandidates(candidates, matching: "resume").map(\.id) == [firstID])
        #expect(TaskRelationshipCandidateSearch.filteredCandidates(candidates, matching: "🛒").map(\.id) == [secondID])
    }

    @Test
    func nonmatchingTaskDeepLinkReturnsNoCandidates() throws {
        let candidateID = try #require(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let missingID = try #require(UUID(uuidString: "55555555-5555-5555-5555-555555555555"))

        let matches = TaskRelationshipCandidateSearch.filteredCandidates(
            [candidate(id: candidateID, name: "Existing task")],
            matching: "routina://task/\(missingID.uuidString)"
        )

        #expect(matches.isEmpty)
    }

    private func candidate(
        id: UUID,
        name: String,
        emoji: String = "✨"
    ) -> RoutineTaskRelationshipCandidate {
        RoutineTaskRelationshipCandidate(
            id: id,
            name: name,
            emoji: emoji,
            relationships: []
        )
    }
}
