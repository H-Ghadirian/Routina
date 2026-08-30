import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct IOSFirstTaskExperienceTests {
    @Test
    func newInstallationPresentsOnlyAfterAnEmptyTaskSnapshotLoads() {
        let testDefaults = makeDefaults()
        let defaults = testDefaults.defaults
        defer { defaults.removePersistentDomain(forName: testDefaults.suiteName) }

        IOSFirstTaskExperience.prepareForLaunch(
            defaults: defaults,
            hasExistingInstallation: false
        )

        #expect(!IOSFirstTaskExperience.shouldPresent(
            hasLoadedTaskSnapshot: false,
            taskCount: 0,
            hasCompleted: defaults.bool(forKey: IOSFirstTaskExperience.completionDefaultsKey)
        ))
        #expect(IOSFirstTaskExperience.shouldPresent(
            hasLoadedTaskSnapshot: true,
            taskCount: 0,
            hasCompleted: defaults.bool(forKey: IOSFirstTaskExperience.completionDefaultsKey)
        ))
    }

    @Test
    func existingInstallationDoesNotEnterTheFirstTaskExperience() {
        let testDefaults = makeDefaults()
        let defaults = testDefaults.defaults
        defer { defaults.removePersistentDomain(forName: testDefaults.suiteName) }

        IOSFirstTaskExperience.prepareForLaunch(
            defaults: defaults,
            hasExistingInstallation: true
        )

        #expect(!IOSFirstTaskExperience.shouldPresent(
            hasLoadedTaskSnapshot: true,
            taskCount: 0,
            hasCompleted: defaults.bool(forKey: IOSFirstTaskExperience.completionDefaultsKey)
        ))
    }

    @Test
    func observingATaskPermanentlyCompletesTheExperience() {
        let testDefaults = makeDefaults()
        let defaults = testDefaults.defaults
        defer { defaults.removePersistentDomain(forName: testDefaults.suiteName) }

        IOSFirstTaskExperience.prepareForLaunch(
            defaults: defaults,
            hasExistingInstallation: false
        )
        #expect(IOSFirstTaskExperience.shouldComplete(taskCount: 1, hasCompleted: false))
        defaults.set(true, forKey: IOSFirstTaskExperience.completionDefaultsKey)

        #expect(!IOSFirstTaskExperience.shouldPresent(
            hasLoadedTaskSnapshot: true,
            taskCount: 0,
            hasCompleted: defaults.bool(forKey: IOSFirstTaskExperience.completionDefaultsKey)
        ))

        IOSFirstTaskExperience.prepareForLaunch(
            defaults: defaults,
            hasExistingInstallation: false
        )
        #expect(defaults.bool(forKey: IOSFirstTaskExperience.completionDefaultsKey))
    }

    private func makeDefaults() -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "IOSFirstTaskExperienceTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }
}
