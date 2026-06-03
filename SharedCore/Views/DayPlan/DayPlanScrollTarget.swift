import Foundation

enum DayPlanScrollTarget: Hashable {
    case hour(Int)
    case currentTime
    case focusedSleep(UUID)
}
