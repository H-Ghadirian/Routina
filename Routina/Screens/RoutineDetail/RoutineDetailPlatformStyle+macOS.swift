#if os(macOS)
import AppKit
import SwiftUI

enum RoutineDetailPlatformStyle {
    static let principalTitleFont: Font = .title3.weight(.semibold)
    static let routineLogsBackground = Color(nsColor: .windowBackgroundColor)
}
#endif
