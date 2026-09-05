import ComposableArchitecture
import SwiftUI

struct CalendarTaskImportSheet: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CalendarTaskImportViewModel()
    @State private var store = Store(initialState: CalendarTaskImportFeature.State()) {
        CalendarTaskImportFeature()
    }

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
        .onChange(of: store.addedSuggestionIDs) { previousIDs, addedIDs in
            for suggestionID in addedIDs.subtracting(previousIDs) {
                viewModel.markAdded(suggestionID: suggestionID)
                onTasksChanged()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            ProgressView("Checking calendars")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .accessDenied, .accessRestricted:
            loadedContent
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
            sourcePicker
            Divider()
            switch viewModel.selectedSource {
            case .appleCalendar:
                appleCalendarContent
            case .outlook:
                outlookContent
            }
        }
    }

    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.availableImportSources.count > 1 {
                RoutinaGlassSegmentedControl(
                    accessibilityLabel: "Source",
                    options: viewModel.availableImportSources,
                    selection: $viewModel.selectedSource,
                    fillsAvailableWidth: true
                ) { source in
                    Text(source.title)
                }
                .onChange(of: viewModel.selectedSource) { _, source in
                    guard source == .outlook, viewModel.canRefreshOutlook else { return }
                    Task {
                        await viewModel.refreshOutlookSuggestions(existingTasks: existingTasks, calendar: calendar)
                    }
                }
            }

            HStack {
                Text(viewModel.selectedSource.title)
                    .font(.headline)
                Spacer()
                Picker("Range", selection: $viewModel.selectedRange) {
                    ForEach(CalendarTaskImportViewModel.ScanRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.selectedRange) { _, _ in
                    switch viewModel.selectedSource {
                    case .appleCalendar:
                        viewModel.refreshSuggestions(existingTasks: existingTasks, calendar: calendar)
                    case .outlook:
                        guard viewModel.canRefreshOutlook else { return }
                        Task {
                            await viewModel.refreshOutlookSuggestions(existingTasks: existingTasks, calendar: calendar)
                        }
                    }
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private var appleCalendarContent: some View {
        switch viewModel.phase {
        case .accessDenied:
            ContentUnavailableView(
                "Calendar access is off",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("Allow calendar access in Settings to review events before adding tasks.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .accessRestricted:
            ContentUnavailableView(
                "Calendar access is restricted",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("This device does not allow Routina to read calendars.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            VStack(spacing: 0) {
                calendarPicker
                suggestionsList($viewModel.suggestions, emptyDescription: "Choose another calendar or date range.")
            }
        }
    }

    private var calendarPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
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
    private var outlookContent: some View {
        if viewModel.outlookConfigurationMissing {
            ContentUnavailableView(
                "Outlook sign in is not configured",
                systemImage: "person.crop.circle.badge.exclamationmark",
                description: Text(
                    "Add a Microsoft Graph app client ID to RoutinaMicrosoftGraphClientID, then register \(AppEnvironment.deepLinkURLScheme)://auth/microsoft as the redirect URI."
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !viewModel.canRefreshOutlook {
            VStack(spacing: 16) {
                ContentUnavailableView(
                    "Connect Outlook",
                    systemImage: "calendar.badge.plus",
                    description: Text("Sign in to Microsoft to fetch calendar events for one-by-one review.")
                )

                Button {
                    Task {
                        await viewModel.signInOutlook(existingTasks: existingTasks, calendar: calendar)
                    }
                } label: {
                    if viewModel.isOutlookLoading {
                        ProgressView()
                    } else {
                        Text("Sign in with Microsoft")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isOutlookLoading)

                if let message = viewModel.outlookErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.outlookAccountTitle)
                            .font(.subheadline.weight(.semibold))
                        Text("Events are fetched from Outlook and nothing is added automatically.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        Task {
                            await viewModel.refreshOutlookSuggestions(existingTasks: existingTasks, calendar: calendar)
                        }
                    } label: {
                        if viewModel.isOutlookLoading {
                            ProgressView()
                        } else {
                            Label("Fetch", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isOutlookLoading)
                }
                .padding()

                if let message = viewModel.outlookErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                suggestionsList($viewModel.outlookSuggestions, emptyDescription: "Fetch Outlook events or choose another date range.")
            }
        }
    }

    @ViewBuilder
    private func suggestionsList(
        _ suggestions: Binding<[CalendarTaskSuggestion]>,
        emptyDescription: String
    ) -> some View {
        if suggestions.wrappedValue.isEmpty {
            ContentUnavailableView(
                "No events found",
                systemImage: "calendar",
                description: Text(emptyDescription)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    ForEach(suggestions) { $suggestion in
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
        store.send(.addTaskRequested(suggestion))
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
                .disabled(!isEditable)

            DatePicker(
                "Deadline",
                selection: Binding(
                    get: { suggestion.deadline ?? suggestion.eventStartDate },
                    set: { suggestion.deadline = $0 }
                ),
                displayedComponents: suggestion.isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .disabled(!isEditable)

            HStack {
                Button("Skip") {
                    onSkip()
                }
                .disabled(!isEditable)

                Spacer()

                Button("Add") {
                    onAdd()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!CalendarTaskSuggestionRowPresentation.canAdd(suggestion))
            }
        }
        .padding(.vertical, 8)
    }

    private var isEditable: Bool {
        CalendarTaskSuggestionRowPresentation.isEditable(suggestion.reviewState)
    }

    private var formattedEventDate: String {
        CalendarTaskSuggestionRowPresentation.formattedEventDate(for: suggestion)
    }

    @ViewBuilder
    private var statusLabel: some View {
        if let status = CalendarTaskSuggestionRowPresentation.status(for: suggestion.reviewState) {
            Label(status.title, systemImage: status.systemImage)
                .foregroundStyle(status.tint.color)
        } else {
            EmptyView()
        }
    }
}

private extension CalendarTaskSuggestionStatusPresentation.Tint {
    var color: Color {
        switch self {
        case .success:
            return .green
        case .secondary:
            return .secondary
        }
    }
}
