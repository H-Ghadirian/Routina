import SwiftUI
import ComposableArchitecture

struct RoutineDetailTCAView: View {
    let store: StoreOf<RoutineDetailFeature>
    @State private var displayedMonthStart = Calendar.current.startOfMonth(for: Date())

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            VStack(spacing: 20) {
                Text(viewStore.task.name ?? "Unnamed Routine")
                    .font(.largeTitle)
                    .bold()

                if viewStore.overdueDays > 0 {
                    Text("Overdue by \(viewStore.overdueDays) day(s)")
                        .foregroundColor(.red)
                        .fontWeight(.bold)
                } else if viewStore.isDoneToday || viewStore.daysSinceLastRoutine == 0 {
                    Text(viewStore.logs.isEmpty ? "Created Today!" : "Done Today!")
                } else {
                    Text("\(viewStore.daysSinceLastRoutine) day(s) since last done")
                }

                if let dueDate = Calendar.current.date(byAdding: .day, value: Int(viewStore.task.interval), to: viewStore.task.lastDone ?? Date()) {
                    Text("Due Date: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundColor(.red)
                }

                VStack(alignment: .leading, spacing: 10) {
                    calendarHeader
                    calendarGrid(
                        doneDates: doneDates(from: viewStore.logs),
                        dueDate: dueDate(for: viewStore.task)
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.08))
                .cornerRadius(12)

                Button("Mark as Done") {
                    viewStore.send(.markAsDone)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewStore.isDoneToday)

                if viewStore.logs.isEmpty {
                    Text("Never done yet")
                } else {
                    List {
                        Section(header: Text("Routine Logs")) {
                            ForEach(viewStore.logs, id: \.self) { log in
                                Text(log.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .onAppear {
                viewStore.send(.onAppear)
                displayedMonthStart = Calendar.current.startOfMonth(for: Date())
            }
        }
    }

    private var calendarHeader: some View {
        HStack {
            Button {
                displayedMonthStart = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonthStart) ?? displayedMonthStart
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(displayedMonthStart.formatted(.dateTime.month(.wide).year()))
                .font(.headline)

            Spacer()

            Button {
                displayedMonthStart = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonthStart) ?? displayedMonthStart
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private func calendarGrid(doneDates: Set<Date>, dueDate: Date?) -> some View {
        let calendar = Calendar.current
        let start = displayedMonthStart
        let days = calendar.daysInMonthGrid(for: start)
        let weekdaySymbols = calendar.orderedShortStandaloneWeekdaySymbols

        return VStack(spacing: 8) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        calendarDayCell(
                            day: day,
                            doneDates: doneDates,
                            dueDate: dueDate
                        )
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
        }
    }

    private func calendarDayCell(day: Date, doneDates: Set<Date>, dueDate: Date?) -> some View {
        let calendar = Calendar.current
        let isDueDate = dueDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isDoneDate = doneDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isToday = calendar.isDateInToday(day)
        let isDueToTodayRangeDate = isInDueToTodayRange(day: day, dueDate: dueDate)

        let backgroundColor: Color = {
            if isDoneDate { return .green }
            if isDueToTodayRangeDate || isDueDate { return .red }
            if isToday { return .blue }
            return .clear
        }()

        let foregroundColor: Color = (isDueDate || isDoneDate || isDueToTodayRangeDate || isToday) ? .white : .primary

        return Text(day.formatted(.dateTime.day()))
            .font(.subheadline)
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(Circle().fill(backgroundColor))
            .overlay(
                Circle()
                    .stroke((isToday && (isDoneDate || isDueToTodayRangeDate || isDueDate)) ? Color.blue : Color.clear, lineWidth: 2)
            )
    }

    private func doneDates(from logs: [RoutineLog]) -> Set<Date> {
        let calendar = Calendar.current
        return Set(logs.compactMap { $0.timestamp }.map { calendar.startOfDay(for: $0) })
    }

    private func dueDate(for task: RoutineTask) -> Date? {
        Calendar.current.date(byAdding: .day, value: Int(task.interval), to: task.lastDone ?? Date())
    }

    private func isInDueToTodayRange(day: Date, dueDate: Date?) -> Bool {
        guard let dueDate else { return false }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let dueStart = calendar.startOfDay(for: dueDate)
        let todayStart = calendar.startOfDay(for: Date())

        guard dueStart <= todayStart else { return false }
        return dayStart >= dueStart && dayStart <= todayStart
    }
}

private extension Calendar {
    var orderedShortStandaloneWeekdaySymbols: [String] {
        let symbols = shortStandaloneWeekdaySymbols
        let startIndex = firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }

    func daysInMonthGrid(for monthStart: Date) -> [Date?] {
        guard
            let monthRange = range(of: .day, in: .month, for: monthStart),
            let monthInterval = dateInterval(of: .month, for: monthStart)
        else { return [] }

        let firstDay = monthInterval.start
        let firstWeekday = component(.weekday, from: firstDay)
        let leadingEmptyDays = (firstWeekday - self.firstWeekday + 7) % 7

        var result: [Date?] = Array(repeating: nil, count: leadingEmptyDays)
        for day in monthRange {
            if let date = date(byAdding: .day, value: day - 1, to: firstDay) {
                result.append(date)
            }
        }
        while result.count % 7 != 0 {
            result.append(nil)
        }
        return result
    }
}
