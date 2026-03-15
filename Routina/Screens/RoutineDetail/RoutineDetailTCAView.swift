import SwiftUI
import ComposableArchitecture

struct RoutineDetailTCAView: View {
    let store: StoreOf<RoutineDetailFeature>
    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonthStart = Calendar.current.startOfMonth(for: Date())
    @State private var isShowingAllLogs = false
    @State private var isEditEmojiPickerPresented = false
    private let emojiOptions = EmojiCatalog.uniqueQuick
    private let allEmojiOptions = EmojiCatalog.searchableAll

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        calendarHeader
                        calendarGrid(
                            doneDates: doneDates(from: store.logs),
                            dueDate: dueDate(for: store.task),
                            isOrangeUrgencyToday: isOrangeUrgency(store.task),
                            selectedDate: selectedDate,
                            onSelectDate: { store.send(.selectedDateChanged($0)) }
                        )
                        calendarLegend
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(12)

                    VStack(spacing: 6) {
                        Text(
                            summaryTitle(
                                isDoneToday: store.isDoneToday,
                                overdueDays: store.overdueDays,
                                daysSinceLastRoutine: store.daysSinceLastRoutine,
                                task: store.task
                            )
                        )
                            .font(.title3.weight(.semibold))
                            .foregroundColor(
                                summaryTitleColor(
                                    isDoneToday: store.isDoneToday,
                                    overdueDays: store.overdueDays,
                                    task: store.task
                                )
                            )
                        Text("Frequency: \(frequencyText(for: store.task))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(totalDoneCountText(for: store.logs.count))
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.secondary)
                        if let dueDate = dueDate(for: store.task) {
                            Text("Due date: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)

                    VStack(spacing: 10) {
                        Text("Selected date: \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button(markDoneButtonTitle(for: selectedDate, isDone: isSelectedDateDone, isFuture: isSelectedDateInFuture)) {
                            store.send(.markAsDone)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(isSelectedDateDone || isSelectedDateInFuture)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Routine Logs")
                            .font(.headline)

                        if store.logs.isEmpty {
                            Text("No logs yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            let logs = displayedLogs(from: store.logs)
                            ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                                Text(log.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)

                                if index < logs.count - 1 {
                                    Divider()
                                }
                            }

                            if store.logs.count > 3 {
                                Button(isShowingAllLogs ? "Show less" : "See all (\(store.logs.count))") {
                                    isShowingAllLogs.toggle()
                                }
                                .font(.footnote.weight(.semibold))
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(12)
                    .background(routineLogsBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding()
            }
            .routinaInlineTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text(routineEmoji(for: store.task))
                        Text(store.task.name ?? "Routine")
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.85)
                    }
                    .font(RoutineDetailPlatformStyle.principalTitleFont)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        store.send(.setEditSheet(true))
                    }
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { store.isEditSheetPresented },
                    set: { store.send(.setEditSheet($0)) }
                )
            ) {
                NavigationStack {
                    RoutineDetailEditRoutineContent(
                        store: store,
                        isEditEmojiPickerPresented: $isEditEmojiPickerPresented,
                        emojiOptions: emojiOptions
                    )
                    .navigationTitle("Edit Routine")
                    .routinaInlineTitleDisplayMode()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                store.send(.setEditSheet(false))
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                store.send(.editSaveTapped)
                            }
                            .disabled(
                                !canSaveEdit(
                                    name: store.editRoutineName,
                                    emoji: store.editRoutineEmoji,
                                    frequency: store.editFrequency,
                                    frequencyValue: store.editFrequencyValue,
                                    task: store.task
                                )
                            )
                        }
                    }
                    .sheet(isPresented: $isEditEmojiPickerPresented) {
                        EmojiPickerSheet(
                            selectedEmoji: Binding(
                                get: { store.editRoutineEmoji },
                                set: { store.send(.editRoutineEmojiChanged($0)) }
                            ),
                            emojis: allEmojiOptions
                        )
                    }
                    .alert(
                        "Delete routine?",
                        isPresented: Binding(
                            get: { store.isDeleteConfirmationPresented },
                            set: { store.send(.setDeleteConfirmation($0)) }
                        )
                    ) {
                        Button("Delete", role: .destructive) {
                            store.send(.deleteRoutineConfirmed)
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will permanently remove \(store.task.name ?? "this routine") and its logs.")
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
                displayedMonthStart = Calendar.current.startOfMonth(for: selectedDate)
            }
            .onChange(of: store.shouldDismissAfterDelete) { _, shouldDismiss in
                guard shouldDismiss else { return }
                dismiss()
                store.send(.deleteDismissHandled)
            }
            .onChange(of: selectedDate) { _, newValue in
                displayedMonthStart = Calendar.current.startOfMonth(for: newValue)
            }
        }
    }

    private var selectedDate: Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: store.selectedDate ?? Date())
    }

    private var isSelectedDateDone: Bool {
        let calendar = Calendar.current
        return store.logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            return calendar.isDate(timestamp, inSameDayAs: selectedDate)
        }
        || store.task.lastDone.map { calendar.isDate($0, inSameDayAs: selectedDate) } == true
    }

    private var isSelectedDateInFuture: Bool {
        Calendar.current.startOfDay(for: selectedDate) > Calendar.current.startOfDay(for: Date())
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

    private var routineLogsBackground: Color {
        RoutineDetailPlatformStyle.routineLogsBackground
    }

    private func calendarGrid(
        doneDates: Set<Date>,
        dueDate: Date?,
        isOrangeUrgencyToday: Bool,
        selectedDate: Date,
        onSelectDate: @escaping (Date) -> Void
    ) -> some View {
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
                            isOrangeUrgencyToday: isOrangeUrgencyToday,
                            isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                            onSelectDate: onSelectDate
                        )
                    } else {
                        Color.clear
                            .frame(height: 28)
                    }
                }
            }
        }
    }

    private func calendarDayCell(
        day: Date,
        doneDates: Set<Date>,
        dueDate: Date?,
        isOrangeUrgencyToday: Bool,
        isSelected: Bool,
        onSelectDate: @escaping (Date) -> Void
    ) -> some View {
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

        return Button {
            onSelectDate(day)
        } label: {
            Text(day.formatted(.dateTime.day()))
                .font(.subheadline)
                .foregroundColor(foregroundColor)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(Circle().fill(backgroundColor))
                .overlay(
                    Circle()
                        .stroke(selectionStrokeColor(isSelected: isSelected, isToday: isToday, isHighlightedDay: isDoneDate || isDueToTodayRangeDate || isDueDate), lineWidth: isSelected ? 3 : 2)
                )
        }
        .buttonStyle(.plain)
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

    private func summaryTitle(
        isDoneToday: Bool,
        overdueDays: Int,
        daysSinceLastRoutine: Int,
        task: RoutineTask
    ) -> String {
        if isDoneToday {
            return "Done today"
        }
        if overdueDays > 0 {
            return "Overdue by \(overdueDays) \(dayWord(overdueDays))"
        }
        guard let daysUntilDue = daysUntilDue(task) else {
            return "\(daysSinceLastRoutine) \(dayWord(daysSinceLastRoutine)) since last done"
        }
        if daysUntilDue == 0 {
            return "Due today"
        }
        if daysUntilDue > 0 {
            return "Due in \(daysUntilDue) \(dayWord(daysUntilDue))"
        }
        return "Overdue by \(-daysUntilDue) \(dayWord(-daysUntilDue))"
    }

    private func summaryTitleColor(
        isDoneToday: Bool,
        overdueDays: Int,
        task: RoutineTask
    ) -> Color {
        if isDoneToday { return .green }
        if overdueDays > 0 { return .red }
        if daysUntilDue(task) == 0 { return .red }
        if isOrangeUrgency(task) { return .orange }
        return .primary
    }

    private func displayedLogs(from logs: [RoutineLog]) -> [RoutineLog] {
        if isShowingAllLogs { return logs }
        return Array(logs.prefix(3))
    }

    private func routineEmoji(for task: RoutineTask) -> String {
        task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨"
    }

    private func canSaveEdit(
        name: String,
        emoji: String,
        frequency: RoutineDetailFeature.EditFrequency,
        frequencyValue: Int,
        task: RoutineTask
    ) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        let currentName = (task.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let currentEmoji = task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨"
        let currentInterval = max(Int(task.interval), 1)
        let newInterval = frequencyValue * frequency.daysMultiplier

        return trimmedName != currentName || emoji != currentEmoji || newInterval != currentInterval
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

    private func totalDoneCountText(for count: Int) -> String {
        count == 1 ? "1 total done" : "\(count) total dones"
    }

    private func markDoneButtonTitle(for selectedDate: Date, isDone: Bool, isFuture: Bool) -> String {
        if isFuture {
            return "Future dates can't be marked done"
        }
        if isDone {
            return "Already done on \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
        }
        if Calendar.current.isDateInToday(selectedDate) {
            return "Mark Today as Done"
        }
        return "Mark \(selectedDate.formatted(date: .abbreviated, time: .omitted)) as Done"
    }

    private func selectionStrokeColor(isSelected: Bool, isToday: Bool, isHighlightedDay: Bool) -> Color {
        if isSelected { return .blue }
        if isToday && isHighlightedDay { return .blue }
        return .clear
    }

    private func dayWord(_ count: Int) -> String {
        abs(count) == 1 ? "day" : "days"
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
