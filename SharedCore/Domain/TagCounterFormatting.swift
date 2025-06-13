import Foundation

enum TagCounterFormatting {
    static func chipTitle(
        tag: String,
        summary: RoutineTagSummary?,
        mode: TagCounterDisplayMode
    ) -> String {
        let baseTitle = "#\(tag)"

        guard let summary else { return baseTitle }

        switch mode {
        case .none:
            return baseTitle
        case .linkedAndDone:
            return "\(baseTitle) \(summary.linkedRoutineCount)t \(summary.doneCount)d"
        case .combinedTotal:
            return "\(baseTitle) \(summary.linkedRoutineCount + summary.doneCount)"
        case .linkedOnly:
            return "\(baseTitle) \(summary.linkedRoutineCount)"
        case .doneOnly:
            return "\(baseTitle) \(summary.doneCount)"
        }
    }
}
