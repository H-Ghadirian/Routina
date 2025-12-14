import ComposableArchitecture
import CoreData
import SwiftUI

struct HomeTCAView: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        WithPerceptionTracking {
            NavigationView {
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
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            store.send(.setAddRoutineSheet(true))
                        } label: {
                            Label("Add Routine", systemImage: "plus")
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
                .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
                    store.send(.onAppear)
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("routineDidUpdate"))) { _ in
                    store.send(.onAppear)
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

        if dueIn < 0 { return 3 } // Overdue, highest priority
        if dueIn == 0 { return 2 } // Due today
        if dueIn == 1 { return 1 } // Due tomorrow
        return 0 // Least urgent
    }

    private func listOfSortedTasksView(
        routineDisplays: [HomeFeature.RoutineDisplay],
        routineTasks: [RoutineTask]
    ) -> some View {
        List {
            ForEach(sortedTasks(routineDisplays)) { task in
                NavigationLink(
                    destination:
                        routineDetailTCAView(taskID: task.id, routineTasks: routineTasks)
                ) {
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
            }
            .onDelete { offsets in
                let sorted = sortedTasks(routineDisplays)
                let ids = offsets.compactMap { sorted[$0].id }
                store.send(.deleteTasks(ids))
            }
        }
    }
    
    private func routineDetailTCAView(
        taskID: NSManagedObjectID,
        routineTasks: [RoutineTask]
    ) -> some View {
        Group {
            if let task = routineTasks.first(where: { $0.objectID == taskID }) {
                if let context = task.managedObjectContext {
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
                            $0.managedObjectContext = context
                        }
                    )
                )
                } else {
                    Text("Routine context unavailable")
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Routine not found")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func urgencySquare(for task: HomeFeature.RoutineDisplay) -> some View {
        return Rectangle()
            .fill(urgencyColor(for: task))
            .frame(width: 20, height: 20)
            .cornerRadius(4)
    }

    private func initialLogs(for task: RoutineTask) -> [RoutineLog] {
        let logs = ((task.value(forKey: "logs") as? NSSet)?.allObjects as? [RoutineLog]) ?? []
        return logs.sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
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
