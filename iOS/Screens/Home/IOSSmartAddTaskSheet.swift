import ComposableArchitecture
import SwiftData
import SwiftUI

extension HomeTCAView {
    @ViewBuilder
    var addRoutineSheetContent: some View {
        IOSSmartAddTaskSheet(homeStore: store, initialText: smartAddSeedText) {
            requestRefresh()
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
    @AppStorage(UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue, store: SharedDefaults.app)
    private var isPlacesEnabled = false
    @State private var text: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var isShowingDetails = false

    init(
        homeStore: StoreOf<HomeFeature>,
        initialText: String,
        onCreated: @escaping () -> Void
    ) {
        self.homeStore = homeStore
        self.onCreated = onCreated
        _text = State(initialValue: initialText)
    }

    private var draft: RoutinaQuickAddDraft? {
        RoutinaQuickAddParser.parse(text, calendar: calendar, includingPlaces: isPlacesEnabled)
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
                    calendar: calendar,
                    includingPlaces: isPlacesEnabled
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
        guard
            let addRoutineStore = homeStore.scope(
                state: \.addRoutineState,
                action: \.addRoutineSheet
            )
        else {
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

        let placeID =
            isPlacesEnabled
            ? matchingPlaceID(named: draft.placeName, in: addRoutineStore)
            : nil
        addRoutineStore.send(.selectedPlaceChanged(placeID))
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
        guard scheduleMode != .oneOff else { return }

        if let advanced = recurrenceRule.advanced {
            addRoutineStore.send(.recurrenceEditorModeChanged(.advanced))
            addRoutineStore.send(.advancedRecurrenceRuleChanged(advanced))
            seedTimeConstraint(from: recurrenceRule, into: addRoutineStore)
            return
        }

        guard !scheduleMode.isSoftIntervalRoutine else { return }
        addRoutineStore.send(.recurrenceEditorModeChanged(.simple))

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

struct IOSSmartAddDetectedChips: View {
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

    static func detectedDetailRows(
        for draft: RoutinaQuickAddDraft,
        calendar: Calendar = .current
    ) -> [DetectedChip] {
        var chips: [DetectedChip] = []

        if draft.scheduleMode != .oneOff {
            chips.append(
                DetectedChip(
                    title: draft.scheduleMode.isSoftIntervalRoutine ? "Gentle repeating" : "Repeats",
                    value: draft.recurrenceRule.displayText(calendar: calendar),
                    systemImage: "calendar"
                ))
        } else if draft.availabilityStartDate != nil || draft.availabilityEndDate != nil {
            let value =
                draft.exactAvailabilityDate(calendar: calendar)
                .map { "One-time task at \($0.formatted(date: .abbreviated, time: .shortened))" }
                ?? draft.scheduleSummaryText
            chips.append(
                DetectedChip(
                    title: "Available",
                    value: value,
                    systemImage: "calendar"
                ))
        } else if let deadline = draft.deadline {
            chips.append(
                DetectedChip(
                    title: "Due",
                    value: deadline.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "calendar"
                ))
        }

        if !draft.tags.isEmpty {
            chips.append(
                DetectedChip(
                    title: "Tags",
                    value: draft.tags.map { "#\($0)" }.joined(separator: " "),
                    systemImage: "tag"
                ))
        }

        if let placeName = draft.placeName {
            chips.append(
                DetectedChip(
                    title: "Place",
                    value: "@\(placeName)",
                    systemImage: "mappin.and.ellipse"
                ))
        }

        if draft.importance != .level2 || draft.urgency != .level2 {
            chips.append(
                DetectedChip(
                    title: "Importance / Urgency",
                    value: "\(draft.importance.title) / \(draft.urgency.title)",
                    systemImage: "exclamationmark.triangle"
                ))
        }

        if let estimatedDurationMinutes = draft.estimatedDurationMinutes {
            chips.append(
                DetectedChip(
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

    struct DetectedChip: Identifiable {
        let title: String
        let value: String
        let systemImage: String

        var id: String { "\(title):\(value)" }
    }
}
