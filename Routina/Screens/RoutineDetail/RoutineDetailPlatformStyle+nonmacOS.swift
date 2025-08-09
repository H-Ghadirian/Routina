#if !os(macOS)
import SwiftUI
import UIKit

enum RoutineDetailPlatformStyle {
    static let principalTitleFont: Font = .title2.weight(.bold)
    static let detailContentPadding: CGFloat = 16
    static let calendarCardBackground = Color.gray.opacity(0.08)
    static let summaryCardBackground = Color(uiColor: .systemBackground)
    static let routineLogsBackground = Color(uiColor: .systemBackground)
    static let sectionCardStroke = Color.gray.opacity(0.2)
    static let dueTodayTitleColor: Color = .red
}
#endif
