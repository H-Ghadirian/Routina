import ComposableArchitecture
import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct TaskChoiceTagPreferencesFeatureTests {
    @Test
    func loadsTaskTagsAndPersistsOnlyEnabledPreferences() async throws {
        let context = makeInMemoryContext()
        context.insert(RoutineTask(name: "Book trip", tags: ["Travel"]))
        context.insert(RoutineTask(name: "File receipts", tags: ["Admin"]))
        try context.save()

        let persistedPreferences = LockIsolated<[TaskChoiceTagPreference]>([])
        var appSettingsClient = AppSettingsClient.noop
        appSettingsClient.taskChoiceTagPreferences = { persistedPreferences.value }
        appSettingsClient.setTaskChoiceTagPreferences = { preferences in
            persistedPreferences.setValue(preferences)
        }
        let expectedTags = [
            TaskChoiceTagPreferencesFeature.State.Tag(name: "Admin", taskCount: 1, preference: nil),
            TaskChoiceTagPreferencesFeature.State.Tag(name: "Travel", taskCount: 1, preference: nil)
        ]
        let store = TestStore(initialState: TaskChoiceTagPreferencesFeature.State()) {
            TaskChoiceTagPreferencesFeature()
        } withDependencies: {
            $0.modelContext = { context }
            $0.appSettingsClient = appSettingsClient
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(.tagsLoaded(expectedTags)) {
            $0.tags = expectedTags
            $0.isLoading = false
        }

        await store.send(.tagToggled(tag: "Travel", isEnabled: true)) {
            $0.tags[1].preference = TaskChoiceTagPreference(tag: "Travel")
        }
        #expect(persistedPreferences.value == [TaskChoiceTagPreference(tag: "Travel")])

        await store.send(.resetLearnedScoresTapped)
        #expect(persistedPreferences.value == [TaskChoiceTagPreference(tag: "Travel")])
    }

    @Test
    func renameAndDeletePreserveOnlyValidTagPreference() {
        let preferences = [TaskChoiceTagPreference(tag: "Travel", score: 0.3, comparisonCount: 4)]

        let renamed = TaskChoiceTagPreferences.replacing(
            "Travel",
            with: "Trips",
            in: preferences
        )
        #expect(renamed == [TaskChoiceTagPreference(tag: "Trips", score: 0.3, comparisonCount: 4)])
        #expect(TaskChoiceTagPreferences.removing("Trips", from: renamed).isEmpty)
    }

    @Test
    func iOSViewKeepsQueriesOutOfTheRenderPath() throws {
        let viewSource = try Self.sourceFile("iOS/Screens/More/TaskChoiceTagPreferencesView.swift")
        let featureSource = try Self.sourceFile("SharedCore/Features/TaskChoice/TaskChoiceTagPreferencesFeature.swift")

        #expect(viewSource.contains("let store: StoreOf<TaskChoiceTagPreferencesFeature>"))
        #expect(viewSource.contains("store.send(.tagToggled"))
        #expect(!viewSource.contains("@Query"))
        #expect(!viewSource.contains("@Environment(\\.modelContext)"))
        #expect(!viewSource.contains("modelContext.save()"))
        #expect(featureSource.contains("FetchDescriptor<RoutineTask>"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
