import ComposableArchitecture
import SwiftData
import SwiftUI

struct HomeTCAView: View {
    let store: StoreOf<HomeFeature>
    let externalSearchText: Binding<String>?
    @Environment(\.calendar) var calendar
    @Query private var fileAttachments: [RoutineAttachment]
    @AppStorage(
        UserDefaultStringValueKey.appSettingRoutineListSectioningMode.rawValue,
        store: SharedDefaults.app
    ) private var routineListSectioningModeRawValue: String = RoutineListSectioningMode.defaultValue.rawValue
    @AppStorage(
        UserDefaultBoolValueKey.appSettingShowPersianDates.rawValue,
        store: SharedDefaults.app
    ) var showPersianDates = false
    @AppStorage(
        UserDefaultStringValueKey.appSettingHomeTaskRowHiddenFields.rawValue,
        store: SharedDefaults.app
    ) private var taskRowHiddenFieldsRawValue = ""
    @State private var localSearchText = ""
    @State var isCompactHeaderHidden = false
    @State var areTaskListModeActionsExpanded = false
    @State var isRefreshScheduled = false
    @State var relatedFilterTagSuggestionAnchor: String?

    init(
        store: StoreOf<HomeFeature>,
        searchText: Binding<String>? = nil
    ) {
        self.store = store
        self.externalSearchText = searchText
    }

    var body: some View {
homeContent
    }

    private var homeContent: some View {
        applyHomeRefreshObservers(
            to: applyPlatformHomeObservers(
                to: applyAddRoutinePresentation(
                    to: applyPlatformDeleteConfirmation(
                        to: applyPlatformRefresh(
                            to: applyPlatformSearchExperience(
                                to: platformNavigationContent,
                                searchText: searchTextBinding
                            )
                        )
                    )
                )
            )
                .sheet(isPresented: isFilterSheetPresentedBinding) {
                    homeFiltersSheet
                }
                .task {
                    syncFileAttachmentTaskIDs()
                }
                .onChange(of: fileAttachmentChangeToken) { _, _ in
                    syncFileAttachmentTaskIDs()
                }
        )
    }

    private var fileAttachmentChangeToken: [String] {
        fileAttachments.map { "\($0.id.uuidString):\($0.taskID.uuidString)" }.sorted()
    }

    private func syncFileAttachmentTaskIDs() {
        store.send(.fileAttachmentTaskIDsChanged(Set(fileAttachments.map(\.taskID))))
    }

    @ViewBuilder
    var detailContent: some View {
        if let detailStore = self.store.scope(
            state: \.taskDetailState,
            action: \.taskDetail
        ) {
            TaskDetailTCAView(store: detailStore)
        } else {
            ContentUnavailableView(
                "Select a task",
                systemImage: "checklist.checked",
                description: Text("Choose a routine or to-do from the sidebar to see its schedule, logs, and actions.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var addRoutineSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isAddRoutineSheetPresented },
            set: { store.send(.setAddRoutineSheet($0)) }
        )
    }

    var searchTextBinding: Binding<String> {
        if let externalSearchText {
            externalSearchText
        } else {
            $localSearchText
        }
    }

    var routineListSectioningMode: RoutineListSectioningMode {
        get {
            RoutineListSectioningMode(rawValue: routineListSectioningModeRawValue) ?? .defaultValue
        }
        nonmutating set {
            routineListSectioningModeRawValue = newValue.rawValue
        }
    }

    var taskRowVisibility: HomeTaskRowVisibility {
        HomeTaskRowVisibility(storageRawValue: taskRowHiddenFieldsRawValue)
    }

    var selectedTaskBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedTaskID },
            set: { store.send(.setSelectedTask($0)) }
        )
    }

    @ViewBuilder
    var addRoutineSheetContent: some View {
        IOSSmartAddTaskSheet(homeStore: store) {
            requestRefresh()
        }
    }

    var timelineRangePicker: some View {
        platformTimelineRangePicker
    }

    var timelineTypePicker: some View {
        platformTimelineTypePicker
    }

    var overallDoneCountSummary: some View {
        HStack(spacing: 12) {
            Label("\(store.doneStats.totalCount) done", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)

            Label("\(store.doneStats.canceledTotalCount) canceled", systemImage: "xmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            Label("\(store.doneStats.missedTotalCount) missed", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.yellow)

            Label("\(store.routineTasks.filter { !$0.isOneOffTask }.count) routines", systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Label("\(store.routineTasks.filter { $0.isOneOffTask && !$0.isCompletedOneOff && !$0.isCanceledOneOff }.count) todos", systemImage: "checkmark.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    var tagFilterBar: some View {
        platformTagFilterBar
    }

    func listOfSortedTasksView(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> some View {
        platformListOfSortedTasksView(
            routineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays
        )
    }

    var compactHomeHeader: some View {
        platformCompactHomeHeader
    }

    func routineRow(for task: HomeFeature.RoutineDisplay, rowNumber: Int) -> some View {
        platformRoutineRow(for: task, rowNumber: rowNumber)
    }

    @ViewBuilder
    func taskDetailDestination(taskID: UUID) -> some View {
        if store.selectedTaskID == taskID,
           let detailStore = self.store.scope(
               state: \.taskDetailState,
               action: \.taskDetail
        ) {
            TaskDetailTCAView(store: detailStore)
        } else if store.routineTasks.contains(where: { $0.id == taskID }) {
            HomeLoadingStateView(
                title: "Opening Routine",
                message: "Loading routine details and recent activity.",
                systemImage: "checklist.checked",
                showsSkeleton: false
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    openTask(taskID)
                }
        } else {
            ContentUnavailableView(
                "Routine not found",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected routine is no longer available.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    func deleteTasks(
        at offsets: IndexSet,
        from sectionTasks: [HomeFeature.RoutineDisplay]
    ) {
        platformDeleteTasks(at: offsets, from: sectionTasks)
    }

    func openTask(_ taskID: UUID) {
        platformOpenTask(taskID)
    }

    func deleteTask(_ taskID: UUID) {
        platformDeleteTask(taskID)
    }

    func statusBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        HomeStatusBadgeView(style: badgeStyle(for: task).map { HomeStatusBadgeStyle($0) })
    }

    func taskTypeBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        HomeTaskTypeBadgeView(isTodo: task.isOneOffTask)
    }

    @ViewBuilder
    func emptyStateView(
        title: String,
        message: String,
        systemImage: String,
        action: (() -> Void)? = nil
    ) -> some View {
        HomeEmptyStateView(
            title: title,
            message: message,
            systemImage: systemImage,
            action: action
        )
    }

    func inlineEmptyStateRow(
        title: String,
        message: String,
        systemImage: String
    ) -> some View {
        HomeInlineEmptyStateRowView(
            title: title,
            message: message,
            systemImage: systemImage
        )
    }

    func handleCompactHeaderScroll(oldOffset: CGFloat, newOffset: CGFloat) {
        let delta = newOffset - oldOffset

        if abs(delta) > 2 {
            collapseExpandedToolbarActions()
        }

        if newOffset <= 12 {
            if isCompactHeaderHidden {
                isCompactHeaderHidden = false
            }
            return
        }

        if delta > 10, !isCompactHeaderHidden {
            isCompactHeaderHidden = true
        } else if delta < -10, isCompactHeaderHidden {
            isCompactHeaderHidden = false
        }
    }

    func collapseExpandedToolbarActions() {
        guard areTaskListModeActionsExpanded else { return }
        withAnimation(.snappy(duration: 0.2)) {
            areTaskListModeActionsExpanded = false
        }
    }
}

private struct IOSSmartAddTaskSheet: View {
    let homeStore: StoreOf<HomeFeature>
    let onCreated: () -> Void

    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isInputFocused: Bool
    @State private var text = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isShowingDetails = false

    private var draft: RoutinaQuickAddDraft? {
        RoutinaQuickAddParser.parse(text, calendar: calendar)
    }

    private var canSave: Bool {
        draft != nil && !isSaving
    }

    var body: some View {
        if isShowingDetails {
            if let addRoutineStore = homeStore.scope(
                state: \.addRoutineState,
                action: \.addRoutineSheet
            ) {
                AddRoutineTCAView(store: addRoutineStore)
            } else {
                ProgressView()
                    .task {
                        prepareDetails()
                    }
            }
        } else {
            smartAddContent
        }
    }

    private var smartAddContent: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "water plants every Sat at 9 #home",
                        text: $text,
                        axis: .vertical
                    )
                    .focused($isInputFocused)
                    .lineLimit(2...5)
                    .disabled(isSaving)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.sentences)
                    .onSubmit(save)
                }

                if let draft, IOSSmartAddDetectedChips.hasDetections(in: draft) {
                    Section("Detected") {
                        IOSSmartAddDetectedChips(draft: draft)
                    }
                }

                Section {
                    Button {
                        openDetails()
                    } label: {
                        Label("Details", systemImage: "slider.horizontal.3")
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                isInputFocused = true
            }
        }
    }

    private func save() {
        guard canSave else { return }
        errorMessage = nil
        isSaving = true

        Task { @MainActor in
            defer { isSaving = false }
            do {
                _ = try await RoutinaQuickAddService.createTask(
                    from: text,
                    context: modelContext,
                    calendar: calendar
                )
                onCreated()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func openDetails() {
        prepareDetails()
        isShowingDetails = true
    }

    private func prepareDetails() {
        homeStore.send(.prepareAddRoutineDetails)
        guard let addRoutineStore = homeStore.scope(
            state: \.addRoutineState,
            action: \.addRoutineSheet
        ) else {
            return
        }

        seedDetailsFromDraft(into: addRoutineStore)
    }

    private func seedDetailsFromDraft(into addRoutineStore: StoreOf<AddRoutineFeature>) {
        guard let draft else {
            addRoutineStore.send(.routineNameChanged(text.trimmingCharacters(in: .whitespacesAndNewlines)))
            return
        }

        addRoutineStore.send(.routineNameChanged(draft.name))
        addRoutineStore.send(.scheduleModeChanged(draft.scheduleMode))
        seedFrequency(from: draft.frequencyInDays, into: addRoutineStore)
        seedRecurrence(from: draft.recurrenceRule, scheduleMode: draft.scheduleMode, into: addRoutineStore)

        if let deadline = draft.deadline {
            addRoutineStore.send(.deadlineEnabledChanged(true))
            addRoutineStore.send(.deadlineDateChanged(deadline))
        } else {
            addRoutineStore.send(.deadlineEnabledChanged(false))
        }

        if let reminderAt = draft.reminderAt {
            addRoutineStore.send(.reminderEnabledChanged(true))
            addRoutineStore.send(.reminderDateChanged(reminderAt))
        } else {
            addRoutineStore.send(.reminderEnabledChanged(false))
        }

        addRoutineStore.send(.importanceChanged(draft.importance))
        addRoutineStore.send(.urgencyChanged(draft.urgency))
        addRoutineStore.send(.estimatedDurationChanged(draft.estimatedDurationMinutes))
        addRoutineStore.send(.focusModeEnabledChanged(draft.focusModeEnabled))

        for tag in addRoutineStore.organization.routineTags {
            addRoutineStore.send(.removeTag(tag))
        }
        for tag in draft.tags {
            addRoutineStore.send(.tagDraftChanged(tag))
            addRoutineStore.send(.addTagTapped)
        }

        addRoutineStore.send(.selectedPlaceChanged(matchingPlaceID(named: draft.placeName, in: addRoutineStore)))
    }

    private func seedFrequency(
        from days: Int,
        into addRoutineStore: StoreOf<AddRoutineFeature>
    ) {
        let safeDays = max(days, 1)
        if safeDays.isMultiple(of: 30) {
            addRoutineStore.send(.frequencyChanged(.month))
            addRoutineStore.send(.frequencyValueChanged(max(safeDays / 30, 1)))
        } else if safeDays.isMultiple(of: 7) {
            addRoutineStore.send(.frequencyChanged(.week))
            addRoutineStore.send(.frequencyValueChanged(max(safeDays / 7, 1)))
        } else {
            addRoutineStore.send(.frequencyChanged(.day))
            addRoutineStore.send(.frequencyValueChanged(safeDays))
        }
    }

    private func seedRecurrence(
        from recurrenceRule: RoutineRecurrenceRule,
        scheduleMode: RoutineScheduleMode,
        into addRoutineStore: StoreOf<AddRoutineFeature>
    ) {
        guard scheduleMode != .oneOff, !scheduleMode.isSoftIntervalRoutine else { return }

        addRoutineStore.send(.recurrenceKindChanged(recurrenceRule.kind))

        switch recurrenceRule.kind {
        case .intervalDays:
            break
        case .dailyTime:
            seedTimeConstraint(from: recurrenceRule, into: addRoutineStore)
        case .weekly:
            addRoutineStore.send(.recurrenceWeekdayChanged(recurrenceRule.weekday ?? calendar.firstWeekday))
            seedTimeConstraint(from: recurrenceRule, into: addRoutineStore)
        case .monthlyDay:
            addRoutineStore.send(.recurrenceDayOfMonthChanged(recurrenceRule.dayOfMonth ?? 1))
            seedTimeConstraint(from: recurrenceRule, into: addRoutineStore)
        }
    }

    private func seedTimeConstraint(
        from recurrenceRule: RoutineRecurrenceRule,
        into addRoutineStore: StoreOf<AddRoutineFeature>
    ) {
        if let timeRange = recurrenceRule.timeRange {
            addRoutineStore.send(.recurrenceHasTimeRangeChanged(true))
            addRoutineStore.send(.recurrenceTimeRangeStartChanged(timeRange.start))
            addRoutineStore.send(.recurrenceTimeRangeEndChanged(timeRange.end))
        } else if let timeOfDay = recurrenceRule.timeOfDay {
            addRoutineStore.send(.recurrenceHasExplicitTimeChanged(true))
            addRoutineStore.send(.recurrenceTimeOfDayChanged(timeOfDay))
        } else {
            addRoutineStore.send(.recurrenceHasExplicitTimeChanged(false))
            addRoutineStore.send(.recurrenceHasTimeRangeChanged(false))
        }
    }

    private func matchingPlaceID(
        named placeName: String?,
        in addRoutineStore: StoreOf<AddRoutineFeature>
    ) -> UUID? {
        guard let placeName,
              let normalizedName = RoutinePlace.normalizedName(placeName)
        else {
            return nil
        }

        return addRoutineStore.organization.availablePlaces.first { place in
            RoutinePlace.normalizedName(place.name) == normalizedName
        }?.id
    }
}

private struct IOSSmartAddDetectedChips: View {
    let draft: RoutinaQuickAddDraft
    @Environment(\.calendar) private var calendar

    static func hasDetections(in draft: RoutinaQuickAddDraft) -> Bool {
        !detectedDetailRows(for: draft).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Self.detectedRows(for: draft, calendar: calendar)) { detectedChip in
                detectedRow(detectedChip)
            }
        }
        .padding(.vertical, 4)
    }

    private static func detectedRows(
        for draft: RoutinaQuickAddDraft,
        calendar: Calendar
    ) -> [DetectedChip] {
        [
            DetectedChip(
                title: "Task",
                value: draft.name,
                systemImage: "textformat"
            )
        ] + detectedDetailRows(for: draft, calendar: calendar)
    }

    private static func detectedDetailRows(
        for draft: RoutinaQuickAddDraft,
        calendar: Calendar = .current
    ) -> [DetectedChip] {
        var chips: [DetectedChip] = []

        if draft.scheduleMode != .oneOff {
            chips.append(DetectedChip(
                title: draft.scheduleMode.isSoftIntervalRoutine ? "Gentle routine" : "Repeats",
                value: draft.recurrenceRule.displayText(calendar: calendar),
                systemImage: "calendar"
            ))
        } else if let deadline = draft.deadline {
            chips.append(DetectedChip(
                title: "Due",
                value: deadline.formatted(date: .abbreviated, time: .shortened),
                systemImage: "calendar"
            ))
        }

        if !draft.tags.isEmpty {
            chips.append(DetectedChip(
                title: "Tags",
                value: draft.tags.map { "#\($0)" }.joined(separator: " "),
                systemImage: "tag"
            ))
        }

        if let placeName = draft.placeName {
            chips.append(DetectedChip(
                title: "Place",
                value: "@\(placeName)",
                systemImage: "mappin.and.ellipse"
            ))
        }

        if draft.importance != .level2 || draft.urgency != .level2 {
            chips.append(DetectedChip(
                title: "Priority",
                value: "\(draft.importance.title) / \(draft.urgency.title)",
                systemImage: "exclamationmark.triangle"
            ))
        }

        if let estimatedDurationMinutes = draft.estimatedDurationMinutes {
            chips.append(DetectedChip(
                title: "Focus",
                value: "\(estimatedDurationMinutes)m",
                systemImage: "timer"
            ))
        }

        return chips
    }

    private func detectedRow(_ detectedChip: DetectedChip) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: detectedChip.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(detectedChip.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(detectedChip.value)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private struct DetectedChip: Identifiable {
        let title: String
        let value: String
        let systemImage: String

        var id: String { "\(title):\(value)" }
    }
}

extension HomeFeature.TaskListMode {
    var filterTaskListKind: HomeFilterTaskListKind {
        switch self {
        case .all:
            return .all
        case .routines:
            return .routines
        case .todos:
            return .todos
        }
    }
}
