import SwiftUI

extension DayPlanWeekCalendarView {
    private func scrollToCurrentTime(with proxy: ScrollViewProxy) {
        guard dates.contains(where: { calendar.isDateInToday($0) }) else { return }

        DispatchQueue.main.async {
            proxy.scrollTo(DayPlanScrollTarget.currentTime, anchor: .center)
        }
    }

    func scrollToInitialTarget(with proxy: ScrollViewProxy) {
        if !scrollToPlannerHighlight(with: proxy), !scrollToFocusedSleep(with: proxy) {
            scrollToCurrentTime(with: proxy)
        }
    }

    @discardableResult
    func scrollToFocusedSleep(with proxy: ScrollViewProxy) -> Bool {
        guard let focusedSleep else { return false }

        DispatchQueue.main.async {
            proxy.scrollTo(DayPlanScrollTarget.focusedSleep(focusedSleep.scrollTargetID), anchor: .center)
        }
        return true
    }

    @discardableResult
    func scrollToPlannerHighlight(with proxy: ScrollViewProxy) -> Bool {
        guard let highlightedBlockID else { return false }

        DispatchQueue.main.async {
            proxy.scrollTo(DayPlanScrollTarget.plannerBlock(highlightedBlockID), anchor: .center)
        }
        return true
    }

}
