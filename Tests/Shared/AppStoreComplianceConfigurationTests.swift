import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct AppStoreComplianceConfigurationTests {
    @Test
    func productionBundlesDeclareThatTheyDoNotUseNonExemptEncryption() throws {
        for relativePath in [
            "Config/macOS/RoutinaMacOSProd-Info.plist",
            "Config/iOS/RoutinaiOSProd-Info.plist",
        ] {
            let data = try Data(contentsOf: Self.projectRoot.appendingPathComponent(relativePath))
            let propertyList = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            )
            let dictionary = try #require(propertyList as? [String: Any])
            let usesNonExemptEncryption = try #require(
                dictionary["ITSAppUsesNonExemptEncryption"] as? Bool
            )

            #expect(usesNonExemptEncryption == false)
        }
    }

    private static let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
