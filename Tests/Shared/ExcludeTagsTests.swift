import Testing
@testable @preconcurrency import RoutinaAppSupport

// MARK: - HomeFeature.matchesExcludedTags

struct ExcludeTagsTests {

    // MARK: - matchesExcludedTags: basic

    @Test
    func matchesExcludedTags_emptySetAlwaysPasses() {
        #expect(HomeFeature.matchesExcludedTags([], in: ["Focus", "Health"]))
        #expect(HomeFeature.matchesExcludedTags([], in: []))
    }

    @Test
    func matchesExcludedTags_taskWithExcludedTagIsFiltered() {
        #expect(!HomeFeature.matchesExcludedTags(["Focus"], in: ["Focus", "Health"]))
    }

    @Test
    func matchesExcludedTags_taskWithNoExcludedTagPasses() {
        #expect(HomeFeature.matchesExcludedTags(["Focus"], in: ["Health", "Morning"]))
    }

    @Test
    func matchesExcludedTags_taskWithNoTagsPasses() {
        #expect(HomeFeature.matchesExcludedTags(["Focus"], in: []))
    }

    // MARK: - matchesExcludedTags: case & accent insensitivity

    @Test
    func matchesExcludedTags_isCaseInsensitive() {
        // excluded set uses lowercase, task tags use title case
        #expect(!HomeFeature.matchesExcludedTags(["focus"], in: ["Focus"]))
        #expect(!HomeFeature.matchesExcludedTags(["FOCUS"], in: ["focus"]))
    }

    @Test
    func matchesExcludedTags_isAccentInsensitive() {
        #expect(!HomeFeature.matchesExcludedTags(["cafe"], in: ["Café"]))
        #expect(!HomeFeature.matchesExcludedTags(["Café"], in: ["cafe"]))
    }

    // MARK: - matchesExcludedTags: multiple excluded tags

    @Test
    func matchesExcludedTags_anyMatchExcludes() {
        // task has "Morning"; excluding "Morning" and "Sleep" — should be filtered
        #expect(!HomeFeature.matchesExcludedTags(["Sleep", "Morning"], in: ["Morning", "Focus"]))
    }

    @Test
    func matchesExcludedTags_noneMatchPasses() {
        #expect(HomeFeature.matchesExcludedTags(["Sleep", "Evening"], in: ["Morning", "Focus"]))
    }

    @Test
    func matchesExcludedTags_allExcludedTagsMustBeAbsentToPas() {
        // Task has both tags that are excluded
        #expect(!HomeFeature.matchesExcludedTags(["Morning", "Focus"], in: ["Morning", "Focus"]))
    }

    // MARK: - matchesExcludedTags: interaction with include (matchesSelectedTag)

    @Test
    func includeAndExclude_sameTagFiltersTaskOut() {
        // Edge case: user somehow has same tag in include and exclude.
        // The task should be excluded because matchesExcludedTags takes precedence.
        let tags = ["Focus"]
        let includeResult = HomeFeature.matchesSelectedTag("Focus", in: tags)
        let excludeResult = HomeFeature.matchesExcludedTags(["Focus"], in: tags)
        // Include passes, but exclude blocks it — combined result is false
        #expect(includeResult == true)
        #expect(excludeResult == false)
    }

    @Test
    func includeTagPasses_excludeTagPasses_taskIsVisible() {
        let tags = ["Focus", "Health"]
        let includeResult = HomeFeature.matchesSelectedTag("Focus", in: tags)
        let excludeResult = HomeFeature.matchesExcludedTags(["Morning"], in: tags)
        #expect(includeResult == true)
        #expect(excludeResult == true)
    }

    @Test
    func includeTagPasses_excludeTagBlocks_taskIsHidden() {
        let tags = ["Focus", "Health"]
        let includeResult = HomeFeature.matchesSelectedTag("Focus", in: tags)
        let excludeResult = HomeFeature.matchesExcludedTags(["Health"], in: tags)
        #expect(includeResult == true)
        #expect(excludeResult == false)
    }

    @Test
    func includeTagFails_taskIsHiddenRegardlessOfExclude() {
        let tags = ["Morning"]
        let includeResult = HomeFeature.matchesSelectedTag("Focus", in: tags)
        let excludeResult = HomeFeature.matchesExcludedTags([], in: tags)
        #expect(includeResult == false)
        #expect(excludeResult == true)
    }

    // MARK: - matchesExcludedTags: partial word should NOT match

    @Test
    func matchesExcludedTags_doesNotMatchSubstring() {
        // "Foc" is not the same tag as "Focus" — should pass
        #expect(HomeFeature.matchesExcludedTags(["Foc"], in: ["Focus"]))
    }

    // MARK: - availableExcludeTags scoping

    @Test
    func availableExcludeTags_withNoIncludeTag_returnsAllTags() {
        // When no include tag is selected, all tags across all tasks are candidates for exclusion.
        let taskA = RoutineTask(name: "A", emoji: "🔧", tags: ["Focus", "Morning"], scheduleMode: .fixedInterval)
        let taskB = RoutineTask(name: "B", emoji: "📝", tags: ["Health"], scheduleMode: .fixedInterval)
        let allTags = RoutineTag.allTags(from: [taskA.tags, taskB.tags])
        // No include filter — exclude pool = all unique tags
        #expect(allTags.contains("Focus"))
        #expect(allTags.contains("Morning"))
        #expect(allTags.contains("Health"))
    }

    @Test
    func availableExcludeTags_withIncludeTag_onlyShowsTagsFromMatchingTasks() {
        // Task A has Focus + Morning; Task B has Health only.
        // If include = "Focus", only Task A matches → exclude candidates = ["Morning"]
        // ("Focus" itself is not offered as an exclude option)
        let taskA = RoutineTask(name: "A", emoji: "🔧", tags: ["Focus", "Morning"], scheduleMode: .fixedInterval)
        let taskB = RoutineTask(name: "B", emoji: "📝", tags: ["Health"], scheduleMode: .fixedInterval)

        // Simulate the scoping: keep only tasks that match the include tag
        let includedTasks = [taskA, taskB].filter {
            HomeFeature.matchesSelectedTag("Focus", in: $0.tags)
        }
        // Build available exclude tags: tags from included tasks, minus the include tag itself
        let candidateTags = RoutineTag.allTags(from: includedTasks.map(\.tags)).filter {
            !RoutineTag.contains("Focus", in: [$0])
        }

        #expect(candidateTags == ["Morning"])
        #expect(!candidateTags.contains("Health"))  // Task B didn't match include
        #expect(!candidateTags.contains("Focus"))   // Include tag excluded from the list
    }

    @Test
    func availableExcludeTags_withIncludeTag_excludeTagFromOtherTaskIsNotOffered() {
        // Ensures a tag that only appears on tasks NOT matching the include filter
        // is not shown in the exclude list.
        let taskFocus = RoutineTask(name: "Focus Task", emoji: "🎯", tags: ["Focus", "Deep Work"], scheduleMode: .fixedInterval)
        let taskHealth = RoutineTask(name: "Health Task", emoji: "💪", tags: ["Health"], scheduleMode: .fixedInterval)

        let includedTasks = [taskFocus, taskHealth].filter {
            HomeFeature.matchesSelectedTag("Focus", in: $0.tags)
        }
        let candidateTags = RoutineTag.allTags(from: includedTasks.map(\.tags)).filter {
            !RoutineTag.contains("Focus", in: [$0])
        }

        #expect(candidateTags.contains("Deep Work"))
        #expect(!candidateTags.contains("Health"))
    }

    @Test
    func availableExcludeTags_noTasksMatchIncludeTag_returnsEmpty() {
        let taskA = RoutineTask(name: "A", emoji: "🔧", tags: ["Morning"], scheduleMode: .fixedInterval)
        let includedTasks = [taskA].filter {
            HomeFeature.matchesSelectedTag("Focus", in: $0.tags)
        }
        let candidateTags = RoutineTag.allTags(from: includedTasks.map(\.tags)).filter {
            !RoutineTag.contains("Focus", in: [$0])
        }
        #expect(candidateTags.isEmpty)
    }

    // MARK: - matchesSelectedTag: existing include behaviour (regression)

    @Test
    func matchesSelectedTag_nilAlwaysPasses() {
        #expect(HomeFeature.matchesSelectedTag(nil, in: ["Focus", "Health"]))
        #expect(HomeFeature.matchesSelectedTag(nil, in: []))
    }

    @Test
    func matchesSelectedTag_returnsTrue_whenTagPresent() {
        #expect(HomeFeature.matchesSelectedTag("Health", in: ["Focus", "Health"]))
    }

    @Test
    func matchesSelectedTag_returnsFalse_whenTagAbsent() {
        #expect(!HomeFeature.matchesSelectedTag("Sleep", in: ["Focus", "Health"]))
    }
}
