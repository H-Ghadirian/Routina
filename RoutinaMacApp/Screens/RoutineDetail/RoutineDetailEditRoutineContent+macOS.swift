#if os(macOS)
import ComposableArchitecture
import SwiftUI

struct RoutineDetailEditRoutineContent: View {
    let store: StoreOf<RoutineDetailFeature>
    @Binding var isEditEmojiPickerPresented: Bool
    let emojiOptions: [String]
    @State private var isTagManagerPresented = false
    @State private var tagManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }

    private var sectionHeaderFont: Font { .headline.weight(.semibold) }

    private var sectionCardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor)
    }

    private var sectionCardStroke: Color {
        Color.gray.opacity(0.18)
    }

    var body: some View {
        let pauseArchivePresentation = RoutinePauseArchivePresentation.make(
            isPaused: store.task.isPaused,
            context: .editSheet
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sectionCard(title: "Basic") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField(
                                "Task name",
                                text: Binding(
                                    get: { store.editRoutineName },
                                    set: { store.send(.editRoutineNameChanged($0)) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Emoji")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack(spacing: 12) {
                                Text(store.editRoutineEmoji)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(Color.blue.opacity(0.15))
                                    )
                                Button("Change Emoji") {
                                    isEditEmojiPickerPresented = true
                                }
                                .buttonStyle(.bordered)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }

                sectionCard(title: "Tags") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            TextField(
                                "health, focus, morning",
                                text: Binding(
                                    get: { store.editTagDraft },
                                    set: { store.send(.editTagDraftChanged($0)) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                store.send(.editAddTagTapped)
                            }

                            Button("Add") {
                                store.send(.editAddTagTapped)
                            }
                            .buttonStyle(.bordered)
                            .disabled(RoutineTag.parseDraft(store.editTagDraft).isEmpty)
                        }

                        availableTagSuggestionsContent
                        manageTagsButton

                        if store.editRoutineTags.isEmpty {
                            Text(store.availableTags.isEmpty ? "No tags yet" : "No selected tags yet")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(store.editRoutineTags, id: \.self) { tag in
                                    Button {
                                        store.send(.editRemoveTag(tag))
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text("#\(tag)")
                                                .lineLimit(1)
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Text(tagSectionHelpText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                sectionCard(title: "Task Type") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Task Type", selection: taskTypeBinding) {
                            Text("Routine").tag(RoutineTaskType.routine)
                            Text("Todo").tag(RoutineTaskType.todo)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 260)

                        Text(taskTypeDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if store.editScheduleMode.taskType == .routine {
                            Divider()
                                .padding(.vertical, 2)

                            Picker("Schedule Type", selection: scheduleModeBinding) {
                                Text("Fixed").tag(RoutineScheduleMode.fixedInterval)
                                Text("Checklist").tag(RoutineScheduleMode.fixedIntervalChecklist)
                                Text("Runout").tag(RoutineScheduleMode.derivedFromChecklist)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 320)

                            Text(scheduleModeDescription)
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if !isStepBasedMode {
                                Divider()
                                    .padding(.vertical, 2)

                                VStack(alignment: .leading, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        TextField(
                                            "Bread",
                                            text: Binding(
                                                get: { store.editChecklistItemDraftTitle },
                                                set: { store.send(.editChecklistItemDraftTitleChanged($0)) }
                                            )
                                        )
                                        .textFieldStyle(.roundedBorder)
                                        .onSubmit {
                                            store.send(.editAddChecklistItemTapped)
                                        }

                                        if store.editScheduleMode == .derivedFromChecklist {
                                            Stepper(
                                                value: Binding(
                                                    get: { store.editChecklistItemDraftInterval },
                                                    set: { store.send(.editChecklistItemDraftIntervalChanged($0)) }
                                                ),
                                                in: 1...365
                                            ) {
                                                Text(checklistIntervalLabel(for: store.editChecklistItemDraftInterval))
                                            }
                                        }

                                        Button("Add Item") {
                                            store.send(.editAddChecklistItemTapped)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(RoutineChecklistItem.normalizedTitle(store.editChecklistItemDraftTitle) == nil)
                                    }

                                    editableChecklistItemsContent

                                    Text(checklistSectionDescription)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                sectionCard(title: "Place") {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker(
                            "Place",
                            selection: Binding(
                                get: { store.editSelectedPlaceID },
                                set: { store.send(.editSelectedPlaceChanged($0)) }
                            )
                        ) {
                            Text("Anywhere").tag(Optional<UUID>.none)
                            ForEach(store.availablePlaces) { place in
                                Text(place.name).tag(Optional(place.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)

                        Text(editPlaceDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if showsRepeatControls {
                    sectionCard(title: "Schedule") {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Frequency")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Picker(
                                    "Frequency",
                                    selection: Binding(
                                        get: { store.editFrequency },
                                        set: { store.send(.editFrequencyChanged($0)) }
                                    )
                                ) {
                                    ForEach(RoutineDetailFeature.EditFrequency.allCases, id: \.self) { frequency in
                                        Text(frequency.rawValue).tag(frequency)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Repeat")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Stepper(
                                    value: Binding(
                                        get: { store.editFrequencyValue },
                                        set: { store.send(.editFrequencyValueChanged($0)) }
                                    ),
                                    in: 1...365
                                ) {
                                    Text(
                                        editStepperLabel(
                                            frequency: store.editFrequency,
                                            frequencyValue: store.editFrequencyValue
                                        )
                                    )
                                }
                            }
                        }
                    }
                }

                if isStepBasedMode {
                    sectionCard(title: "Steps") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                TextField(
                                    "Wash clothes",
                                    text: Binding(
                                        get: { store.editStepDraft },
                                        set: { store.send(.editStepDraftChanged($0)) }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    store.send(.editAddStepTapped)
                                }

                                Button("Add") {
                                    store.send(.editAddStepTapped)
                                }
                                .buttonStyle(.bordered)
                                .disabled(RoutineStep.normalizedTitle(store.editStepDraft) == nil)
                            }

                            editableStepsContent

                            Text(stepsSectionDescription)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                sectionCard(title: "Danger Zone") {
                    VStack(alignment: .leading, spacing: 10) {
                        if !store.task.isOneOffTask {
                            Button(pauseArchivePresentation.actionTitle) {
                                store.send(store.task.isPaused ? .resumeTapped : .pauseTapped)
                            }
                            .buttonStyle(.bordered)
                            .tint(store.task.isPaused ? .teal : .orange)

                            Text(pauseArchivePresentation.description ?? "")
                                .font(.footnote)
                                .foregroundColor(.secondary)

                            Divider()
                        }

                        Button(role: .destructive) {
                            store.send(.setDeleteConfirmation(true))
                        } label: {
                            Text("Delete Task")
                        }
                        .buttonStyle(.borderless)

                        Text("This action cannot be undone.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 520, minHeight: 460)
        .sheet(isPresented: $isTagManagerPresented) {
            SettingsTagManagerPresentationView(store: tagManagerStore)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .routineTagDidRename)
                .receive(on: RunLoop.main)
        ) { notification in
            guard let payload = notification.routineTagRenamePayload else { return }
            store.send(.editTagRenamed(oldName: payload.oldName, newName: payload.newName))
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .routineTagDidDelete)
                .receive(on: RunLoop.main)
        ) { notification in
            guard let tagName = notification.routineTagDeletedName else { return }
            store.send(.editTagDeleted(tagName))
        }
    }

    private var scheduleModeBinding: Binding<RoutineScheduleMode> {
        Binding(
            get: { store.editScheduleMode },
            set: { store.send(.editScheduleModeChanged($0)) }
        )
    }

    private var taskTypeBinding: Binding<RoutineTaskType> {
        Binding(
            get: { store.editScheduleMode.taskType },
            set: { taskType in
                let nextMode: RoutineScheduleMode
                switch taskType {
                case .routine:
                    nextMode = store.editScheduleMode == .oneOff ? .fixedInterval : store.editScheduleMode
                case .todo:
                    nextMode = .oneOff
                }
                store.send(.editScheduleModeChanged(nextMode))
            }
        )
    }

    private var isStepBasedMode: Bool {
        store.editScheduleMode == .fixedInterval || store.editScheduleMode == .oneOff
    }

    private var showsRepeatControls: Bool {
        store.editScheduleMode != .derivedFromChecklist && store.editScheduleMode != .oneOff
    }

    private var taskTypeDescription: String {
        switch store.editScheduleMode.taskType {
        case .routine:
            return "Routines repeat on a schedule and stay in your rotation."
        case .todo:
            return "Todos are one-off tasks. Once you finish one, it stays completed."
        }
    }

    private var manageTagsButton: some View {
        Button {
            isTagManagerPresented = true
        } label: {
            Label("Manage Tags", systemImage: "slider.horizontal.3")
        }
        .buttonStyle(.bordered)
    }

    private var tagSectionHelpText: String {
        if store.availableTags.isEmpty {
            return "Press return or Add. Separate multiple tags with commas, or open Manage Tags."
        }
        return "Tap an existing tag below, open Manage Tags, or press return/Add to create a new one. Separate multiple tags with commas."
    }

    @ViewBuilder
    private var editableStepsContent: some View {
        if store.editRoutineSteps.isEmpty {
            Text("No steps yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(Array(store.editRoutineSteps.enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 10) {
                        Text("\(index + 1).")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .leading)

                        Text(step.title)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 6) {
                            Button {
                                store.send(.editMoveStepUp(step.id))
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)

                            Button {
                                store.send(.editMoveStepDown(step.id))
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == store.editRoutineSteps.count - 1)

                            Button(role: .destructive) {
                                store.send(.editRemoveStep(step.id))
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var editableChecklistItemsContent: some View {
        if store.editRoutineChecklistItems.isEmpty {
            Text("No checklist items yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(store.editRoutineChecklistItems) { item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if store.editScheduleMode == .derivedFromChecklist {
                                Text(checklistIntervalLabel(for: item.intervalDays))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button(role: .destructive) {
                            store.send(.editRemoveChecklistItem(item.id))
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var availableTagSuggestionsContent: some View {
        if !store.availableTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose from existing tags")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(store.availableTags, id: \.self) { tag in
                        let isSelected = RoutineTag.contains(tag, in: store.editRoutineTags)
                        Button {
                            store.send(.editToggleTagSelection(tag))
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.caption)
                                Text("#\(tag)")
                                    .lineLimit(1)
                            }
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(isSelected ? "Remove" : "Add") tag \(tag)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(sectionHeaderFont)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(sectionCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(sectionCardStroke, lineWidth: 1)
        )
    }

    private func editStepperLabel(
        frequency: RoutineDetailFeature.EditFrequency,
        frequencyValue: Int
    ) -> String {
        if frequencyValue == 1 {
            switch frequency {
            case .day: return "Everyday"
            case .week: return "Everyweek"
            case .month: return "Everymonth"
            }
        }
        return "Every \(frequencyValue) \(frequency.singularLabel)s"
    }

    private var editPlaceDescription: String {
        if let selectedPlaceID = store.editSelectedPlaceID,
           let place = store.availablePlaces.first(where: { $0.id == selectedPlaceID }) {
            return "Show this task when you are at \(place.name)."
        }
        return "Anywhere means the task is always visible."
    }

    private var stepsSectionDescription: String {
        if store.editScheduleMode == .oneOff {
            return "Steps run in order. Leave this empty for a single-step todo."
        }
        return "Steps run in order. Leave this empty for a one-step routine."
    }

    private var scheduleModeDescription: String {
        switch store.editScheduleMode {
        case .fixedInterval:
            return "Use one overall repeat interval for the whole routine."
        case .fixedIntervalChecklist:
            return "Use one overall repeat interval and complete every checklist item to finish the routine."
        case .derivedFromChecklist:
            return "Use checklist item due dates to decide when the routine is due."
        case .oneOff:
            return "This task does not repeat."
        }
    }

    private var checklistSectionDescription: String {
        switch store.editScheduleMode {
        case .fixedIntervalChecklist:
            return "The routine is done when every checklist item is completed."
        case .derivedFromChecklist:
            return "The routine becomes due when the earliest checklist item is due."
        case .fixedInterval, .oneOff:
            return ""
        }
    }

    private func checklistIntervalLabel(for intervalDays: Int) -> String {
        if intervalDays == 1 {
            return "Runs out in 1 day"
        }
        return "Runs out in \(intervalDays) days"
    }
}
#endif
