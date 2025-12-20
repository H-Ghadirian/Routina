import SwiftUI
import ComposableArchitecture

struct RoutineDetailTCAView: View {
    let store: StoreOf<RoutineDetailFeature>
    @State private var displayedMonthStart = Calendar.current.startOfMonth(for: Date())
    @State private var isShowingAllLogs = false
    @State private var isEditEmojiPickerPresented = false
    private let emojiOptions = EmojiCatalog.quick
    private let allEmojiOptions = EmojiCatalog.all

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        calendarHeader
                        calendarGrid(
                            doneDates: doneDates(from: viewStore.logs),
                            dueDate: dueDate(for: viewStore.task),
                            isOrangeUrgencyToday: isOrangeUrgency(viewStore.task)
                        )
                        calendarLegend
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(12)

                    VStack(spacing: 6) {
                        Text(summaryTitle(for: viewStore))
                            .font(.title3.weight(.semibold))
                            .foregroundColor(summaryTitleColor(for: viewStore))
                        Text("Frequency: \(frequencyText(for: viewStore.task))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let dueDate = dueDate(for: viewStore.task) {
                            Text("Due date: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)

                    if !viewStore.isDoneToday {
                        Button("Mark as Done") {
                            viewStore.send(.markAsDone)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Routine Logs")
                            .font(.headline)

                        if viewStore.logs.isEmpty {
                            Text("No logs yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            let logs = displayedLogs(from: viewStore.logs)
                            ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                                Text(log.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)

                                if index < logs.count - 1 {
                                    Divider()
                                }
                            }

                            if viewStore.logs.count > 3 {
                                Button(isShowingAllLogs ? "Show less" : "See all (\(viewStore.logs.count))") {
                                    isShowingAllLogs.toggle()
                                }
                                .font(.footnote.weight(.semibold))
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("\(routineEmoji(for: viewStore.task)) \(viewStore.task.name ?? "Routine")")
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        viewStore.send(.setEditSheet(true))
                    }
                }
            }
            .sheet(
                isPresented: viewStore.binding(
                    get: \.isEditSheetPresented,
                    send: RoutineDetailFeature.Action.setEditSheet
                )
            ) {
                NavigationStack {
                    Form {
                        Section(header: Text("Name")) {
                            TextField(
                                "Routine name",
                                text: viewStore.binding(
                                    get: \.editRoutineName,
                                    send: RoutineDetailFeature.Action.editRoutineNameChanged
                                )
                            )
                        }

                        Section(header: Text("Emoji")) {
                            HStack(spacing: 12) {
                                Text("Selected")
                                    .foregroundColor(.secondary)
                                Text(viewStore.editRoutineEmoji)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                Spacer()
                                Button("Choose Emoji") {
                                    isEditEmojiPickerPresented = true
                                }
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(emojiOptions, id: \.self) { emoji in
                                        Button {
                                            viewStore.send(.editRoutineEmojiChanged(emoji))
                                        } label: {
                                            Text(emoji)
                                                .font(.title2)
                                                .frame(width: 40, height: 40)
                                                .background(
                                                    Circle()
                                                        .fill(viewStore.editRoutineEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        Section(header: Text("Frequency")) {
                            Picker(
                                "Frequency",
                                selection: viewStore.binding(
                                    get: \.editFrequency,
                                    send: RoutineDetailFeature.Action.editFrequencyChanged
                                )
                            ) {
                                ForEach(RoutineDetailFeature.EditFrequency.allCases, id: \.self) { frequency in
                                    Text(frequency.rawValue).tag(frequency)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Section(header: Text("Repeat")) {
                            Stepper(
                                value: viewStore.binding(
                                    get: \.editFrequencyValue,
                                    send: RoutineDetailFeature.Action.editFrequencyValueChanged
                                ),
                                in: 1...365
                            ) {
                                Text(editStepperLabel(for: viewStore))
                            }
                        }
                    }
                    .navigationTitle("Edit Routine")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                viewStore.send(.setEditSheet(false))
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Save") {
                                viewStore.send(.editSaveTapped)
                            }
                            .disabled(viewStore.editRoutineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .sheet(isPresented: $isEditEmojiPickerPresented) {
                        RoutineDetailEmojiPickerSheet(
                            selectedEmoji: viewStore.binding(
                                get: \.editRoutineEmoji,
                                send: RoutineDetailFeature.Action.editRoutineEmojiChanged
                            ),
                            emojis: allEmojiOptions
                        )
                    }
                }
            }
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
                .font(.subheadline.weight(.semibold))

            Spacer()

            Button {
                displayedMonthStart = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonthStart) ?? displayedMonthStart
            } label: {
                Image(systemName: "chevron.right")
            }
        }
    }

    private var calendarLegend: some View {
        HStack(spacing: 12) {
            legendItem(color: .green, label: "Done")
            legendItem(color: .red, label: "Overdue")
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
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private func calendarGrid(doneDates: Set<Date>, dueDate: Date?, isOrangeUrgencyToday: Bool) -> some View {
        let calendar = Calendar.current
        let start = displayedMonthStart
        let days = calendar.daysInMonthGrid(for: start)
        let weekdaySymbols = calendar.orderedShortStandaloneWeekdaySymbols

        return VStack(spacing: 6) {
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        calendarDayCell(
                            day: day,
                            doneDates: doneDates,
                            dueDate: dueDate,
                            isOrangeUrgencyToday: isOrangeUrgencyToday
                        )
                    } else {
                        Color.clear
                            .frame(height: 28)
                    }
                }
            }
        }
    }

    private func calendarDayCell(day: Date, doneDates: Set<Date>, dueDate: Date?, isOrangeUrgencyToday: Bool) -> some View {
        let calendar = Calendar.current
        let isDueDate = dueDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isDoneDate = doneDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isToday = calendar.isDateInToday(day)
        let isDueToTodayRangeDate = isInDueToTodayRange(day: day, dueDate: dueDate)

        let backgroundColor: Color = {
            if isDoneDate { return .green }
            if isDueToTodayRangeDate || isDueDate { return .red }
            if isToday && isOrangeUrgencyToday { return .orange }
            if isToday { return .blue }
            return .clear
        }()

        let foregroundColor: Color = (isDueDate || isDoneDate || isDueToTodayRangeDate || isToday) ? .white : .primary

        return Text(day.formatted(.dateTime.day()))
            .font(.subheadline)
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
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

    private func isOrangeUrgency(_ task: RoutineTask) -> Bool {
        let daysSinceLastRoutine = Calendar.current.dateComponents(
            [.day],
            from: task.lastDone ?? Date(),
            to: Date()
        ).day ?? 0
        let progress = Double(daysSinceLastRoutine) / Double(task.interval)
        return progress >= 0.75 && progress < 0.90
    }

    private func daysUntilDue(_ task: RoutineTask) -> Int? {
        guard let dueDate = dueDate(for: task) else { return nil }
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let dueStart = calendar.startOfDay(for: dueDate)
        return calendar.dateComponents([.day], from: todayStart, to: dueStart).day
    }

    private func summaryTitle(for viewStore: ViewStoreOf<RoutineDetailFeature>) -> String {
        if viewStore.isDoneToday {
            return "Done today"
        }
        if viewStore.overdueDays > 0 {
            return "Overdue by \(viewStore.overdueDays) \(dayWord(viewStore.overdueDays))"
        }
        guard let daysUntilDue = daysUntilDue(viewStore.task) else {
            return "\(viewStore.daysSinceLastRoutine) \(dayWord(viewStore.daysSinceLastRoutine)) since last done"
        }
        if daysUntilDue == 0 {
            return "Due today"
        }
        if daysUntilDue > 0 {
            return "Due in \(daysUntilDue) \(dayWord(daysUntilDue))"
        }
        return "Overdue by \(-daysUntilDue) \(dayWord(-daysUntilDue))"
    }

    private func summaryTitleColor(for viewStore: ViewStoreOf<RoutineDetailFeature>) -> Color {
        if viewStore.isDoneToday { return .green }
        if viewStore.overdueDays > 0 { return .red }
        if isOrangeUrgency(viewStore.task) { return .orange }
        return .primary
    }

    private func displayedLogs(from logs: [RoutineLog]) -> [RoutineLog] {
        if isShowingAllLogs { return logs }
        return Array(logs.prefix(3))
    }

    private func routineEmoji(for task: RoutineTask) -> String {
        (task.value(forKey: "emoji") as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "✨"
    }

    private func frequencyText(for task: RoutineTask) -> String {
        let interval = max(Int(task.interval), 1)
        if interval % 30 == 0 {
            let value = interval / 30
            return value == 1 ? "Every month" : "Every \(value) months"
        }
        if interval % 7 == 0 {
            let value = interval / 7
            return value == 1 ? "Every week" : "Every \(value) weeks"
        }
        return interval == 1 ? "Every day" : "Every \(interval) days"
    }

    private func dayWord(_ count: Int) -> String {
        abs(count) == 1 ? "day" : "days"
    }

    private func editStepperLabel(for viewStore: ViewStoreOf<RoutineDetailFeature>) -> String {
        if viewStore.editFrequencyValue == 1 {
            switch viewStore.editFrequency {
            case .day: return "Everyday"
            case .week: return "Everyweek"
            case .month: return "Everymonth"
            }
        }
        return "Every \(viewStore.editFrequencyValue) \(viewStore.editFrequency.singularLabel)s"
    }
}

private struct RoutineDetailEmojiPickerSheet: View {
    @Binding var selectedEmoji: String
    let emojis: [String]
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.title2)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
