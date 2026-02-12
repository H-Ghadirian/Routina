import ComposableArchitecture
import CoreData
import SwiftUI

struct HomeTCAView: View {
    let store: StoreOf<HomeFeature>
    @State private var showingAddRoutine = false

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationView {
                Group {
                    if viewStore.routineTasks.isEmpty {
                        Text("No routine defined yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        listOfSortedTasksView(viewStore)
                    }
                }
                .navigationTitle("Routina")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            viewStore.send(.setAddRoutineSheet(true))
                        } label: {
                            Label("Add Routine", systemImage: "plus")
                        }
                    }
                }
                .sheet(
                    isPresented: viewStore.binding(
                        get: \.isAddRoutineSheetPresented,
                        send: HomeFeature.Action.setAddRoutineSheet
                    )
                ) {
                    IfLetStore(
                        self.store.scope(
                            state: \.addRoutineState,
                            action: \.addRoutineSheet
                        ),
                        then: AddRoutineTCAView.init(store:)
                    )
                }
                .onAppear {
                    viewStore.send(.onAppear)
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
                    viewStore.send(.onAppear)
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("routineDidUpdate"))) { _ in
                    viewStore.send(.onAppear)
                }
            }
        }
    }

    private func sortedTasks(_ viewStore: ViewStoreOf<HomeFeature>) -> [HomeFeature.RoutineDisplay] {
        viewStore.routineDisplays.sorted { task1, task2 in
            urgencyLevel(for: task1) > urgencyLevel(for: task2)
        }
    }

    private func urgencyLevel(for task: HomeFeature.RoutineDisplay) -> Int {
        let dueIn = task.interval - daysSinceLastRoutine(task)

        if dueIn <= 0 { return 3 } // Overdue, highest priority
        if dueIn == 1 { return 2 } // Due today
        if dueIn == 2 { return 1 } // Due tomorrow
        return 0 // Least urgent
    }

    private func listOfSortedTasksView(_ viewStore: ViewStoreOf<HomeFeature>) -> some View {
        List {
            ForEach(sortedTasks(viewStore)) { task in
                NavigationLink(
                    destination:
                        routineDetailTCAView(taskID: task.id, viewStore: viewStore)
                ) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(task.emoji) \(task.name)")
                            if task.isDoneToday {
                                Text("Done today")
                                    .font(.caption)
                                    .foregroundColor(.green)
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
                let sorted = sortedTasks(viewStore)
                let ids = offsets.compactMap { sorted[$0].id }
                viewStore.send(.deleteTasks(ids))
            }
        }
    }
    
    private func routineDetailTCAView(taskID: NSManagedObjectID, viewStore: ViewStoreOf<HomeFeature>) -> some View {
        Group {
            if let task = viewStore.routineTasks.first(where: { $0.objectID == taskID }) {
                RoutineDetailTCAView(
                    store: Store(
                        initialState: RoutineDetailFeature.State(
                            task: task,
                            logs: initialLogs(for: task),
                            daysSinceLastRoutine: Calendar.current.dateComponents([.day], from: task.lastDone ?? Date(), to: Date()).day ?? 0,
                            overdueDays: max((Calendar.current.dateComponents([.day], from: (Calendar.current.date(byAdding: .day, value: Int(task.interval), to: task.lastDone ?? Date()) ?? Date()), to: Date()).day ?? 0), 0),
                            isDoneToday: task.lastDone.map { Calendar.current.isDateInToday($0) } ?? false
                        ),
                        reducer: { RoutineDetailFeature() }
                    )
                )
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

    private func daysSinceLastRoutine(_ task: HomeFeature.RoutineDisplay) -> Int {
        Calendar.current.dateComponents([.day], from: task.lastDone ?? Date(), to: Date()).day ?? 0
    }

    private func daysToDueDate(_ task: HomeFeature.RoutineDisplay) -> Int {
        max(task.interval - daysSinceLastRoutine(task), 0)
    }
}
