import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct StatsDashboardToolbarAvailabilityTests {
    @Test
    func toolbarHidesEveryControlWhenNothingCanUseIt() {
        let availability = StatsDashboardToolbarAvailability.make(
            hasReportableDashboardItems: false,
            hasVisibleSummaryItems: false,
            hasFilterableTasks: false,
            hasActiveSheetFilters: false
        )

        #expect(!availability.showsAnyControl)
        #expect(!availability.showsSummaryDisplayMode)
        #expect(!availability.showsEditor)
        #expect(!availability.showsFilters)
    }

    @Test
    func toolbarKeepsOnlyTheFilterRecoveryPathForAnActiveEmptyFilter() {
        let availability = StatsDashboardToolbarAvailability.make(
            hasReportableDashboardItems: false,
            hasVisibleSummaryItems: false,
            hasFilterableTasks: false,
            hasActiveSheetFilters: true
        )

        #expect(availability.showsAnyControl)
        #expect(!availability.showsSummaryDisplayMode)
        #expect(!availability.showsEditor)
        #expect(availability.showsFilters)
    }

    @Test
    func toolbarShowsOnlyControlsThatCanAffectAvailableContent() {
        let chartOnly = StatsDashboardToolbarAvailability.make(
            hasReportableDashboardItems: true,
            hasVisibleSummaryItems: false,
            hasFilterableTasks: true,
            hasActiveSheetFilters: false
        )
        let withSummary = StatsDashboardToolbarAvailability.make(
            hasReportableDashboardItems: true,
            hasVisibleSummaryItems: true,
            hasFilterableTasks: true,
            hasActiveSheetFilters: false
        )

        #expect(!chartOnly.showsSummaryDisplayMode)
        #expect(chartOnly.showsEditor)
        #expect(chartOnly.showsFilters)
        #expect(withSummary.showsSummaryDisplayMode)
        #expect(withSummary.showsEditor)
        #expect(withSummary.showsFilters)
    }

    @Test
    func iosStatsWiresToolbarControlsAndEditingToAvailability() throws {
        let source = try Self.sourceFile("iOS/Screens/Stats/StatsView.swift")

        #expect(source.contains("hasReportableDashboardItems: !availableDashboardItems.isEmpty"))
        #expect(source.contains("hasVisibleSummaryItems: scopedVisibleOrderedDashboardItems.contains"))
        #expect(source.contains("hasFilterableTasks: !tasks.isEmpty"))
        #expect(source.contains("hasActiveSheetFilters: hasActiveSheetFilters"))
        #expect(source.contains("if dashboardToolbarAvailability.showsSummaryDisplayMode"))
        #expect(source.contains("if dashboardToolbarAvailability.showsEditor"))
        #expect(source.contains("if dashboardToolbarAvailability.showsFilters"))
        #expect(source.contains(".onChange(of: dashboardToolbarAvailability.showsEditor)"))
        #expect(source.contains("isEditingDashboard = false"))
        #expect(source.contains("isAddDashboardItemSheetPresented = false"))
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
