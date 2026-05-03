import SwiftUI

struct TaskDetailCalendarSectionView<CalendarContent: View>: View {
    let displayedMonthStart: Date
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let showsAssumedLegend: Bool
    let showsPausedLegend: Bool
    let showsCreatedLegend: Bool
    let calendarContent: CalendarContent

    init(
        displayedMonthStart: Date,
        onPreviousMonth: @escaping () -> Void,
        onNextMonth: @escaping () -> Void,
        showsAssumedLegend: Bool,
        showsPausedLegend: Bool,
        showsCreatedLegend: Bool,
        @ViewBuilder calendarContent: () -> CalendarContent
    ) {
        self.displayedMonthStart = displayedMonthStart
        self.onPreviousMonth = onPreviousMonth
        self.onNextMonth = onNextMonth
        self.showsAssumedLegend = showsAssumedLegend
        self.showsPausedLegend = showsPausedLegend
        self.showsCreatedLegend = showsCreatedLegend
        self.calendarContent = calendarContent()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TaskDetailCalendarSectionHeaderView(
                displayedMonthStart: displayedMonthStart,
                onPreviousMonth: onPreviousMonth,
                onNextMonth: onNextMonth
            )
            .padding(.bottom, 8)

            calendarContent
                .padding(.bottom, 12)

            Spacer(minLength: 0)

            Divider()
                .padding(.bottom, 12)

            TaskDetailCalendarSectionLegendView(
                showsAssumedLegend: showsAssumedLegend,
                showsPausedLegend: showsPausedLegend,
                showsCreatedLegend: showsCreatedLegend
            )
        }
        .padding(12)
    }
}

private struct TaskDetailCalendarSectionHeaderView: View {
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

private struct TaskDetailCalendarSectionLegendView: View {
    let showsAssumedLegend: Bool
    let showsPausedLegend: Bool
    let showsCreatedLegend: Bool

    var body: some View {
        HStack(spacing: 12) {
            if showsCreatedLegend {
                TaskDetailCalendarSectionLegendItemView(color: .purple, label: "Created")
            }
            TaskDetailCalendarSectionLegendItemView(color: .green, label: "Done")
            if showsAssumedLegend {
                TaskDetailCalendarSectionLegendItemView(color: .mint, label: "Assumed")
            }
            TaskDetailCalendarSectionLegendItemView(color: .red, label: "Overdue")
            if showsPausedLegend {
                TaskDetailCalendarSectionLegendItemView(color: .teal, label: "Paused")
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

private struct TaskDetailCalendarSectionLegendItemView: View {
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
