import SwiftUI
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct TaskDetailOverviewHeightsPreferenceKeyTests {
    @Test
    func reduceMergesLatestHeightsByID() {
        var value: [String: CGFloat] = [
            "summary": 120,
            "calendar": 200
        ]

        TaskDetailOverviewHeightsPreferenceKey.reduce(value: &value) {
            [
                "summary": 140,
                "relationships": 180
            ]
        }

        #expect(value == [
            "summary": 140,
            "calendar": 200,
            "relationships": 180
        ])
    }
}
