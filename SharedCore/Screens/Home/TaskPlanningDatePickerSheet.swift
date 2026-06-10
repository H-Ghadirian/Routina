import SwiftUI

struct TaskPlanningDatePickerSheet: View {
    @Binding var date: Date
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
#if os(macOS)
        macBody
#else
        NavigationStack {
            Form {
                DatePicker(
                    "Plan date",
                    selection: $date,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
            }
            .navigationTitle("Plan to do")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }
            }
        }
#if os(iOS)
        .presentationDetents([.medium])
#endif
#endif
    }

#if os(macOS)
    private var macBody: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.14))
                        )

                    Text("Plan to do")
                        .font(.headline)

                    Spacer()
                }

                TaskPlanningSelectedDateHeader(date: $date)

                TaskPlanningMonthCalendar(selection: $date)
            }
            .padding(20)

            Divider()

            HStack(spacing: 10) {
                Spacer()

                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.bar)
        }
        .frame(width: 380)
    }
#endif
}

#if os(macOS)
private struct TaskPlanningSelectedDateHeader: View {
    @Binding var date: Date
    @Environment(\.calendar) private var calendar

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Plan date")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer()

            Button("Today") {
                date = calendar.startOfDay(for: Date())
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct TaskPlanningMonthCalendar: View {
    @Binding var selection: Date
    @Environment(\.calendar) private var calendar
    @State private var visibleMonth: Date

    private let columns = Array(
        repeating: GridItem(.fixed(42), spacing: 4, alignment: .center),
        count: 7
    )

    init(selection: Binding<Date>) {
        _selection = selection
        _visibleMonth = State(
            initialValue: Calendar.current.dateInterval(of: .month, for: selection.wrappedValue)?.start
                ?? selection.wrappedValue
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Button {
                    moveVisibleMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Previous month")

                Button {
                    moveVisibleMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Next month")

                Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)

                Button {
                    moveVisibleMonthToSelection()
                } label: {
                    Image(systemName: "scope")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Show selected month")
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 42, height: 18)
                }

                ForEach(calendarDays, id: \.self) { day in
                    TaskPlanningMonthDayButton(
                        day: day,
                        visibleMonth: visibleMonth,
                        selection: selection,
                        select: select
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .onAppear(perform: moveVisibleMonthToSelection)
        .onChange(of: selection) { _, newValue in
            guard !calendar.isDate(newValue, equalTo: visibleMonth, toGranularity: .month) else { return }
            visibleMonth = monthStart(for: newValue)
        }
    }

    private var weekdaySymbols: [String] {
        ordered(calendar.shortStandaloneWeekdaySymbols).map { symbol in
            String(symbol.prefix(2))
        }
    }

    private var calendarDays: [Date] {
        guard let firstDay = calendar.dateInterval(of: .month, for: visibleMonth)?.start else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        guard let firstGridDay = calendar.date(byAdding: .day, value: -leadingDays, to: firstDay) else {
            return []
        }

        return (0..<42).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: firstGridDay)
        }
    }

    private func ordered(_ symbols: [String]) -> [String] {
        guard !symbols.isEmpty else { return [] }
        let firstIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[firstIndex...]) + Array(symbols[..<firstIndex])
    }

    private func select(_ day: Date) {
        selection = calendar.startOfDay(for: day)
        if !calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month) {
            visibleMonth = monthStart(for: day)
        }
    }

    private func moveVisibleMonth(by offset: Int) {
        visibleMonth = calendar.date(byAdding: .month, value: offset, to: visibleMonth)
            .map(monthStart(for:))
            ?? visibleMonth
    }

    private func moveVisibleMonthToSelection() {
        visibleMonth = monthStart(for: selection)
    }

    private func monthStart(for date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}

private struct TaskPlanningMonthDayButton: View {
    let day: Date
    let visibleMonth: Date
    let selection: Date
    let select: (Date) -> Void

    @Environment(\.calendar) private var calendar

    var body: some View {
        Button {
            select(day)
        } label: {
            Text(dayNumber)
                .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(foregroundStyle)
                .frame(width: 34, height: 28)
                .background(background)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
    }

    private var dayNumber: String {
        String(calendar.component(.day, from: day))
    }

    private var isSelected: Bool {
        calendar.isDate(day, inSameDayAs: selection)
    }

    private var isToday: Bool {
        calendar.isDateInToday(day)
    }

    private var isInVisibleMonth: Bool {
        calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month)
    }

    private var foregroundStyle: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color(nsColor: .alternateSelectedControlTextColor))
        }

        if isInVisibleMonth {
            return AnyShapeStyle(Color.primary)
        }

        return AnyShapeStyle(Color.secondary.opacity(0.58))
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.accentColor)
        } else if isToday {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
        }
    }
}
#endif
