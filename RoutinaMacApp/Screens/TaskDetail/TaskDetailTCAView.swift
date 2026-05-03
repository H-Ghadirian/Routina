import SwiftUI
import ComposableArchitecture
import SwiftData

struct TaskDetailTCAView: View {
    let store: StoreOf<TaskDetailFeature>
    var showsPrincipalToolbarTitle = true
    @Dependency(\.appSettingsClient) private var appSettingsClient
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FocusSession.startedAt, order: .reverse) private var focusSessions: [FocusSession]
    @Query private var focusSessionTasks: [RoutineTask]
    @State var displayedMonthStart = Calendar.current.startOfMonth(for: Date())
    @State var isShowingAllLogs = false
    @State private var isRoutineLogsExpanded = false
    @State private var isTaskChangesExpanded = false
    @State private var isTimeSectionExpanded = false
    @State private var editingTimeLog: RoutineLog?
    @State private var editingTimeSpentMinutes = 25
    @State private var taskTimeEntryHours = 0
    @State private var taskTimeEntryMinutes = 25
    @State var isEditEmojiPickerPresented = false
    @State var syncedMacOverviewHeight: CGFloat = 0
    @State var attachmentTempURL: URL?
    @State var fileToSave: AttachmentItem?
    @State private var isRelationshipGraphPresented = false
    @State private var isMatrixExpanded = false
    @State private var isCalendarExpanded = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) private var showPersianDates = false
    let emojiOptions = EmojiCatalog.uniqueQuick
    let allEmojiOptions = EmojiCatalog.searchableAll

    var body: some View {
        WithPerceptionTracking {
            detailBody
            .routinaInlineTitleDisplayMode()
            .toolbar {
                if showsPrincipalToolbarTitle && !isInlineEditPresented {
                    ToolbarItem(placement: .principal) {
                        Text(store.routineEmoji)
                            .font(TaskDetailPlatformStyle.principalTitleFont)
                    }
                }
                if showsPrincipalToolbarTitle && isInlineEditPresented {
                    ToolbarItem(placement: .principal) {
                        HStack(spacing: 8) {
                            Text("✏️")
                            Text("Edit Task")
                                .lineLimit(1)
                        }
                        .font(TaskDetailPlatformStyle.principalTitleFont)
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
                }
                if isInlineEditPresented {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            store.send(.setEditSheet(false))
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.send(.editSaveTapped)
                        }
                        .disabled(!canSaveCurrentEdit)
                    }
                } else {
                    ToolbarItemGroup(placement: .primaryAction) {
                        toolbarActionButtons
                        CloudSharingToolbarButton(task: store.task)
                        Button("Edit") {
                            store.send(.setEditSheet(true))
                        }
                    }
                }
            }
            .routinaPlatformEditPresentation(
                isPresented: editSheetBinding,
                store: store,
                isEditEmojiPickerPresented: $isEditEmojiPickerPresented,
                emojiOptions: emojiOptions,
                canSaveCurrentEdit: canSaveCurrentEdit
            )
            .sheet(isPresented: $isEditEmojiPickerPresented) {
                EmojiPickerSheet(
                    selectedEmoji: Binding(
                        get: { store.editRoutineEmoji },
                        set: { store.send(.editRoutineEmojiChanged($0)) }
                    ),
                    emojis: allEmojiOptions
                )
            }
            .sheet(isPresented: $isRelationshipGraphPresented) {
                TaskRelationshipGraphSheet(
                    centerTask: store.task,
                    relationships: store.resolvedRelationships,
                    statusColor: TaskDetailPresentation.statusColor(for:),
                    onSelectTask: { taskID in
                        isRelationshipGraphPresented = false
                        store.send(.openLinkedTask(taskID))
                    }
                )
            }
            .sheet(item: $editingTimeLog) { log in
                timeSpentSheet(for: log)
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
            .alert(
                "Undo log?",
                isPresented: Binding(
                    get: { store.isUndoCompletionConfirmationPresented },
                    set: { store.send(.setUndoCompletionConfirmation($0)) }
                )
            ) {
                Button("Undo", role: .destructive) {
                    store.send(.confirmUndoCompletion)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the selected log and may update the routine's schedule.")
            }
            .onAppear {
                displayedMonthStart = Calendar.current.startOfMonth(for: store.resolvedSelectedDate)
                collapseDefaultSections()
            }
            .onChange(of: store.task.id) { _, _ in
                collapseDefaultSections()
                displayedMonthStart = Calendar.current.startOfMonth(for: store.resolvedSelectedDate)
            }
            .onChange(of: store.shouldDismissAfterDelete) { _, shouldDismiss in
                guard shouldDismiss else { return }
                dismiss()
                store.send(.deleteDismissHandled)
            }
            .onChange(of: store.resolvedSelectedDate) { _, newValue in
                displayedMonthStart = Calendar.current.startOfMonth(for: newValue)
            }
            .routinaAttachmentShareSheet(url: $attachmentTempURL)
            .fileExporter(
                isPresented: fileExporterPresentationBinding,
                document: fileToSave.map { RoutineAttachmentFileDocument(data: $0.data) },
                contentType: .data,
                defaultFilename: fileToSave?.fileName
            ) { _ in
                fileToSave = nil
            }
        }
    }

    private var fileExporterPresentationBinding: Binding<Bool> {
        Binding(
            get: { fileToSave != nil },
            set: { isPresented in
                if !isPresented {
                    fileToSave = nil
                }
            }
        )
    }

    @ViewBuilder
    private var detailBody: some View {
        if isInlineEditPresented {
            TaskDetailEditRoutineContent(
                store: store,
                isEditEmojiPickerPresented: $isEditEmojiPickerPresented,
                emojiOptions: emojiOptions
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if store.task.isOneOffTask {
            todoDetailContent
                .background { taskColorBackground }
        } else {
            taskDetailContent
                .background { taskColorBackground }
        }
    }

    @ViewBuilder
    private var taskColorBackground: some View {
        if let color = store.task.color.swiftUIColor {
            color.opacity(0.07).ignoresSafeArea()
        }
    }

    private var todoDetailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                todoHeaderSection
                notificationDisabledWarningSection
                todoStateTimingSection
                routineLogsSection
                taskChangesSection
                if store.task.hasChecklistItems {
                    checklistItemsSection
                }
                relationshipsSection
                if store.task.hasNotes || store.task.hasImage || !store.taskAttachments.isEmpty {
                    taskExtrasSection
                }
            }
            .padding(TaskDetailPlatformStyle.detailContentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var pressurePicker: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("PRESSURE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 2)
            TaskDetailColoredSegmentedControl(
                options: RoutineTaskPressure.allCases,
                selection: store.task.pressure,
                title: { $0.title },
                tint: { TaskDetailPriorityPresentation.pressureTint(for: $0, style: .segmentedControl) },
                selectedForeground: { TaskDetailPriorityPresentation.pressureSelectedForeground(for: $0) },
                action: { store.send(.pressureChanged($0)) }
            )
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .detailHeaderBoxStyle()
    }

    private var todoStatePicker: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("STATE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 2)
            TaskDetailColoredSegmentedControl(
                options: TodoState.allCases,
                selection: store.task.todoState ?? .ready,
                title: { $0.displayTitle },
                tint: { TaskDetailPriorityPresentation.todoStateTint(for: $0, style: .segmentedControl) },
                selectedForeground: { TaskDetailPriorityPresentation.todoStateSelectedForeground(for: $0) },
                action: { newState in
                    if newState == .done && store.hasActiveRelationshipBlocker {
                        store.send(.setBlockedStateConfirmation(true))
                    } else {
                        store.send(.todoStateChanged(newState))
                    }
                }
            )
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
        .detailHeaderBoxStyle()
        .alert(
            "Blocked Task",
            isPresented: Binding(
                get: { store.isBlockedStateConfirmationPresented },
                set: { store.send(.setBlockedStateConfirmation($0)) }
            )
        ) {
            Button("Mark Done Anyway", role: .destructive) {
                store.send(.confirmBlockedStateCompletion)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(store.blockerSummaryText)
        }
    }

    @ViewBuilder
    private var todoStateTimingSection: some View {
        if let summary = TodoStateTiming.summary(
            for: store.task,
            referenceDate: Date(),
            calendar: Calendar.current
        ) {
            TodoStateTimingSectionView(
                summary: summary,
                showPersianDates: showPersianDates
            )
        }
    }

    private var priorityDisclosureBox: some View {
        TaskDetailPriorityDisclosureBox(
            priority: store.task.priority,
            importance: store.task.importance,
            urgency: store.task.urgency,
            isExpanded: $isMatrixExpanded,
            summaryLayout: .horizontal,
            matrixMaxWidth: 420,
            onImportanceChanged: { store.send(.importanceChanged($0)) },
            onUrgencyChanged: { store.send(.urgencyChanged($0)) }
        )
    }

    private func headerTagsBox(minHeight: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TAGS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(store.task.tags, id: \.self) { tag in
                    statusTagChip(tag)
                }
            }
        }
        .detailHeaderBoxStyle(minHeight: minHeight)
    }

    @ViewBuilder
    private func headerPointsBox(minHeight: CGFloat? = nil) -> some View {
        if let storyPoints = store.task.storyPoints {
            VStack(alignment: .leading, spacing: 4) {
                Text("POINTS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(TaskDetailHeaderBadgePresentation.storyPointsText(for: storyPoints))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .detailHeaderBoxStyle(tint: .purple, minHeight: minHeight)
        }
    }

    @ViewBuilder
    private var headerTagsAndPointsRow: some View {
        let hasTags = !store.task.tags.isEmpty
        let hasPoints = store.task.storyPoints != nil

        if hasTags && hasPoints {
            ViewThatFits(in: .horizontal) {
                TaskDetailEqualHeightPairRow(spacing: 8) { minHeight in
                    headerTagsBox(minHeight: minHeight)
                } trailing: { minHeight in
                    headerPointsBox(minHeight: minHeight)
                }

                VStack(alignment: .leading, spacing: 8) {
                    headerTagsBox()
                    headerPointsBox()
                }
            }
        } else if hasTags {
            headerTagsBox()
        } else if hasPoints {
            headerPointsBox()
        }
    }

    @ViewBuilder
    private var headerLinkBox: some View {
        if let linkURL = store.task.resolvedLinkURL {
            VStack(alignment: .leading, spacing: 4) {
                Text("DETAILS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Link(destination: linkURL) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "link")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                        Text(store.task.link ?? linkURL.absoluteString)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .detailHeaderBoxStyle()
        }
    }

    private var headerCalendarDisclosure: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCalendarExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CALENDAR")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                            Text(headerCalendarSummaryText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isCalendarExpanded ? 180 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isCalendarExpanded {
                Divider()
                calendarSection
                    .background(TaskDetailPlatformStyle.calendarCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(TaskDetailPlatformStyle.sectionCardStroke, lineWidth: 1)
                    )
            }
        }
        .detailHeaderBoxStyle(tint: .blue)
    }

    private var headerCalendarSummaryText: String {
        let dateText = PersianDateDisplay.appendingSupplementaryDate(
            to: store.resolvedSelectedDate.formatted(date: .abbreviated, time: .omitted),
            for: store.resolvedSelectedDate,
            enabled: showPersianDates
        )
        if Calendar.current.isDateInToday(store.resolvedSelectedDate) {
            return "Today • \(dateText)"
        }
        return dateText
    }

    @ViewBuilder
    private var todoHeaderControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            priorityDisclosureBox
            todoTimeSpentHeaderBox

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 8) {
                    if !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
                        todoStatePicker
                            .frame(minWidth: 380)
                    }
                    pressurePicker
                        .frame(minWidth: 300)
                }

                VStack(alignment: .leading, spacing: 8) {
                    if !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
                        todoStatePicker
                    }
                    pressurePicker
                }
            }
        }
    }

    private var todoTimeSpentHeaderBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTimeSectionExpanded.toggle()
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TIME")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(taskTimeSpentDisplayText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(store.task.actualDurationMinutes == nil ? .secondary : .primary)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isTimeSectionExpanded ? 180 : 0))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isTimeSectionExpanded {
                Divider()
                    .opacity(0.35)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 10) {
                        taskTimeEntryControls
                        taskTimeEntryActions
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        taskTimeEntryControls
                        taskTimeEntryActions
                    }
                }

                if store.task.focusModeEnabled {
                    Divider()
                        .opacity(0.35)

                    FocusSessionCard(
                        task: store.task,
                        sessions: focusSessions,
                        allTasks: focusSessionTasks,
                        isEmbedded: true,
                        onCompletedDuration: addCompletedFocusToTimeSpent
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: isTimeSectionExpanded ? 120 : nil, alignment: .topLeading)
        .detailHeaderBoxStyle(tint: .cyan)
        .onAppear {
            resetTaskTimeEntry()
        }
        .onChange(of: store.task.id) { _, _ in
            resetTaskTimeEntry()
        }
        .onChange(of: store.task.actualDurationMinutes) { _, _ in
            resetTaskTimeEntry()
        }
    }

    private var taskTimeEntryControls: some View {
        HStack(alignment: .bottom, spacing: 8) {
            timeSpentNumberField("Hours", value: $taskTimeEntryHours, range: 0...24)
            timeSpentNumberField("Minutes", value: $taskTimeEntryMinutes, range: 0...59)

            HStack(spacing: 6) {
                ForEach([15, 30, 60], id: \.self) { minutes in
                    Button("+\(RoutineTimeSpentFormatting.compactMinutesText(minutes))") {
                        setTaskTimeEntryTotal(minutes)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private var taskTimeEntryActions: some View {
        HStack(alignment: .center, spacing: 10) {
            Label(taskTimeEntryPreviewText, systemImage: "equal.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button {
                applyTaskTimeEntry()
            } label: {
                Label(
                    taskTimeEntryApplyTitle,
                    systemImage: "plus.circle.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.cyan)
            .disabled(!canApplyTaskTimeEntry)
        }
    }

    private func timeSpentNumberField(
        _ label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(label, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 64)
                .onChange(of: value.wrappedValue) { _, newValue in
                    value.wrappedValue = min(max(newValue, range.lowerBound), range.upperBound)
                }
        }
    }

    @ViewBuilder
    private var routineHeaderControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            priorityDisclosureBox
            pressurePicker
        }
    }

    private var taskDetailContent: some View {
        let _ = store.taskRefreshID

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                routineHeaderSection
                notificationDisabledWarningSection
                if store.task.focusModeEnabled {
                    focusSessionSection
                }
                routineLogsSection
                taskChangesSection
                if store.task.hasChecklistItems {
                    checklistItemsSection
                }
                relationshipsSection
                if store.task.hasNotes || store.task.hasImage || !store.taskAttachments.isEmpty {
                    taskExtrasSection
                }
            }
            .padding(TaskDetailPlatformStyle.detailContentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var focusSessionSection: some View {
        FocusSessionCard(
            task: store.task,
            sessions: focusSessions,
            allTasks: focusSessionTasks,
            onCompletedDuration: addCompletedFocusToTimeSpent
        )
    }

    private func timeSpentSheet(for log: RoutineLog) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Time Spent")
                    .font(.title3.weight(.semibold))
                Text("Record the actual time for this completion.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Stepper(value: $editingTimeSpentMinutes, in: 1...1440) {
                HStack {
                    Text("Time spent")
                    Spacer()
                    Text(RoutineTimeSpentFormatting.compactMinutesText(editingTimeSpentMinutes))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                if log.actualDurationMinutes != nil {
                    Button(role: .destructive) {
                        store.send(.updateLogDuration(log.id, nil))
                        editingTimeLog = nil
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                }

                Spacer()

                Button("Cancel") {
                    editingTimeLog = nil
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    store.send(.updateLogDuration(log.id, editingTimeSpentMinutes))
                    editingTimeLog = nil
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 420)
        .padding(24)
    }

    private var canSaveCurrentEdit: Bool {
        TaskDetailEditChangeDetector.canSave(TaskDetailEditChangeRequest(state: store.state))
    }

    var editSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isEditSheetPresented },
            set: { store.send(.setEditSheet($0)) }
        )
    }

    var isInlineEditPresented: Bool {
        platformIsInlineEditPresented
    }

    @ViewBuilder
    func detailOverviewSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        platformDetailOverviewSection(pauseArchivePresentation: pauseArchivePresentation)
    }

    var calendarSection: some View {
        TaskDetailCalendarSectionView(
            displayedMonthStart: displayedMonthStart,
            onPreviousMonth: {
                displayedMonthStart = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonthStart) ?? displayedMonthStart
            },
            onNextMonth: {
                displayedMonthStart = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonthStart) ?? displayedMonthStart
            },
            showsAssumedLegend: store.task.autoAssumeDailyDone,
            showsPausedLegend: store.task.pausedAt != nil,
            showsCreatedLegend: store.task.createdAt != nil
        ) {
            TaskDetailCalendarGridView(
                displayedMonthStart: displayedMonthStart,
                doneDates: TaskDetailCalendarPresentation.doneDates(from: store.logs, task: store.task),
                assumedDates: TaskDetailCalendarPresentation.assumedDates(from: store.logs, task: store.task),
                dueDate: store.resolvedDueDate,
                createdAt: store.task.createdAt,
                pausedAt: store.task.pausedAt,
                isOrangeUrgencyToday: TaskDetailPresentation.isOrangeUrgency(store.task),
                selectedDate: store.resolvedSelectedDate,
                onSelectDate: { store.send(.selectedDateChanged($0)) }
            )
        }
        .routinaPlatformCalendarCardStyle()
    }

    func heightReader(id: String) -> some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: TaskDetailOverviewHeightsPreferenceKey.self,
                    value: [id: proxy.size.height]
                )
        }
    }

    private func collapseDefaultSections() {
        isMatrixExpanded = false
        isTimeSectionExpanded = false
        isCalendarExpanded = false
        isRoutineLogsExpanded = false
        isTaskChangesExpanded = false
    }

    func compactStatusSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        statusSection(
            pauseArchivePresentation: pauseArchivePresentation,
            titleFont: .title3.weight(.semibold),
            useLargePrimaryControl: false,
            contentPadding: 16,
            cardBackground: TaskDetailPlatformStyle.summaryCardBackground,
            cardStroke: TaskDetailPlatformStyle.sectionCardStroke
        )
    }

    private var todoHeaderSection: some View {
        TaskDetailHeaderSectionView(
            title: store.task.name ?? "Task",
            statusContextMessage: statusContextMessage,
            badgeRows: todoHeaderBadgeRows,
            tags: []
        ) { tag in
            statusTagChip(tag)
        } additionalContent: {
            VStack(alignment: .leading, spacing: 8) {
                todoHeaderControls

                if !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
                    headerCalendarDisclosure
                }

                headerTagsAndPointsRow
                headerLinkBox
            }
        }
    }

    private var routineHeaderSection: some View {
        TaskDetailHeaderSectionView(
            title: store.task.name ?? "Routine",
            statusContextMessage: statusContextMessage,
            badgeRows: routineHeaderBadgeRows,
            tags: []
        ) { tag in
            statusTagChip(tag)
        } additionalContent: {
            VStack(alignment: .leading, spacing: 8) {
                routineHeaderControls

                headerCalendarDisclosure

                headerTagsAndPointsRow
                headerLinkBox
            }
        }
    }

    @ViewBuilder
    private var notificationDisabledWarningSection: some View {
        if let warningText = store.notificationDisabledWarningText,
           let actionTitle = store.notificationDisabledWarningActionTitle {
            TaskDetailNotificationDisabledWarningView(
                warningText: warningText,
                actionTitle: actionTitle
            ) {
                store.send(.notificationDisabledWarningTapped)
            }
        }
    }

    private var todoHeaderBadgeRows: [[TaskDetailHeaderBadgeItem]] {
        var rows: [[TaskDetailHeaderBadgeItem]] = []

        if let linkedPlace = store.linkedPlaceSummary {
            rows.append([
                TaskDetailHeaderBadgeItem(
                    title: "Location",
                    value: linkedPlace.name,
                    systemImage: nil,
                    tint: .blue
                )
            ])
        }

        if let dueDateMetadataText = dueDateMetadataDisplayText {
            rows.append([
                TaskDetailHeaderBadgeItem(
                    title: "Due",
                    value: dueDateMetadataText,
                    systemImage: nil,
                    tint: .orange
                )
            ])
        }

        if let reminderMetadataText = store.reminderMetadataText {
            rows.append([
                TaskDetailHeaderBadgeItem(
                    title: "Reminder",
                    value: reminderMetadataText,
                    systemImage: "bell.fill",
                    tint: .indigo
                )
            ])
        }

        if !estimationHeaderBadges.isEmpty {
            rows.append(estimationHeaderBadges)
        }

        return rows
    }

    private var routineHeaderBadgeRows: [[TaskDetailHeaderBadgeItem]] {
        var rows: [[TaskDetailHeaderBadgeItem]] = [
            [
                TaskDetailHeaderBadgeItem(
                    title: "Status",
                    value: store.summaryStatusTitle,
                    systemImage: nil,
                    tint: summaryStatusColor
                ),
                TaskDetailHeaderBadgeItem(
                    title: "Frequency",
                    value: store.frequencyText,
                    systemImage: nil,
                    tint: .mint
                )
            ]
        ]

        var secondRow: [TaskDetailHeaderBadgeItem] = [
            TaskDetailHeaderBadgeItem(
                title: "Completed",
                value: store.completedLogCountText,
                systemImage: nil,
                tint: .green
            )
        ]
        if store.canceledLogCount > 0 {
            secondRow.append(
                TaskDetailHeaderBadgeItem(
                    title: "Canceled",
                    value: store.canceledLogCountText,
                    systemImage: nil,
                    tint: .orange
                )
            )
        }
        if let dueDateMetadataText = dueDateMetadataDisplayText {
            secondRow.append(
                TaskDetailHeaderBadgeItem(
                    title: "Due",
                    value: dueDateMetadataText,
                    systemImage: nil,
                    tint: .orange
                )
            )
        } else if let linkedPlace = store.linkedPlaceSummary {
            secondRow.append(
                TaskDetailHeaderBadgeItem(
                    title: "Location",
                    value: linkedPlace.name,
                    systemImage: nil,
                    tint: .blue
                )
            )
        }
        rows.append(secondRow)

        if let linkedPlace = store.linkedPlaceSummary, store.dueDateMetadataText != nil {
            rows.append([
                TaskDetailHeaderBadgeItem(
                    title: "Location",
                    value: linkedPlace.name,
                    systemImage: nil,
                    tint: .blue
                )
            ])
        }

        if let reminderMetadataText = store.reminderMetadataText {
            rows.append([
                TaskDetailHeaderBadgeItem(
                    title: "Reminder",
                    value: reminderMetadataText,
                    systemImage: "bell.fill",
                    tint: .indigo
                )
            ])
        }

        if !estimationHeaderBadges.isEmpty {
            rows.append(estimationHeaderBadges)
        }

        return rows
    }

    private var estimationHeaderBadges: [TaskDetailHeaderBadgeItem] {
        TaskDetailHeaderBadgePresentation.estimationBadges(
            task: store.task,
            displayedActualDurationMinutes: displayedActualDurationMinutes,
            includeSpent: false,
            includeStoryPoints: false
        )
    }

    private var displayedActualDurationMinutes: Int {
        TaskDetailHeaderBadgePresentation.displayedActualDurationMinutes(
            task: store.task,
            logs: store.logs
        )
    }

    private var displayedActualDurationText: String? {
        displayedActualDurationMinutes > 0
            ? TaskDetailHeaderBadgePresentation.durationText(for: displayedActualDurationMinutes)
            : nil
    }

    private var latestCompletedLog: RoutineLog? {
        TaskDetailHeaderBadgePresentation.latestCompletedLog(in: store.logs)
    }

    @ViewBuilder
    private var toolbarActionButtons: some View {
        Button {
            store.send(store.completionButtonAction)
        } label: {
            TaskDetailCompletionButtonLabel(
                title: store.completionButtonTitle,
                systemImage: store.completionButtonSystemImage
            )
        }
        .buttonStyle(.borderedProminent)
        .tint(toolbarCompletionTint)
        .disabled(store.isCompletionButtonDisabled)

        if store.task.isOneOffTask && !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
            Button {
                store.send(.cancelTodo)
            }
            label: {
                Label(store.cancelTodoButtonTitle, systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(store.isCancelTodoButtonDisabled)
        }

        if !store.task.isOneOffTask {
            Button {
                store.send(store.task.isArchived() ? .resumeTapped : .pauseTapped)
            }
            label: {
                Label(toolbarPauseActionTitle, systemImage: toolbarPauseSystemImage)
            }
            .buttonStyle(.bordered)
            .tint(toolbarPauseTint)
        }
    }

    private var todoPrimaryActionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            primaryActionButton
            cancelTodoButton

            if store.task.isCompletedOneOff || store.task.isCanceledOneOff {
                Text("Select the logged date in the calendar if you want to undo it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !store.blockingRelationships.isEmpty {
                Text(store.blockerSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .detailCardStyle()
    }

    private func routinePrimaryActionSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.summaryStatusTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(summaryStatusColor)

                if let statusContextMessage {
                    Text(statusContextMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            primaryActionButton

            if store.task.isSoftIntervalRoutine && !store.task.isOngoing && !store.task.isArchived() {
                Button("Start ongoing") {
                    store.send(.startOngoingTapped)
                }
                .buttonStyle(.bordered)
                .tint(.teal)
                .routinaPlatformSecondaryActionControlSize()
                .frame(maxWidth: .infinity)
            }

            Button(pauseArchivePresentation.actionTitle) {
                store.send(store.task.isArchived() ? .resumeTapped : .pauseTapped)
            }
            .buttonStyle(.bordered)
            .tint(store.task.isArchived() ? .teal : .orange)
            .routinaPlatformSecondaryActionControlSize()
            .frame(maxWidth: .infinity)

            if let secondaryActionTitle = pauseArchivePresentation.secondaryActionTitle {
                Button(secondaryActionTitle) {
                    store.send(.notTodayTapped)
                }
                .buttonStyle(.bordered)
                .tint(.indigo)
                .routinaPlatformSecondaryActionControlSize()
                .frame(maxWidth: .infinity)
            }

            if store.isStepRoutineOffToday {
                Text("Step-based routines can only be progressed for today.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if store.task.isChecklistCompletionRoutine && !store.canUndoSelectedDate {
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

            if let secondaryActionDescription = pauseArchivePresentation.secondaryActionDescription {
                Text(secondaryActionDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !store.blockingRelationships.isEmpty {
                Text(store.blockerSummaryText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .detailCardStyle()
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        Button {
            store.send(store.completionButtonAction)
        } label: {
            TaskDetailCompletionButtonLabel(
                title: store.completionButtonTitle,
                systemImage: store.completionButtonSystemImage
            )
                .routinaPlatformPrimaryActionLabelLayout()
        }
        .buttonStyle(.borderedProminent)
        .routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: true)
        .routinaPlatformPrimaryActionButtonLayout()
        .disabled(store.isCompletionButtonDisabled)
    }

    @ViewBuilder
    private var timeSpentActionButton: some View {
        if store.task.isOneOffTask {
            Button {
                beginEditingTaskTime()
            } label: {
                Label(
                    store.task.actualDurationMinutes == nil ? "Add Time Spent" : "Edit Time Spent",
                    systemImage: "clock.badge"
                )
                .routinaPlatformPrimaryActionLabelLayout()
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
            .routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: false)
            .routinaPlatformPrimaryActionButtonLayout()
        } else if let log = latestCompletedLog {
            Button {
                beginEditingTime(for: log)
            } label: {
                Label(
                    log.actualDurationMinutes == nil ? "Add Time Spent" : "Edit Time Spent",
                    systemImage: "clock.badge"
                )
                .routinaPlatformPrimaryActionLabelLayout()
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
            .routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: false)
            .routinaPlatformPrimaryActionButtonLayout()
        }
    }

    @ViewBuilder
    private var cancelTodoButton: some View {
        if store.task.isOneOffTask && !store.task.isCompletedOneOff && !store.task.isCanceledOneOff {
            Button {
                store.send(.cancelTodo)
            } label: {
                Label(store.cancelTodoButtonTitle, systemImage: "xmark.circle")
                    .routinaPlatformPrimaryActionLabelLayout()
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .routinaPlatformPrimaryActionControlSize(useLargePrimaryControl: true)
            .routinaPlatformPrimaryActionButtonLayout()
            .disabled(store.isCancelTodoButtonDisabled)
        }
    }

    private var taskExtrasSection: some View {
        TaskDetailExtrasSectionView(
            imageData: store.task.imageData,
            attachments: store.taskAttachments,
            notes: CalendarTaskImportSupport.displayNotes(from: store.task.notes),
            linkURL: nil,
            linkText: nil,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            onOpenImage: openTaskImage(data:),
            onSaveAttachment: saveAttachment(item:),
            onOpenAttachment: { openAttachment(data: $0.data, fileName: $0.fileName) }
        )
    }

    func macStatusSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation
    ) -> some View {
        statusSection(
            pauseArchivePresentation: pauseArchivePresentation,
            titleFont: .title2.weight(.semibold),
            useLargePrimaryControl: true,
            contentPadding: 18
        )
    }

    private func statusSection(
        pauseArchivePresentation: RoutinePauseArchivePresentation,
        titleFont: Font,
        useLargePrimaryControl: Bool,
        contentPadding: CGFloat,
        cardBackground: Color? = nil,
        cardStroke: Color? = nil
    ) -> some View {
        TaskDetailStatusSectionView(
            title: store.summaryStatusTitle,
            titleColor: summaryStatusColor,
            statusContextMessage: statusContextMessage,
            titleFont: titleFont,
            showsMetadata: hasVisibleStatusMetadata,
            metadataItems: TaskDetailStatusMetadataPresentation.items(
                for: store.state,
                showSelectedDate: true,
                displayedActualDurationText: displayedActualDurationText,
                dueDateMetadataDisplayText: dueDateMetadataDisplayText
            ),
            pauseArchivePresentation: pauseArchivePresentation,
            completionButtonTitle: store.completionButtonTitle,
            completionButtonSystemImage: store.completionButtonSystemImage,
            isOneOffTask: store.task.isOneOffTask,
            isArchived: store.task.isArchived(),
            isCompletionButtonDisabled: store.isCompletionButtonDisabled,
            isStepRoutineOffToday: store.isStepRoutineOffToday,
            isChecklistCompletionRoutine: store.task.isChecklistCompletionRoutine,
            canUndoSelectedDate: store.canUndoSelectedDate,
            shouldShowBulkConfirmAssumedDays: store.shouldShowBulkConfirmAssumedDays,
            bulkConfirmAssumedDaysTitle: store.bulkConfirmAssumedDaysTitle,
            hasBlockingRelationships: !store.blockingRelationships.isEmpty,
            blockerSummaryText: store.blockerSummaryText,
            useLargePrimaryControl: useLargePrimaryControl,
            contentPadding: contentPadding,
            cardBackground: cardBackground,
            cardStroke: cardStroke
        ) {
            timeSpentActionButton
        } onComplete: {
            store.send(store.completionButtonAction)
        } onPauseResume: {
            store.send(store.task.isArchived() ? .resumeTapped : .pauseTapped)
        } onNotToday: {
            store.send(.notTodayTapped)
        } onConfirmAssumedPastDays: {
            store.send(.confirmAssumedPastDays)
        }
    }

    private func statusTagChip(_ tag: String) -> some View {
        let tint = tagTint(for: tag)

        return Text("#\(tag)")
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.13))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.25), lineWidth: 1)
            )
    }

    private func tagTint(for tag: String) -> Color {
        if let color = Color(routineTagHex: RoutineTagColors.colorHex(for: tag, in: appSettingsClient.tagColors())) {
            return color
        }
        return .secondary
    }

    private var statusContextMessage: String? {
        if store.task.isArchived() {
            return "Resume it anytime to put it back in rotation."
        }
        if store.task.isOneOffTask {
            if store.task.isCompletedOneOff || store.task.isCanceledOneOff {
                return "Select the logged date to undo it if needed."
            }
            return nil
        }
        if store.isSelectedDateAssumedDone {
            if Calendar.current.isDateInToday(store.resolvedSelectedDate) {
                return "Today is assumed done. Confirm it if you want it counted in history and stats."
            }
            return "This day is assumed done. Confirm it if you want it counted in history and stats."
        }
        if Calendar.current.isDateInToday(store.resolvedSelectedDate) {
            return "Today is selected. Pick another date to review its history."
        }
        let dateText = PersianDateDisplay.appendingSupplementaryDate(
            to: store.resolvedSelectedDate.formatted(date: .abbreviated, time: .omitted),
            for: store.resolvedSelectedDate,
            enabled: showPersianDates
        )
        return "Reviewing \(dateText)."
    }

    private var dueDateMetadataDisplayText: String? {
        guard let dueDateMetadataText = store.dueDateMetadataText else { return nil }
        guard let dueDate = store.resolvedDueDate else { return dueDateMetadataText }
        return PersianDateDisplay.appendingSupplementaryDate(
            to: dueDateMetadataText,
            for: dueDate,
            enabled: showPersianDates
        )
    }

    private var shouldShowCompletionCount: Bool {
        TaskDetailStatusMetadataPresentation.shouldShowCompletionCount(for: store.state)
    }

    private var hasVisibleStatusMetadata: Bool {
        !store.task.isOneOffTask
            || shouldShowCompletionCount
            || store.linkedPlaceSummary != nil
            || store.task.pausedAt != nil
            || store.dueDateMetadataText != nil
            || store.shouldShowSelectedDateMetadata
            || !store.task.tags.isEmpty
            || store.task.hasImage
            || !store.taskAttachments.isEmpty
            || store.task.isChecklistDriven
            || store.task.isChecklistCompletionRoutine
            || store.task.hasSequentialSteps
    }

    private var routineLogsSection: some View {
        TaskDetailRoutineLogsSectionView(
            logs: store.logs,
            isExpanded: $isRoutineLogsExpanded,
            isShowingAllLogs: $isShowingAllLogs,
            createdAtBadgeValue: store.state.createdAtBadgeValue,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke
        ) { _, log, _ in
            let presentation = TaskDetailRoutineLogRowPresentation(log: log, showPersianDates: showPersianDates)
            TaskDetailRoutineLogRowContent(
                presentation: presentation,
                timeSpentStyle: .full,
                onEditTime: { beginEditingTime(for: log) }
            )
            .contextMenu {
                Button(log.actualDurationMinutes == nil ? "Add Time Spent" : "Edit Time Spent") {
                    beginEditingTime(for: log)
                }
                if let timestamp = log.timestamp {
                    Button(presentation.actionTitle) {
                        store.send(.requestRemoveLogEntry(timestamp))
                    }
                }
            }
        }
    }

    private func beginEditingTime(for log: RoutineLog) {
        editingTimeSpentMinutes = TaskDetailTimeSpentPresentation.defaultEditMinutes(
            currentMinutes: log.actualDurationMinutes,
            estimatedMinutes: store.task.estimatedDurationMinutes
        )
        editingTimeLog = log
    }

    private func beginEditingTaskTime() {
        resetTaskTimeEntry()
    }

    private var taskTimeSpentDisplayText: String {
        store.task.actualDurationMinutes.map(TaskDetailHeaderBadgePresentation.durationText(for:)) ?? "Not logged"
    }

    private var taskTimeEntryTotalMinutes: Int {
        TaskDetailTimeSpentPresentation.entryTotalMinutes(
            hours: taskTimeEntryHours,
            minutes: taskTimeEntryMinutes
        )
    }

    private var taskTimeEntryPreviewMinutes: Int {
        TaskDetailTimeSpentPresentation.previewTotalMinutes(
            currentMinutes: store.task.actualDurationMinutes,
            entryMinutes: taskTimeEntryTotalMinutes
        )
    }

    private var taskTimeEntryPreviewText: String {
        TaskDetailTimeSpentPresentation.previewText(
            currentMinutes: store.task.actualDurationMinutes,
            entryMinutes: taskTimeEntryTotalMinutes
        )
    }

    private var taskTimeEntryApplyTitle: String {
        TaskDetailTimeSpentPresentation.applyTitle(entryMinutes: taskTimeEntryTotalMinutes)
    }

    private var canApplyTaskTimeEntry: Bool {
        TaskDetailTimeSpentPresentation.canApplyEntry(
            currentMinutes: store.task.actualDurationMinutes,
            entryMinutes: taskTimeEntryTotalMinutes
        )
    }

    private func setTaskTimeEntryTotal(_ minutes: Int) {
        let clampedMinutes = TaskDetailTimeSpentPresentation.clampedMinutes(minutes)
        taskTimeEntryHours = clampedMinutes / 60
        taskTimeEntryMinutes = clampedMinutes % 60
    }

    private func resetTaskTimeEntry() {
        setTaskTimeEntryTotal(
            TaskDetailTimeSpentPresentation.defaultAdditionalEntryMinutes(
                currentMinutes: store.task.actualDurationMinutes,
                estimatedMinutes: store.task.estimatedDurationMinutes
            )
        )
    }

    private func applyTaskTimeEntry() {
        guard canApplyTaskTimeEntry else { return }
        store.send(.updateTaskDuration(taskTimeEntryPreviewMinutes))
        setTaskTimeEntryTotal(25)
    }

    private func addCompletedFocusToTimeSpent(_ seconds: TimeInterval) {
        let minutes = TaskDetailTimeSpentPresentation.focusSessionMinutes(from: seconds)

        if store.task.isOneOffTask {
            let currentMinutes = store.task.actualDurationMinutes ?? 0
            store.send(.updateTaskDuration(TaskDetailTimeSpentPresentation.clampedMinutes(currentMinutes + minutes)))
        } else if let latestCompletedLog {
            let currentMinutes = latestCompletedLog.actualDurationMinutes ?? 0
            store.send(.updateLogDuration(latestCompletedLog.id, TaskDetailTimeSpentPresentation.clampedMinutes(currentMinutes + minutes)))
        }
    }

    private var taskChangesSection: some View {
        TaskDetailTaskChangesSectionView(
            changes: store.task.changeLogEntries,
            isExpanded: $isTaskChangesExpanded,
            showPersianDates: showPersianDates,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            relatedTaskName: relatedTaskName(for:)
        )
    }

    private func relatedTaskName(for change: RoutineTaskChangeLogEntry) -> String {
        guard let relatedTaskID = change.relatedTaskID else { return "task" }
        return focusSessionTasks.first(where: { $0.id == relatedTaskID })?.name ?? "task"
    }

    private var relationshipsSection: some View {
        TaskDetailRelationshipsSectionView(
            groups: store.groupedResolvedRelationships,
            selectedRelationshipKind: Binding(
                get: { store.addLinkedTaskRelationshipKind },
                set: { store.send(.addLinkedTaskRelationshipKindChanged($0)) }
            ),
            isVisualizeDisabled: store.resolvedRelationships.isEmpty,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            onVisualize: { isRelationshipGraphPresented = true },
            onOpenTask: { store.send(.openLinkedTask($0)) },
            onOpenAddLinkedTask: { store.send(.openAddLinkedTask) }
        )
    }

    private var checklistItemsSection: some View {
        TaskDetailChecklistSectionView(
            task: store.task,
            selectedDate: store.resolvedSelectedDate,
            isDoneToday: store.isDoneToday,
            background: routineLogsBackground,
            stroke: TaskDetailPlatformStyle.sectionCardStroke,
            isMarkedDone: { store.state.isChecklistItemMarkedDone($0) },
            onToggleCompletion: { store.send(.toggleChecklistItemCompletion($0)) },
            onMarkPurchased: { store.send(.markChecklistItemPurchased($0)) }
        )
    }

    private var summaryStatusColor: Color {
        TaskDetailPresentation.summaryTitleColor(
            pausedAt: store.task.pausedAt,
            isDoneToday: store.isDoneToday,
            isAssumedDoneToday: store.isAssumedDoneToday,
            overdueDays: store.overdueDays,
            task: store.task
        )
    }

    private var toolbarCompletionTint: Color {
        store.canUndoSelectedDate ? .orange : .green
    }

    private var toolbarPauseActionTitle: String {
        store.task.isArchived() ? "Resume" : "Pause"
    }

    private var toolbarPauseSystemImage: String {
        store.task.isArchived() ? "play.fill" : "pause.fill"
    }

    private var toolbarPauseTint: Color {
        store.task.isArchived() ? .teal : .orange
    }

    private var routineLogsBackground: Color {
        TaskDetailPlatformStyle.routineLogsBackground
    }

    // MARK: - Attachment actions

    func saveAttachment(item: AttachmentItem) {
        fileToSave = item
    }

    func openAttachment(data: Data, fileName: String) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoutineAttachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent(fileName)
        try? data.write(to: fileURL)
        platformOpenAttachment(url: fileURL)
    }

    func openTaskImage(data: Data) {
        let fileName = TaskDetailAttachmentPresentation.taskImageFileName(for: store.task, data: data)
        openAttachment(data: data, fileName: fileName)
    }

}

private struct TaskDetailEqualHeightPairRow<Leading: View, Trailing: View>: View {
    let spacing: CGFloat
    let leading: (CGFloat?) -> Leading
    let trailing: (CGFloat?) -> Trailing

    @State private var measuredHeight: CGFloat = 0

    init(
        spacing: CGFloat = 8,
        @ViewBuilder leading: @escaping (CGFloat?) -> Leading,
        @ViewBuilder trailing: @escaping (CGFloat?) -> Trailing
    ) {
        self.spacing = spacing
        self.leading = leading
        self.trailing = trailing
    }

    var body: some View {
        let synchronizedHeight = measuredHeight > 0 ? measuredHeight : nil

        HStack(alignment: .top, spacing: spacing) {
            leading(synchronizedHeight)
                .background(TaskDetailEqualHeightReader(id: "leading"))
                .frame(maxWidth: .infinity, alignment: .topLeading)

            trailing(synchronizedHeight)
                .background(TaskDetailEqualHeightReader(id: "trailing"))
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onPreferenceChange(TaskDetailEqualHeightPreferenceKey.self) { heights in
            let maxHeight = heights.values.max() ?? 0
            guard abs(maxHeight - measuredHeight) > 0.5 else { return }
            measuredHeight = maxHeight
        }
    }
}

private struct TaskDetailEqualHeightReader: View {
    let id: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: TaskDetailEqualHeightPreferenceKey.self,
                value: [id: proxy.size.height]
            )
        }
    }
}

private struct TaskDetailEqualHeightPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct TaskDetailColoredSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    let selection: Option
    let title: (Option) -> String
    let tint: (Option) -> Color
    let selectedForeground: (Option) -> Color
    let action: (Option) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isSelected = selection == option

                Button {
                    action(option)
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isSelected ? selectedForeground(option).opacity(0.88) : tint(option))
                            .frame(width: 6, height: 6)

                        Text(title(option))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? selectedForeground(option) : .primary)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(tint(option))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(option))
                .accessibilityValue(isSelected ? "Selected" : "")

                if index < options.index(before: options.endIndex) {
                    let nextOption = options[options.index(after: index)]
                    let isAdjacentToSelection = isSelected || selection == nextOption

                    Rectangle()
                        .fill(.primary.opacity(isAdjacentToSelection ? 0 : 0.14))
                        .frame(width: 1, height: 18)
                }
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
