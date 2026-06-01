import SwiftData
import SwiftUI

struct EmotionLogEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RoutineNote.createdAt, order: .reverse) private var notes: [RoutineNote]
    @Query(sort: \RoutineGoal.title) private var goals: [RoutineGoal]
    @Query private var tasks: [RoutineTask]
    @Query(sort: \RoutinePlace.name) private var places: [RoutinePlace]
    @Query(sort: \SleepSession.startedAt, order: .reverse) private var sleepSessions: [SleepSession]

    private enum PleasantnessSegment: String, CaseIterable, Identifiable {
        case unpleasant
        case pleasant

        var id: Self { self }

        var title: String {
            switch self {
            case .unpleasant: return "Unpleasant"
            case .pleasant: return "Pleasant"
            }
        }

        var value: Double {
            switch self {
            case .unpleasant: return -0.65
            case .pleasant: return 0.65
            }
        }
    }

    private enum EnergySegment: String, CaseIterable, Identifiable {
        case low
        case high

        var id: Self { self }

        var title: String {
            switch self {
            case .low: return "Low"
            case .high: return "High"
            }
        }

        var value: Double {
            switch self {
            case .low: return -0.65
            case .high: return 0.65
            }
        }
    }

    @State private var valence = 0.25
    @State private var arousal = -0.15
    @State private var selectedFamilies: Set<EmotionFamily> = [.calm]
    @State private var selectedLabels: Set<String> = [EmotionFamily.calm.defaultLabel]
    @State private var intensity = 3.0
    @State private var selectedBodyAreas: Set<EmotionBodyArea> = []
    @State private var reflection = ""
    @State private var linkedNoteID: UUID?
    @State private var linkedGoalID: UUID?
    @State private var linkedTaskID: UUID?
    @State private var linkedPlaceID: UUID?
    @State private var linkedSleepSessionID: UUID?

    let emotion: EmotionLog?
    let onCancel: (() -> Void)?
    let onSaved: ((UUID) -> Void)?

    init(
        emotion: EmotionLog? = nil,
        onCancel: (() -> Void)? = nil,
        onSaved: ((UUID) -> Void)? = nil
    ) {
        self.emotion = emotion
        self.onCancel = onCancel
        self.onSaved = onSaved

        let initialFamilies = emotion?.families ?? [.calm]
        let initialLabels = emotion?.displayLabels ?? [EmotionFamily.calm.defaultLabel]
        _valence = State(initialValue: emotion?.valence ?? 0.25)
        _arousal = State(initialValue: emotion?.arousal ?? -0.15)
        _selectedFamilies = State(initialValue: Set(initialFamilies))
        _selectedLabels = State(initialValue: Set(initialLabels))
        _intensity = State(initialValue: Double(emotion?.clampedIntensity ?? 3))
        _selectedBodyAreas = State(initialValue: Set(emotion?.bodyAreas ?? []))
        _reflection = State(initialValue: emotion?.reflection ?? "")
        _linkedNoteID = State(initialValue: emotion?.linkedNoteID)
        _linkedGoalID = State(initialValue: emotion?.linkedGoalID)
        _linkedTaskID = State(initialValue: emotion?.linkedTaskID)
        _linkedPlaceID = State(initialValue: emotion?.linkedPlaceID)
        _linkedSleepSessionID = State(initialValue: emotion?.linkedSleepSessionID)
    }

    var body: some View {
        NavigationStack {
            editorContent
                .navigationTitle(editorTitle)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            cancel()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(saveButtonTitle) {
                            save()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
                #endif
        }
        #if os(macOS)
        .frame(minWidth: 540, minHeight: 680)
        #endif
    }

    private var editorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                moodCard
                detailCard
                bodyCard
                if shouldShowContextCard {
                    contextCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: 820, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(primarySelectedFamily.tintColor.opacity(0.16))
                Image(systemName: primarySelectedFamily.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(primarySelectedFamily.tintColor)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(selectedFamilyTitle)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)

                Text(selectedLabelTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            #if os(macOS)
            Button("Cancel") {
                cancel()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)

            Button {
                save()
            } label: {
                Label(saveButtonTitle, systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            #endif
        }
    }

    private var editorTitle: String {
        emotion == nil ? "Emotion Log" : "Edit Emotion"
    }

    private var saveButtonTitle: String {
        emotion == nil ? "Save" : "Update"
    }

    private var moodCard: some View {
        EmotionLogCard(title: "Mood", systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 16) {
                pleasantnessPicker
                energyPicker

                Text(moodDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pleasantnessPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            emotionSectionTitle("Pleasantness")

            Picker("Pleasantness", selection: pleasantnessSelection) {
                ForEach(PleasantnessSegment.allCases) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var energyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            emotionSectionTitle("Energy")

            Picker("Energy", selection: energySelection) {
                ForEach(EnergySegment.allCases) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var detailCard: some View {
        EmotionLogCard(title: "Feeling", systemImage: primarySelectedFamily.systemImage) {
            VStack(alignment: .leading, spacing: 16) {
                emotionSectionTitle("Emotion families")

                chipFlow {
                    ForEach(suggestedFamilies) { family in
                        EmotionChip(
                            title: family.title,
                            systemImage: family.systemImage,
                            tint: family.tintColor,
                            isSelected: selectedFamilies.contains(family)
                        ) {
                            toggleFamily(family)
                        }
                    }
                }

                Divider()

                emotionSectionTitle("Specific feelings")

                ForEach(selectedFamiliesInDisplayOrder) { family in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(family.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        chipFlow {
                            ForEach(family.labels, id: \.self) { label in
                                EmotionChip(
                                    title: label.capitalized,
                                    tint: family.tintColor,
                                    isSelected: selectedLabels.contains(label)
                                ) {
                                    toggleSpecificFeeling(label)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Intensity")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Int(intensity.rounded()))/5")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                            .foregroundStyle(primarySelectedFamily.tintColor)
                    }

                    Slider(value: $intensity, in: 1...5, step: 1)
                        .tint(primarySelectedFamily.tintColor)
                }
            }
        }
    }

    private func emotionSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private var bodyCard: some View {
        EmotionLogCard(title: "Body", systemImage: "figure.mind.and.body") {
            VStack(alignment: .leading, spacing: 14) {
                chipFlow {
                    ForEach(EmotionBodyArea.allCases) { area in
                        EmotionChip(
                            title: area.title,
                            tint: primarySelectedFamily.tintColor,
                            isSelected: selectedBodyAreas.contains(area)
                        ) {
                            toggleBodyArea(area)
                        }
                    }
                }

                TextField("Optional note", text: $reflection, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var contextCard: some View {
        EmotionLogCard(title: "Links", systemImage: "link") {
            LazyVGrid(
                columns: contextLinkColumns,
                alignment: .leading,
                spacing: 10
            ) {
                contextLinkMenu(
                    title: "Note",
                    pluralTitle: "notes",
                    systemImage: "note.text",
                    selection: $linkedNoteID,
                    items: notes,
                    label: { $0.displayTitle }
                )

                contextLinkMenu(
                    title: "Goal",
                    pluralTitle: "goals",
                    systemImage: "target",
                    selection: $linkedGoalID,
                    items: goals,
                    label: { $0.displayTitle }
                )

                contextLinkMenu(
                    title: "Task",
                    pluralTitle: "tasks",
                    systemImage: "checklist",
                    selection: $linkedTaskID,
                    items: tasks.sorted { taskTitle($0).localizedCaseInsensitiveCompare(taskTitle($1)) == .orderedAscending },
                    label: taskTitle
                )

                contextLinkMenu(
                    title: "Place",
                    pluralTitle: "places",
                    systemImage: "mappin.and.ellipse",
                    selection: $linkedPlaceID,
                    items: places,
                    label: { $0.displayName }
                )

                contextLinkMenu(
                    title: "Sleep",
                    pluralTitle: "sleep sessions",
                    systemImage: "bed.double.fill",
                    selection: $linkedSleepSessionID,
                    items: sleepSessions,
                    label: sleepTitle
                )
            }
        }
    }

    private var contextLinkColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 220), spacing: 10)]
    }

    private var shouldShowContextCard: Bool {
        !notes.isEmpty
            || !goals.isEmpty
            || !tasks.isEmpty
            || !places.isEmpty
            || !sleepSessions.isEmpty
            || linkedNoteID != nil
            || linkedGoalID != nil
            || linkedTaskID != nil
            || linkedPlaceID != nil
            || linkedSleepSessionID != nil
    }

    private var suggestedFamilies: [EmotionFamily] {
        let suggestions = EmotionFamily.suggestedFamilies(valence: valence, arousal: arousal)
        let selectedOutsideSuggestions = EmotionFamily.allCases.filter {
            selectedFamilies.contains($0) && !suggestions.contains($0)
        }
        return suggestions + selectedOutsideSuggestions
    }

    private var selectedFamiliesInDisplayOrder: [EmotionFamily] {
        let orderedFamilies = suggestedFamilies + EmotionFamily.allCases
        return orderedFamilies.reduce(into: [EmotionFamily]()) { result, family in
            guard selectedFamilies.contains(family),
                  !result.contains(family)
            else { return }
            result.append(family)
        }
    }

    private var selectedLabelsInDisplayOrder: [String] {
        let orderedLabels = selectedFamiliesInDisplayOrder.flatMap(\.labels)
        let selectedKnownLabels = orderedLabels.reduce(into: [String]()) { result, label in
            guard selectedLabels.contains(label),
                  !result.contains(label)
            else { return }
            result.append(label)
        }
        let customLabels = selectedLabels
            .filter { !orderedLabels.contains($0) }
            .sorted()
        return selectedKnownLabels + customLabels
    }

    private var primarySelectedFamily: EmotionFamily {
        selectedFamiliesInDisplayOrder.first ?? .calm
    }

    private var selectedFamilyTitle: String {
        let families = selectedFamiliesInDisplayOrder
        guard families.count != 1 else { return families[0].title }
        return "\(families.count) families"
    }

    private var selectedLabelTitle: String {
        let labels = selectedLabelsInDisplayOrder.map { $0.capitalized }
        return labels.isEmpty ? "Select feelings" : labels.joined(separator: ", ")
    }

    private var pleasantnessSelection: Binding<PleasantnessSegment> {
        Binding(
            get: { valence >= 0 ? .pleasant : .unpleasant },
            set: { segment in
                valence = segment.value
                updateSuggestedFamilyIfNeeded()
            }
        )
    }

    private var energySelection: Binding<EnergySegment> {
        Binding(
            get: { arousal >= 0 ? .high : .low },
            set: { segment in
                arousal = segment.value
                updateSuggestedFamilyIfNeeded()
            }
        )
    }

    private var moodDescription: String {
        switch (valence >= 0, arousal >= 0) {
        case (true, true): return "Pleasant, high energy"
        case (true, false): return "Pleasant, low energy"
        case (false, true): return "Unpleasant, high energy"
        case (false, false): return "Unpleasant, low energy"
        }
    }

    private func updateSuggestedFamilyIfNeeded() {
        let suggestions = EmotionFamily.suggestedFamilies(valence: valence, arousal: arousal)
        let retainedFamilies = selectedFamilies.filter { suggestions.contains($0) }
        if retainedFamilies.isEmpty, let first = suggestions.first {
            selectedFamilies = [first]
        } else {
            selectedFamilies = retainedFamilies
        }
        reconcileSelectedLabels()
    }

    private func toggleFamily(_ family: EmotionFamily) {
        if selectedFamilies.contains(family) {
            guard selectedFamilies.count > 1 else { return }
            selectedFamilies.remove(family)
        } else {
            selectedFamilies.insert(family)
            selectedLabels.insert(family.defaultLabel)
        }
        reconcileSelectedLabels()
    }

    private func toggleSpecificFeeling(_ label: String) {
        if selectedLabels.contains(label) {
            guard selectedLabels.count > 1 else { return }
            selectedLabels.remove(label)
        } else {
            selectedLabels.insert(label)
        }
    }

    private func reconcileSelectedLabels() {
        let availableLabels = Set(selectedFamilies.flatMap(\.labels))
        selectedLabels = selectedLabels.filter { availableLabels.contains($0) }
        if selectedLabels.isEmpty, let firstFamily = selectedFamiliesInDisplayOrder.first {
            selectedLabels = [firstFamily.defaultLabel]
        }
    }

    private func toggleBodyArea(_ area: EmotionBodyArea) {
        if selectedBodyAreas.contains(area) {
            selectedBodyAreas.remove(area)
        } else {
            selectedBodyAreas.insert(area)
        }
    }

    private func cancel() {
        if let onCancel {
            onCancel()
        } else {
            dismiss()
        }
    }

    @ViewBuilder
    private func chipFlow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 132), spacing: 10)],
            alignment: .leading,
            spacing: 10,
            content: content
        )
    }

    @ViewBuilder
    private func contextLinkMenu<Item: Identifiable>(
        title: String,
        pluralTitle: String,
        systemImage: String,
        selection: Binding<UUID?>,
        items: [Item],
        label: @escaping (Item) -> String
    ) -> some View where Item.ID == UUID {
        let selectedTitle = selectedContextTitle(
            title: title,
            pluralTitle: pluralTitle,
            selection: selection.wrappedValue,
            items: items,
            label: label
        )
        let isEnabled = !items.isEmpty || selection.wrappedValue != nil

        if isEnabled {
            Menu {
                if selection.wrappedValue != nil {
                    Button {
                        selection.wrappedValue = nil
                    } label: {
                        Label("Remove \(title.lowercased()) link", systemImage: "xmark.circle")
                    }

                    if !items.isEmpty {
                        Divider()
                    }
                }

                ForEach(items) { item in
                    Button {
                        selection.wrappedValue = item.id
                    } label: {
                        if selection.wrappedValue == item.id {
                            Label(label(item), systemImage: "checkmark")
                        } else {
                            Text(label(item))
                        }
                    }
                }
            } label: {
                contextLinkLabel(
                    title: title,
                    selectedTitle: selectedTitle,
                    systemImage: systemImage,
                    isSelected: selection.wrappedValue != nil,
                    isEnabled: true
                )
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .accessibilityLabel("Link \(title.lowercased())")
        } else {
            contextLinkLabel(
                title: title,
                selectedTitle: selectedTitle,
                systemImage: systemImage,
                isSelected: false,
                isEnabled: false
            )
            .accessibilityLabel("No \(pluralTitle) available")
        }
    }

    private func selectedContextTitle<Item: Identifiable>(
        title: String,
        pluralTitle: String,
        selection: UUID?,
        items: [Item],
        label: (Item) -> String
    ) -> String where Item.ID == UUID {
        guard let selection else {
            if items.isEmpty {
                return "No \(pluralTitle)"
            }
            return "Choose \(title.lowercased())"
        }
        guard let selectedItem = items.first(where: { $0.id == selection }) else {
            return "Missing \(title.lowercased())"
        }
        return label(selectedItem)
    }

    private func contextLinkLabel(
        title: String,
        selectedTitle: String,
        systemImage: String,
        isSelected: Bool,
        isEnabled: Bool
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(primarySelectedFamily.tintColor.opacity(isEnabled ? 0.14 : 0.06))
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isEnabled ? primarySelectedFamily.tintColor : .secondary)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(selectedTitle)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 8)

            Image(systemName: isEnabled ? "chevron.up.chevron.down" : "minus.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isEnabled ? primarySelectedFamily.tintColor : Color.secondary.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassCard(
            cornerRadius: 12,
            tint: isSelected ? primarySelectedFamily.tintColor : .secondary,
            tintOpacity: isSelected ? 0.16 : 0.07,
            interactive: isEnabled
        )
        .contentShape(Rectangle())
    }

    private func taskTitle(_ task: RoutineTask) -> String {
        RoutineTask.trimmedName(task.name) ?? "Untitled task"
    }

    private func sleepTitle(_ session: SleepSession) -> String {
        guard let startedAt = session.startedAt else { return "Sleep" }
        if let endedAt = session.endedAt {
            return "\(startedAt.formatted(date: .abbreviated, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
        }
        return "Sleep since \(startedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private func save() {
        let bodyAreas = EmotionBodyArea.allCases.filter { selectedBodyAreas.contains($0) }
        let savedID: UUID
        if let emotion {
            emotion.update(
                families: selectedFamiliesInDisplayOrder,
                labels: selectedLabelsInDisplayOrder,
                valence: valence,
                arousal: arousal,
                intensity: Int(intensity.rounded()),
                bodyAreas: bodyAreas,
                reflection: reflection,
                linkedNoteID: linkedNoteID,
                linkedGoalID: linkedGoalID,
                linkedTaskID: linkedTaskID,
                linkedPlaceID: linkedPlaceID,
                linkedSleepSessionID: linkedSleepSessionID
            )
            savedID = emotion.id
        } else {
            let log = EmotionLog(
                families: selectedFamiliesInDisplayOrder,
                labels: selectedLabelsInDisplayOrder,
                valence: valence,
                arousal: arousal,
                intensity: Int(intensity.rounded()),
                bodyAreas: bodyAreas,
                reflection: reflection,
                linkedNoteID: linkedNoteID,
                linkedGoalID: linkedGoalID,
                linkedTaskID: linkedTaskID,
                linkedPlaceID: linkedPlaceID,
                linkedSleepSessionID: linkedSleepSessionID
            )
            modelContext.insert(log)
            savedID = log.id
        }

        do {
            try modelContext.save()
            if let onSaved {
                onSaved(savedID)
            } else {
                dismiss()
            }
        } catch {
            modelContext.rollback()
        }
    }
}

struct EmotionLogDetailView: View {
    let emotion: EmotionLog
    @State private var isEditing = false
    @Query private var notes: [RoutineNote]
    @Query private var goals: [RoutineGoal]
    @Query private var tasks: [RoutineTask]
    @Query private var places: [RoutinePlace]
    @Query private var sleepSessions: [SleepSession]

    var body: some View {
        Group {
            if isEditing {
                EmotionLogEditorView(
                    emotion: emotion,
                    onCancel: { isEditing = false },
                    onSaved: { _ in isEditing = false }
                )
                .id(emotion.id)
            } else {
                detailContent
            }
        }
        .onChange(of: emotion.id) { _, _ in
            isEditing = false
        }
    }

    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    EmotionLogSymbolView(emotion: emotion)
                        .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(emotion.displayLabel.capitalized)
                            .font(.title2.weight(.semibold))
                            .lineLimit(2)

                        Text(emotion.familiesDisplayTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Button {
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                }

                EmotionLogCard(title: "Mood", systemImage: "circle.grid.cross") {
                    VStack(alignment: .leading, spacing: 14) {
                        EmotionMoodMapPreview(
                            valence: emotion.valence,
                            arousal: emotion.arousal,
                            tint: emotion.family.tintColor
                        )
                        .frame(height: 210)

                        HStack {
                            Label("Intensity \(emotion.clampedIntensity)/5", systemImage: "gauge.with.dots.needle.67percent")
                            Spacer()
                            Text((emotion.createdAt ?? Date()).formatted(date: .abbreviated, time: .shortened))
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                if !emotion.bodyAreas.isEmpty || EmotionLog.cleanedText(emotion.reflection) != nil {
                    EmotionLogCard(title: "Body", systemImage: "figure.mind.and.body") {
                        VStack(alignment: .leading, spacing: 12) {
                            if !emotion.bodyAreas.isEmpty {
                                chipFlow {
                                    ForEach(emotion.bodyAreas) { area in
                                        Text(area.title)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .routinaGlassPill(tint: emotion.family.tintColor, tintOpacity: 0.14)
                                    }
                                }
                            }

                            if let reflection = EmotionLog.cleanedText(emotion.reflection) {
                                Text(reflection)
                                    .font(.body)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }

                if emotion.hasContextLinks {
                    EmotionLogCard(title: "Links", systemImage: "link") {
                        VStack(alignment: .leading, spacing: 10) {
                            if let note = linkedNote {
                                linkedEntityRow(
                                    "Note",
                                    value: note.displayTitle,
                                    systemImage: "note.text",
                                    deepLink: .note(note.id)
                                )
                            }
                            if let goal = linkedGoal {
                                linkedEntityRow(
                                    "Goal",
                                    value: goal.displayTitle,
                                    systemImage: "target",
                                    deepLink: .goal(goal.id)
                                )
                            }
                            if let task = linkedTask {
                                linkedEntityRow(
                                    "Task",
                                    value: taskTitle(task),
                                    systemImage: "checklist",
                                    deepLink: .task(task.id)
                                )
                            }
                            if let place = linkedPlace {
                                contextRow("Place", value: place.displayName, systemImage: "mappin.and.ellipse")
                            }
                            if let sleep = linkedSleepSession {
                                contextRow("Sleep", value: sleepTitle(sleep), systemImage: "bed.double.fill")
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 820, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("Emotion")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var linkedNote: RoutineNote? {
        emotion.linkedNoteID.flatMap { id in notes.first { $0.id == id } }
    }

    private var linkedGoal: RoutineGoal? {
        emotion.linkedGoalID.flatMap { id in goals.first { $0.id == id } }
    }

    private var linkedTask: RoutineTask? {
        emotion.linkedTaskID.flatMap { id in tasks.first { $0.id == id } }
    }

    private var linkedPlace: RoutinePlace? {
        emotion.linkedPlaceID.flatMap { id in places.first { $0.id == id } }
    }

    private var linkedSleepSession: SleepSession? {
        emotion.linkedSleepSessionID.flatMap { id in sleepSessions.first { $0.id == id } }
    }

    @ViewBuilder
    private func chipFlow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 112), spacing: 8)],
            alignment: .leading,
            spacing: 8,
            content: content
        )
    }

    private func linkedEntityRow(
        _ title: String,
        value: String,
        systemImage: String,
        deepLink: RoutinaDeepLink
    ) -> some View {
        Button {
            RoutinaDeepLinkDispatcher.open(deepLink)
        } label: {
            contextRow(title, value: value, systemImage: systemImage, showsChevron: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open linked \(title.lowercased())")
    }

    private func contextRow(
        _ title: String,
        value: String,
        systemImage: String,
        showsChevron: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(emotion.family.tintColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func taskTitle(_ task: RoutineTask) -> String {
        RoutineTask.trimmedName(task.name) ?? "Untitled task"
    }

    private func sleepTitle(_ session: SleepSession) -> String {
        guard let startedAt = session.startedAt else { return "Sleep" }
        if let endedAt = session.endedAt {
            return "\(startedAt.formatted(date: .abbreviated, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
        }
        return "Sleep since \(startedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

struct EmotionLogSymbolView: View {
    let emotion: EmotionLog

    var body: some View {
        ZStack {
            Circle()
                .fill(emotion.family.tintColor.opacity(0.16))
            Image(systemName: emotion.family.systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(emotion.family.tintColor)
        }
    }
}

private struct EmotionMoodMapPreview: View {
    let valence: Double
    let arousal: Double
    let tint: Color

    var body: some View {
        EmotionMoodMapSurface(
            valence: valence,
            arousal: arousal,
            tint: tint,
            isInteractive: false,
            onPointChanged: nil
        )
    }
}

private struct EmotionMoodMapSurface: View {
    let valence: Double
    let arousal: Double
    let tint: Color
    let isInteractive: Bool
    let onPointChanged: ((CGPoint, CGSize) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let marker = CGPoint(
                x: CGFloat((EmotionLog.clampedAffectValue(valence) + 1) / 2) * size.width,
                y: CGFloat(1 - ((EmotionLog.clampedAffectValue(arousal) + 1) / 2)) * size.height
            )

            ZStack {
                quadrantGrid

                Path { path in
                    path.move(to: CGPoint(x: size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                    path.move(to: CGPoint(x: 0, y: size.height / 2))
                    path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                }
                .stroke(.primary.opacity(0.12), lineWidth: 1)

                mapLabels

                Circle()
                    .fill(tint)
                    .frame(width: 22, height: 22)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.85), lineWidth: 3)
                    }
                    .shadow(color: tint.opacity(0.35), radius: 10, y: 4)
                    .position(marker)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isInteractive else { return }
                        let point = CGPoint(
                            x: min(max(value.location.x, 0), size.width),
                            y: min(max(value.location.y, 0), size.height)
                        )
                        onPointChanged?(point, size)
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mood map")
        }
    }

    private var quadrantGrid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle().fill(Color.red.opacity(0.14))
                Rectangle().fill(Color.yellow.opacity(0.20))
            }
            HStack(spacing: 0) {
                Rectangle().fill(Color.blue.opacity(0.16))
                Rectangle().fill(Color.green.opacity(0.16))
            }
        }
    }

    private var mapLabels: some View {
        VStack {
            Text("High energy")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer()

            HStack {
                Text("Unpleasant")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                    .padding(.leading, -12)

                Spacer()

                Text("Pleasant")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(90))
                    .fixedSize()
                    .padding(.trailing, -4)
            }

            Spacer()

            Text("Low energy")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 8)
    }
}

private struct EmotionChip: View {
    let title: String
    var systemImage: String?
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        tint: Color,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 24)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .routinaGlassPill(tint: isSelected ? tint : .secondary, tintOpacity: isSelected ? 0.22 : 0.08, interactive: true)
            .contentShape(Capsule(style: .continuous))
            .foregroundStyle(isSelected ? tint : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

private struct EmotionLogCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassCard(cornerRadius: 14, tint: .secondary, tintOpacity: 0.07)
    }
}

extension EmotionFamily {
    var tintColor: Color {
        switch self {
        case .joy: return .yellow
        case .calm: return .green
        case .sadness: return .blue
        case .anger: return .red
        case .fear: return .orange
        case .shameGuilt: return .purple
        case .disgust: return .mint
        case .surpriseCuriosity: return .cyan
        }
    }
}
