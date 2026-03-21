import SwiftUI
import ComposableArchitecture

struct AddRoutineTCAView: View {
    let store: StoreOf<AddRoutineFeature>
    @FocusState private var isRoutineNameFocused: Bool
    @State private var isEmojiPickerPresented = false
    private let emojiOptions = EmojiCatalog.uniqueQuick
    private let allEmojiOptions = EmojiCatalog.searchableAll

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                addRoutineContent
                .navigationTitle("Add Routine")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            store.send(.cancelTapped)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.send(.saveTapped)
                        }
                        .disabled(isSaveDisabled)
                    }
                }
                .routinaAddRoutineNameAutofocus(isRoutineNameFocused: $isRoutineNameFocused)
                .routinaAddRoutineEmojiPicker(isPresented: $isEmojiPickerPresented) {
                    EmojiPickerSheet(
                        selectedEmoji: routineEmojiBinding,
                        emojis: allEmojiOptions
                    )
                }
                .routinaAddRoutineSheetFrame()
            }
        }
    }

    @ViewBuilder
    private var addRoutineContent: some View {
        #if os(macOS)
        macOSContent
        #else
        Form {
            Section(header: Text("Name")) {
                TextField("Routine name", text: routineNameBinding)
                    .focused($isRoutineNameFocused)
                if let nameValidationMessage {
                    Text(nameValidationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(header: Text("Emoji")) {
                HStack(spacing: 12) {
                    Text("Selected")
                        .foregroundColor(.secondary)
                    Text(store.routineEmoji)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                    Spacer()
                    Button("Choose Emoji") {
                        isEmojiPickerPresented = true
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button {
                                store.send(.routineEmojiChanged(emoji))
                            } label: {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(store.routineEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section(header: Text("Tags")) {
                tagComposer
                editableTagsContent

                Text("Press return or Add. Separate multiple tags with commas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Schedule Type")) {
                Picker("Schedule Type", selection: scheduleModeBinding) {
                    Text("Fixed").tag(RoutineScheduleMode.fixedInterval)
                    Text("Checklist").tag(RoutineScheduleMode.fixedIntervalChecklist)
                    Text("Runout").tag(RoutineScheduleMode.derivedFromChecklist)
                }
                .pickerStyle(.segmented)

                Text(scheduleModeDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.scheduleMode == .fixedInterval {
                Section(header: Text("Steps")) {
                    stepComposer
                    editableStepsContent

                    Text("Steps run in order. Leave this empty for a one-step routine.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(header: Text("Checklist Items")) {
                    checklistItemComposer
                    editableChecklistItemsContent

                    Text(checklistSectionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(header: Text("Place")) {
                Picker("Place", selection: selectedPlaceBinding) {
                    Text("Anywhere").tag(Optional<UUID>.none)
                    ForEach(store.availablePlaces) { place in
                        Text(place.name).tag(Optional(place.id))
                    }
                }

                Text(placeSelectionDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if store.scheduleMode != .derivedFromChecklist {
                Section(header: Text("Frequency")) {
                    Picker("Frequency", selection: frequencyBinding) {
                        ForEach(AddRoutineFeature.Frequency.allCases, id: \.self) { frequency in
                            Text(frequency.rawValue).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Repeat")) {
                    Stepper(value: frequencyValueBinding, in: 1...365) {
                        Text(
                            stepperLabel(
                                frequency: store.frequency,
                                frequencyValue: store.frequencyValue
                            )
                        )
                    }
                }
            }
        }
        #endif
    }

    private var routineNameBinding: Binding<String> {
        Binding(
            get: { store.routineName },
            set: { store.send(.routineNameChanged($0)) }
        )
    }

    private var routineEmojiBinding: Binding<String> {
        Binding(
            get: { store.routineEmoji },
            set: { store.send(.routineEmojiChanged($0)) }
        )
    }

    private var tagDraftBinding: Binding<String> {
        Binding(
            get: { store.tagDraft },
            set: { store.send(.tagDraftChanged($0)) }
        )
    }

    private var stepDraftBinding: Binding<String> {
        Binding(
            get: { store.stepDraft },
            set: { store.send(.stepDraftChanged($0)) }
        )
    }

    private var checklistItemDraftTitleBinding: Binding<String> {
        Binding(
            get: { store.checklistItemDraftTitle },
            set: { store.send(.checklistItemDraftTitleChanged($0)) }
        )
    }

    private var checklistItemDraftIntervalBinding: Binding<Int> {
        Binding(
            get: { store.checklistItemDraftInterval },
            set: { store.send(.checklistItemDraftIntervalChanged($0)) }
        )
    }

    private var scheduleModeBinding: Binding<RoutineScheduleMode> {
        Binding(
            get: { store.scheduleMode },
            set: { store.send(.scheduleModeChanged($0)) }
        )
    }

    private var frequencyBinding: Binding<AddRoutineFeature.Frequency> {
        Binding(
            get: { store.frequency },
            set: { store.send(.frequencyChanged($0)) }
        )
    }

    private var frequencyValueBinding: Binding<Int> {
        Binding(
            get: { store.frequencyValue },
            set: { store.send(.frequencyValueChanged($0)) }
        )
    }

    private var selectedPlaceBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedPlaceID },
            set: { store.send(.selectedPlaceChanged($0)) }
        )
    }

    private var isSaveDisabled: Bool {
        store.isSaveDisabled
    }

    private var nameValidationMessage: String? {
        store.nameValidationMessage
    }

    private var isAddTagDisabled: Bool {
        RoutineTag.parseDraft(store.tagDraft).isEmpty
    }

    private var isAddStepDisabled: Bool {
        RoutineStep.normalizedTitle(store.stepDraft) == nil
    }

    private var isAddChecklistItemDisabled: Bool {
        RoutineChecklistItem.normalizedTitle(store.checklistItemDraftTitle) == nil
    }

    private var scheduleModeDescription: String {
        switch store.scheduleMode {
        case .fixedInterval:
            return "Use one overall repeat interval for the whole routine."
        case .fixedIntervalChecklist:
            return "Use one overall repeat interval and complete every checklist item to finish the routine."
        case .derivedFromChecklist:
            return "Use checklist item due dates to decide when the routine is due."
        }
    }

    private var checklistSectionDescription: String {
        switch store.scheduleMode {
        case .fixedIntervalChecklist:
            return "The routine is done when every checklist item is completed."
        case .derivedFromChecklist:
            return "Each item gets its own due date. The routine becomes due when the earliest item is due."
        case .fixedInterval:
            return ""
        }
    }

    private var placeSelectionDescription: String {
        if let selectedPlaceID = store.selectedPlaceID,
           let place = store.availablePlaces.first(where: { $0.id == selectedPlaceID }) {
            return "Show this routine when you are at \(place.name)."
        }
        return "Anywhere means the routine is always visible."
    }

    private var tagComposer: some View {
        HStack(spacing: 10) {
            TextField("health, focus, morning", text: tagDraftBinding)
                .onSubmit {
                    store.send(.addTagTapped)
                }

            Button("Add") {
                store.send(.addTagTapped)
            }
            .disabled(isAddTagDisabled)
        }
    }

    private var stepComposer: some View {
        HStack(spacing: 10) {
            TextField("Wash clothes", text: stepDraftBinding)
                .onSubmit {
                    store.send(.addStepTapped)
                }

            Button("Add") {
                store.send(.addStepTapped)
            }
            .disabled(isAddStepDisabled)
        }
    }

    private var checklistItemComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Bread", text: checklistItemDraftTitleBinding)
                .onSubmit {
                    store.send(.addChecklistItemTapped)
                }

            if store.scheduleMode == .derivedFromChecklist {
                Stepper(value: checklistItemDraftIntervalBinding, in: 1...365) {
                    Text(checklistIntervalLabel(for: store.checklistItemDraftInterval))
                }
            }

            Button("Add Item") {
                store.send(.addChecklistItemTapped)
            }
            .disabled(isAddChecklistItemDisabled)
        }
    }

    @ViewBuilder
    private var editableTagsContent: some View {
        if store.routineTags.isEmpty {
            Text("No tags yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(store.routineTags, id: \.self) { tag in
                    Button {
                        store.send(.removeTag(tag))
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
                    .accessibilityLabel("Remove tag \(tag)")
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var editableStepsContent: some View {
        if store.routineSteps.isEmpty {
            Text("No steps yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(Array(store.routineSteps.enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 10) {
                        Text("\(index + 1).")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .leading)

                        Text(step.title)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 6) {
                            Button {
                                store.send(.moveStepUp(step.id))
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)

                            Button {
                                store.send(.moveStepDown(step.id))
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == store.routineSteps.count - 1)

                            Button(role: .destructive) {
                                store.send(.removeStep(step.id))
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
        if store.routineChecklistItems.isEmpty {
            Text("No checklist items yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(store.routineChecklistItems) { item in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if store.scheduleMode == .derivedFromChecklist {
                                Text(checklistIntervalLabel(for: item.intervalDays))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button(role: .destructive) {
                            store.send(.removeChecklistItem(item.id))
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

    private func stepperLabel(
        frequency: AddRoutineFeature.Frequency,
        frequencyValue: Int
    ) -> String {
        if frequencyValue == 1 {
            switch frequency {
            case .day:
                return "Every day"
            case .week:
                return "Every week"
            case .month:
                return "Every month"
            }
        }

        let unit = frequency.singularLabel
        return "Every \(frequencyValue) \(unit)s"
    }

    private func checklistIntervalLabel(for intervalDays: Int) -> String {
        if intervalDays == 1 {
            return "Runs out in 1 day"
        }
        return "Runs out in \(intervalDays) days"
    }

#if os(macOS)
    private let formLabelWidth: CGFloat = 110

    private var sectionCardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor)
    }

    private var sectionCardStroke: Color {
        Color.gray.opacity(0.18)
    }

    private var macOSContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                macSectionCard(title: "Basic") {
                    VStack(alignment: .leading, spacing: 14) {
                        macFormRow("Name") {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Routine name", text: routineNameBinding)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($isRoutineNameFocused)
                                if let nameValidationMessage {
                                    Text(nameValidationMessage)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                        }

                        macFormRow("Emoji") {
                            HStack(spacing: 12) {
                                Text(store.routineEmoji)
                                    .font(.title2)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.16))
                                    )
                                Text("Selected")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                                Button("Choose Emoji") {
                                    isEmojiPickerPresented = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }

                        macFormRow("Quick Picks") {
                            HStack(spacing: 6) {
                                ForEach(Array(emojiOptions.prefix(8)), id: \.self) { emoji in
                                    Button {
                                        store.send(.routineEmojiChanged(emoji))
                                    } label: {
                                        Text(emoji)
                                            .font(.title3)
                                            .frame(width: 30, height: 30)
                                            .background(
                                                Circle()
                                                    .fill(store.routineEmoji == emoji ? Color.accentColor.opacity(0.18) : Color.clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        macFormRow("Tags") {
                            VStack(alignment: .leading, spacing: 10) {
                                tagComposer
                                editableTagsContent
                                Text("Press return or Add. Separate multiple tags with commas.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        macFormRow("Type") {
                            VStack(alignment: .leading, spacing: 10) {
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
                            }
                        }

                        macFormRow("Place") {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("Place", selection: selectedPlaceBinding) {
                                    Text("Anywhere").tag(Optional<UUID>.none)
                                    ForEach(store.availablePlaces) { place in
                                        Text(place.name).tag(Optional(place.id))
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)

                                Text(placeSelectionDescription)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if store.scheduleMode == .fixedInterval {
                            macFormRow("Steps") {
                                VStack(alignment: .leading, spacing: 10) {
                                    stepComposer
                                    editableStepsContent
                                    Text("Steps run in order. Leave this empty for a one-step routine.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            macFormRow("Checklist") {
                                VStack(alignment: .leading, spacing: 10) {
                                    checklistItemComposer
                                    editableChecklistItemsContent
                                    Text(checklistSectionDescription)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if store.scheduleMode != .derivedFromChecklist {
                    macSectionCard(title: "Schedule") {
                        VStack(alignment: .leading, spacing: 10) {
                            macFormRow("Repeat") {
                                HStack(spacing: 10) {
                                    Text("Every")
                                        .foregroundStyle(.secondary)
                                    Stepper(value: frequencyValueBinding, in: 1...365) {
                                        Text("\(store.frequencyValue)")
                                            .font(.body.monospacedDigit())
                                            .frame(minWidth: 28, alignment: .trailing)
                                    }
                                    .fixedSize()
                                    Picker("Unit", selection: frequencyBinding) {
                                        ForEach(AddRoutineFeature.Frequency.allCases, id: \.self) { frequency in
                                            Text(frequency.rawValue).tag(frequency)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.segmented)
                                    .frame(width: 220)
                                    Spacer(minLength: 0)
                                }
                            }

                            macFormRow("") {
                                Text(stepperLabel(frequency: store.frequency, frequencyValue: store.frequencyValue))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func macSectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
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

    @ViewBuilder
    private func macFormRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(title.isEmpty ? " " : title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: formLabelWidth, alignment: .trailing)
            content()
        }
    }
#endif
}
