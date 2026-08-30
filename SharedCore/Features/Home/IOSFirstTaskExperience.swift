import Foundation

enum IOSFirstTaskExperience {
    static let completionDefaultsKey = "routina.ios.firstTaskExperienceCompleted.v1"

    static func prepareForLaunch(
        defaults: UserDefaults = SharedDefaults.app,
        hasExistingInstallation: Bool
    ) {
        guard defaults.object(forKey: completionDefaultsKey) == nil else { return }
        defaults.set(hasExistingInstallation, forKey: completionDefaultsKey)
    }

    static func shouldPresent(
        hasLoadedTaskSnapshot: Bool,
        taskCount: Int,
        hasCompleted: Bool
    ) -> Bool {
        hasLoadedTaskSnapshot
            && taskCount == 0
            && !hasCompleted
    }

    static func shouldComplete(
        taskCount: Int,
        hasCompleted: Bool
    ) -> Bool {
        taskCount > 0 && !hasCompleted
    }
}
