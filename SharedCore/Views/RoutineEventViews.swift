import SwiftData
import SwiftUI

struct RoutineEventEditorView: View {
    @Environment(\.calendar) var calendar
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query var tasks: [RoutineTask]
    @Query var goals: [RoutineGoal]
    @Query(sort: \RoutineNote.createdAt, order: .reverse) var notes: [RoutineNote]
    @Query(sort: \RoutineEvent.startedAt, order: .reverse) var events: [RoutineEvent]
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) var isNotesEnabled = false

    let event: RoutineEvent?
    let onCancel: (() -> Void)?
    let onSaved: ((UUID) -> Void)?
    let draftBaseline: RoutineEventDraftSnapshot

    @State var title: String
    @State var notesText: String
    @State var emoji: String
    @State var isAllDay: Bool
    @State var startDate: Date
    @State var endDate: Date
    @State var reminderAt: Date?
    @State var tags: [String]
    @State var tagDraft = ""
    @State var errorText: String?

    init(
        event: RoutineEvent? = nil,
        onCancel: (() -> Void)? = nil,
        onSaved: ((UUID) -> Void)? = nil
    ) {
        self.event = event
        self.onCancel = onCancel
        self.onSaved = onSaved
        let defaultStartDate = Date()
        let defaultEndDate = defaultStartDate.addingTimeInterval(60 * 60)
        let draft = event == nil ? RoutineEventDraftSnapshot.load() : nil
        draftBaseline = RoutineEventDraftSnapshot(
            title: "",
            notesText: "",
            emoji: "",
            isAllDay: true,
            startDate: defaultStartDate,
            endDate: defaultEndDate,
            reminderAt: nil,
            tags: [],
            tagDraft: ""
        )
        _title = State(initialValue: event?.title ?? draft?.title ?? "")
        _notesText = State(initialValue: event?.notes ?? draft?.notesText ?? "")
        _emoji = State(initialValue: event?.emoji ?? draft?.emoji ?? "")
        _isAllDay = State(initialValue: event?.isAllDay ?? draft?.isAllDay ?? true)
        _startDate = State(initialValue: event?.startedAt ?? draft?.startDate ?? defaultStartDate)
        _endDate = State(initialValue: event?.endedAt ?? draft?.endDate ?? defaultEndDate)
        _reminderAt = State(initialValue: event?.reminderAt ?? draft?.reminderAt)
        _tags = State(initialValue: event?.tags ?? draft?.tags ?? [])
        _tagDraft = State(initialValue: draft?.tagDraft ?? "")
    }

    var body: some View {
        editorContent
            .onChange(of: isAllDay) { oldValue, _ in
                let previousEventDate = RoutineEvent.reminderEventDate(
                    startedAt: oldValue ? calendar.startOfDay(for: startDate) : startDate,
                    isAllDay: oldValue,
                    calendar: calendar
                )
                normalizeDates()
                rebaseReminderIfUsingLeadTime(previousEventDate: previousEventDate)
            }
            .onChange(of: currentDraftSnapshot) { _, snapshot in
                guard event == nil else { return }
                snapshot.persist(comparedTo: draftBaseline)
            }
    }

    @ViewBuilder
    var editorContent: some View {
        #if os(macOS)
            macEditorContent
        #else
            NavigationStack {
                formEditorContent
                    .navigationTitle(editorTitle)
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
            }
        #endif
    }

    var formEditorContent: some View {
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

            notificationSection

            if isNotesEnabled {
                Section("Notes") {
                    TextField("Context", text: $notesText, axis: .vertical)
                        .lineLimit(4...8)
                }
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
    }
}

struct RoutineEventDetailView: View {
    let event: RoutineEvent
    @Environment(\.calendar) private var calendar
    @State private var isEditing = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isNotesEnabled = false

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
                        if let reminderText {
                            Text(reminderText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
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

                if isNotesEnabled, let notes = RoutineEvent.cleanedText(event.notes) {
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

    private var reminderText: String? {
        guard let reminderAt = event.reminderAt else { return nil }
        return "Notification \(reminderAt.formatted(date: .abbreviated, time: .shortened))"
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
            let visibleEnd =
                calendar.date(byAdding: .second, value: -1, to: endedAt).map {
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
