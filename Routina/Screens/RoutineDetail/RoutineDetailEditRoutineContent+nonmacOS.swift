#if !os(macOS)
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

    var body: some View {
        Form {
            Section(header: Text("Name")) {
                TextField(
                    "Routine name",
                    text: Binding(
                        get: { store.editRoutineName },
                        set: { store.send(.editRoutineNameChanged($0)) }
                    )
                )
            }

            Section(header: Text("Emoji")) {
                HStack(spacing: 12) {
                    Text("Selected")
                        .foregroundColor(.secondary)
                    Text(store.editRoutineEmoji)
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
                                store.send(.editRoutineEmojiChanged(emoji))
                            } label: {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(store.editRoutineEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(header: Text("Tags")) {
                HStack(spacing: 10) {
                    TextField(
                        "health, focus, morning",
                        text: Binding(
                            get: { store.editTagDraft },
                            set: { store.send(.editTagDraftChanged($0)) }
                        )
                    )
                    .onSubmit {
                        store.send(.editAddTagTapped)
                    }

                    Button("Add") {
                        store.send(.editAddTagTapped)
                    }
                    .disabled(RoutineTag.parseDraft(store.editTagDraft).isEmpty)
                }

                availableTagSuggestionsContent
                manageTagsButton

                if store.editRoutineTags.isEmpty {
                    Text(store.availableTags.isEmpty ? "No tags yet" : "No selected tags yet")
                        .font(.caption)
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
                    .padding(.vertical, 4)
                }

                Text(tagSectionHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Schedule Type")) {
                Picker(
                    "Schedule Type",
                    selection: Binding(
                        get: { store.editScheduleMode },
                        set: { store.send(.editScheduleModeChanged($0)) }
                    )
                ) {
                    Text("Fixed").tag(RoutineScheduleMode.fixedInterval)
                    Text("Checklist").tag(RoutineScheduleMode.fixedIntervalChecklist)
                    Text("Runout").tag(RoutineScheduleMode.derivedFromChecklist)
                }
                .pickerStyle(.segmented)

                Text(scheduleModeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.editScheduleMode == .fixedInterval {
                Section(header: Text("Steps")) {
                    HStack(spacing: 10) {
                        TextField(
                            "Wash clothes",
                            text: Binding(
                                get: { store.editStepDraft },
                                set: { store.send(.editStepDraftChanged($0)) }
                            )
                        )
                        .onSubmit {
                            store.send(.editAddStepTapped)
                        }

                        Button("Add") {
                            store.send(.editAddStepTapped)
                        }
                        .disabled(RoutineStep.normalizedTitle(store.editStepDraft) == nil)
                    }

                    if store.editRoutineSteps.isEmpty {
                        Text("No steps yet")
                            .font(.caption)
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

                    Text("Steps run in order. Leave this empty for a one-step routine.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(header: Text("Checklist Items")) {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField(
                            "Bread",
                            text: Binding(
                                get: { store.editChecklistItemDraftTitle },
                                set: { store.send(.editChecklistItemDraftTitleChanged($0)) }
                            )
                        )
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
                        .disabled(RoutineChecklistItem.normalizedTitle(store.editChecklistItemDraftTitle) == nil)
                    }

                    if store.editRoutineChecklistItems.isEmpty {
                        Text("No checklist items yet")
                            .font(.caption)
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

                    Text(checklistSectionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("Place")) {
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

                Text(editPlaceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.editScheduleMode != .derivedFromChecklist {
                Section(header: Text("Frequency")) {
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
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Repeat")) {
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

            Section {
                Button(role: .destructive) {
                    store.send(.setDeleteConfirmation(true))
                } label: {
                    Text("Delete Routine")
                }
            } footer: {
                Text("This action cannot be undone.")
            }
        }
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

    private var manageTagsButton: some View {
        Button {
            isTagManagerPresented = true
        } label: {
            Label("Manage Tags", systemImage: "slider.horizontal.3")
        }
    }

    private var tagSectionHelpText: String {
        if store.availableTags.isEmpty {
            return "Press return or Add. Separate multiple tags with commas, or open Manage Tags."
        }
        return "Tap an existing tag below, open Manage Tags, or press return/Add to create a new one. Separate multiple tags with commas."
    }

    @ViewBuilder
    private var availableTagSuggestionsContent: some View {
        if !store.availableTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose from existing tags")
                    .font(.caption.weight(.medium))
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
                .padding(.vertical, 4)
            }
        }
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
            return "Show this routine when you are at \(place.name)."
        }
        return "Anywhere means the routine is always visible."
    }

    private var scheduleModeDescription: String {
        switch store.editScheduleMode {
        case .fixedInterval:
            return "Use one overall repeat interval for the whole routine."
        case .fixedIntervalChecklist:
            return "Use one overall repeat interval and complete every checklist item to finish the routine."
        case .derivedFromChecklist:
            return "Use checklist item due dates to decide when the routine is due."
        }
    }

    private var checklistSectionDescription: String {
        switch store.editScheduleMode {
        case .fixedIntervalChecklist:
            return "The routine is done when every checklist item is completed."
        case .derivedFromChecklist:
            return "The routine becomes due when the earliest checklist item is due."
        case .fixedInterval:
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
