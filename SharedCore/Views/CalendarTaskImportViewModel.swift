import SwiftUI

@MainActor
final class CalendarTaskImportViewModel: ObservableObject {
    enum ImportSource: String, CaseIterable, Identifiable {
        case appleCalendar
        case outlook

        var id: Self { self }

        var title: String {
            switch self {
            case .appleCalendar: return "Apple Calendar"
            case .outlook: return "Outlook"
            }
        }

        static func availableSources(isOutlookConfigured: Bool) -> [Self] {
            isOutlookConfigured ? allCases : [.appleCalendar]
        }
    }

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
    @Published var selectedSource: ImportSource = .appleCalendar
    @Published var availableCalendars: [CalendarItem] = []
    @Published var selectedCalendarIDs: Set<String> = []
    @Published var selectedRange: ScanRange = .twoWeeks
    @Published var suggestions: [CalendarTaskSuggestion] = []
    @Published var outlookSuggestions: [CalendarTaskSuggestion] = []
    @Published var outlookAccount: MicrosoftGraphAccount?
    @Published var outlookErrorMessage: String?
    @Published var outlookConfigurationMissing = false
    @Published var isOutlookLoading = false

    private let service = CalendarTaskImportService()
    private let outlookService = MicrosoftGraphCalendarService()
    private var outlookAccessToken: String?

    var availableImportSources: [ImportSource] {
        ImportSource.availableSources(isOutlookConfigured: MicrosoftGraphCalendarService.isConfigured)
    }

    var canRefreshOutlook: Bool {
        outlookAccessToken != nil
    }

    var outlookAccountTitle: String {
        guard let outlookAccount else { return "Outlook connected" }
        if let email = outlookAccount.email, !email.isEmpty {
            return "\(outlookAccount.displayName) • \(email)"
        }
        return outlookAccount.displayName
    }

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

    func signInOutlook(existingTasks: [RoutineTask], calendar: Calendar) async {
        outlookErrorMessage = nil
        outlookConfigurationMissing = false
        isOutlookLoading = true
        defer { isOutlookLoading = false }

        do {
            let result = try await outlookService.signIn()
            outlookAccessToken = result.accessToken
            outlookAccount = result.account
            await refreshOutlookSuggestions(existingTasks: existingTasks, calendar: calendar)
        } catch MicrosoftGraphCalendarError.notConfigured {
            outlookConfigurationMissing = true
        } catch MicrosoftGraphCalendarError.signInCanceled {
            outlookErrorMessage = "Microsoft sign in was canceled."
        } catch {
            outlookErrorMessage = "Could not sign in to Microsoft."
        }
    }

    func refreshOutlookSuggestions(existingTasks: [RoutineTask], calendar: Calendar) async {
        guard let outlookAccessToken else { return }
        outlookErrorMessage = nil
        isOutlookLoading = true
        defer { isOutlookLoading = false }

        let startDate = Date()
        let endDate = calendar.date(byAdding: .day, value: selectedRange.dayCount, to: startDate) ?? startDate
        do {
            outlookSuggestions = try await outlookService.suggestions(
                accessToken: outlookAccessToken,
                from: startDate,
                through: endDate,
                existingTasks: existingTasks,
                calendar: calendar
            )
        } catch {
            outlookSuggestions = []
            outlookErrorMessage = "Could not fetch Outlook events."
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
        if let index = suggestions.firstIndex(where: { $0.id == suggestionID }) {
            suggestions[index].reviewState = .added
        }
        if let index = outlookSuggestions.firstIndex(where: { $0.id == suggestionID }) {
            outlookSuggestions[index].reviewState = .added
        }
    }
}
