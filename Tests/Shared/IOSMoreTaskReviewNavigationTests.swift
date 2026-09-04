import Foundation
import Testing

struct IOSPrimaryTabNavigationTests {
    @Test
    func statsAndSettingsReplaceTimelineAndMoreAsPrimaryTabs() throws {
        let source = try Self.sourceFile("iOS/Screens/App/AppView.swift")

        let newTab = try #require(source.range(of: "SwiftUI.Tab(\"New\""))
        let statsTab = try #require(source.range(of: "SwiftUI.Tab(Tab.stats.rawValue"))
        let settingsTab = try #require(source.range(of: "SwiftUI.Tab(Tab.settings.rawValue"))
        #expect(newTab.lowerBound < statsTab.lowerBound)
        #expect(statsTab.lowerBound < settingsTab.lowerBound)
        #expect(!source.contains("SwiftUI.Tab(Tab.timeline.rawValue"))
        #expect(!source.contains("SwiftUI.Tab(Tab.more.rawValue"))
        #expect(!source.contains("private struct AppMoreNavigationView"))
        #expect(source.contains("if store.selectedTab == .more"))
        #expect(source.contains("store.send(.tabSelected(.settings))"))
    }

    private static func sourceFile(_ relativePath: String) throws -> String {
        try SourceInspectionSupport.readProjectFile(relativePath)
    }
}
