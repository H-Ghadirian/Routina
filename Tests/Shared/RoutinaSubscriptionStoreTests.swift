import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct RoutinaSubscriptionStoreTests {
    @Test
    func unlimitedTaskOverride_isIgnoredByProductionApps() {
        #expect(
            AppEnvironment.resolvedUnlocksAllTasks(
                isDevelopmentAppVariant: false,
                processOverride: true,
                configuredDefault: true,
                storedOverride: true
            ) == false
        )
    }

    @Test
    func unlimitedTaskOverride_remainsAvailableToDevelopmentApps() {
        #expect(AppEnvironment.resolvedUnlocksAllTasks(
            isDevelopmentAppVariant: true,
            processOverride: nil,
            configuredDefault: false,
            storedOverride: true
        ))
        #expect(AppEnvironment.resolvedUnlocksAllTasks(
            isDevelopmentAppVariant: true,
            processOverride: true,
            configuredDefault: false,
            storedOverride: nil
        ))
    }

    @Test
    func publicPurchaseLinksUsePublishedRoutinaPageAnchors() {
        #expect(RoutinaPublicLinks.support.absoluteString == "https://h-ghadirian.github.io/")
        #expect(RoutinaPublicLinks.privacyPolicy.absoluteString == "https://h-ghadirian.github.io/#privacy")
        #expect(RoutinaPublicLinks.termsOfUse.absoluteString == "https://h-ghadirian.github.io/#terms")
    }

    @Test
    func releasePurchaseSurfacesKeepLegalDisclosureAndDevelopmentOnlyOverride() throws {
        let paywallSource = try Self.sourceFile("SharedCore/Views/SubscriptionPaywallView.swift")
        let iosSettingsSource = try Self.sourceFile("iOS/Screens/Settings/SettingsDataSupportDetailViews.swift")
        let macSettingsSource = try Self.sourceFile("RoutinaMacApp/Screens/Settings/SettingsMacDataSupportDetailViews.swift")
        let calendarImportSource = try Self.sourceFile("SharedCore/Views/CalendarTaskImportSheet.swift")

        #expect(paywallSource.contains("RoutinaPublicLinks.privacyPolicy"))
        #expect(paywallSource.contains("RoutinaPublicLinks.termsOfUse"))
        #expect(paywallSource.contains("Subscriptions renew automatically"))
        #expect(iosSettingsSource.contains(
            "if AppEnvironment.isDevelopmentAppVariant {\n                Toggle(\"Unlock unlimited tasks\""
        ))
        #expect(macSettingsSource.contains(
            "if AppEnvironment.isDevelopmentAppVariant {\n                Toggle(\"Unlock unlimited tasks\""
        ))
        #expect(calendarImportSource.contains("options: viewModel.availableImportSources"))
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
