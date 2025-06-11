import SwiftUI
import UIKit

enum TaskDetailPlatformStyle {
    static let principalTitleFont: Font = .title2.weight(.bold)
    static let detailContentPadding: CGFloat = 16
    static let calendarCardBackground = Color.gray.opacity(0.08)
    static let summaryCardBackground = Color(uiColor: .systemBackground)
    static let routineLogsBackground = Color(uiColor: .systemBackground)
    static let sectionCardStroke = Color.gray.opacity(0.2)
    static let dueTodayTitleColor: Color = .red
    static let graphSheetBackground = Color(uiColor: .secondarySystemBackground)
    static let graphNodeCardBackground = Color(uiColor: .systemBackground)
}
