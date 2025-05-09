import AppKit
import SwiftUI

enum TaskDetailPlatformStyle {
    static let principalTitleFont: Font = .title3.weight(.semibold)
    static let detailContentPadding: CGFloat = 20
    static let calendarCardBackground = Color(nsColor: .controlBackgroundColor)
    static let summaryCardBackground = Color(nsColor: .windowBackgroundColor)
    static let routineLogsBackground = Color(nsColor: .windowBackgroundColor)
    static let sectionCardStroke = Color.primary.opacity(0.12)
    static let dueTodayTitleColor: Color = .orange
}
