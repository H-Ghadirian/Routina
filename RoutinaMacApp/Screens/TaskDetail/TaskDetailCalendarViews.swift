import SwiftUI

struct TaskDetailCalendarCardView<CalendarContent: View>: View {
    let header: TaskDetailCalendarHeaderView
    let showsAssumedLegend: Bool
    let showsPausedLegend: Bool
    let calendarContent: CalendarContent

    init(
        displayedMonthStart: Date,
        onPreviousMonth: @escaping () -> Void,
        onNextMonth: @escaping () -> Void,
        showsAssumedLegend: Bool,
        showsPausedLegend: Bool,
        @ViewBuilder calendarContent: () -> CalendarContent
    ) {
        self.header = TaskDetailCalendarHeaderView(
            displayedMonthStart: displayedMonthStart,
            onPreviousMonth: onPreviousMonth,
            onNextMonth: onNextMonth
        )
        self.showsAssumedLegend = showsAssumedLegend
        self.showsPausedLegend = showsPausedLegend
        self.calendarContent = calendarContent()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 8)

            calendarContent
                .padding(.bottom, 12)

            Spacer(minLength: 0)

            Divider()
                .padding(.bottom, 12)

            TaskDetailCalendarLegendView(
                showsAssumedLegend: showsAssumedLegend,
                showsPausedLegend: showsPausedLegend
            )
        }
        .padding(12)
        .routinaPlatformCalendarCardStyle()
    }
}

struct TaskDetailCalendarHeaderView: View {
    let displayedMonthStart: Date
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void

    var body: some View {
        HStack {
            Button(action: onPreviousMonth) {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(displayedMonthStart.formatted(.dateTime.month(.wide).year()))
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button(action: onNextMonth) {
                Image(systemName: "chevron.right")
            }
        }
    }
}

struct TaskDetailCalendarLegendView: View {
    let showsAssumedLegend: Bool
    let showsPausedLegend: Bool

    var body: some View {
        HStack(spacing: 12) {
            TaskDetailCalendarLegendItemView(color: .green, label: "Done")
            if showsAssumedLegend {
                TaskDetailCalendarLegendItemView(color: .mint, label: "Assumed")
            }
            TaskDetailCalendarLegendItemView(color: .red, label: "Overdue")
            if showsPausedLegend {
                TaskDetailCalendarLegendItemView(color: .teal, label: "Paused")
            }
            HStack(spacing: 4) {
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: 10, height: 10)
                Text("Today")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TaskDetailCalendarLegendItemView: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
