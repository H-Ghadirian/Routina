import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct StatsEmptyDashboardMessageTests {
    @Test
    func emptyDashboardOmitsSleepWhenSleepIsDisabled() {
        let message = StatsEmptyDashboardMessage.text(
            hasActiveFilters: false,
            isSleepEnabled: false
        )

        #expect(message == "Reports appear after you complete tasks, focus, or log activity in this period.")
        #expect(!message.localizedCaseInsensitiveContains("sleep"))
    }

    @Test
    func emptyDashboardIncludesSleepWhenSleepIsEnabled() {
        let message = StatsEmptyDashboardMessage.text(
            hasActiveFilters: false,
            isSleepEnabled: true
        )

        #expect(message == "Reports appear after you complete tasks, focus, sleep, or log activity in this period.")
    }

    @Test
    func activeFilterRecoveryMessageDoesNotDependOnSleepAvailability() {
        let withSleep = StatsEmptyDashboardMessage.text(
            hasActiveFilters: true,
            isSleepEnabled: true
        )
        let withoutSleep = StatsEmptyDashboardMessage.text(
            hasActiveFilters: true,
            isSleepEnabled: false
        )

        #expect(withSleep == withoutSleep)
        #expect(withoutSleep.contains("clear filters"))
    }

    @Test
    func platformStatsViewsPassEffectiveSleepAvailability() throws {
        let iosSource = try Self.sourceFile("iOS/Screens/Stats/StatsView.swift")
        let macSource = try Self.sourceFile("RoutinaMacApp/Screens/StatsView.swift")
        let effectiveGate = "isSleepEnabled: isAwayEnabled && isStatsSleepTabEnabled"

        #expect(iosSource.contains(effectiveGate))
        #expect(macSource.contains(effectiveGate))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectRoot = testsDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: projectRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
