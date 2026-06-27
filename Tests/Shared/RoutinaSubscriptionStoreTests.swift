import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@Suite(.serialized)
struct RoutinaSubscriptionStoreTests {
    @Test
    func currentEntitlement_usesSettingsUnlockOverride() async {
        let defaults = SharedDefaults.app
        let key = UserDefaultBoolValueKey.appSettingUnlockUnlimitedTasks.rawValue
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults[.appSettingUnlockUnlimitedTasks] = true

        let entitlement = await RoutinaSubscriptionStore.currentEntitlement()

        #expect(entitlement.hasUnlimitedTasks)
    }
}
