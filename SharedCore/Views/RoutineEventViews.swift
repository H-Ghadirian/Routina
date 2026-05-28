import SwiftData
import SwiftUI

struct RoutineEventEditorView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [RoutineTask]
    @Query private var goals: [RoutineGoal]
    @Query(sort: \RoutineNote.createdAt, order: .reverse) private var notes: [RoutineNote]
    @Query(sort: \RoutineEvent.startedAt, order: .reverse) private var events: [RoutineEvent]

    let event: RoutineEvent?
    let onCancel: (() -> Void)?
    let onSaved: ((UUID) -> Void)?

    @State private var title: String
    @State private var notesText: String
    @State private var emoji: String
    @State private var isAllDay: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var tags: [String]
    @State private var tagDraft = ""
    @State private var errorText: String?

    init(
        event: RoutineEvent? = nil,
        onCancel: (() -> Void)? = nil,
        onSaved: ((UUID) -> Void)? = nil
    ) {
        self.event = event
        self.onCancel = onCancel
        self.onSaved = onSaved
        _title = State(initialValue: event?.title ?? "")
        _notesText = State(initialValue: event?.notes ?? "")
        _emoji = State(initialValue: event?.emoji ?? "")
        _isAllDay = State(initialValue: event?.isAllDay ?? true)
        _startDate = State(initialValue: event?.startedAt ?? Date())
        _endDate = State(initialValue: event?.endedAt ?? Date().addingTimeInterval(60 * 60))
        _tags = State(initialValue: event?.tags ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Title", text: $title)
                    TextField("Emoji", text: $emoji)
                    Toggle("All Day", isOn: $isAllDay)
                }

                Section("When") {
                    if isAllDay {
                        DatePicker("Starts", selection: allDayStartBinding, displayedComponents: [.date])
                        DatePicker("Ends", selection: allDayEndBinding, displayedComponents: [.date])
                    } else {
                        DatePicker("Starts", selection: timedStartBinding)
                        DatePicker("Ends", selection: timedEndBinding)
                    }
                }

                Section("Notes") {
                    TextField("Context", text: $notesText, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section("Tags") {
                    tagsSection
                }

                if let errorText {
                    Section {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(event == nil ? "New Event" : "Edit Event")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .onChange(of: isAllDay) { _, _ in
                normalizeDates()
            }
        }
    }

    private var canSave: Bool {
        RoutineEvent.cleanedText(title) != nil
            && normalizedEndDate > normalizedStartDate
    }

    private var normalizedStartDate: Date {
        if isAllDay {
            return calendar.startOfDay(for: startDate)
        }
        return startDate
    }

    private var normalizedEndDate: Date {
        if isAllDay {
            let endDay = calendar.startOfDay(for: endDate)
            let startDay = calendar.startOfDay(for: startDate)
            let visibleEndDay = max(endDay, startDay)
            return calendar.date(byAdding: .day, value: 1, to: visibleEndDay) ?? visibleEndDay
        }
        return max(endDate, startDate.addingTimeInterval(60))
    }

    private var allDayStartBinding: Binding<Date> {
        Binding(
            get: { startDate },
            set: { newValue in
                startDate = calendar.startOfDay(for: newValue)
                if calendar.startOfDay(for: endDate) < calendar.startOfDay(for: startDate) {
                    endDate = startDate
                }
            }
        )
    }

    private var allDayEndBinding: Binding<Date> {
        Binding(
            get: {
                guard let adjusted = calendar.date(byAdding: .second, value: -1, to: normalizedEndDate) else {
                    return endDate
                }
                return calendar.startOfDay(for: adjusted)
            },
            set: { newValue in
                endDate = max(calendar.startOfDay(for: newValue), calendar.startOfDay(for: startDate))
            }
        )
    }

    private var timedStartBinding: Binding<Date> {
        Binding(
            get: { startDate },
            set: { newValue in
                let oldDuration = max(endDate.timeIntervalSince(startDate), 60 * 15)
                startDate = newValue
                if endDate <= startDate {
                    endDate = startDate.addingTimeInterval(oldDuration)
                }
            }
        )
    }

    private var timedEndBinding: Binding<Date> {
        Binding(
            get: { endDate },
            set: { newValue in
                endDate = max(newValue, startDate.addingTimeInterval(60))
            }
        )
    }

    private var availableTags: [String] {
        RoutineTag.allTags(
            from: tasks.map(\.tags) + goals.map(\.tags) + notes.map(\.tags) + events.map(\.tags)
        )
    }

    private var availableUnselectedTags: [String] {
        availableTags.filter { !RoutineTag.contains($0, in: tags) }
    }

    private var tagAutocompleteSuggestion: String? {
        RoutineTag.autocompleteSuggestion(
            for: tagDraft,
            availableTags: availableTags,
            selectedTags: tags
        )
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack(alignment: .trailing) {
                    TextField("health, travel, work", text: $tagDraft)
                        .onSubmit(addTagDraft)
                        .padding(.trailing, tagAutocompleteSuggestion == nil ? 0 : 88)

                    if let suggestion = tagAutocompleteSuggestion {
                        Button {
                            acceptTagAutocompleteSuggestion()
                        } label: {
                            Text("#\(suggestion)")
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .routinaGlassPill(tint: .secondary, tintOpacity: 0.12, interactive: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Complete tag \(suggestion)")
                    }
                }

                Button {
                    addTagDraft()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .disabled(RoutineTag.parseDraft(tagDraft).isEmpty)
            }

            selectedTagsContent
            existingTagsContent
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var selectedTagsContent: some View {
        if tags.isEmpty {
            Text("No tags selected")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button {
                        tags = RoutineTag.removing(tag, from: tags)
                    } label: {
                        HStack(spacing: 6) {
                            Text("#\(tag)")
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .routinaGlassPill(tint: .accentColor, tintOpacity: 0.14, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityLabel("Remove tag \(tag)")
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var existingTagsContent: some View {
        if !availableUnselectedTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Existing tags")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(availableUnselectedTags, id: \.self) { tag in
                        Button {
                            tags = RoutineTag.appending(tag, to: tags, availableTags: availableTags)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                    .font(.caption)
                                Text("#\(tag)")
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .routinaGlassPill(tint: .secondary, tintOpacity: 0.10, interactive: true)
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .accessibilityLabel("Add tag \(tag)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func normalizeDates() {
        if isAllDay {
            startDate = calendar.startOfDay(for: startDate)
            endDate = max(calendar.startOfDay(for: endDate), startDate)
        } else if endDate <= startDate {
            endDate = startDate.addingTimeInterval(60 * 60)
        }
    }

    private func cancel() {
        if let onCancel {
            onCancel()
        } else {
            dismiss()
        }
    }

    private func save() {
        guard canSave else { return }
        let now = Date()
        let target = event ?? RoutineEvent(createdAt: now, updatedAt: now)
        target.title = RoutineEvent.cleanedText(title)
        target.notes = RoutineEvent.cleanedText(notesText)
        target.emoji = RoutineEvent.cleanedText(emoji)
        target.tags = tags
        target.isAllDay = isAllDay
        target.startedAt = normalizedStartDate
        target.endedAt = normalizedEndDate
        if target.createdAt == nil {
            target.createdAt = now
        }
        target.updatedAt = now

        if event == nil {
            modelContext.insert(target)
        }

        do {
            try modelContext.save()
            onSaved?(target.id)
            dismiss()
        } catch {
            errorText = "Could not save the event."
        }
    }

    private func addTagDraft() {
        guard !RoutineTag.parseDraft(tagDraft).isEmpty else { return }
        tags = RoutineTag.appending(tagDraft, to: tags, availableTags: availableTags)
        tagDraft = ""
    }

    private func acceptTagAutocompleteSuggestion() {
        guard let suggestion = tagAutocompleteSuggestion else { return }
        tags = RoutineTag.appending(suggestion, to: tags, availableTags: availableTags)
        tagDraft = ""
    }
}

struct RoutineEventDetailView: View {
    let event: RoutineEvent
    @Environment(\.calendar) private var calendar
    @State private var isEditing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Text(event.displayEmoji)
                        .font(.system(size: 42))
                        .frame(width: 58, height: 58)
                        .routinaGlassCard(cornerRadius: 14, tint: .teal, tintOpacity: 0.12)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.displayTitle)
                            .font(.title2.weight(.semibold))
                        Text(dateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                if !event.tags.isEmpty {
                    HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(event.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.teal)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .routinaGlassPill(tint: .teal, tintOpacity: 0.12)
                        }
                    }
                }

                if let notes = RoutineEvent.cleanedText(event.notes) {
                    RoutineEventDetailCard(title: "Notes", systemImage: "text.alignleft") {
                        Text(notes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Event")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isEditing = true
                } label: {
                    Label("Edit Event", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            RoutineEventEditorView(event: event)
        }
    }

    private var dateText: String {
        RoutineEventDateFormatting.text(
            startedAt: event.startedAt,
            endedAt: event.endedAt,
            isAllDay: event.isAllDay,
            calendar: calendar
        )
    }
}

private struct RoutineEventDetailCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
                .font(.body)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .routinaGlassPanel(cornerRadius: 12, tint: .secondary, tintOpacity: 0.08)
    }
}

enum RoutineEventDateFormatting {
    static func text(
        startedAt: Date?,
        endedAt: Date?,
        isAllDay: Bool,
        calendar: Calendar
    ) -> String {
        guard let startedAt else { return "No date" }
        guard let endedAt, endedAt > startedAt else {
            return startedAt.formatted(date: .abbreviated, time: isAllDay ? .omitted : .shortened)
        }

        if isAllDay {
            let startDay = calendar.startOfDay(for: startedAt)
            let visibleEnd = calendar.date(byAdding: .second, value: -1, to: endedAt).map {
                calendar.startOfDay(for: $0)
            } ?? startDay
            if calendar.isDate(startDay, inSameDayAs: visibleEnd) {
                return startDay.formatted(date: .abbreviated, time: .omitted)
            }
            return "\(startDay.formatted(date: .abbreviated, time: .omitted)) - \(visibleEnd.formatted(date: .abbreviated, time: .omitted))"
        }

        if calendar.isDate(startedAt, inSameDayAs: endedAt) {
            return "\(startedAt.formatted(date: .abbreviated, time: .shortened)) - \(endedAt.formatted(date: .omitted, time: .shortened))"
        }

        return "\(startedAt.formatted(date: .abbreviated, time: .shortened)) - \(endedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
