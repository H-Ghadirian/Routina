import Combine
import ComposableArchitecture
import CoreData
import SwiftData
import SwiftUI

struct HomeTCAView: View {
    private enum RoutineListFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case due = "Due"
        case doneToday = "Done Today"

        var id: String { rawValue }
    }

    private struct RoutineListSection: Identifiable {
        let title: String
        let tasks: [HomeFeature.RoutineDisplay]

        var id: String { title }
    }

    let store: StoreOf<HomeFeature>
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTaskID: UUID?
    @State private var searchText = ""
    @State private var selectedFilter: RoutineListFilter = .all

    var body: some View {
        WithPerceptionTracking {
            homeContent
        }
    }

    private var homeContent: some View {
        applyPlatformRefresh(to: navigationContent)
            .sheet(isPresented: addRoutineSheetBinding) {
                addRoutineSheetContent
            }
            .onAppear {
                store.send(.onAppear)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: Notification.Name("routineDidUpdate"))
                    .receive(on: RunLoop.main)
            ) { _ in
                store.send(.onAppear)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
                    .receive(on: RunLoop.main)
            ) { _ in
                store.send(.onAppear)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
                    .receive(on: RunLoop.main)
            ) { _ in
                store.send(.onAppear)
            }
            .onChange(of: store.routineTasks) { _, tasks in
                guard let selectedTaskID else { return }
                if !tasks.contains(where: { $0.id == selectedTaskID }) {
                    self.selectedTaskID = nil
                }
            }
    }

    private var navigationContent: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
    }

    private var sidebarContent: some View {
        VStack(spacing: 12) {
            if store.routineTasks.isEmpty {
                emptyStateView(
                    title: "No routines yet",
                    message: "Start with one recurring task, and the sidebar will organize what needs attention for you.",
                    systemImage: "checklist"
                ) {
                    store.send(.setAddRoutineSheet(true))
                }
            } else {
                filterPicker

                listOfSortedTasksView(
                    routineDisplays: store.routineDisplays,
                    routineTasks: store.routineTasks
                )
            }
        }
        .navigationTitle("Routina")
        .searchable(text: $searchText, prompt: "Search routines")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                platformRefreshButton
                Button {
                    store.send(.setAddRoutineSheet(true))
                } label: {
                    Label("Add Routine", systemImage: "plus")
                }
            }
        }
        .routinaHomeSidebarColumnWidth()
    }

    @ViewBuilder
    private var detailContent: some View {
        if let selectedTaskID {
            routineDetailTCAView(taskID: selectedTaskID, routineTasks: store.routineTasks)
        } else {
            Color.clear
        }
    }

    private var addRoutineSheetBinding: Binding<Bool> {
        Binding(
            get: { store.isAddRoutineSheetPresented },
            set: { store.send(.setAddRoutineSheet($0)) }
        )
    }

    @ViewBuilder
    private var addRoutineSheetContent: some View {
        if let addRoutineStore = self.store.scope(
            state: \.addRoutineState,
            action: \.addRoutineSheet
        ) {
            AddRoutineTCAView(store: addRoutineStore)
        }
    }

    private var filterPicker: some View {
        Picker("Routine Filter", selection: $selectedFilter) {
            ForEach(RoutineListFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private func sortedTasks(_ routineDisplays: [HomeFeature.RoutineDisplay]) -> [HomeFeature.RoutineDisplay] {
        routineDisplays.sorted { task1, task2 in
            let overdueDays1 = daysSinceLastRoutine(task1) - task1.interval
            let overdueDays2 = daysSinceLastRoutine(task2) - task2.interval

            if overdueDays1 != overdueDays2 {
                return overdueDays1 > overdueDays2
            }

            let urgency1 = urgencyLevel(for: task1)
            let urgency2 = urgencyLevel(for: task2)
            if urgency1 != urgency2 {
                return urgency1 > urgency2
            }

            return task1.name.localizedCaseInsensitiveCompare(task2.name) == .orderedAscending
        }
    }

    private func urgencyLevel(for task: HomeFeature.RoutineDisplay) -> Int {
        let dueIn = dueInDays(for: task)

        if dueIn < 0 { return 3 }
        if dueIn == 0 { return 2 }
        if dueIn == 1 { return 1 }
        return 0
    }

    private func listOfSortedTasksView(
        routineDisplays: [HomeFeature.RoutineDisplay],
        routineTasks: [RoutineTask]
    ) -> some View {
        let sections = groupedRoutineSections(from: routineDisplays)

        return Group {
            if sections.isEmpty {
                emptyStateView(
                    title: "No matching routines",
                    message: "Try a different search or switch back to another filter.",
                    systemImage: "magnifyingglass"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedTaskID) {
                    ForEach(sections) { section in
                        Section(section.title) {
                            ForEach(section.tasks) { task in
                                NavigationLink(value: task.taskID) {
                                    routineRow(for: task)
                                }
                                .contentShape(Rectangle())
                                .contextMenu {
                                    Button {
                                        selectedTaskID = task.taskID
                                    } label: {
                                        Label("Open", systemImage: "arrow.right.circle")
                                    }

                                    Button {
                                        store.send(.markTaskDone(task.taskID))
                                    } label: {
                                        Label("Mark Done", systemImage: "checkmark.circle")
                                    }
                                    .disabled(task.isDoneToday)

                                    Button(role: .destructive) {
                                        if selectedTaskID == task.taskID {
                                            selectedTaskID = nil
                                        }
                                        store.send(.deleteTasks([task.taskID]))
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .onDelete { offsets in
                                deleteTasks(at: offsets, from: section.tasks)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .navigationDestination(for: UUID.self) { taskID in
                    routineDetailTCAView(taskID: taskID, routineTasks: routineTasks)
                }
            }
        }
    }

    private func routineRow(for task: HomeFeature.RoutineDisplay) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(rowIconBackgroundColor(for: task))
                Text(task.emoji)
                    .font(.title3)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
#if os(macOS)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(task.name)
                        .font(.headline)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Spacer(minLength: 8)

                    statusBadge(for: task)
                }

                Text(rowMetadataText(for: task))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
#else
                Text(task.name)
                    .font(.headline)
                    .lineLimit(1)
                    .layoutPriority(1)

                statusBadge(for: task)

                Text(rowMetadataText(for: task))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
#endif
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func routineDetailTCAView(
        taskID: UUID,
        routineTasks: [RoutineTask]
    ) -> some View {
        Group {
            if let task = routineTasks.first(where: { $0.id == taskID }) {
                let currentModelContext = modelContext
                RoutineDetailTCAView(
                    store: Store(
                        initialState: RoutineDetailFeature.State(
                            task: task,
                            logs: initialLogs(for: task),
                            daysSinceLastRoutine: Calendar.current.dateComponents([.day], from: task.lastDone ?? Date(), to: Date()).day ?? 0,
                            overdueDays: max((Calendar.current.dateComponents([.day], from: (Calendar.current.date(byAdding: .day, value: Int(task.interval), to: task.lastDone ?? Date()) ?? Date()), to: Date()).day ?? 0), 0),
                            isDoneToday: task.lastDone.map { Calendar.current.isDateInToday($0) } ?? false
                        ),
                        reducer: { RoutineDetailFeature() },
                        withDependencies: {
                            $0.modelContext = { @MainActor in currentModelContext }
                        }
                    )
                )
            } else {
                Text("Routine not found")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func groupedRoutineSections(
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

        return [
            RoutineListSection(title: "Overdue", tasks: overdue),
            RoutineListSection(title: "Due Soon", tasks: dueSoon),
            RoutineListSection(title: "On Track", tasks: onTrack),
            RoutineListSection(title: "Done Today", tasks: doneToday)
        ]
        .filter { !$0.tasks.isEmpty }
    }

    private func deleteTasks(
        at offsets: IndexSet,
        from sectionTasks: [HomeFeature.RoutineDisplay]
    ) {
        let ids = offsets.compactMap { sectionTasks[$0].taskID }
        if let selectedTaskID, ids.contains(selectedTaskID) {
            self.selectedTaskID = nil
        }
        store.send(.deleteTasks(ids))
    }

    private func initialLogs(for task: RoutineTask) -> [RoutineLog] {
        HomeFeature.detailLogs(taskID: task.id, context: modelContext)
    }

    private func urgencyColor(for task: HomeFeature.RoutineDisplay) -> Color {
        let progress = Double(daysSinceLastRoutine(task)) / Double(task.interval)
        switch progress {
        case ..<0.75: return .green
        case ..<0.90: return .orange
        default: return .red
        }
    }

    private func rowIconBackgroundColor(for task: HomeFeature.RoutineDisplay) -> Color {
        urgencyColor(for: task).opacity(task.isDoneToday ? 0.22 : 0.14)
    }

    private func isYellowUrgency(_ task: HomeFeature.RoutineDisplay) -> Bool {
        let progress = Double(daysSinceLastRoutine(task)) / Double(task.interval)
        return progress >= 0.75 && progress < 0.90
    }

    private func daysSinceLastRoutine(_ task: HomeFeature.RoutineDisplay) -> Int {
        Calendar.current.dateComponents([.day], from: task.lastDone ?? Date(), to: Date()).day ?? 0
    }

    private func filteredTasks(
        _ routineDisplays: [HomeFeature.RoutineDisplay]
    ) -> [HomeFeature.RoutineDisplay] {
        sortedTasks(routineDisplays).filter { task in
            matchesSearch(task) && matchesFilter(task)
        }
    }

    private func matchesSearch(_ task: HomeFeature.RoutineDisplay) -> Bool {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return true }
        return task.name.localizedCaseInsensitiveContains(trimmedSearch)
            || task.emoji.localizedCaseInsensitiveContains(trimmedSearch)
    }

    private func matchesFilter(_ task: HomeFeature.RoutineDisplay) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .due:
            return !task.isDoneToday && (urgencyLevel(for: task) > 0 || isYellowUrgency(task))
        case .doneToday:
            return task.isDoneToday
        }
    }

    private func dueInDays(for task: HomeFeature.RoutineDisplay) -> Int {
        task.interval - daysSinceLastRoutine(task)
    }

    private func overdueDays(for task: HomeFeature.RoutineDisplay) -> Int {
        max(-dueInDays(for: task), 0)
    }

    private func rowMetadataText(for task: HomeFeature.RoutineDisplay) -> String {
        "\(cadenceDescription(for: task.interval)) • \(completionDescription(for: task))"
    }

    private func cadenceDescription(for interval: Int) -> String {
        if interval == 1 { return "Daily" }
        if interval % 30 == 0 {
            let months = interval / 30
            return months == 1 ? "Monthly" : "Every \(months) months"
        }
        if interval % 7 == 0 {
            let weeks = interval / 7
            return weeks == 1 ? "Weekly" : "Every \(weeks) weeks"
        }
        return "Every \(interval) days"
    }

    private func completionDescription(for task: HomeFeature.RoutineDisplay) -> String {
        guard task.lastDone != nil else { return "Never completed" }

        let elapsedDays = daysSinceLastRoutine(task)
        if elapsedDays == 0 { return "Completed today" }
        if elapsedDays == 1 { return "Completed yesterday" }
        return "Completed \(elapsedDays) days ago"
    }

    private func statusBadge(for task: HomeFeature.RoutineDisplay) -> some View {
        let style = badgeStyle(for: task)

        return Label(style.title, systemImage: style.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(style.foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(style.backgroundColor, in: Capsule())
    }

    private func badgeStyle(
        for task: HomeFeature.RoutineDisplay
    ) -> (title: String, systemImage: String, foregroundColor: Color, backgroundColor: Color) {
        if task.isDoneToday {
            return ("Done", "checkmark.circle.fill", .green, Color.green.opacity(0.14))
        }

        let dueIn = dueInDays(for: task)
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

    @ViewBuilder
    private func emptyStateView(
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
                Button("Add Routine", action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
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

        _ = store.send(.onAppear)

        // CloudKit imports are asynchronous; do a second pass shortly after manual refresh.
        try? await Task.sleep(for: .seconds(2))
        _ = store.send(.onAppear)
    }
}
