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

    private var isSaveDisabled: Bool {
        store.isSaveDisabled
    }

    private var nameValidationMessage: String? {
        store.nameValidationMessage
    }

    private var isAddTagDisabled: Bool {
        RoutineTag.parseDraft(store.tagDraft).isEmpty
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
                    }
                }

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
