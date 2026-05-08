import SwiftUI

struct TaskDetailCalendarSectionView<CalendarContent: View>: View {
    let displayedMonthStart: Date
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let showsAssumedLegend: Bool
    let showsMissedLegend: Bool
    let showsCanceledLegend: Bool
    let showsDueLegend: Bool
    let showsOverdueLegend: Bool
    let showsSoftDueLegend: Bool
    let showsPausedLegend: Bool
    let showsCreatedLegend: Bool
    let calendarContent: CalendarContent

    init(
        displayedMonthStart: Date,
        onPreviousMonth: @escaping () -> Void,
        onNextMonth: @escaping () -> Void,
        showsAssumedLegend: Bool,
        showsMissedLegend: Bool = false,
        showsCanceledLegend: Bool = false,
        showsDueLegend: Bool = false,
        showsOverdueLegend: Bool = true,
        showsSoftDueLegend: Bool,
        showsPausedLegend: Bool,
        showsCreatedLegend: Bool,
        @ViewBuilder calendarContent: () -> CalendarContent
    ) {
        self.displayedMonthStart = displayedMonthStart
        self.onPreviousMonth = onPreviousMonth
        self.onNextMonth = onNextMonth
        self.showsAssumedLegend = showsAssumedLegend
        self.showsMissedLegend = showsMissedLegend
        self.showsCanceledLegend = showsCanceledLegend
        self.showsDueLegend = showsDueLegend
        self.showsOverdueLegend = showsOverdueLegend
        self.showsSoftDueLegend = showsSoftDueLegend
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
                showsMissedLegend: showsMissedLegend,
                showsCanceledLegend: showsCanceledLegend,
                showsDueLegend: showsDueLegend,
                showsOverdueLegend: showsOverdueLegend,
                showsSoftDueLegend: showsSoftDueLegend,
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
    let showsMissedLegend: Bool
    let showsCanceledLegend: Bool
    let showsDueLegend: Bool
    let showsOverdueLegend: Bool
    let showsSoftDueLegend: Bool
    let showsPausedLegend: Bool
    let showsCreatedLegend: Bool

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 72), spacing: 10, alignment: .leading)
            ],
            alignment: .leading,
            spacing: 8
        ) {
            if showsCreatedLegend {
                TaskDetailCalendarSectionLegendItemView(color: .purple, label: "Created")
            }
            TaskDetailCalendarSectionLegendItemView(color: .green, label: "Done")
            if showsAssumedLegend {
                TaskDetailCalendarSectionLegendItemView(color: .mint, label: "Assumed")
            }
            if showsMissedLegend {
                TaskDetailCalendarSectionLegendItemView(color: .yellow, label: "Missed")
            }
            if showsCanceledLegend {
                TaskDetailCalendarSectionLegendItemView(color: .orange, label: "Canceled")
            }
            if showsDueLegend {
                TaskDetailCalendarSectionLegendItemView(color: .orange, label: "Due")
            }
            if showsOverdueLegend {
                TaskDetailCalendarSectionLegendItemView(color: .red, label: "Overdue")
            }
            if showsSoftDueLegend {
                TaskDetailCalendarSectionLegendItemView(color: .orange, label: "Soft due")
            }
            if showsPausedLegend {
                TaskDetailCalendarSectionLegendItemView(color: .teal, label: "Paused")
            }
            TaskDetailCalendarSectionTodayLegendItemView()
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
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct TaskDetailCalendarSectionTodayLegendItemView: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .stroke(Color.blue, lineWidth: 2)
                .frame(width: 10, height: 10)
            Text("Today")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
