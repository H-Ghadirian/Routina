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
            let _ = store.taskRefreshID
            let pauseArchivePresentation = RoutinePauseArchivePresentation.make(
                isPaused: store.task.isPaused,
                context: .detail
            )
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detailOverviewSection(pauseArchivePresentation: pauseArchivePresentation)
                    if store.task.hasChecklistItems {
                        checklistItemsSection
                    }
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
                    .navigationTitle("Edit Task")
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
                                    scheduleMode: store.editScheduleMode,
                                    steps: store.editRoutineSteps,
                                    stepDraft: store.editStepDraft,
                                    checklistItems: store.editRoutineChecklistItems,
                                    checklistItemDraftTitle: store.editChecklistItemDraftTitle,
                                    checklistItemDraftInterval: store.editChecklistItemDraftInterval,
                                    frequency: store.editFrequency,
                                    frequencyValue: store.editFrequencyValue,
                                    recurrenceKind: store.editRecurrenceKind,
                                    recurrenceTimeOfDay: store.editRecurrenceTimeOfDay,
                                    recurrenceWeekday: store.editRecurrenceWeekday,
                                    recurrenceDayOfMonth: store.editRecurrenceDayOfMonth,
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
        VStack(alignment: .leading, spacing: 0) {
            calendarHeader
                .padding(.bottom, 8)

            calendarGrid(
                doneDates: doneDates(from: store.logs),
                dueDate: dueDate(for: store.task),
                pausedAt: store.task.pausedAt,
                isOrangeUrgencyToday: isOrangeUrgency(store.task),
                selectedDate: selectedDate,
                onSelectDate: { store.send(.selectedDateChanged($0)) }
            )
            .padding(.bottom, 12)

            Spacer(minLength: 0)

            Divider()
                .padding(.bottom, 12)

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
        VStack(alignment: .leading, spacing: 16) {
            statusSummaryHeader(titleFont: .title3.weight(.semibold))

            Divider()

            statusMetadataSection()

            Divider()

            statusActionSection(pauseArchivePresentation: pauseArchivePresentation)
        }
        .padding(16)
        .background(RoutineDetailPlatformStyle.summaryCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RoutineDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
        )
    }

    private func macStatusSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            statusSummaryHeader(titleFont: .title2.weight(.semibold))

            Divider()

            statusMetadataSection()

            Divider()

            statusActionSection(pauseArchivePresentation: pauseArchivePresentation, useLargePrimaryControl: true)
        }
        .padding(18)
    }

    private func statusSummaryHeader(titleFont: Font) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summaryStatusTitle)
                .font(titleFont)
                .foregroundColor(summaryStatusColor)

            if let statusContextMessage {
                Text(statusContextMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statusMetadataSection() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !store.task.isOneOffTask {
                statusMetadataRow(label: "Frequency", value: frequencyText(for: store.task))
            }

            if shouldShowCompletionCount {
                statusMetadataRow(label: "Completed", value: totalDoneCountText(for: store.logs.count))
            }

            if let linkedPlace = linkedPlaceSummary {
                statusMetadataRow(label: "Location", value: linkedPlace.name, systemImage: "location")
            }

            if let pausedAt = store.task.pausedAt {
                statusMetadataRow(
                    label: "Paused",
                    value: pausedAt.formatted(date: .abbreviated, time: .omitted)
                )
            } else if let dueDateMetadataText {
                statusMetadataRow(label: "Due", value: dueDateMetadataText)
            }

            if shouldShowSelectedDateMetadata {
                statusMetadataRow(label: "Selected", value: selectedDateMetadataText)
            }

            if !store.task.tags.isEmpty {
                statusTagsRow(tags: store.task.tags)
            }

            if store.task.isChecklistDriven {
                statusMetadataRow(
                    label: "Checklist",
                    value: "\(store.task.checklistItems.count) \(store.task.checklistItems.count == 1 ? "item" : "items")"
                )
                if let nextDueChecklistItemTitle = store.task.nextDueChecklistItem(referenceDate: Date())?.title {
                    statusMetadataRow(label: "Next Due", value: nextDueChecklistItemTitle)
                }
            } else if store.task.isChecklistCompletionRoutine {
                statusMetadataRow(
                    label: "Checklist",
                    value: "\(store.task.totalChecklistItemCount) \(store.task.totalChecklistItemCount == 1 ? "item" : "items")"
                )
                statusMetadataRow(label: "Progress", value: checklistProgressText(for: store.task))
                if let nextPendingChecklistItemTitle = store.task.nextPendingChecklistItemTitle {
                    statusMetadataRow(label: "Next Item", value: nextPendingChecklistItemTitle)
                }
            } else if store.task.hasSequentialSteps {
                statusMetadataRow(label: "Progress", value: stepProgressText(for: store.task))
                if let nextStepTitle = store.task.nextStepTitle {
                    statusMetadataRow(label: "Next Step", value: nextStepTitle)
                }
            }
        }
    }

    private func statusActionSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation,
        useLargePrimaryControl: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                store.send(completionButtonAction)
            } label: {
                completionButtonLabel
            }
            .buttonStyle(.borderedProminent)
#if os(macOS)
            .controlSize(useLargePrimaryControl ? .large : .regular)
#endif
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(isCompletionButtonDisabled)

            if !store.task.isOneOffTask {
                Button(pauseArchivePresentation.actionTitle) {
                    store.send(store.task.isPaused ? .resumeTapped : .pauseTapped)
                }
                .buttonStyle(.bordered)
                .tint(store.task.isPaused ? .teal : .orange)
#if os(macOS)
                .controlSize(.regular)
#endif
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if isStepRoutineOffToday {
                Text("Step-based routines can only be progressed for today.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if store.task.isChecklistCompletionRoutine && !canUndoSelectedDate {
                Text("Complete checklist items below to finish this routine.")
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

    private func statusMetadataRow(
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

    private func statusTagsRow(tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TAGS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(tags, id: \.self) { tag in
                    statusTagChip(tag)
                }
            }
        }
    }

    private func statusTagChip(_ tag: String) -> some View {
        Text("#\(tag)")
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
            )
    }

    private var statusContextMessage: String? {
        if store.task.isPaused {
            return "Resume it anytime to put it back in rotation."
        }
        if store.task.isOneOffTask {
            if store.task.isCompletedOneOff {
                return "Select the completion date to undo it if needed."
            }
            return nil
        }
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today is selected. Pick another date to review its history."
        }
        return "Reviewing \(selectedDate.formatted(date: .abbreviated, time: .omitted))."
    }

    private var shouldShowCompletionCount: Bool {
        if store.task.isOneOffTask {
            return store.logs.count > 0
        }
        return true
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

    private var checklistItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Checklist Items")
                .font(.headline)

            if store.task.checklistItems.isEmpty {
                Text("No checklist items yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(sortedChecklistItems, id: \.id) { item in
                    checklistRow(for: item)

                    if item.id != sortedChecklistItems.last?.id {
                        Divider()
                    }
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

    @ViewBuilder
    private var completionButtonLabel: some View {
        if let systemImage = completionButtonSystemImage {
            Label(completionButtonTitle, systemImage: systemImage)
        } else {
            Text(completionButtonTitle)
        }
    }

    private var canUndoSelectedDate: Bool {
        !store.task.isChecklistDriven && isSelectedDateDone
    }

    private var completionButtonAction: RoutineDetailFeature.Action {
        canUndoSelectedDate ? .undoSelectedDateCompletion : .markAsDone
    }

    private var completionButtonTitle: String {
        completionButtonText(
            for: selectedDate,
            isDone: isSelectedDateDone,
            isFuture: isSelectedDateInFuture,
            isPaused: store.task.isPaused,
            task: store.task
        )
    }

    private var completionButtonSystemImage: String? {
        canUndoSelectedDate ? "arrow.uturn.backward" : nil
    }

    private var isCompletionButtonDisabled: Bool {
        guard !canUndoSelectedDate else { return false }
        if store.task.isCompletedOneOff {
            return true
        }
        if store.task.isChecklistCompletionRoutine {
            return true
        }
        if store.task.isChecklistDriven {
            return store.task.isPaused
                || !Calendar.current.isDateInToday(selectedDate)
                || checklistDueItemCount == 0
        }
        return isSelectedDateInFuture || store.task.isPaused || isStepRoutineOffToday
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

    private var checklistDueItemCount: Int {
        store.task.dueChecklistItems(referenceDate: Date()).count
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
        guard !task.isOneOffTask else { return nil }
        return RoutineDateMath.dueDate(for: task, referenceDate: Date())
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
        guard !task.isPaused, !task.isChecklistDriven, !task.isOneOffTask else { return false }
        if task.recurrenceRule.isFixedCalendar {
            return daysUntilDue(task) == 1
        }
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
        if task.isOneOffTask {
            if task.isInProgress {
                return "Step \(task.completedSteps + 1) of \(task.totalSteps) in progress"
            }
            if let lastDone = task.lastDone {
                if isDoneToday {
                    return "Completed today"
                }
                return "Completed on \(lastDone.formatted(date: .abbreviated, time: .omitted))"
            }
            return "To do"
        }
        if task.isChecklistCompletionRoutine {
            if task.isChecklistInProgress {
                return "Checklist \(task.completedChecklistItemCount) of \(task.totalChecklistItemCount) in progress"
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
        if task.isChecklistDriven {
            if overdueDays > 0 {
                return "Overdue by \(overdueDays) \(dayWord(overdueDays))"
            }
            if let daysUntilDue = daysUntilDue(task) {
                if daysUntilDue == 0 {
                    return "Due today"
                }
                if daysUntilDue > 0 {
                    return "Due in \(daysUntilDue) \(dayWord(daysUntilDue))"
                }
            }
            if isDoneToday {
                return "Updated today"
            }
            return "\(daysSinceLastRoutine) \(dayWord(daysSinceLastRoutine)) since last update"
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
        if task.isOneOffTask {
            if task.isInProgress { return .orange }
            if task.isCompletedOneOff || isDoneToday { return .green }
            return .primary
        }
        if task.isChecklistCompletionRoutine {
            if task.isChecklistInProgress { return .orange }
            if isDoneToday { return .green }
            if overdueDays > 0 { return .red }
            if daysUntilDue(task) == 0 { return RoutineDetailPlatformStyle.dueTodayTitleColor }
            if isOrangeUrgency(task) { return .orange }
            return .primary
        }
        if task.isChecklistDriven {
            if overdueDays > 0 { return .red }
            if daysUntilDue(task) == 0 { return RoutineDetailPlatformStyle.dueTodayTitleColor }
            if isDoneToday { return .green }
            return .primary
        }
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

    private var sortedChecklistItems: [RoutineChecklistItem] {
        if store.task.isChecklistCompletionRoutine {
            return store.task.checklistItems
        }
        return store.task.checklistItems.sorted {
            RoutineDateMath.dueDate(for: $0, referenceDate: Date())
                < RoutineDateMath.dueDate(for: $1, referenceDate: Date())
        }
    }

    @ViewBuilder
    private func checklistRow(for item: RoutineChecklistItem) -> some View {
        if store.task.isChecklistCompletionRoutine {
            completionChecklistRow(for: item)
        } else {
            dueChecklistRow(for: item)
        }
    }

    private func completionChecklistRow(for item: RoutineChecklistItem) -> some View {
        let isDone = isChecklistItemMarkedDone(item)
        let isInteractive = canToggleChecklistItem(item)

        return Button {
            store.send(.toggleChecklistItemCompletion(item.id))
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isDone ? .green : checklistCompletionControlColor(isInteractive: isInteractive))
                    .frame(width: 24, height: 24)

                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDone ? .secondary : .primary)
                    .strikethrough(isDone, color: .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
        .accessibilityLabel(item.title)
        .accessibilityValue(isDone ? "Completed" : "Not completed")
    }

    private func dueChecklistRow(for item: RoutineChecklistItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Text(checklistStatusText(for: item))
                    .font(.caption)
                    .foregroundStyle(checklistStatusColor(for: item))
            }

            Spacer(minLength: 0)

            Button("Bought") {
                store.send(.markChecklistItemPurchased(item.id))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(store.task.isPaused || !Calendar.current.isDateInToday(selectedDate))
        }
    }

    private func checklistStatusText(for item: RoutineChecklistItem) -> String {
        if store.task.isChecklistCompletionRoutine {
            return isChecklistItemMarkedDone(item) ? "Done" : "Pending"
        }
        let calendar = Calendar.current
        let dueDate = RoutineDateMath.dueDate(for: item, referenceDate: Date(), calendar: calendar)
        let daysUntilDue = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? 0

        if daysUntilDue < 0 {
            return "Overdue by \(abs(daysUntilDue)) \(dayWord(abs(daysUntilDue)))"
        }
        if daysUntilDue == 0 {
            return "Due today"
        }
        if daysUntilDue == 1 {
            return "Due tomorrow"
        }
        return "Due in \(daysUntilDue) days"
    }

    private func checklistStatusColor(for item: RoutineChecklistItem) -> Color {
        if store.task.isChecklistCompletionRoutine {
            return isChecklistItemMarkedDone(item) ? .green : .secondary
        }
        let calendar = Calendar.current
        let dueDate = RoutineDateMath.dueDate(for: item, referenceDate: Date(), calendar: calendar)
        let daysUntilDue = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: dueDate)
        ).day ?? 0

        if daysUntilDue < 0 { return .red }
        if daysUntilDue == 0 { return .orange }
        return .secondary
    }

    private func canSaveEdit(
        name: String,
        emoji: String,
        selectedPlaceID: UUID?,
        tags: [String],
        tagDraft: String,
        scheduleMode: RoutineScheduleMode,
        steps: [RoutineStep],
        stepDraft: String,
        checklistItems: [RoutineChecklistItem],
        checklistItemDraftTitle: String,
        checklistItemDraftInterval: Int,
        frequency: RoutineDetailFeature.EditFrequency,
        frequencyValue: Int,
        recurrenceKind: RoutineRecurrenceRule.Kind,
        recurrenceTimeOfDay: RoutineTimeOfDay,
        recurrenceWeekday: Int,
        recurrenceDayOfMonth: Int,
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
        let currentChecklistItems = RoutineChecklistItem.sanitized(task.checklistItems)
        let candidateChecklistItems = RoutineChecklistItem.normalizedTitle(checklistItemDraftTitle).map { title in
            checklistItems + [RoutineChecklistItem(title: title, intervalDays: checklistItemDraftInterval)]
        } ?? checklistItems
        let currentRecurrenceRule = task.recurrenceRule
        let newRecurrenceRule: RoutineRecurrenceRule
        switch recurrenceKind {
        case .intervalDays:
            newRecurrenceRule = .interval(days: frequencyValue * frequency.daysMultiplier)
        case .dailyTime:
            newRecurrenceRule = .daily(at: recurrenceTimeOfDay)
        case .weekly:
            newRecurrenceRule = .weekly(on: recurrenceWeekday)
        case .monthlyDay:
            newRecurrenceRule = .monthly(on: recurrenceDayOfMonth)
        }
        let sanitizedCandidateChecklistItems = RoutineChecklistItem.sanitized(candidateChecklistItems)

        guard scheduleMode == .fixedInterval || scheduleMode == .oneOff || !sanitizedCandidateChecklistItems.isEmpty else {
            return false
        }

        return trimmedName != currentName
            || emoji != currentEmoji
            || selectedPlaceID != task.placeID
            || candidateTags != currentTags
            || scheduleMode != task.scheduleMode
            || RoutineStep.sanitized(candidateSteps) != currentSteps
            || sanitizedCandidateChecklistItems != currentChecklistItems
            || newRecurrenceRule != currentRecurrenceRule
    }

    private func frequencyText(for task: RoutineTask) -> String {
        if task.isOneOffTask {
            return "One-off todo"
        }
        if task.isChecklistDriven {
            return "Checklist-driven"
        }
        return task.recurrenceRule.displayText()
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

    private func checklistProgressText(for task: RoutineTask) -> String {
        if store.isDoneToday && !task.isChecklistInProgress {
            return "All items completed today"
        }
        let completed = task.completedChecklistItemCount
        let total = max(task.totalChecklistItemCount, 1)
        return "\(completed) of \(total) items completed"
    }

    private func completionButtonText(
        for selectedDate: Date,
        isDone: Bool,
        isFuture: Bool,
        isPaused: Bool,
        task: RoutineTask
    ) -> String {
        if !task.isChecklistDriven && isDone {
            return "Undo"
        }
        if task.isCompletedOneOff {
            return "Select the completion date to undo"
        }
        if isPaused {
            return "Resume the routine to mark dates done"
        }
        if task.isOneOffTask {
            if Calendar.current.isDateInToday(selectedDate) {
                return "Mark Done"
            }
            return "Mark \(selectedDate.formatted(date: .abbreviated, time: .omitted)) as Done"
        }
        if task.isChecklistCompletionRoutine && !Calendar.current.isDateInToday(selectedDate) {
            return "Checklist progress can only be updated today"
        }
        if task.isChecklistCompletionRoutine {
            return "Complete checklist items below"
        }
        if task.isChecklistDriven && !Calendar.current.isDateInToday(selectedDate) {
            return "Checklist routines can only be updated today"
        }
        if task.isChecklistDriven {
            let dueItems = task.dueChecklistItems(referenceDate: Date())
            if dueItems.isEmpty {
                return "No due items right now"
            }
            if dueItems.count == 1, let title = dueItems.first?.title {
                return "Buy: \(title)"
            }
            return "Buy \(dueItems.count) due items"
        }
        if task.hasSequentialSteps && !Calendar.current.isDateInToday(selectedDate) {
            return "Step routines can only be progressed today"
        }
        if isFuture {
            return "Future dates can't be marked done"
        }
        if let nextStepTitle = task.nextStepTitle {
            return "Complete: \(nextStepTitle)"
        }
        if Calendar.current.isDateInToday(selectedDate) {
            return "Mark Today as Done"
        }
        return "Mark \(selectedDate.formatted(date: .abbreviated, time: .omitted)) as Done"
    }

    private func isChecklistItemMarkedDone(_ item: RoutineChecklistItem) -> Bool {
        guard store.task.isChecklistCompletionRoutine else { return false }
        if store.isDoneToday && !store.task.isChecklistInProgress {
            return true
        }
        return store.task.isChecklistItemCompleted(item.id)
    }

    private func canToggleChecklistItem(_ item: RoutineChecklistItem) -> Bool {
        guard store.task.isChecklistCompletionRoutine,
              !store.task.isPaused,
              Calendar.current.isDateInToday(selectedDate) else {
            return false
        }

        if store.isDoneToday && !store.task.isChecklistInProgress {
            return false
        }

        if store.task.isChecklistItemCompleted(item.id) {
            return store.task.isChecklistInProgress
        }

        return true
    }

    private func checklistCompletionControlColor(isInteractive: Bool) -> Color {
        isInteractive ? .secondary : .secondary.opacity(0.45)
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
