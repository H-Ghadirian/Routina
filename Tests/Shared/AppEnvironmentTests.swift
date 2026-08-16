import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct AppEnvironmentTests {
    @Test
    func signedCloudKitEnvironmentDescriptionUsesTheEntitlementValue() {
        #expect(AppEnvironment.cloudKitEnvironmentDescription(from: "development") == "Development")
        #expect(AppEnvironment.cloudKitEnvironmentDescription(from: "Production") == "Production")
        #expect(AppEnvironment.cloudKitEnvironmentDescription(from: " staging ") == "staging")
    }

    @Test
    func signedCloudKitEnvironmentDescriptionExplainsAbsentOrInvalidValues() {
        #expect(AppEnvironment.cloudKitEnvironmentDescription(from: nil) == "Not present")
        #expect(AppEnvironment.cloudKitEnvironmentDescription(from: "  ") == "Not present")
        #expect(AppEnvironment.cloudKitEnvironmentDescription(from: true) == "Unexpected value")
    }

    @Test
    func diagnosticsReportIncludesAllSupportValues() {
        var diagnostics = SettingsDiagnosticsState()
        diagnostics.appVersion = "1.3.0"
        diagnostics.buildNumber = "42"
        diagnostics.operatingSystemDescription = "iOS 26.5.0"
        diagnostics.dataModeDescription = "Production (iCloud)"
        diagnostics.iCloudContainerDescription = "iCloud.ir.hamedgh.Routinam.prod"
        diagnostics.signedCloudKitEnvironmentDescription = "Not present"
        diagnostics.cloudDiagnosticsTimestamp = "09.08.26, 11:23:10"
        diagnostics.cloudDiagnosticsSummary = "type=export status=succeeded"
        diagnostics.manualCloudRefreshTimestamp = "16.08.26, 14:38:00"
        diagnostics.manualCloudRefreshSummary = "status=failed mode=full received=800 changed=790 deleted=10"
        diagnostics.pushDiagnosticsStatus = "Push registered (token bytes: 32)"

        #expect(
            SettingsDiagnosticsReport.text(for: diagnostics) == """
            Routina Diagnostics
            App Version: 1.3.0
            Build Number: 42
            Operating System: iOS 26.5.0
            Data Mode: Production (iCloud)
            iCloud Container: iCloud.ir.hamedgh.Routinam.prod
            Signed CloudKit Environment: Not present
            Last CloudKit Event: 09.08.26, 11:23:10
            CloudKit Detail: type=export status=succeeded
            Last Manual Refresh: 16.08.26, 14:38:00
            Manual Refresh Detail: status=failed mode=full received=800 changed=790 deleted=10
            Push Status: Push registered (token bytes: 32)
            """
        )
    }
}
