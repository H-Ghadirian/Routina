import SwiftUI

struct TaskDetailOverviewHeightsPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

enum TaskDetailCollapsedTitlePresentation {
    static func shouldShow(titleMaxY: CGFloat?) -> Bool {
        guard let titleMaxY else { return false }
        return titleMaxY <= 0
    }
}
