import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct FocusSessionTagRecencyTests {
    @Test
    func ordersPreviouslyUsedTagsByMostRecentFocusStart() {
        let olderFocus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            tagName: "Chores"
        )
        let newerFocus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: Date(timeIntervalSinceReferenceDate: 200),
            tagName: "Bathroom"
        )

        #expect(
            FocusSessionTagRecency.orderedAvailableTags(
                ["Bathroom", "Bug", "Chores", "Cleaning"],
                focusSessions: [olderFocus, newerFocus]
            ) == ["Bathroom", "Chores", "Bug", "Cleaning"]
        )
    }

    @Test
    func ignoresFocusTagsThatAreNoLongerAvailable() {
        let removedTagFocus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: Date(timeIntervalSinceReferenceDate: 300),
            tagName: "Removed"
        )

        #expect(
            FocusSessionTagRecency.orderedAvailableTags(
                ["Bug", "Chores"],
                focusSessions: [removedTagFocus]
            ) == ["Bug", "Chores"]
        )
    }
}

@MainActor
struct FocusSessionStartDefaultsTests {
    @Test
    func defaultsToTwentyFiveMinutesWithoutAttributedHistory() {
        let unassignedFocus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: Date(timeIntervalSinceReferenceDate: 300),
            plannedDurationSeconds: 45 * 60
        )

        #expect(
            FocusSessionStartDefaults.latest(
                focusSessions: [unassignedFocus],
                availableTags: ["HSE"]
            ) == FocusSessionStartDefaults(duration: 25 * 60, tagName: nil)
        )
    }

    @Test
    func restoresLatestAttributedDurationAndAvailableTag() {
        let olderTaskFocus = FocusSession(
            taskID: UUID(),
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            plannedDurationSeconds: 45 * 60
        )
        let latestTagFocus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: Date(timeIntervalSinceReferenceDate: 200),
            plannedDurationSeconds: 0,
            tagName: "hse"
        )
        let newerUnassignedFocus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: Date(timeIntervalSinceReferenceDate: 300),
            plannedDurationSeconds: 90 * 60
        )

        #expect(
            FocusSessionStartDefaults.latest(
                focusSessions: [olderTaskFocus, latestTagFocus, newerUnassignedFocus],
                availableTags: ["HSE", "Buy"]
            ) == FocusSessionStartDefaults(duration: 0, tagName: "HSE")
        )
    }

    @Test
    func keepsLatestDurationWithoutPreselectingUnavailableTag() {
        let latestTagFocus = FocusSession(
            taskID: FocusSession.unassignedTaskID,
            startedAt: Date(timeIntervalSinceReferenceDate: 200),
            plannedDurationSeconds: 15 * 60,
            tagName: "Removed"
        )

        #expect(
            FocusSessionStartDefaults.latest(
                focusSessions: [latestTagFocus],
                availableTags: ["HSE"]
            ) == FocusSessionStartDefaults(duration: 15 * 60, tagName: nil)
        )
    }

    @Test
    func offersARecentCustomDurationAlongsideStandardOptions() {
        let options = FocusSessionStartDefaults.durationOptions(including: 20 * 60)
        let expected: [TimeInterval] = [0, 900, 1_200, 1_500, 2_700, 3_600, 5_400]

        #expect(options == expected)
    }

    @Test
    func rememberedDurationOverridesHistoryAndSurvivesPersistence() {
        let suiteName = "FocusSessionStartDefaultsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let latestFocus = FocusSession(
            taskID: UUID(),
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            plannedDurationSeconds: 15 * 60
        )

        let expectedDuration = TimeInterval(45 * 60)
        FocusSessionStartDefaults.rememberDuration(expectedDuration, defaults: defaults)

        #expect(FocusSessionStartDefaults.rememberedDuration(defaults: defaults) == expectedDuration)
        #expect(
            FocusSessionStartDefaults.latest(
                focusSessions: [latestFocus],
                availableTags: [],
                rememberedDuration: FocusSessionStartDefaults.rememberedDuration(defaults: defaults)
            ) == FocusSessionStartDefaults(duration: expectedDuration, tagName: nil)
        )
        #expect(
            FocusSessionStartDefaults.latest(
                focusSessions: [],
                availableTags: [],
                rememberedDuration: FocusSessionStartDefaults.rememberedDuration(defaults: defaults)
            ) == FocusSessionStartDefaults(duration: expectedDuration, tagName: nil)
        )
    }
}
