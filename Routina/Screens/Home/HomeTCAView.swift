import Combine
import ComposableArchitecture
import CoreData
import MapKit
import SwiftData
import SwiftUI

struct HomeTCAView: View {
    enum RoutineListFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case due = "Due"
        case todos = "Todos"
        case doneToday = "Done Today"

        var id: String { rawValue }
    }

    enum IOSTaskListMode: String, CaseIterable, Identifiable {
        case routines = "Routines"
        case todos = "Todos"

        var id: Self { self }

        var systemImage: String {
            switch self {
            case .routines:
                return "repeat"
            case .todos:
                return "checklist"
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .routines:
                return "Show routines"
            case .todos:
                return "Show todos"
            }
        }
    }

    struct RoutineListSection: Identifiable {
        let title: String
        var tasks: [HomeFeature.RoutineDisplay]

        var id: String { title }
    }

    let store: StoreOf<HomeFeature>
#if os(macOS)
    let settingsStore: StoreOf<SettingsFeature>
#endif
    let externalSearchText: Binding<String>?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) var calendar
    @Query(sort: \RoutineLog.timestamp, order: .reverse) var timelineLogs: [RoutineLog]
    @AppStorage(
        UserDefaultStringValueKey.appSettingRoutineListSectioningMode.rawValue,
        store: SharedDefaults.app
    ) private var routineListSectioningModeRawValue: String = RoutineListSectioningMode.defaultValue.rawValue
    @State private var localSearchText = ""
    @State var selectedFilter: RoutineListFilter = .all
    @State var iosTaskListMode: IOSTaskListMode = .routines
    @State var selectedTag: String?
    @State var excludedTags: Set<String> = []
    @State var selectedManualPlaceFilterID: UUID?
    @State var isFilterSheetPresented = false
    @State var isCompactHeaderHidden = false
    @State private var isRefreshScheduled = false
    @State var selectedTimelineRange: TimelineRange = .all
    @State var selectedTimelineFilterType: TimelineFilterType = .all
    @State var selectedTimelineTag: String?
#if os(macOS)
    @State var macSidebarSelection: MacSidebarSelection?
    @State var macSidebarMode: MacSidebarMode = .routines
    @State var macTaskListMode: MacTaskListMode = .routines
    @State var selectedSettingsSection: SettingsMacSection? = .notifications
    @State var addEditFormCoordinator = AddEditFormCoordinator()
    @State var statsSelectedRange: DoneChartRange = .week
    @State var statsSelectedTag: String? = nil
#endif

    init(
        store: StoreOf<HomeFeature>,
        searchText: Binding<String>? = nil
    ) {
        self.store = store
#if os(macOS)
        self.settingsStore = Store(initialState: SettingsFeature.State()) {
            SettingsFeature()
        }
#endif
        self.externalSearchText = searchText
    }

    var body: some View {
        WithPerceptionTracking {
            homeContent
        }
    }

    private var homeContent: some View {
        applyPlatformHomeObservers(
            to: applyAddRoutinePresentation(
                to: applyPlatformDeleteConfirmation(
                    to: applyPlatformRefresh(
                        to: applyPlatformSearchExperience(
                            to: platformNavigationContent,
                            searchText: searchTextBinding
                        )
                    )
                )
            )
        )
            .sheet(isPresented: $isFilterSheetPresented) {
                homeFiltersSheet
            }
            .onAppear {
                requestRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .routineDidUpdate)
                    .receive(on: RunLoop.main)
            ) { _ in
                requestRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                requestRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                requestRefresh()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: PlatformSupport.didBecomeActiveNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                requestRefresh()
            }
            .onChange(of: store.routineDisplays) { _, displays in
                validateSelectedTag(
                    activeDisplays: displays,
                    awayDisplays: store.awayRoutineDisplays,
                    archivedDisplays: store.archivedRoutineDisplays
                )
            }
            .onChange(of: store.awayRoutineDisplays) { _, displays in
                validateSelectedTag(
                    activeDisplays: store.routineDisplays,
                    awayDisplays: displays,
                    archivedDisplays: store.archivedRoutineDisplays
                )
            }
            .onChange(of: store.archivedRoutineDisplays) { _, displays in
                validateSelectedTag(
                    activeDisplays: store.routineDisplays,
                    awayDisplays: store.awayRoutineDisplays,
                    archivedDisplays: displays
                )
            }
            .onChange(of: store.routinePlaces) { _, places in
                guard let selectedManualPlaceFilterID else { return }
                let placeStillExists = places.contains { place in
                    place.id == selectedManualPlaceFilterID
                }
                if !placeStillExists {
                    self.selectedManualPlaceFilterID = nil
                }
            }
    }

    @ViewBuilder
    var detailContent: some View {
        if let detailStore = self.store.scope(
            state: \.routineDetailState,
            action: \.routineDetail
        ) {
            RoutineDetailTCAView(store: detailStore)
        } else {
            ContentUnavailableView(
                "Select a task",
                systemImage: "checklist.checked",
                description: Text("Choose a routine or to-do from the sidebar to see its schedule, logs, and actions.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    var addRoutineSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isAddRoutineSheetPresented },
            set: { store.send(.setAddRoutineSheet($0)) }
        )
    }

    var searchTextBinding: Binding<String> {
        if let externalSearchText {
            externalSearchText
        } else {
            $localSearchText
        }
    }

    private var routineListSectioningMode: RoutineListSectioningMode {
        RoutineListSectioningMode(rawValue: routineListSectioningModeRawValue) ?? .defaultValue
    }

    var selectedTaskBinding: Binding<UUID?> {
        Binding(
            get: { store.selectedTaskID },
            set: { store.send(.setSelectedTask($0)) }
        )
    }

    @ViewBuilder
    var addRoutineSheetContent: some View {
        if let addRoutineStore = self.store.scope(
            state: \.addRoutineState,
            action: \.addRoutineSheet
        ) {
            AddRoutineTCAView(store: addRoutineStore)
        }
    }

    var timelineRangePicker: some View {
        platformTimelineRangePicker
    }

    var timelineTypePicker: some View {
        platformTimelineTypePicker
    }

    var overallDoneCountSummary: some View {
        HStack(spacing: 12) {
            Label("\(store.doneStats.totalCount) dones", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)

            Label("\(store.routineTasks.filter { !$0.isOneOffTask }.count) routines", systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Label("\(store.routineTasks.filter { $0.isOneOffTask && !$0.isCompletedOneOff }.count) todos", systemImage: "checkmark.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    var tagFilterBar: some View {
        platformTagFilterBar
    }

    private func sortedTasks(_ routineDisplays: [HomeFeature.RoutineDisplay]) -> [HomeFeature.RoutineDisplay] {
        routineDisplays.sorted(by: regularTaskSort)
    }

    private func regularTaskSort(
        _ task1: HomeFeature.RoutineDisplay,
        _ task2: HomeFeature.RoutineDisplay
    ) -> Bool {
        let overdueDays1 = overdueDays(for: task1)
        let overdueDays2 = overdueDays(for: task2)

        if overdueDays1 != overdueDays2 {
            return overdueDays1 > overdueDays2
        }

        let urgency1 = urgencyLevel(for: task1)
        let urgency2 = urgencyLevel(for: task2)
        if urgency1 != urgency2 {
            return urgency1 > urgency2
        }

        if let dueDateComparison = dueDateSortResult(task1, task2) {
            return dueDateComparison
        }

        if task1.priority != task2.priority {
            return task1.priority.sortOrder > task2.priority.sortOrder
        }

        return task1.name.localizedCaseInsensitiveCompare(task2.name) == .orderedAscending
    }

    private func dueDateSortResult(
        _ lhs: HomeFeature.RoutineDisplay,
        _ rhs: HomeFeature.RoutineDisplay
    ) -> Bool? {
        switch (lhs.dueDate, rhs.dueDate) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate < rhsDate
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return nil
        }
    }

    private func archivedTaskSort(
        _ lhs: HomeFeature.RoutineDisplay,
        _ rhs: HomeFeature.RoutineDisplay
    ) -> Bool {
        let lhsDate = lhs.pausedAt ?? lhs.lastDone ?? .distantPast
        let rhsDate = rhs.pausedAt ?? rhs.lastDone ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private func pinnedTaskSort(
        _ lhs: HomeFeature.RoutineDisplay,
        _ rhs: HomeFeature.RoutineDisplay
    ) -> Bool {
        let lhsDate = lhs.pinnedAt ?? .distantPast
        let rhsDate = rhs.pinnedAt ?? .distantPast
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }
        if lhs.isPaused != rhs.isPaused {
            return !lhs.isPaused && rhs.isPaused
        }
        return lhs.isPaused && rhs.isPaused ? archivedTaskSort(lhs, rhs) : regularTaskSort(lhs, rhs)
    }

    private func urgencyLevel(for task: HomeFeature.RoutineDisplay) -> Int {
        let dueIn = dueInDays(for: task)

        if dueIn < 0 { return 3 }
        if dueIn == 0 { return 2 }
        if dueIn == 1 { return 1 }
        return 0
    }

    func sharedTaskSections(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> (sections: [RoutineListSection], awayTasks: [HomeFeature.RoutineDisplay], archivedTasks: [HomeFeature.RoutineDisplay]) {
        (
            groupedRoutineSections(from: routineDisplays),
            filteredAwayTasks(awayRoutineDisplays),
            filteredArchivedTasks(archivedRoutineDisplays)
        )
    }

    func listOfSortedTasksView(
        routineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> some View {
        platformListOfSortedTasksView(
            routineDisplays: routineDisplays,
            awayRoutineDisplays: awayRoutineDisplays,
            archivedRoutineDisplays: archivedRoutineDisplays
        )
    }

    var compactHomeHeader: some View {
        platformCompactHomeHeader
    }

    var filterSheetButton: some View {
        Button {
            isFilterSheetPresented = true
        } label: {
            Image(
                systemName: hasActiveOptionalFilters
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
            .foregroundStyle(hasActiveOptionalFilters ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filters")
    }

    @ViewBuilder
    var activeFilterChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let selectedTag {
                    compactFilterChip(title: "#\(selectedTag)") {
                        self.selectedTag = nil
                    }
                }

                ForEach(excludedTags.sorted(), id: \.self) { tag in
                    compactFilterChip(title: "not #\(tag)", tintColor: .red) {
                        excludedTags.remove(tag)
                    }
                }

                if let selectedPlaceName {
                    compactFilterChip(title: selectedPlaceName, systemImage: "mappin.and.ellipse") {
                        selectedManualPlaceFilterID = nil
                    }
                }

                if store.hideUnavailableRoutines {
                    compactFilterChip(title: "Away hidden", systemImage: "location.slash") {
                        store.send(.hideUnavailableRoutinesChanged(false))
                    }
                }

                if activeOptionalFilterCount > 1 {
                    Button("Clear All") {
                        clearOptionalFilters()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    func compactFilterChip(
        title: String,
        systemImage: String? = nil,
        tintColor: Color = .secondary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2)
                }

                Text(title)
                    .font(.caption.weight(.medium))

                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .foregroundStyle(tintColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tintColor.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    var hideUnavailableRoutinesBinding: Binding<Bool> {
        Binding(
            get: { store.hideUnavailableRoutines },
            set: { store.send(.hideUnavailableRoutinesChanged($0)) }
        )
    }

    var manualPlaceFilterBinding: Binding<UUID?> {
        Binding(
            get: { selectedManualPlaceFilterID },
            set: { selectedManualPlaceFilterID = $0 }
        )
    }

    var sortedRoutinePlaces: [RoutinePlace] {
        store.routinePlaces.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    var selectedPlaceName: String? {
        guard let selectedManualPlaceFilterID else { return nil }
        return store.routinePlaces.first(where: { $0.id == selectedManualPlaceFilterID })?.displayName
    }

    var activeOptionalFilterCount: Int {
        var count = 0

        if selectedTag != nil {
            count += 1
        }
        count += excludedTags.count
        if selectedManualPlaceFilterID != nil {
            count += 1
        }
        if store.hideUnavailableRoutines {
            count += 1
        }

        return count
    }

    var hasActiveOptionalFilters: Bool {
        activeOptionalFilterCount > 0
    }

    var hasSavedPlaces: Bool {
        !sortedRoutinePlaces.isEmpty
    }

    var hasPlaceLinkedRoutines: Bool {
        store.routineTasks.contains { $0.placeID != nil }
    }

    var hasPlaceAwareContent: Bool {
        hasSavedPlaces || hasPlaceLinkedRoutines
    }

    func clearOptionalFilters() {
        selectedTag = nil
        excludedTags = []
        selectedManualPlaceFilterID = nil

        if store.hideUnavailableRoutines {
            store.send(.hideUnavailableRoutinesChanged(false))
        }
    }

    var manualPlaceFilterDescription: String {
        guard let selectedManualPlaceFilterID,
              let place = store.routinePlaces.first(where: { $0.id == selectedManualPlaceFilterID })
        else {
            return "Choose a saved place to show only routines linked to that place."
        }
        return "Showing only routines linked to \(place.displayName)."
    }

    var placeFilterSectionDescription: String {
        if hasSavedPlaces {
            return manualPlaceFilterDescription
        }
        return "Save a place in Settings, then link it to a routine to filter by place here."
    }

    var locationStatusText: String {
        switch store.locationSnapshot.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if store.awayRoutineDisplays.isEmpty {
                return "All place-linked routines are currently available."
            }
            if store.hideUnavailableRoutines {
                return "\(store.awayRoutineDisplays.count) routines are hidden because you are away from their saved place."
            }
            return "\(store.awayRoutineDisplays.count) routines are away from their saved place and shown below."
        case .notDetermined:
            return "Allow location access to automatically separate place-based routines. Until then they stay visible."
        case .disabled:
            return "Location services are disabled on this device, so place-based routines stay visible."
        case .restricted, .denied:
            return "Location access is off, so place-based routines stay visible."
        }
    }

    func filteredAwayTasks(
        _ routineDisplays: [HomeFeature.RoutineDisplay]
    ) -> [HomeFeature.RoutineDisplay] {
        sortedTasks(routineDisplays).filter { task in
            matchesCurrentTaskListMode(task)
                && matchesSearch(task)
                && matchesFilter(task)
                && matchesManualPlaceFilter(task)
                && HomeFeature.matchesSelectedTag(selectedTag, in: task.tags)
                && HomeFeature.matchesExcludedTags(excludedTags, in: task.tags)
        }
    }

    func routineRow(for task: HomeFeature.RoutineDisplay, rowNumber: Int) -> some View {
        platformRoutineRow(for: task, rowNumber: rowNumber)
    }

    @ViewBuilder
    func routineDetailDestination(taskID: UUID) -> some View {
        if store.selectedTaskID == taskID,
           let detailStore = self.store.scope(
               state: \.routineDetailState,
               action: \.routineDetail
           ) {
            RoutineDetailTCAView(store: detailStore)
        } else if store.routineTasks.contains(where: { $0.id == taskID }) {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    openTask(taskID)
                }
        } else {
            ContentUnavailableView(
                "Routine not found",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected routine is no longer available.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    func groupedRoutineSections(
        from routineDisplays: [HomeFeature.RoutineDisplay]
    ) -> [RoutineListSection] {
        let filtered = filteredTasks(routineDisplays)

        let overdue = filtered.filter { overdueDays(for: $0) > 0 }
        let dueSoon = filtered.filter {
            !($0.isDoneToday) &&
            overdueDays(for: $0) == 0 &&
            (urgencyLevel(for: $0) > 0 || isYellowUrgency($0))
        }
        let onTrack = filtered.filter {
            !($0.isDoneToday) &&
            overdueDays(for: $0) == 0 &&
            urgencyLevel(for: $0) == 0 &&
            !isYellowUrgency($0)
        }
        let doneToday = filtered.filter(\.isDoneToday)

        let onTrackSections: [RoutineListSection]
        switch routineListSectioningMode {
        case .status:
            onTrackSections = [RoutineListSection(title: "On Track", tasks: onTrack)]
        case .deadlineDate:
            onTrackSections = deadlineBasedSections(from: onTrack)
        }

        return (
            [
            RoutineListSection(title: "Overdue", tasks: overdue),
                RoutineListSection(title: "Due Soon", tasks: dueSoon)
            ]
            + onTrackSections
            + [RoutineListSection(title: "Done Today", tasks: doneToday)]
        )
        .filter { !$0.tasks.isEmpty }
    }

    private func deadlineBasedSections(
        from tasks: [HomeFeature.RoutineDisplay]
    ) -> [RoutineListSection] {
        guard !tasks.isEmpty else { return [] }

        let sorted = tasks.sorted { lhs, rhs in
            let lhsDate = sectionDateForDeadlineGrouping(for: lhs) ?? .distantFuture
            let rhsDate = sectionDateForDeadlineGrouping(for: rhs) ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return regularTaskSort(lhs, rhs)
        }

        var sections: [RoutineListSection] = []
        for task in sorted {
            let title = deadlineSectionTitle(for: task)
            if let lastIndex = sections.indices.last, sections[lastIndex].title == title {
                sections[lastIndex].tasks.append(task)
            } else {
                sections.append(RoutineListSection(title: title, tasks: [task]))
            }
        }

        return sections
    }

    private func sectionDateForDeadlineGrouping(
        for task: HomeFeature.RoutineDisplay
    ) -> Date? {
        guard task.daysUntilDue != Int.max else { return nil }
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: max(task.daysUntilDue, 0), to: today)
            .map { calendar.startOfDay(for: $0) }
    }

    private func deadlineSectionTitle(for task: HomeFeature.RoutineDisplay) -> String {
        guard let sectionDate = sectionDateForDeadlineGrouping(for: task) else {
            return "On Track"
        }
        return formattedDeadlineSectionTitle(for: sectionDate)
    }

    private func formattedDeadlineSectionTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .autoupdatingCurrent
        let includesYear = calendar.component(.year, from: date) != calendar.component(.year, from: Date())
        formatter.setLocalizedDateFormatFromTemplate(includesYear ? "EEE MMM d yyyy" : "EEE MMM d")
        return formatter.string(from: date)
    }
    

    func deleteTasks(
        at offsets: IndexSet,
        from sectionTasks: [HomeFeature.RoutineDisplay]
    ) {
        platformDeleteTasks(at: offsets, from: sectionTasks)
    }

    func openTask(_ taskID: UUID) {
        platformOpenTask(taskID)
    }

    func deleteTask(_ taskID: UUID) {
        platformDeleteTask(taskID)
    }

    private func urgencyColor(for task: HomeFeature.RoutineDisplay) -> Color {
        if task.isPaused {
            return .teal
        }
        if case .away = task.locationAvailability {
            return .blue
        }
        if task.isInProgress {
            return .orange
        }
        if task.isOneOffTask {
            return task.isCompletedOneOff ? .green : .blue
        }
        if task.scheduleMode == .fixedIntervalChecklist
            && task.completedChecklistItemCount > 0
            && !task.isDoneToday {
            return .orange
        }
        if task.recurrenceRule.isFixedCalendar {
            let urgency = urgencyLevel(for: task)
            switch urgency {
            case 3:
                return .red
            case 2, 1:
                return .orange
            default:
                return .green
            }
        }
        let progress = Double(daysSinceScheduleAnchor(task)) / Double(task.interval)
        switch progress {
        case ..<0.75: return .green
        case ..<0.90: return .orange
        default: return .red
        }
    }

    func rowIconBackgroundColor(for task: HomeFeature.RoutineDisplay) -> Color {
        urgencyColor(for: task).opacity(task.isDoneToday ? 0.22 : 0.14)
    }

    private func isYellowUrgency(_ task: HomeFeature.RoutineDisplay) -> Bool {
        if task.isOneOffTask {
            return false
        }
        if task.isInProgress
            || task.scheduleMode == .derivedFromChecklist
            || (task.scheduleMode == .fixedIntervalChecklist && task.completedChecklistItemCount > 0) {
            return false
        }
        if task.recurrenceRule.isFixedCalendar {
            return dueInDays(for: task) == 1
        }
        let progress = Double(daysSinceScheduleAnchor(task)) / Double(task.interval)
        return progress >= 0.75 && progress < 0.90
    }

    private func daysSinceLastRoutine(_ task: HomeFeature.RoutineDisplay) -> Int {
        RoutineDateMath.elapsedDaysSinceLastDone(from: task.lastDone, referenceDate: Date())
    }

    private func daysSinceScheduleAnchor(_ task: HomeFeature.RoutineDisplay) -> Int {
        RoutineDateMath.elapsedDaysSinceLastDone(
            from: task.scheduleAnchor ?? task.lastDone,
            referenceDate: Date()
        )
    }

    private func filteredTasks(
        _ routineDisplays: [HomeFeature.RoutineDisplay]
    ) -> [HomeFeature.RoutineDisplay] {
        sortedTasks(routineDisplays).filter { task in
            matchesCurrentTaskListMode(task)
                && matchesSearch(task)
                && matchesFilter(task)
                && matchesManualPlaceFilter(task)
                && HomeFeature.matchesSelectedTag(selectedTag, in: task.tags)
                && HomeFeature.matchesExcludedTags(excludedTags, in: task.tags)
        }
    }

    func filteredArchivedTasks(
        _ routineDisplays: [HomeFeature.RoutineDisplay],
        includePinned: Bool = true
    ) -> [HomeFeature.RoutineDisplay] {
        routineDisplays
            .filter { task in
                matchesCurrentTaskListMode(task)
                    && !task.isCompletedOneOff
                    && (includePinned || !task.isPinned)
                    && matchesSearch(task)
                    && matchesManualPlaceFilter(task)
                    && HomeFeature.matchesSelectedTag(selectedTag, in: task.tags)
                    && HomeFeature.matchesExcludedTags(excludedTags, in: task.tags)
            }
            .sorted(by: archivedTaskSort)
    }

    func filteredPinnedTasks(
        activeRoutineDisplays: [HomeFeature.RoutineDisplay],
        awayRoutineDisplays: [HomeFeature.RoutineDisplay],
        archivedRoutineDisplays: [HomeFeature.RoutineDisplay]
    ) -> [HomeFeature.RoutineDisplay] {
        let activePinned = sortedTasks(activeRoutineDisplays + awayRoutineDisplays).filter { task in
            task.isPinned
                && matchesCurrentTaskListMode(task)
                && matchesSearch(task)
                && matchesFilter(task)
                && matchesManualPlaceFilter(task)
                && HomeFeature.matchesSelectedTag(selectedTag, in: task.tags)
                && HomeFeature.matchesExcludedTags(excludedTags, in: task.tags)
        }
        let archivedPinned = filteredArchivedTasks(archivedRoutineDisplays).filter(\.isPinned)

        return (activePinned + archivedPinned).sorted(by: pinnedTaskSort)
    }

    private func matchesSearch(_ task: HomeFeature.RoutineDisplay) -> Bool {
        let trimmedSearch = searchTextBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return true }
        return task.name.localizedCaseInsensitiveContains(trimmedSearch)
            || task.emoji.localizedCaseInsensitiveContains(trimmedSearch)
            || (task.notes?.localizedCaseInsensitiveContains(trimmedSearch) ?? false)
            || (task.placeName?.localizedCaseInsensitiveContains(trimmedSearch) ?? false)
            || RoutineTag.matchesQuery(trimmedSearch, in: task.tags)
    }

    private func matchesFilter(_ task: HomeFeature.RoutineDisplay) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .due:
            return !task.isDoneToday && (urgencyLevel(for: task) > 0 || isYellowUrgency(task))
        case .todos:
            return task.isOneOffTask
        case .doneToday:
            return task.isDoneToday
        }
    }

    private func matchesManualPlaceFilter(_ task: HomeFeature.RoutineDisplay) -> Bool {
        guard let selectedManualPlaceFilterID else { return true }
        return task.placeID == selectedManualPlaceFilterID
    }

    private func dueInDays(for task: HomeFeature.RoutineDisplay) -> Int {
        task.daysUntilDue
    }

    private func overdueDays(for task: HomeFeature.RoutineDisplay) -> Int {
        max(-dueInDays(for: task), 0)
    }

    func routineNavigationRow(
        for task: HomeFeature.RoutineDisplay,
        rowNumber: Int,
        includeMarkDone: Bool = true
    ) -> some View {
        platformRoutineNavigationRow(for: task, rowNumber: rowNumber, includeMarkDone: includeMarkDone)
    }

    @ViewBuilder
    func routineContextMenu(
        for task: HomeFeature.RoutineDisplay,
        includeMarkDone: Bool
    ) -> some View {
        Button {
            openTask(task.taskID)
        } label: {
            Label("Open", systemImage: "arrow.right.circle")
        }

        if task.isPaused {
            Button {
                store.send(.resumeTask(task.taskID))
            } label: {
                Label("Resume", systemImage: "play.circle")
            }
        } else if task.isCompletedOneOff {
            EmptyView()
        } else {
            if includeMarkDone {
                Button {
                    store.send(.markTaskDone(task.taskID))
                } label: {
                    Label(markDoneLabel(for: task), systemImage: "checkmark.circle")
                }
                .disabled(isMarkDoneDisabled(task))
            }

            if !task.isOneOffTask {
                Button {
                    store.send(.pauseTask(task.taskID))
                } label: {
                    Label("Pause", systemImage: "pause.circle")
                }
            }
        }

        platformPinMenuItem(for: task)
        platformDeleteMenuItem(for: task)
    }

    func rowMetadataText(for task: HomeFeature.RoutineDisplay) -> String? {
        if task.isOneOffTask {
            let items = todoRowMetadataItems(for: task)
            return items.isEmpty ? nil : items.joined(separator: " • ")
        }

        let prioritySegment = task.priority.metadataLabel.map { "\($0) • " } ?? ""

        if task.isPaused {
            return "\(cadenceDescription(for: task)) • \(prioritySegment)\(doneCountDescription(for: task.doneCount)) • \(pauseDescription(for: task))\(stepMetadataSuffix(for: task))\(placeMetadataSuffix(for: task))"
        }
        return "\(cadenceDescription(for: task)) • \(prioritySegment)\(doneCountDescription(for: task.doneCount)) • \(completionDescription(for: task))\(stepMetadataSuffix(for: task))\(placeMetadataSuffix(for: task))"
    }

    private func todoRowMetadataItems(for task: HomeFeature.RoutineDisplay) -> [String] {
        var items: [String] = []

        if let deadlineText = conciseDeadlineText(for: task) {
            items.append(deadlineText)
        }

        if let priorityText = task.priority.metadataLabel {
            items.append(priorityText)
        }

        if task.isPaused {
            items.append(pauseDescription(for: task))
        } else if task.isCompletedOneOff || task.isInProgress {
            items.append(completionDescription(for: task))
        }

        if let stepText = conciseTodoStepText(for: task) {
            items.append(stepText)
        }

        if let placeText = concisePlaceMetadataText(for: task) {
            items.append(placeText)
        }

        return items
    }

    private func pauseDescription(for task: HomeFeature.RoutineDisplay) -> String {
        guard let pausedAt = task.pausedAt else { return "Paused" }
        let elapsedDays = RoutineDateMath.elapsedDaysSinceLastDone(from: pausedAt, referenceDate: Date())
        if elapsedDays == 0 { return "Paused today" }
        if elapsedDays == 1 { return "Paused yesterday" }
        return "Paused \(elapsedDays) days ago"
    }

    private func doneCountDescription(for count: Int) -> String {
        count == 1 ? "1 done" : "\(count) dones"
    }

    private func cadenceDescription(for task: HomeFeature.RoutineDisplay) -> String {
        if task.isOneOffTask {
            return "One-off todo"
        }
        if task.scheduleMode == .derivedFromChecklist {
            return "Checklist-driven"
        }
        return task.recurrenceRule.displayText()
    }

    private func completionDescription(for task: HomeFeature.RoutineDisplay) -> String {
        if task.isOneOffTask {
            if task.isInProgress {
                let totalSteps = max(task.steps.count, 1)
                return "Step \(task.completedStepCount + 1) of \(totalSteps)"
            }
            guard task.lastDone != nil else { return "Not completed yet" }

            let elapsedDays = daysSinceLastRoutine(task)
            if elapsedDays == 0 { return "Completed today" }
            if elapsedDays == 1 { return "Completed yesterday" }
            return "Completed \(elapsedDays) days ago"
        }
        if task.scheduleMode == .derivedFromChecklist {
            if task.isDoneToday && overdueDays(for: task) == 0 {
                return "Updated today"
            }
            guard task.lastDone != nil else { return "Never updated" }

            let elapsedDays = daysSinceLastRoutine(task)
            if elapsedDays == 0 { return "Updated today" }
            if elapsedDays == 1 { return "Updated yesterday" }
            return "Updated \(elapsedDays) days ago"
        }
        if task.scheduleMode == .fixedIntervalChecklist && task.completedChecklistItemCount > 0 {
            return "Checklist \(task.completedChecklistItemCount) of \(max(task.checklistItemCount, 1))"
        }
        if task.isInProgress {
            let totalSteps = max(task.steps.count, 1)
            return "Step \(task.completedStepCount + 1) of \(totalSteps)"
        }
        guard task.lastDone != nil else { return "Never completed" }

        let elapsedDays = daysSinceLastRoutine(task)
        if elapsedDays == 0 { return "Completed today" }
        if elapsedDays == 1 { return "Completed yesterday" }
        return "Completed \(elapsedDays) days ago"
    }

    func statusBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        let style = badgeStyle(for: task)

        return HStack(spacing: 4) {
            Image(systemName: style.systemImage)
                .imageScale(.small)

            Text(style.title)
                .lineLimit(1)
        }
        .font(.subheadline.weight(.semibold))
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(2)
        .foregroundStyle(style.foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(style.backgroundColor, in: Capsule())
    }

    func tagFilterButton(
        title: String,
        isSelected: Bool,
        selectedColor: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? selectedColor : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(isSelected ? selectedColor.opacity(0.16) : Color.secondary.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
    }

    private func badgeStyle(
        for task: HomeFeature.RoutineDisplay
    ) -> (title: String, systemImage: String, foregroundColor: Color, backgroundColor: Color) {
        if task.isPaused {
            return ("Paused", "pause.circle.fill", .teal, Color.teal.opacity(0.16))
        }
        if case .away = task.locationAvailability {
            return ("Away", "location.slash.fill", .blue, Color.blue.opacity(0.14))
        }
        if task.isInProgress {
            return ("Step \(task.completedStepCount + 1)/\(max(task.steps.count, 1))", "list.number", .orange, Color.orange.opacity(0.16))
        }
        if task.isOneOffTask {
            if task.isCompletedOneOff {
                return ("Done", "checkmark.circle.fill", .green, Color.green.opacity(0.14))
            }
            return ("To Do", "circle", .blue, Color.blue.opacity(0.12))
        }
        let dueIn = dueInDays(for: task)

        if task.scheduleMode == .derivedFromChecklist {
            if dueIn < 0 {
                return ("Overdue \(abs(dueIn))d", "exclamationmark.circle.fill", .red, Color.red.opacity(0.14))
            }
            if dueIn == 0 {
                return ("Today", "clock.fill", .orange, Color.orange.opacity(0.16))
            }
            if task.isDoneToday {
                return ("Updated", "checkmark.circle.fill", .green, Color.green.opacity(0.14))
            }
            if dueIn == 1 {
                return ("Tomorrow", "calendar", .orange, Color.orange.opacity(0.14))
            }
            return ("On Track", "circle.fill", .secondary, Color.secondary.opacity(0.12))
        }

        if task.scheduleMode == .fixedIntervalChecklist
            && task.completedChecklistItemCount > 0
            && !task.isDoneToday {
            return (
                "\(task.completedChecklistItemCount)/\(max(task.checklistItemCount, 1)) done",
                "checklist.checked",
                .orange,
                Color.orange.opacity(0.16)
            )
        }

        if task.isDoneToday {
            return ("Done", "checkmark.circle.fill", .green, Color.green.opacity(0.14))
        }

        if dueIn < 0 {
            return ("Overdue \(abs(dueIn))d", "exclamationmark.circle.fill", .red, Color.red.opacity(0.14))
        }
        if dueIn == 0 {
            return ("Today", "clock.fill", .orange, Color.orange.opacity(0.16))
        }
        if dueIn == 1 {
            return ("Tomorrow", "calendar", .orange, Color.orange.opacity(0.14))
        }
        if isYellowUrgency(task) {
            return ("\(dueIn)d left", "calendar.badge.clock", .orange, Color.orange.opacity(0.12))
        }

        return ("On Track", "circle.fill", .secondary, Color.secondary.opacity(0.12))
    }

    private func stepMetadataSuffix(for task: HomeFeature.RoutineDisplay) -> String {
        if task.scheduleMode == .derivedFromChecklist {
            if let nextDueChecklistItemTitle = task.nextDueChecklistItemTitle {
                if task.dueChecklistItemCount > 1 {
                    return " • Due: \(nextDueChecklistItemTitle) +\(task.dueChecklistItemCount - 1)"
                }
                return " • Due: \(nextDueChecklistItemTitle)"
            }
            let totalItems = task.checklistItemCount
            return totalItems == 0 ? "" : " • \(totalItems) \(totalItems == 1 ? "item" : "items")"
        }
        if task.scheduleMode == .fixedIntervalChecklist {
            if let nextPendingChecklistItemTitle = task.nextPendingChecklistItemTitle,
               task.completedChecklistItemCount < task.checklistItemCount {
                return " • Next: \(nextPendingChecklistItemTitle)"
            }
            let totalItems = task.checklistItemCount
            if totalItems == 0 { return "" }
            return " • Checklist \(task.completedChecklistItemCount)/\(totalItems)"
        }
        guard !task.steps.isEmpty else { return "" }
        if let nextStepTitle = task.nextStepTitle {
            return " • Next: \(nextStepTitle)"
        }
        let totalSteps = task.steps.count
        return " • \(totalSteps) \(totalSteps == 1 ? "step" : "steps")"
    }

    private func conciseTodoStepText(for task: HomeFeature.RoutineDisplay) -> String? {
        guard !task.steps.isEmpty else { return nil }
        if task.isCompletedOneOff { return nil }
        if let nextStepTitle = task.nextStepTitle {
            return "Next: \(nextStepTitle)"
        }
        if task.steps.count > 1 {
            return "\(task.steps.count) steps"
        }
        return nil
    }

    private func conciseDeadlineText(for task: HomeFeature.RoutineDisplay) -> String? {
        guard task.isOneOffTask, let dueDate = task.dueDate else { return nil }
        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            return "Due today"
        }
        if calendar.isDateInTomorrow(dueDate) {
            return "Due tomorrow"
        }
        if dueDate < Date() {
            let days = max(
                abs(calendar.dateComponents(
                    [.day],
                    from: calendar.startOfDay(for: dueDate),
                    to: calendar.startOfDay(for: Date())
                ).day ?? 0),
                1
            )
            return "Overdue \(days)d"
        }
        return "Due \(dueDate.formatted(date: .abbreviated, time: .omitted))"
    }

    private func markDoneLabel(for task: HomeFeature.RoutineDisplay) -> String {
        if task.scheduleMode == .derivedFromChecklist {
            if task.dueChecklistItemCount == 0 {
                return "No Due Items"
            }
            if task.dueChecklistItemCount == 1 {
                return "Buy Due Item"
            }
            return "Buy Due Items"
        }
        if task.scheduleMode == .fixedIntervalChecklist {
            return "Checklist"
        }
        return task.steps.isEmpty ? "Mark Done" : "Complete Next Step"
    }

    private func isMarkDoneDisabled(_ task: HomeFeature.RoutineDisplay) -> Bool {
        if task.isOneOffTask {
            return task.isCompletedOneOff || task.isPaused
        }
        if task.scheduleMode == .derivedFromChecklist {
            return task.isPaused || task.dueChecklistItemCount == 0
        }
        if task.scheduleMode == .fixedIntervalChecklist {
            return true
        }
        if task.recurrenceRule.isFixedCalendar,
           let dueDate = task.dueDate,
           dueDate > Date() {
            return true
        }
        return task.isDoneToday || task.isPaused
    }

    private func placeMetadataSuffix(for task: HomeFeature.RoutineDisplay) -> String {
        switch task.locationAvailability {
        case .unrestricted:
            return ""
        case let .available(placeName):
            return " • At \(placeName)"
        case let .away(placeName, _):
            return " • Away from \(placeName)"
        case let .unknown(placeName):
            return " • \(placeName) task"
        }
    }

    private func concisePlaceMetadataText(for task: HomeFeature.RoutineDisplay) -> String? {
        switch task.locationAvailability {
        case .unrestricted:
            return nil
        case let .available(placeName):
            return "At \(placeName)"
        case let .away(placeName, _):
            return "Away from \(placeName)"
        case let .unknown(placeName):
            return placeName
        }
    }

    @ViewBuilder
    func emptyStateView(
        title: String,
        message: String,
        systemImage: String,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if let action {
                Button("Add Task", action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    func inlineEmptyStateRow(
        title: String,
        message: String,
        systemImage: String
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 40)
    }

    @MainActor
    func performManualRefresh() async {
        if modelContext.hasChanges {
            try? modelContext.save()
        }

        if let containerIdentifier = AppEnvironment.cloudKitContainerIdentifier {
            try? await CloudKitDirectPullService.pullLatestIntoLocalStore(
                containerIdentifier: containerIdentifier,
                modelContext: modelContext
            )
        }

        requestRefresh()

        // CloudKit imports are asynchronous; do a second pass shortly after manual refresh.
        try? await Task.sleep(for: .seconds(2))
        requestRefresh()
    }

    private var allRoutineDisplays: [HomeFeature.RoutineDisplay] {
        store.routineDisplays + store.awayRoutineDisplays + store.archivedRoutineDisplays
    }

    var iOSAvailableFilters: [RoutineListFilter] {
        [.all, .due, .doneToday]
    }

    var availableTags: [String] {
        HomeFeature.availableTags(from: allRoutineDisplays.filter(matchesCurrentTaskListMode))
    }

    /// Tags available for exclusion — scoped to tasks that already match the selected include tag.
    var availableExcludeTags: [String] {
        let base = allRoutineDisplays.filter(matchesCurrentTaskListMode).filter { task in
            HomeFeature.matchesSelectedTag(selectedTag, in: task.tags)
        }
        return HomeFeature.availableTags(from: base).filter { tag in
            // Don't offer the include tag itself as an exclude option
            selectedTag.map { !RoutineTag.contains($0, in: [tag]) } ?? true
        }
    }

    func handleCompactHeaderScroll(oldOffset: CGFloat, newOffset: CGFloat) {
        let delta = newOffset - oldOffset

        if newOffset <= 12 {
            if isCompactHeaderHidden {
                isCompactHeaderHidden = false
            }
            return
        }

        if delta > 10, !isCompactHeaderHidden {
            isCompactHeaderHidden = true
        } else if delta < -10, isCompactHeaderHidden {
            isCompactHeaderHidden = false
        }
    }

    private func validateSelectedTag(
        activeDisplays: [HomeFeature.RoutineDisplay],
        awayDisplays: [HomeFeature.RoutineDisplay],
        archivedDisplays: [HomeFeature.RoutineDisplay]
    ) {
        let all = (activeDisplays + awayDisplays + archivedDisplays).filter(matchesCurrentTaskListMode)
        let allAvailableTags = HomeFeature.availableTags(from: all)

        if let selectedTag, !RoutineTag.contains(selectedTag, in: allAvailableTags) {
            self.selectedTag = nil
        }

        // Prune excluded tags to only those still present in the include-scoped pool
        excludedTags = excludedTags.filter { RoutineTag.contains($0, in: availableExcludeTags) }
    }

    @ViewBuilder
    func iosTaskListModeButton(_ mode: IOSTaskListMode) -> some View {
        let isSelected = iosTaskListMode == mode

        Button {
            iosTaskListMode = mode
        } label: {
            Image(systemName: mode.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.accessibilityLabel)
    }

    @MainActor
    private func requestRefresh() {
        guard !isRefreshScheduled else { return }
        isRefreshScheduled = true

        Task { @MainActor in
            defer { isRefreshScheduled = false }
            await Task.yield()
            store.send(.onAppear)
        }
    }
}
