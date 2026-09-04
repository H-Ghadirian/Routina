import SwiftUI

struct TaskDetailOverviewHeightsPreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

enum TaskDetailCollapsedTitlePresentation {
    static func shouldShow(
        titleMaxY: CGFloat?,
        currentVisibility: Bool
    ) -> Bool {
        guard let titleMaxY else { return currentVisibility }
        return titleMaxY <= 0
    }
}
