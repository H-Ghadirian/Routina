import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct RoutinaPerformanceProfilerTests {
    @Test
    func enablesOnlyForNonTestDebugRuns() {
        #expect(
            RoutinaPerformanceProfiler.shouldEnable(
                isDebugBuild: true,
                isAutomatedTestMode: false
            )
        )
        #expect(
            !RoutinaPerformanceProfiler.shouldEnable(
                isDebugBuild: false,
                isAutomatedTestMode: false
            )
        )
        #expect(
            !RoutinaPerformanceProfiler.shouldEnable(
                isDebugBuild: true,
                isAutomatedTestMode: true
            )
        )
    }

    @Test
    func reportSummarizesSymptomsWithoutSerializingItsLocalPath() throws {
        let profile = RoutinaPerformanceProfile(
            schemaVersion: 2,
            sessionIdentifier: "session",
            platform: "macOS",
            startedAt: Date(timeIntervalSince1970: 1_713_456_789),
            generatedAt: Date(timeIntervalSince1970: 1_713_456_799),
            uptimeSeconds: 10,
            appVersion: "1.3.0",
            buildNumber: "42",
            operatingSystem: "macOS 26.5.0",
            profileMode: "Debug automatic symptom recorder",
            resourceSamples: [
                RoutinaPerformanceResourceSample(
                    timestamp: Date(timeIntervalSince1970: 1_713_456_790),
                    uptimeSeconds: 1,
                    cpuPercent: 12.5,
                    residentMemoryBytes: 80_000_000,
                    thermalState: "nominal",
                    isLowPowerModeEnabled: false
                ),
                RoutinaPerformanceResourceSample(
                    timestamp: Date(timeIntervalSince1970: 1_713_456_791),
                    uptimeSeconds: 2,
                    cpuPercent: 71.5,
                    residentMemoryBytes: 120_000_000,
                    thermalState: "fair",
                    isLowPowerModeEnabled: false
                ),
            ],
            mainThreadHitches: [
                RoutinaPerformanceMainThreadHitch(
                    timestamp: Date(timeIntervalSince1970: 1_713_456_792),
                    uptimeSeconds: 3,
                    delayMilliseconds: 1_200,
                    precedingInteractionNames: [
                        RoutinaPerformanceInteraction.homeTaskListScrolled.rawValue,
                    ]
                ),
            ],
            lifecycleEvents: [
                RoutinaPerformanceLifecycleEvent(
                    timestamp: Date(timeIntervalSince1970: 1_713_456_789),
                    uptimeSeconds: 0,
                    name: "app.launch"
                ),
            ],
            interactionEvents: [
                RoutinaPerformanceInteractionEvent(
                    timestamp: Date(timeIntervalSince1970: 1_713_456_791),
                    uptimeSeconds: 2,
                    name: RoutinaPerformanceInteraction.homeTaskListScrolled.rawValue
                ),
            ],
            droppedResourceSampleCount: 0,
            droppedMainThreadHitchCount: 0,
            droppedLifecycleEventCount: 0,
            droppedInteractionEventCount: 0,
            fileURL: URL(fileURLWithPath: "/Users/example/private-profile.json")
        )

        #expect(
            profile.summary == RoutinaPerformanceProfileSummary(
                maximumCPUPercent: 71.5,
                maximumResidentMemoryBytes: 120_000_000,
                largestMainThreadDelayMilliseconds: 1_200,
                mainThreadHitchCount: 1
            )
        )

        let data = try JSONEncoder().encode(profile)
        let document = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(document["fileURL"] == nil)
        #expect(document["resourceSamples"] != nil)
        #expect(document["mainThreadHitches"] != nil)
        #expect(document["interactionEvents"] != nil)
        #expect(
            (document["mainThreadHitches"] as? [[String: Any]])?.first?["precedingInteractionNames"]
                as? [String] == [RoutinaPerformanceInteraction.homeTaskListScrolled.rawValue]
        )
    }

    @Test
    func interactionLabelsRejectUnknownNavigationValues() {
        #expect(RoutinaPerformanceInteraction.navigationTab(named: "Home") == .navigationHome)
        #expect(RoutinaPerformanceInteraction.navigationTab(named: "Private task name") == nil)
        #expect(RoutinaPerformanceInteraction.macSidebar(named: "Settings") == .macSidebarSettings)
        #expect(RoutinaPerformanceInteraction.macSidebar(named: "Private section name") == nil)
    }

    @Test
    func preservesCurrentProfileBeforeAReplacementRunStarts() throws {
        let testDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".codex", isDirectory: true)
            .appendingPathComponent(
                "PerformanceProfilePreservationTests-\(UUID().uuidString)",
                isDirectory: true
            )
        defer { try? FileManager.default.removeItem(at: testDirectory) }

        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true
        )
        let currentProfileURL = testDirectory.appendingPathComponent(
            RoutinaPerformanceProfiler.fileName
        )
        let previousRunProfileURL = testDirectory.appendingPathComponent(
            RoutinaPerformanceProfiler.previousRunFileName
        )
        let interruptedRunData = try #require("interrupted run".data(using: .utf8))
        let olderRunData = try #require("older run".data(using: .utf8))
        try interruptedRunData.write(to: currentProfileURL)
        try olderRunData.write(to: previousRunProfileURL)

        RoutinaPerformanceProfileFileStore.preserveCurrentProfileAsPreviousRun(
            currentProfileURL: currentProfileURL,
            previousRunProfileURL: previousRunProfileURL
        )

        #expect(try Data(contentsOf: previousRunProfileURL) == interruptedRunData)
        #expect(try Data(contentsOf: currentProfileURL) == interruptedRunData)
    }
}
