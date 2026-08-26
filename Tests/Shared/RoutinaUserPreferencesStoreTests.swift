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
struct RoutinaUserPreferencesStoreTests {
    @Test
    func temporaryViewStateStoreSkipsEquivalentValues() throws {
        let suiteName = "TemporaryViewStateDefaultsStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(TemporaryViewStateDefaultsStore.storeIfChanged(.default, in: defaults))
        #expect(TemporaryViewStateDefaultsStore.load(from: defaults) == .default)
        #expect(!TemporaryViewStateDefaultsStore.storeIfChanged(.default, in: defaults))
        #expect(TemporaryViewStateDefaultsStore.storeIfChanged(nil, in: defaults))
        #expect(!TemporaryViewStateDefaultsStore.storeIfChanged(nil, in: defaults))
    }

    @Test
    func preferenceBridgePersistsAndAppliesOnlySemanticChanges() throws {
        let suiteName = "RoutinaUserPreferencesStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.register(defaults: AppSettingsDefaults.boolValues)
        defaults.register(defaults: AppSettingsDefaults.stringValues)
        defaults.register(defaults: AppSettingsDefaults.intValues)

        let context = makeInMemoryContext()

        #expect(RoutinaUserPreferencesStore.mirrorDefaultsToStore(in: context, defaults: defaults))
        let preferences = try #require(
            context.fetch(FetchDescriptor<RoutinaUserPreferences>()).first
        )
        let initialUpdatedAt = preferences.updatedAt

        #expect(!RoutinaUserPreferencesStore.mirrorDefaultsToStore(in: context, defaults: defaults))
        #expect(preferences.updatedAt == initialUpdatedAt)

        defaults[.appSettingTagColors] = "{\"Focus\":\"#112233\"}"
        #expect(RoutinaUserPreferencesStore.mirrorDefaultsToStore(in: context, defaults: defaults))
        #expect(preferences.tagColors == "{\"Focus\":\"#112233\"}")
        let changedUpdatedAt = preferences.updatedAt

        #expect(!RoutinaUserPreferencesStore.mirrorDefaultsToStore(in: context, defaults: defaults))
        #expect(preferences.updatedAt == changedUpdatedAt)

        preferences.tagColors = "{\"Focus\":\"#445566\"}"
        try context.save()
        #expect(RoutinaUserPreferencesStore.applyToDefaults(from: context, defaults: defaults))
        #expect(defaults[.appSettingTagColors] == "{\"Focus\":\"#445566\"}")
        #expect(!RoutinaUserPreferencesStore.applyToDefaults(from: context, defaults: defaults))
    }

    @Test
    func preferenceBridgeAppliesNewestDuplicateAndRemovesStaleRecord() throws {
        let suiteName = "RoutinaUserPreferencesStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.register(defaults: AppSettingsDefaults.boolValues)
        defaults.register(defaults: AppSettingsDefaults.stringValues)
        defaults.register(defaults: AppSettingsDefaults.intValues)

        let context = makeInMemoryContext()
        let stale = RoutinaUserPreferences(
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        stale.customTaskSections = ""
        let current = RoutinaUserPreferences(
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        current.customTaskSections = "mac-backlog-sections"
        context.insert(stale)
        context.insert(current)
        try context.save()

        #expect(RoutinaUserPreferencesStore.applyToDefaults(from: context, defaults: defaults))
        #expect(defaults[.appSettingCustomTaskSections] == "mac-backlog-sections")

        let remaining = try context.fetch(FetchDescriptor<RoutinaUserPreferences>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.updatedAt == Date(timeIntervalSince1970: 2_000))
    }
}
