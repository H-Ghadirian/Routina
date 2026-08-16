import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct UnlimitedTaskCreationTests {
    @Test
    func quickAddCreatesTasksBeyondTheFormerActiveTaskLimit() async throws {
        let context = makeInMemoryContext()
        for index in 0..<25 {
            _ = makeTask(
                in: context,
                name: "Existing task \(index)",
                interval: 1,
                lastDone: nil,
                emoji: nil,
                scheduleMode: .oneOff
            )
        }

        let result = try await RoutinaQuickAddService.createTask(
            from: "Another task",
            context: context,
            referenceDate: Date(timeIntervalSince1970: 1_000),
            calendar: makeTestCalendar()
        )

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        #expect(tasks.count == 26)
        #expect(tasks.contains { $0.id == result.taskID })
    }

    @Test
    func taskCreationSurfacesDoNotRestoreThePurchaseGate() throws {
        let sourcePaths = [
            "SharedCore/Features/Home/HomeAddRoutineSupport.swift",
            "SharedCore/Services/RoutinaQuickAddService.swift",
            "iOS/Features/Home/HomeFeature.swift",
            "RoutinaMacApp/Features/Home/HomeFeature.swift",
        ]

        for path in sourcePaths {
            let source = try Self.sourceFile(path)
            #expect(!source.contains("RoutinaTaskUsageGate"))
            #expect(!source.contains("SubscriptionPaywall"))
            #expect(!source.contains("subscriptionRequired"))
        }
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
