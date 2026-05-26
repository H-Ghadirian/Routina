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

    @State private var valence = 0.25
    @State private var arousal = -0.15
    @State private var selectedFamily: EmotionFamily = .calm
    @State private var selectedLabel = EmotionFamily.calm.defaultLabel
    @State private var intensity = 3.0
    @State private var selectedBodyAreas: Set<EmotionBodyArea> = []
    @State private var reflection = ""
    @State private var linkedNoteID: UUID?
    @State private var linkedGoalID: UUID?
    @State private var linkedTaskID: UUID?
    @State private var linkedPlaceID: UUID?
    @State private var linkedSleepSessionID: UUID?

    let onSaved: ((UUID) -> Void)?

    init(onSaved: ((UUID) -> Void)? = nil) {
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            editorContent
                .navigationTitle("Emotion Log")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            save()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }
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
                contextCard
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
                    .fill(selectedFamily.tintColor.opacity(0.16))
                Image(systemName: selectedFamily.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(selectedFamily.tintColor)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(selectedFamily.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)

                Text(selectedLabel.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var moodCard: some View {
        EmotionLogCard(title: "Mood Map", systemImage: "circle.grid.cross") {
            VStack(alignment: .leading, spacing: 14) {
                EmotionMoodMapPicker(
                    valence: $valence,
                    arousal: $arousal,
                    tint: selectedFamily.tintColor
                )
                .frame(height: 250)
                .onChange(of: valence) { _, _ in
                    updateSuggestedFamilyIfNeeded()
                }
                .onChange(of: arousal) { _, _ in
                    updateSuggestedFamilyIfNeeded()
                }

                Text(moodDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detailCard: some View {
        EmotionLogCard(title: "Feeling", systemImage: selectedFamily.systemImage) {
            VStack(alignment: .leading, spacing: 16) {
                chipFlow {
                    ForEach(suggestedFamilies) { family in
                        EmotionChip(
                            title: family.title,
                            systemImage: family.systemImage,
                            tint: family.tintColor,
                            isSelected: family == selectedFamily
                        ) {
                            selectedFamily = family
                            selectedLabel = family.defaultLabel
                        }
                    }
                }

                Divider()

                chipFlow {
                    ForEach(selectedFamily.labels, id: \.self) { label in
                        EmotionChip(
                            title: label.capitalized,
                            tint: selectedFamily.tintColor,
                            isSelected: label == selectedLabel
                        ) {
                            selectedLabel = label
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
                            .foregroundStyle(selectedFamily.tintColor)
                    }

                    Slider(value: $intensity, in: 1...5, step: 1)
                        .tint(selectedFamily.tintColor)
                }
            }
        }
    }

    private var bodyCard: some View {
        EmotionLogCard(title: "Body", systemImage: "figure.mind.and.body") {
            VStack(alignment: .leading, spacing: 14) {
                chipFlow {
                    ForEach(EmotionBodyArea.allCases) { area in
                        EmotionChip(
                            title: area.title,
                            tint: selectedFamily.tintColor,
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
            VStack(alignment: .leading, spacing: 12) {
                contextPicker(
                    title: "Note",
                    selection: $linkedNoteID,
                    items: notes,
                    label: { $0.displayTitle }
                )

                contextPicker(
                    title: "Goal",
                    selection: $linkedGoalID,
                    items: goals,
                    label: { $0.displayTitle }
                )

                contextPicker(
                    title: "Task",
                    selection: $linkedTaskID,
                    items: tasks.sorted { taskTitle($0).localizedCaseInsensitiveCompare(taskTitle($1)) == .orderedAscending },
                    label: taskTitle
                )

                contextPicker(
                    title: "Place",
                    selection: $linkedPlaceID,
                    items: places,
                    label: { $0.displayName }
                )

                contextPicker(
                    title: "Sleep",
                    selection: $linkedSleepSessionID,
                    items: sleepSessions,
                    label: sleepTitle
                )
            }
        }
    }

    private var suggestedFamilies: [EmotionFamily] {
        let suggestions = EmotionFamily.suggestedFamilies(valence: valence, arousal: arousal)
        return suggestions.contains(selectedFamily)
            ? suggestions
            : [selectedFamily] + suggestions
    }

    private var moodDescription: String {
        switch (valence >= 0, arousal >= 0) {
        case (true, true): return "Pleasant, higher energy"
        case (true, false): return "Pleasant, lower energy"
        case (false, true): return "Unpleasant, higher energy"
        case (false, false): return "Unpleasant, lower energy"
        }
    }

    private func updateSuggestedFamilyIfNeeded() {
        let suggestions = EmotionFamily.suggestedFamilies(valence: valence, arousal: arousal)
        guard !suggestions.contains(selectedFamily), let first = suggestions.first else { return }
        selectedFamily = first
        selectedLabel = first.defaultLabel
    }

    private func toggleBodyArea(_ area: EmotionBodyArea) {
        if selectedBodyAreas.contains(area) {
            selectedBodyAreas.remove(area)
        } else {
            selectedBodyAreas.insert(area)
        }
    }

    @ViewBuilder
    private func chipFlow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 118), spacing: 8)],
            alignment: .leading,
            spacing: 8,
            content: content
        )
    }

    private func contextPicker<Item: Identifiable>(
        title: String,
        selection: Binding<UUID?>,
        items: [Item],
        label: @escaping (Item) -> String
    ) -> some View where Item.ID == UUID {
        Picker(title, selection: selection) {
            Text("None").tag(Optional<UUID>.none)
            ForEach(items) { item in
                Text(label(item)).tag(Optional(item.id))
            }
        }
        .pickerStyle(.menu)
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
        let log = EmotionLog(
            family: selectedFamily,
            label: selectedLabel,
            valence: valence,
            arousal: arousal,
            intensity: Int(intensity.rounded()),
            bodyAreas: EmotionBodyArea.allCases.filter { selectedBodyAreas.contains($0) },
            reflection: reflection,
            linkedNoteID: linkedNoteID,
            linkedGoalID: linkedGoalID,
            linkedTaskID: linkedTaskID,
            linkedPlaceID: linkedPlaceID,
            linkedSleepSessionID: linkedSleepSessionID
        )
        modelContext.insert(log)
        do {
            try modelContext.save()
            onSaved?(log.id)
            dismiss()
        } catch {
            modelContext.rollback()
        }
    }
}

struct EmotionLogDetailView: View {
    let emotion: EmotionLog
    @Query private var notes: [RoutineNote]
    @Query private var goals: [RoutineGoal]
    @Query private var tasks: [RoutineTask]
    @Query private var places: [RoutinePlace]
    @Query private var sleepSessions: [SleepSession]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    EmotionLogSymbolView(emotion: emotion)
                        .frame(width: 54, height: 54)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(emotion.displayLabel.capitalized)
                            .font(.title2.weight(.semibold))
                            .lineLimit(1)

                        Text(emotion.family.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
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
                                linkRow("Note", value: note.displayTitle, systemImage: "note.text")
                            }
                            if let goal = linkedGoal {
                                linkRow("Goal", value: goal.displayTitle, systemImage: "target")
                            }
                            if let task = linkedTask {
                                linkRow("Task", value: taskTitle(task), systemImage: "checklist")
                            }
                            if let place = linkedPlace {
                                linkRow("Place", value: place.displayName, systemImage: "mappin.and.ellipse")
                            }
                            if let sleep = linkedSleepSession {
                                linkRow("Sleep", value: sleepTitle(sleep), systemImage: "bed.double.fill")
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

    private func linkRow(_ title: String, value: String, systemImage: String) -> some View {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct EmotionMoodMapPicker: View {
    @Binding var valence: Double
    @Binding var arousal: Double
    let tint: Color

    var body: some View {
        EmotionMoodMapSurface(
            valence: valence,
            arousal: arousal,
            tint: tint,
            isInteractive: true
        ) { point, size in
            valence = EmotionLog.clampedAffectValue(Double(point.x / max(size.width, 1)) * 2 - 1)
            arousal = EmotionLog.clampedAffectValue((1 - Double(point.y / max(size.height, 1))) * 2 - 1)
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
                        .font(.caption.weight(.semibold))
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .routinaGlassPill(tint: isSelected ? tint : .secondary, tintOpacity: isSelected ? 0.22 : 0.08, interactive: true)
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
