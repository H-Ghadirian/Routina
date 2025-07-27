import EventKit
import SwiftData
import SwiftUI

struct CalendarTaskImportSheet: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = CalendarTaskImportViewModel()

    let existingTasks: [RoutineTask]
    let onTasksChanged: () -> Void

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Calendar Tasks")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                .task {
                    await viewModel.load(existingTasks: existingTasks, calendar: calendar)
                }
        }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 560)
        #endif
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            ProgressView("Checking calendars")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .accessDenied:
            ContentUnavailableView(
                "Calendar access is off",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("Allow calendar access in Settings to review events before adding tasks.")
            )
        case .accessRestricted:
            ContentUnavailableView(
                "Calendar access is restricted",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("This device does not allow Routina to read calendars.")
            )
        case .loaded:
            loadedContent
        case .failed:
            ContentUnavailableView(
                "Could not load events",
                systemImage: "exclamationmark.triangle",
                description: Text("Try again after checking calendar permissions.")
            )
        }
    }

    private var loadedContent: some View {
        VStack(spacing: 0) {
            calendarPicker
            Divider()
            suggestionsList
        }
    }

    private var calendarPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Calendars")
                    .font(.headline)
                Spacer()
                Picker("Range", selection: $viewModel.selectedRange) {
                    ForEach(CalendarTaskImportViewModel.ScanRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.selectedRange) { _, _ in
                    viewModel.refreshSuggestions(existingTasks: existingTasks, calendar: calendar)
                }
            }

            if viewModel.availableCalendars.isEmpty {
                Text("No calendars are available.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.availableCalendars) { item in
                            Toggle(isOn: viewModel.calendarSelectionBinding(for: item.id)) {
                                Text(item.title)
                                    .lineLimit(1)
                            }
                            .toggleStyle(.button)
                            .onChange(of: viewModel.selectedCalendarIDs) { _, _ in
                                viewModel.refreshSuggestions(existingTasks: existingTasks, calendar: calendar)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private var suggestionsList: some View {
        if viewModel.suggestions.isEmpty {
            ContentUnavailableView(
                "No events found",
                systemImage: "calendar",
                description: Text("Choose another calendar or date range.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    ForEach($viewModel.suggestions) { $suggestion in
                        CalendarTaskSuggestionRow(
                            suggestion: $suggestion,
                            onAdd: { addTask(from: suggestion) },
                            onSkip: { suggestion.reviewState = .skipped }
                        )
                    }
                } header: {
                    Text("Review one by one")
                } footer: {
                    Text("Nothing is added until you confirm an individual suggestion.")
                }
            }
        }
    }

    private func addTask(from suggestion: CalendarTaskSuggestion) {
        guard suggestion.reviewState == .pending,
              let trimmedTitle = RoutineTask.trimmedName(suggestion.taskTitle) else {
            return
        }

        let task = RoutineTask(
            name: trimmedTitle,
            emoji: "calendar.badge.plus",
            notes: CalendarTaskImportSupport.notes(for: suggestion),
            deadline: suggestion.deadline,
            priority: .none,
            importance: .level2,
            urgency: .level2,
            tags: ["Calendar"],
            scheduleMode: .oneOff,
            interval: 1,
            recurrenceRule: .interval(days: 1),
            todoStateRawValue: TodoState.ready.rawValue
        )
        modelContext.insert(task)
        do {
            try modelContext.save()
            viewModel.markAdded(suggestionID: suggestion.id)
            NotificationCenter.default.postRoutineDidUpdate()
            onTasksChanged()
        } catch {
            modelContext.delete(task)
        }
    }
}

private struct CalendarTaskSuggestionRow: View {
    @Binding var suggestion: CalendarTaskSuggestion
    let onAdd: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.eventTitle)
                        .font(.headline)
                    Text("\(suggestion.calendarTitle) • \(formattedEventDate)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusLabel
            }

            TextField("Task title", text: $suggestion.taskTitle)
                .textFieldStyle(.roundedBorder)
                .disabled(suggestion.reviewState != .pending)

            DatePicker(
                "Deadline",
                selection: Binding(
                    get: { suggestion.deadline ?? suggestion.eventStartDate },
                    set: { suggestion.deadline = $0 }
                ),
                displayedComponents: suggestion.isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .disabled(suggestion.reviewState != .pending)

            HStack {
                Button("Skip") {
                    onSkip()
                }
                .disabled(suggestion.reviewState != .pending)

                Spacer()

                Button("Add") {
                    onAdd()
                }
                .buttonStyle(.borderedProminent)
                .disabled(suggestion.reviewState != .pending || RoutineTask.trimmedName(suggestion.taskTitle) == nil)
            }
        }
        .padding(.vertical, 8)
    }

    private var formattedEventDate: String {
        if suggestion.isAllDay {
            return suggestion.eventStartDate.formatted(date: .abbreviated, time: .omitted)
        }
        return suggestion.eventStartDate.formatted(date: .abbreviated, time: .shortened)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch suggestion.reviewState {
        case .pending:
            EmptyView()
        case .added:
            Label("Added", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .skipped:
            Label("Skipped", systemImage: "minus.circle")
                .foregroundStyle(.secondary)
        case .duplicate:
            Label("Already added", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
final class CalendarTaskImportViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case accessDenied
        case accessRestricted
        case failed
    }

    enum ScanRange: String, CaseIterable, Identifiable {
        case week
        case twoWeeks
        case month

        var id: Self { self }

        var title: String {
            switch self {
            case .week: return "7 days"
            case .twoWeeks: return "14 days"
            case .month: return "30 days"
            }
        }

        var dayCount: Int {
            switch self {
            case .week: return 7
            case .twoWeeks: return 14
            case .month: return 30
            }
        }
    }

    struct CalendarItem: Identifiable, Equatable {
        let id: String
        let title: String
    }

    @Published var phase: Phase = .idle
    @Published var availableCalendars: [CalendarItem] = []
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var selectedRange: ScanRange = .twoWeeks
    @Published var suggestions: [CalendarTaskSuggestion] = []

    private let service = CalendarTaskImportService()

    func load(existingTasks: [RoutineTask], calendar: Calendar) async {
        guard phase == .idle else { return }
        phase = .loading
        do {
            try await service.requestAccessIfNeeded()
            let calendars = service.calendars()
            availableCalendars = calendars.map {
                CalendarItem(id: $0.calendarIdentifier, title: $0.title)
            }
            selectedCalendarIDs = Set(availableCalendars.map(\.id))
            refreshSuggestions(existingTasks: existingTasks, calendar: calendar)
            phase = .loaded
        } catch CalendarTaskImportError.accessDenied {
            phase = .accessDenied
        } catch CalendarTaskImportError.accessRestricted {
            phase = .accessRestricted
        } catch {
            phase = .failed
        }
    }

    func refreshSuggestions(existingTasks: [RoutineTask], calendar: Calendar) {
        guard phase == .loaded || phase == .loading else { return }
        let startDate = Date()
        let endDate = calendar.date(byAdding: .day, value: selectedRange.dayCount, to: startDate) ?? startDate
        do {
            suggestions = try service.suggestions(
                from: startDate,
                through: endDate,
                calendarIdentifiers: selectedCalendarIDs,
                existingTasks: existingTasks,
                calendar: calendar
            )
        } catch {
            suggestions = []
            phase = .failed
        }
    }

    func calendarSelectionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { self.selectedCalendarIDs.contains(id) },
            set: { isSelected in
                if isSelected {
                    self.selectedCalendarIDs.insert(id)
                } else {
                    self.selectedCalendarIDs.remove(id)
                }
            }
        )
    }

    func markAdded(suggestionID: String) {
        guard let index = suggestions.firstIndex(where: { $0.id == suggestionID }) else { return }
        suggestions[index].reviewState = .added
    }
}
