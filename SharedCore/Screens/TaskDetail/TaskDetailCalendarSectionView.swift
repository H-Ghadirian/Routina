import SwiftUI

struct TaskDetailCalendarSectionView<CalendarContent: View>: View {
    let displayedMonthStart: Date
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let isTodaySelected: Bool
    let onToday: () -> Void
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
        isTodaySelected: Bool,
        onToday: @escaping () -> Void,
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
        self.isTodaySelected = isTodaySelected
        self.onToday = onToday
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
                onNextMonth: onNextMonth,
                isTodaySelected: isTodaySelected,
                onToday: onToday
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
    let isTodaySelected: Bool
    let onToday: () -> Void

    var body: some View {
        HStack {
            Button(action: onPreviousMonth) {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(displayedMonthStart.formatted(.dateTime.month(.wide).year()))
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button("Today", action: onToday)
                .controlSize(.small)
                .disabled(isTodaySelected)
                .accessibilityHint("Select today")

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
        ViewThatFits(in: .horizontal) {
            horizontalLegend
            wrappingLegend
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var horizontalLegend: some View {
        HStack(spacing: 24) {
            ForEach(legendItems) { item in
                TaskDetailCalendarSectionLegendItemView(item: item)
            }
        }
    }

    private var wrappingLegend: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 72), spacing: 10, alignment: .leading)
            ],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(legendItems) { item in
                TaskDetailCalendarSectionLegendItemView(item: item)
            }
        }
    }

    private var legendItems: [TaskDetailCalendarSectionLegendItem] {
        var items: [TaskDetailCalendarSectionLegendItem] = []

        if showsCreatedLegend {
            items.append(TaskDetailCalendarSectionLegendItem(color: TaskDetailStatusPalette.created, label: "Created"))
        }
        items.append(TaskDetailCalendarSectionLegendItem(color: TaskDetailStatusPalette.done, label: "Done"))
        if showsAssumedLegend {
            items.append(TaskDetailCalendarSectionLegendItem(color: TaskDetailStatusPalette.assumed, label: "Assumed"))
        }
        if showsMissedLegend {
            items.append(TaskDetailCalendarSectionLegendItem(color: TaskDetailStatusPalette.missed, label: "Missed"))
        }
        if showsCanceledLegend {
            items.append(TaskDetailCalendarSectionLegendItem(color: TaskDetailStatusPalette.canceled, label: "Canceled"))
        }
        if showsDueLegend {
            items.append(TaskDetailCalendarSectionLegendItem(color: TaskDetailStatusPalette.due, label: "Due"))
        }
        if showsOverdueLegend {
            items.append(TaskDetailCalendarSectionLegendItem(color: TaskDetailStatusPalette.overdue, label: "Overdue"))
        }
        if showsSoftDueLegend {
            items.append(TaskDetailCalendarSectionLegendItem(color: TaskDetailStatusPalette.due, label: "Gentle nudge"))
        }
        if showsPausedLegend {
            items.append(TaskDetailCalendarSectionLegendItem(color: TaskDetailStatusPalette.paused, label: "Paused"))
        }
        items.append(TaskDetailCalendarSectionLegendItem(color: TaskDetailStatusPalette.today, label: "Today", isUnderlined: true))

        return items
    }
}

private struct TaskDetailCalendarSectionLegendItem: Identifiable {
    let color: Color
    let label: String
    var isStroked = false
    var isUnderlined = false

    var id: String { label }
}

private struct TaskDetailCalendarSectionLegendItemView: View {
    let item: TaskDetailCalendarSectionLegendItem

    var body: some View {
        HStack(spacing: 4) {
            marker
                .frame(width: 10, height: 10)
            Text(item.label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var marker: some View {
        if item.isUnderlined {
            Text("1")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(item.color)
                .underline(true, color: item.color)
        } else if item.isStroked {
            Circle()
                .stroke(item.color, lineWidth: 2)
        } else {
            Circle()
                .fill(item.color)
        }
    }
}
