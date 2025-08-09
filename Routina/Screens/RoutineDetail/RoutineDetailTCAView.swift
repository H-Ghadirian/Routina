import SwiftUI
import ComposableArchitecture

struct RoutineDetailTCAView: View {
    let store: StoreOf<RoutineDetailFeature>
    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonthStart = Calendar.current.startOfMonth(for: Date())
    @State private var isShowingAllLogs = false
    @State private var isEditEmojiPickerPresented = false
    @State private var syncedMacOverviewHeight: CGFloat = 0
    private let emojiOptions = EmojiCatalog.uniqueQuick
    private let allEmojiOptions = EmojiCatalog.searchableAll

    var body: some View {
        WithPerceptionTracking {
            let pauseArchivePresentation = RoutinePauseArchivePresentation.make(
                isPaused: store.task.isPaused,
                context: .detail
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detailOverviewSection(pauseArchivePresentation: pauseArchivePresentation)
                    routineLogsSection
                }
                .padding(RoutineDetailPlatformStyle.detailContentPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                                    selectedPlaceID: store.editSelectedPlaceID,
                                    tags: store.editRoutineTags,
                                    tagDraft: store.editTagDraft,
                                    steps: store.editRoutineSteps,
                                    stepDraft: store.editStepDraft,
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

    @ViewBuilder
    private func detailOverviewSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
#if os(macOS)
        HStack(alignment: .top, spacing: 20) {
            calendarSection
                .background(heightReader(id: "calendar"))
                .frame(
                    maxWidth: .infinity,
                    minHeight: syncedMacOverviewHeight > 0 ? syncedMacOverviewHeight : nil,
                    alignment: .topLeading
                )
                .background(RoutineDetailPlatformStyle.calendarCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(RoutineDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
                )
                .layoutPriority(1)

            macStatusSection(pauseArchivePresentation: pauseArchivePresentation)
                .background(heightReader(id: "status"))
                .frame(width: 320)
                .frame(
                    minHeight: syncedMacOverviewHeight > 0 ? syncedMacOverviewHeight : nil,
                    alignment: .topLeading
                )
                .background(RoutineDetailPlatformStyle.summaryCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(RoutineDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
                )
        }
        .onPreferenceChange(RoutineDetailOverviewHeightsPreferenceKey.self) { heights in
            let maxHeight = heights.values.max() ?? 0
            guard abs(maxHeight - syncedMacOverviewHeight) > 0.5 else { return }
            syncedMacOverviewHeight = maxHeight
        }
#else
        VStack(spacing: 16) {
            calendarSection
            compactStatusSection(pauseArchivePresentation: pauseArchivePresentation)
        }
#endif
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            calendarHeader
            calendarGrid(
                doneDates: doneDates(from: store.logs),
                dueDate: dueDate(for: store.task),
                pausedAt: store.task.pausedAt,
                isOrangeUrgencyToday: isOrangeUrgency(store.task),
                selectedDate: selectedDate,
                onSelectDate: { store.send(.selectedDateChanged($0)) }
            )
            calendarLegend
        }
        .padding(12)
#if !os(macOS)
        .background(RoutineDetailPlatformStyle.calendarCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RoutineDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
        )
#endif
    }

    private func heightReader(id: String) -> some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: RoutineDetailOverviewHeightsPreferenceKey.self,
                    value: [id: proxy.size.height]
                )
        }
    }

    private func compactStatusSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(summaryStatusTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(summaryStatusColor)
                Text("Frequency: \(frequencyText(for: store.task))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(totalDoneCountText(for: store.logs.count))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                if let linkedPlace = linkedPlaceSummary {
                    Label("Linked to \(linkedPlace.name)", systemImage: "location.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                }
                if let pausedAt = store.task.pausedAt {
                    Text("Paused on \(pausedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if let dueDate = dueDate(for: store.task) {
                    Text("Due date: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if store.task.hasSequentialSteps {
                    Text(stepProgressText(for: store.task))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    if let nextStepTitle = store.task.nextStepTitle {
                        Text("Next step: \(nextStepTitle)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

            VStack(spacing: 10) {
                Text("Selected date: \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(markDoneButtonLabel) {
                    store.send(.markAsDone)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(isMarkDoneDisabled)

                if isStepRoutineOffToday {
                    Text("Step-based routines can only be progressed for today.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(pauseArchivePresentation.actionTitle) {
                    store.send(store.task.isPaused ? .resumeTapped : .pauseTapped)
                }
                .buttonStyle(.bordered)
                .tint(store.task.isPaused ? .teal : .orange)
                .frame(maxWidth: .infinity)

                if let pauseDescription = pauseArchivePresentation.description {
                    Text(pauseDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func macStatusSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(summaryStatusTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(summaryStatusColor)

                if store.task.isPaused {
                    Text("This routine is archived until you resume it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if Calendar.current.isDateInToday(selectedDate) {
                    Text("Today is selected. Use the calendar to review another day when needed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Reviewing \(selectedDate.formatted(date: .abbreviated, time: .omitted)).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                macMetadataRow(label: "Frequency", value: frequencyText(for: store.task))
                macMetadataRow(label: "Completed", value: totalDoneCountText(for: store.logs.count))

                if let linkedPlace = linkedPlaceSummary {
                    macMetadataRow(label: "Location", value: linkedPlace.name, systemImage: "location")
                }

                if let pausedAt = store.task.pausedAt {
                    macMetadataRow(
                        label: "Paused",
                        value: pausedAt.formatted(date: .abbreviated, time: .omitted)
                    )
                } else if let dueDateMetadataText {
                    macMetadataRow(label: "Due", value: dueDateMetadataText)
                }

                if shouldShowSelectedDateMetadata {
                    macMetadataRow(label: "Selected", value: selectedDateMetadataText)
                }

                if store.task.hasSequentialSteps {
                    macMetadataRow(label: "Progress", value: stepProgressText(for: store.task))
                    if let nextStepTitle = store.task.nextStepTitle {
                        macMetadataRow(label: "Next Step", value: nextStepTitle)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Button(markDoneButtonLabel) {
                    store.send(.markAsDone)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(isMarkDoneDisabled)

                Button(pauseArchivePresentation.actionTitle) {
                    store.send(store.task.isPaused ? .resumeTapped : .pauseTapped)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .frame(maxWidth: .infinity, alignment: .leading)

                if isStepRoutineOffToday {
                    Text("Step-based routines can only be progressed for today.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let pauseDescription = pauseArchivePresentation.description {
                    Text(pauseDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
    }

    private func macMetadataRow(
        label: String,
        value: String,
        systemImage: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var routineLogsSection: some View {
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RoutineDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
        )
    }

    private var summaryStatusTitle: String {
        summaryTitle(
            pausedAt: store.task.pausedAt,
            isDoneToday: store.isDoneToday,
            overdueDays: store.overdueDays,
            daysSinceLastRoutine: store.daysSinceLastRoutine,
            task: store.task
        )
    }

    private var summaryStatusColor: Color {
        summaryTitleColor(
            pausedAt: store.task.pausedAt,
            isDoneToday: store.isDoneToday,
            overdueDays: store.overdueDays,
            task: store.task
        )
    }

    private var markDoneButtonLabel: String {
        markDoneButtonTitle(
            for: selectedDate,
            isDone: isSelectedDateDone,
            isFuture: isSelectedDateInFuture,
            isPaused: store.task.isPaused,
            task: store.task
        )
    }

    private var isMarkDoneDisabled: Bool {
        isSelectedDateDone || isSelectedDateInFuture || store.task.isPaused || isStepRoutineOffToday
    }

    private var dueDateMetadataText: String? {
        guard let dueDate = dueDate(for: store.task), !Calendar.current.isDateInToday(dueDate) else {
            return nil
        }
        return dueDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var shouldShowSelectedDateMetadata: Bool {
        !Calendar.current.isDateInToday(selectedDate)
    }

    private var selectedDateMetadataText: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today"
        }
        return selectedDate.formatted(date: .abbreviated, time: .omitted)
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

    private var isStepRoutineOffToday: Bool {
        store.task.hasSequentialSteps && !Calendar.current.isDateInToday(selectedDate)
    }

    private var linkedPlaceSummary: RoutinePlaceSummary? {
        guard let placeID = store.task.placeID else { return nil }
        return store.availablePlaces.first(where: { $0.id == placeID })
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
            if store.task.pausedAt != nil {
                legendItem(color: .teal, label: "Paused")
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
        pausedAt: Date?,
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
                            pausedAt: pausedAt,
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
        pausedAt: Date?,
        isOrangeUrgencyToday: Bool,
        isSelected: Bool,
        onSelectDate: @escaping (Date) -> Void
    ) -> some View {
        let calendar = Calendar.current
        let isDueDate = dueDate.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isDoneDate = doneDates.contains { calendar.isDate($0, inSameDayAs: day) }
        let isToday = calendar.isDateInToday(day)
        let isDueToTodayRangeDate = isInDueToTodayRange(day: day, dueDate: dueDate)
        let isPausedDate = isInPausedRange(day: day, pausedAt: pausedAt)

        let backgroundColor: Color = {
            if isDoneDate { return .green }
            if isPausedDate { return .teal }
            if isDueToTodayRangeDate || isDueDate { return .red }
            if isToday && isOrangeUrgencyToday { return .orange }
            if isToday { return .blue }
            return .clear
        }()

        let foregroundColor: Color = (isDueDate || isDoneDate || isDueToTodayRangeDate || isPausedDate || isToday) ? .white : .primary

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
                        .stroke(
                            selectionStrokeColor(
                                isSelected: isSelected,
                                isToday: isToday,
                                isHighlightedDay: isDoneDate || isDueToTodayRangeDate || isDueDate || isPausedDate
                            ),
                            lineWidth: isSelected ? 3 : 2
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func doneDates(from logs: [RoutineLog]) -> Set<Date> {
        let calendar = Calendar.current
        return Set(logs.compactMap { $0.timestamp }.map { calendar.startOfDay(for: $0) })
    }

    private func dueDate(for task: RoutineTask) -> Date? {
        RoutineDateMath.dueDate(for: task, referenceDate: Date())
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

    private func isInPausedRange(day: Date, pausedAt: Date?) -> Bool {
        guard let pausedAt else { return false }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let pausedStart = calendar.startOfDay(for: pausedAt)
        let todayStart = calendar.startOfDay(for: Date())
        return dayStart >= pausedStart && dayStart <= todayStart
    }

    private func isOrangeUrgency(_ task: RoutineTask) -> Bool {
        guard !task.isPaused else { return false }
        let anchor = task.scheduleAnchor ?? task.lastDone
        let daysSinceAnchor = RoutineDateMath.elapsedDaysSinceLastDone(from: anchor, referenceDate: Date())
        let progress = Double(daysSinceAnchor) / Double(task.interval)
        return progress >= 0.75 && progress < 0.90
    }

    private func daysUntilDue(_ task: RoutineTask) -> Int? {
        guard !task.isPaused else { return nil }
        return RoutineDateMath.daysUntilDue(for: task, referenceDate: Date())
    }

    private func summaryTitle(
        pausedAt: Date?,
        isDoneToday: Bool,
        overdueDays: Int,
        daysSinceLastRoutine: Int,
        task: RoutineTask
    ) -> String {
        if let pausedAt {
            return "Paused since \(pausedAt.formatted(date: .abbreviated, time: .omitted))"
        }
        if task.isInProgress {
            return "Step \(task.completedSteps + 1) of \(task.totalSteps) in progress"
        }
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
        pausedAt: Date?,
        isDoneToday: Bool,
        overdueDays: Int,
        task: RoutineTask
    ) -> Color {
        if pausedAt != nil { return .teal }
        if task.isInProgress { return .orange }
        if isDoneToday { return .green }
        if overdueDays > 0 { return .red }
        if daysUntilDue(task) == 0 { return RoutineDetailPlatformStyle.dueTodayTitleColor }
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
        selectedPlaceID: UUID?,
        tags: [String],
        tagDraft: String,
        steps: [RoutineStep],
        stepDraft: String,
        frequency: RoutineDetailFeature.EditFrequency,
        frequencyValue: Int,
        task: RoutineTask
    ) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        let currentName = (task.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let currentEmoji = task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨"
        let currentTags = RoutineTag.deduplicated(task.tags)
        let candidateTags = RoutineTag.appending(tagDraft, to: tags)
        let currentSteps = RoutineStep.sanitized(task.steps)
        let candidateSteps = RoutineStep.normalizedTitle(stepDraft).map { title in
            steps + [RoutineStep(title: title)]
        } ?? steps
        let currentInterval = max(Int(task.interval), 1)
        let newInterval = frequencyValue * frequency.daysMultiplier

        return trimmedName != currentName
            || emoji != currentEmoji
            || selectedPlaceID != task.placeID
            || candidateTags != currentTags
            || RoutineStep.sanitized(candidateSteps) != currentSteps
            || newInterval != currentInterval
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
        count == 1 ? "1 completion" : "\(count) completions"
    }

    private func stepProgressText(for task: RoutineTask) -> String {
        guard task.hasSequentialSteps else { return "" }
        if task.isInProgress {
            return "Step \(task.completedSteps + 1) of \(task.totalSteps)"
        }
        return "\(task.totalSteps) sequential \(task.totalSteps == 1 ? "step" : "steps")"
    }

    private func markDoneButtonTitle(
        for selectedDate: Date,
        isDone: Bool,
        isFuture: Bool,
        isPaused: Bool,
        task: RoutineTask
    ) -> String {
        if isPaused {
            return "Resume the routine to mark dates done"
        }
        if task.hasSequentialSteps && !Calendar.current.isDateInToday(selectedDate) {
            return "Step routines can only be progressed today"
        }
        if isFuture {
            return "Future dates can't be marked done"
        }
        if isDone {
            return "Already done on \(selectedDate.formatted(date: .abbreviated, time: .omitted))"
        }
        if let nextStepTitle = task.nextStepTitle {
            return "Complete: \(nextStepTitle)"
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

private struct RoutineDetailOverviewHeightsPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
