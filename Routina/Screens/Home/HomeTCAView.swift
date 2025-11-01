import ComposableArchitecture
import SwiftData
import SwiftUI

struct HomeTCAView: View {
    let store: StoreOf<HomeFeature>
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTaskID: UUID?

    var body: some View {
        WithPerceptionTracking {
            NavigationSplitView {
                Group {
                    if store.routineTasks.isEmpty {
                        Text("No routine defined yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        listOfSortedTasksView(
                            routineDisplays: store.routineDisplays,
                            routineTasks: store.routineTasks
                        )
                    }
                }
                .navigationTitle("Routina")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            store.send(.setAddRoutineSheet(true))
                        } label: {
                            Label("Add Routine", systemImage: "plus")
                        }
                    }
                }
            } detail: {
                Group {
                    if let selectedTaskID {
                        routineDetailTCAView(taskID: selectedTaskID, routineTasks: store.routineTasks)
                    } else {
                        Color.clear
                    }
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { store.isAddRoutineSheetPresented },
                    set: { store.send(.setAddRoutineSheet($0)) }
                )
            ) {
                if let addRoutineStore = self.store.scope(
                    state: \.addRoutineState,
                    action: \.addRoutineSheet
                ) {
                    AddRoutineTCAView(store: addRoutineStore)
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("routineDidUpdate"))) { _ in
                store.send(.onAppear)
            }
            .onChange(of: store.routineTasks) { _, tasks in
                guard let selectedTaskID else { return }
                if !tasks.contains(where: { $0.id == selectedTaskID }) {
                    self.selectedTaskID = nil
                }
            }
        }
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
        let dueIn = task.interval - daysSinceLastRoutine(task)

        if dueIn < 0 { return 3 }
        if dueIn == 0 { return 2 }
        if dueIn == 1 { return 1 }
        return 0
    }

    private func listOfSortedTasksView(
        routineDisplays: [HomeFeature.RoutineDisplay],
        routineTasks: [RoutineTask]
    ) -> some View {
        List(selection: $selectedTaskID) {
            ForEach(sortedTasks(routineDisplays)) { task in
                NavigationLink(value: task.taskID) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(task.emoji) \(task.name)")
                            if task.isDoneToday {
                                Text("Done Today")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else if isRedUrgency(task) {
                                Text(redUrgencySubtitle(for: task))
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else if isYellowUrgency(task) {
                                Text("Due in \(daysToDueDate(task)) days")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        Spacer()
                        urgencySquare(for: task)
                    }
                }
                .contentShape(Rectangle())
            }
            .onDelete { offsets in
                let sorted = sortedTasks(routineDisplays)
                let ids = offsets.compactMap { sorted[$0].taskID }
                if let selectedTaskID, ids.contains(selectedTaskID) {
                    self.selectedTaskID = nil
                }
                store.send(.deleteTasks(ids))
            }
        }
        .navigationDestination(for: UUID.self) { taskID in
            routineDetailTCAView(taskID: taskID, routineTasks: routineTasks)
        }
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

    private func urgencySquare(for task: HomeFeature.RoutineDisplay) -> some View {
        Rectangle()
            .fill(urgencyColor(for: task))
            .frame(width: 20, height: 20)
            .cornerRadius(4)
    }

    private func initialLogs(for _: RoutineTask) -> [RoutineLog] {
        []
    }

    private func urgencyColor(for task: HomeFeature.RoutineDisplay) -> Color {
        let progress = Double(daysSinceLastRoutine(task)) / Double(task.interval)
        switch progress {
        case ..<0.75: return .green
        case ..<0.90: return .orange
        default: return .red
        }
    }

    private func isYellowUrgency(_ task: HomeFeature.RoutineDisplay) -> Bool {
        let progress = Double(daysSinceLastRoutine(task)) / Double(task.interval)
        return progress >= 0.75 && progress < 0.90
    }

    private func isRedUrgency(_ task: HomeFeature.RoutineDisplay) -> Bool {
        let progress = Double(daysSinceLastRoutine(task)) / Double(task.interval)
        return progress >= 0.90
    }

    private func daysSinceLastRoutine(_ task: HomeFeature.RoutineDisplay) -> Int {
        Calendar.current.dateComponents([.day], from: task.lastDone ?? Date(), to: Date()).day ?? 0
    }

    private func daysToDueDate(_ task: HomeFeature.RoutineDisplay) -> Int {
        max(task.interval - daysSinceLastRoutine(task), 0)
    }

    private func redUrgencySubtitle(for task: HomeFeature.RoutineDisplay) -> String {
        let dueIn = task.interval - daysSinceLastRoutine(task)
        if dueIn == 0 { return "Due Today" }

        let overdueDays = max(-dueIn, 1)
        let dayWord = overdueDays == 1 ? "day" : "days"
        return "Overdue by \(overdueDays) \(dayWord)"
    }
}
