import SwiftUI

enum DayPlanWeekCalendarSizing {
    static let timeColumnWidth: CGFloat = 64
    static let regularMinimumCalendarWidth: CGFloat = 420
    static let inspectorMinimumCalendarWidth: CGFloat = 360
    static let inspectorMultiDayMinimumCalendarWidth: CGFloat = 860
    static let regularMinimumDayWidth: CGFloat = 96
    static let inspectorMinimumDayWidth: CGFloat = 96
    static let detailPadding: CGFloat = 20
    static let detailHorizontalPadding: CGFloat = detailPadding * 2
    static let dayTaskListColumnPadding: CGFloat = 10

    private static let dayTaskListRowHorizontalPadding: CGFloat = 20
    private static let dayTaskListAvatarWidth: CGFloat = 34
    private static let dayTaskListAvatarSpacing: CGFloat = 10
    private static let dayTaskListTrailingTextReserve: CGFloat = 16
    private static let minimumDayTaskListTextWidthWithAvatar: CGFloat = 88

    static func minimumCalendarWidth(isExternalInspectorPresented: Bool) -> CGFloat {
        isExternalInspectorPresented ? inspectorMinimumCalendarWidth : regularMinimumCalendarWidth
    }

    static func minimumDetailWidth(isExternalInspectorPresented: Bool) -> CGFloat {
        minimumCalendarWidth(isExternalInspectorPresented: isExternalInspectorPresented) + detailHorizontalPadding
    }

    static func minimumDayWidth(isExternalInspectorPresented: Bool) -> CGFloat {
        isExternalInspectorPresented ? inspectorMinimumDayWidth : regularMinimumDayWidth
    }

    static func dayWidth(
        availableWidth: CGFloat,
        dayCount: Int,
        isExternalInspectorPresented: Bool
    ) -> CGFloat {
        let dayCount = max(dayCount, 1)
        let minimumDayWidth = minimumDayWidth(
            isExternalInspectorPresented: isExternalInspectorPresented
        )
        let availableDayWidth = max(availableWidth - timeColumnWidth, 0) / CGFloat(dayCount)
        return max(availableDayWidth, minimumDayWidth)
    }

    static func showsDayTaskListAvatar(rowWidth: CGFloat?) -> Bool {
        guard let rowWidth, rowWidth.isFinite else { return true }

        let reservedWidth =
            dayTaskListRowHorizontalPadding
            + dayTaskListAvatarWidth
            + dayTaskListAvatarSpacing
            + dayTaskListTrailingTextReserve

        return rowWidth - reservedWidth >= minimumDayTaskListTextWidthWithAvatar
    }
}
