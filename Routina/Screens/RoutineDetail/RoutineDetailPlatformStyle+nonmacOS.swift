#if !os(macOS)
import SwiftUI
import UIKit

enum RoutineDetailPlatformStyle {
    static let principalTitleFont: Font = .title2.weight(.bold)
    static let routineLogsBackground = Color(uiColor: .systemBackground)
}
#endif
