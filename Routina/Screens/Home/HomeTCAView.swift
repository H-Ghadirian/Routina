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
                .task {
                    viewStore.send(.onAppear)
                }
            }
        }
    }

    private func sortedTasks(_ viewStore: ViewStoreOf<HomeFeature>) -> [RoutineTask] {
        viewStore.routineTasks.sorted { task1, task2 in
            urgencyLevel(for: task1) > urgencyLevel(for: task2)
        }
    }

    private func urgencyLevel(for task: RoutineTask) -> Int {
        let daysSinceLastRoutine = Calendar.current.dateComponents([.day], from: task.lastDone ?? Date(), to: Date()).day ?? 0
        let dueIn = Int(task.interval) - daysSinceLastRoutine

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
                        routineDetailTCAView(task: task)
                ) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.name ?? "Unnamed task")
                            if isDoneToday(task) {
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
            .onDelete { viewStore.send(.deleteTask($0)) }
        }
    }
    
    private func routineDetailTCAView(task: RoutineTask) -> some View {
        RoutineDetailTCAView(
            store: Store(
                initialState: RoutineDetailFeature.State(
                    task: task,
                    logs: [], //task.logs,
                    daysSinceLastRoutine: Calendar.current.dateComponents([.day], from: task.lastDone ?? Date(), to: Date()).day ?? 0,
                    overdueDays: max((Calendar.current.dateComponents([.day], from: (Calendar.current.date(byAdding: .day, value: Int(task.interval), to: task.lastDone ?? Date()) ?? Date()), to: Date()).day ?? 0), 0)
                ),
                reducer: { RoutineDetailFeature() }
            )
        )
    }

    private func urgencySquare(for task: RoutineTask) -> some View {
        return Rectangle()
            .fill(urgencyColor(for: task))
            .frame(width: 20, height: 20)
            .cornerRadius(4)
    }

    private func isDoneToday(_ task: RoutineTask) -> Bool {
        let logs = ((task.value(forKey: "logs") as? NSSet)?.allObjects as? [RoutineLog]) ?? []
        return logs.contains {
            guard let timestamp = $0.timestamp else { return false }
            return Calendar.current.isDateInToday(timestamp)
        }
    }

    private func urgencyColor(for task: RoutineTask) -> Color {
        let progress = Double(daysSinceLastRoutine(task)) / Double(task.interval)
        switch progress {
        case ..<0.75: return .green
        case ..<0.90: return .orange
        default: return .red
        }
    }

    private func isYellowUrgency(_ task: RoutineTask) -> Bool {
        let progress = Double(daysSinceLastRoutine(task)) / Double(task.interval)
        return progress >= 0.75 && progress < 0.90
    }

    private func daysSinceLastRoutine(_ task: RoutineTask) -> Int {
        Calendar.current.dateComponents([.day], from: task.lastDone ?? Date(), to: Date()).day ?? 0
    }

    private func daysToDueDate(_ task: RoutineTask) -> Int {
        max(Int(task.interval) - daysSinceLastRoutine(task), 0)
    }
}
